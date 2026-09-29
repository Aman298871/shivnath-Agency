import hashlib
from decimal import Decimal
from datetime import date, timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from django.db.models import Sum
from django.db import transaction, IntegrityError

from accounts.models import Notification, FranchiseProfile, UserProfile
from products.models import Product, ProductStockThreshold
from inventory.models import (
    ProductionBatch,
    DealerStockBatch,
    InventoryTransactionLedger,
    ExpiryAlertLog,
    Expense,
    DailyBusinessReport,
)
from billing.models import Invoice, DealerCreditProfile
from orders.models import Order
from leads.models import Lead, LeadJourneyState
from leads.services import send_lead_journey_step


class Command(BaseCommand):
    help = "Runs automated enterprise ERP/CRM periodic maintenance tasks (FEFO Expiry, Low Stock, Payment Reminders, Lead Journeys, Daily Report)."

    def handle(self, *args, **options):
        self.stdout.write("Running Shivnath Agency ERP/CRM scheduled maintenance tasks...")

        today = timezone.now().date()
        now = timezone.now()

        # =====================================================================
        # 1. 5-TIER BATCH EXPIRY MONITORING WITH HASH DEDUPLICATION
        # =====================================================================
        self.stdout.write("1. Evaluating Batch Expiry Tiers...")
        tiers = [
            (0, '0_DAYS_EXPIRED', 'Batch Expired (Immediate Quarantine Required)'),
            (3, '3_DAYS', '3 Days to Expiry'),
            (7, '7_DAYS', '7 Days to Expiry'),
            (15, '15_DAYS', '15 Days to Expiry'),
            (30, '30_DAYS', '30 Days to Expiry'),
        ]

        # Company Production Batches
        active_company_batches = ProductionBatch.objects.filter(status='ACTIVE', quantity_remaining_company__gt=0)
        for pb in active_company_batches:
            pb_exp = pb.expiry_date
            if isinstance(pb_exp, str):
                try:
                    pb_exp = date.fromisoformat(pb_exp.split('T')[0])
                except Exception:
                    pb_exp = today
            days_left = (pb_exp - today).days
            for threshold_days, level_key, level_label in tiers:
                if (threshold_days == 0 and days_left <= 0) or (threshold_days > 0 and 0 < days_left <= threshold_days):
                    dedup_hash = ExpiryAlertLog.compute_hash('COMPANY', pb.id, level_key)
                    if not ExpiryAlertLog.objects.filter(deduplication_hash=dedup_hash).exists():
                        created_alert = False
                        try:
                            with transaction.atomic():
                                ExpiryAlertLog.objects.create(
                                    batch_type='COMPANY',
                                    production_batch=pb,
                                    alert_level=level_key,
                                    alert_date=today,
                                    deduplication_hash=dedup_hash
                                )
                                created_alert = True
                        except IntegrityError:
                            created_alert = False

                        if created_alert:
                            # Create Notification for Admins
                            Notification.objects.create(
                                role_target='admin',
                                notification_type='EXPIRY_ALERT',
                                title=f"Batch Expiry Alert: {pb.product.name} ({pb.batch_number})",
                                message=f"Company Batch {pb.batch_number} has {days_left} day(s) remaining before expiry ({pb.expiry_date}). Remaining units: {pb.quantity_remaining_company}.",
                                entity_type='PRODUCTION_BATCH',
                                entity_id=pb.id
                            )

                            # If expired, mark batch and log ledger entry
                            if threshold_days == 0 and days_left <= 0:
                                pb.status = 'EXPIRED'
                                pb.save(update_fields=['status'])
                                InventoryTransactionLedger.objects.create(
                                    transaction_type='EXPIRY',
                                    material_type='FINISHED_GOODS',
                                    location_type='COMPANY_WAREHOUSE',
                                    product=pb.product,
                                    production_batch=pb,
                                    quantity=-Decimal(pb.quantity_remaining_company),
                                    balance_after=Decimal('0.00'),
                                    unit_cost_or_price=pb.unit_production_cost,
                                    reference_type='PRODUCTION_BATCH',
                                    reference_id=pb.batch_number,
                                    notes=f"Automated system quarantine upon reaching expiry date {pb.expiry_date}."
                                )
                    break

        # Dealer Stock Batches
        active_dealer_batches = DealerStockBatch.objects.filter(is_active=True, remaining_quantity__gt=0)
        for db in active_dealer_batches:
            db_exp = db.expiry_date
            if isinstance(db_exp, str):
                try:
                    db_exp = date.fromisoformat(db_exp.split('T')[0])
                except Exception:
                    db_exp = today
            days_left = (db_exp - today).days
            for threshold_days, level_key, level_label in tiers:
                if (threshold_days == 0 and days_left <= 0) or (threshold_days > 0 and 0 < days_left <= threshold_days):
                    dedup_hash = ExpiryAlertLog.compute_hash('DEALER', db.id, level_key)
                    if not ExpiryAlertLog.objects.filter(deduplication_hash=dedup_hash).exists():
                        created_dealer_alert = False
                        try:
                            with transaction.atomic():
                                ExpiryAlertLog.objects.create(
                                    batch_type='DEALER',
                                    dealer=db.dealer,
                                    dealer_batch=db,
                                    alert_level=level_key,
                                    alert_date=today,
                                    deduplication_hash=dedup_hash
                                )
                                created_dealer_alert = True
                        except IntegrityError:
                            created_dealer_alert = False

                        if created_dealer_alert:
                            # Notify Dealer
                            if db.dealer.user:
                                Notification.objects.create(
                                    recipient=db.dealer.user,
                                    notification_type='EXPIRY_ALERT',
                                    title=f"Expiry Alert: {db.product.name} Batch {db.batch_number}",
                                    message=f"Your stock batch {db.batch_number} has {days_left} day(s) until expiry ({db.expiry_date}). Remaining stock: {db.remaining_quantity}.",
                                    entity_type='DEALER_STOCK_BATCH',
                                    entity_id=db.id
                                )
                            # Also Notify Admin
                            Notification.objects.create(
                                role_target='admin',
                                notification_type='EXPIRY_ALERT',
                                title=f"Dealer Stock Expiry Alert: {db.dealer.business_name} - {db.product.sku}",
                                message=f"Dealer {db.dealer.business_name} has {db.remaining_quantity} unit(s) of batch {db.batch_number} expiring in {days_left} day(s).",
                                entity_type='DEALER_STOCK_BATCH',
                                entity_id=db.id
                            )
                            if threshold_days == 0 and days_left <= 0:
                                db.is_active = False
                                db.save(update_fields=['is_active'])
                                InventoryTransactionLedger.objects.create(
                                    transaction_type='EXPIRY',
                                    material_type='FINISHED_GOODS',
                                    location_type='DEALER_WAREHOUSE',
                                    dealer=db.dealer,
                                    product=db.product,
                                    dealer_batch=db,
                                    quantity=-Decimal(db.remaining_quantity),
                                    balance_after=Decimal('0.00'),
                                    unit_cost_or_price=db.unit_transfer_price,
                                    reference_type='DEALER_STOCK_BATCH',
                                    reference_id=db.batch_number,
                                    notes=f"Automated dealer inventory quarantine upon reaching expiry date {db.expiry_date}."
                                )
                    break

        # =====================================================================
        # 1.1 PENDING / UNCOLLECTED STOCK EXPIRY MONITORING
        # =====================================================================
        self.stdout.write("1.1 Evaluating Pending Stock Expiry Alerts...")
        from inventory.services import get_pending_stock_expiry_alerts
        from accounts.models import AdminNotification
        pending_alerts = get_pending_stock_expiry_alerts(target_date=today)
        for pa in pending_alerts:
            title = f"⚠️ STOCK EXPIRY ALERT: {pa['product_name']} ({pa['order_number']})"
            msg = (
                f"Dealer/Customer: {pa['dealer_or_customer']}\n"
                f"Order: {pa['order_number']}\n"
                f"Product: {pa['product_name']} ({pa['product_sku']})\n"
                f"Pending Quantity: {pa['pending_quantity']} units "
                f"(Original: {pa['allocated_quantity']}, Collected: {pa['collected_quantity']})\n"
                f"Batch: {pa['batch_number']} | Expiry: {pa['expiry_date']} ({pa['remaining_days']} days remaining)\n"
                f"{pa['warning_message']}"
            )
            existing_notif = AdminNotification.objects.filter(
                notification_type='stock_alert',
                reference_id=pa['order_id'],
                title=title
            ).first()
            if existing_notif:
                existing_notif.message = msg
                existing_notif.save(update_fields=['message'])
            else:
                AdminNotification.objects.create(
                    title=title,
                    message=msg,
                    notification_type='stock_alert',
                    reference_id=pa['order_id']
                )

        # =====================================================================
        # 2. LOW-STOCK THRESHOLD MONITORING
        # =====================================================================
        self.stdout.write("2. Evaluating Low-Stock Thresholds...")
        thresholds = ProductStockThreshold.objects.filter(alert_enabled=True).select_related('product')
        for th in thresholds:
            p = th.product
            # Check company stock
            company_stock = ProductionBatch.objects.filter(
                product=p, status='ACTIVE', quantity_remaining_company__gt=0
            ).aggregate(total=Sum('quantity_remaining_company'))['total'] or 0

            if company_stock <= th.company_low_stock_threshold:
                dedup_key = f"LOW_CO_{p.id}_{today.strftime('%Y%m%d')}"
                if not Notification.objects.filter(title__contains=dedup_key).exists():
                    Notification.objects.create(
                        role_target='admin',
                        notification_type='LOW_STOCK_ALERT',
                        title=f"Company Plant Low Stock: {p.name} [{dedup_key}]",
                        message=f"Central plant stock for {p.name} ({p.sku}) is at {company_stock} units, below minimum threshold ({th.company_low_stock_threshold}). Schedule production batch immediately.",
                        entity_type='PRODUCT',
                        entity_id=p.id
                    )

            # Check each approved dealer stock
            dealers = FranchiseProfile.objects.filter(status='approved')
            for dlr in dealers:
                dlr_stock = DealerStockBatch.objects.filter(
                    dealer=dlr, product=p, is_active=True, remaining_quantity__gt=0
                ).aggregate(total=Sum('remaining_quantity'))['total'] or 0

                if dlr_stock <= th.dealer_low_stock_threshold:
                    dedup_key_dlr = f"LOW_DLR_{dlr.id}_{p.id}_{today.strftime('%Y%m%d')}"
                    if not Notification.objects.filter(title__contains=dedup_key_dlr).exists():
                        if dlr.user:
                            Notification.objects.create(
                                recipient=dlr.user,
                                notification_type='LOW_STOCK_ALERT',
                                title=f"Low Stock Warning: {p.name} [{dedup_key_dlr}]",
                                message=f"Your local inventory for {p.name} is down to {dlr_stock} units (threshold: {th.dealer_low_stock_threshold}). Please place a stock request.",
                                entity_type='PRODUCT',
                                entity_id=p.id
                            )

        # =====================================================================
        # 3. DEALER PAYMENT & OVERDUE REMINDERS
        # =====================================================================
        self.stdout.write("3. Checking Dealer Payment Reminders...")
        unpaid_invoices = Invoice.objects.filter(
            invoice_type='DEALER_PURCHASE_INVOICE',
            status__in=['UNPAID', 'PARTIALLY_PAID'],
            due_date__isnull=False
        ).select_related('stock_request__dealer__user')

        for inv in unpaid_invoices:
            due_days = (inv.due_date - today).days
            dealer = inv.stock_request.dealer if inv.stock_request else None
            if not dealer:
                continue

            # Reminder if due in 3 days, or overdue
            if due_days <= 3:
                dedup_tag = f"PAY_REM_{inv.id}_{today.strftime('%Y%m%d')}"
                if not Notification.objects.filter(title__contains=dedup_tag).exists():
                    urgency = "OVERDUE" if due_days < 0 else f"DUE IN {due_days} DAYS"
                    bal = inv.outstanding_balance
                    if dealer.user:
                        Notification.objects.create(
                            recipient=dealer.user,
                            notification_type='PAYMENT_REMINDER',
                            title=f"Invoice Payment {urgency}: {inv.invoice_number} [{dedup_tag}]",
                            message=f"Invoice {inv.invoice_number} has an outstanding balance of ₹{bal:.2f}, due on {inv.due_date}. Please clear payment via UPI or Bank Transfer.",
                            entity_type='INVOICE',
                            entity_id=inv.id
                        )
                    # Notify Admin of overdue invoices
                    if due_days < 0:
                        Notification.objects.create(
                            role_target='admin',
                            notification_type='PAYMENT_REMINDER',
                            title=f"Overdue Dealer Invoice: {dealer.business_name} [{dedup_tag}]",
                            message=f"Dealer {dealer.business_name} ({dealer.dealer_code}) has an overdue invoice {inv.invoice_number} for ₹{bal:.2f} ({abs(due_days)} days overdue).",
                            entity_type='INVOICE',
                            entity_id=inv.id
                        )

        # =====================================================================
        # 4. CRM 15-DAY LEAD NURTURING AUTOMATION
        # =====================================================================
        self.stdout.write("4. Executing Due CRM Lead Journey Steps...")
        active_journeys = LeadJourneyState.objects.filter(
            is_paused=False,
            completed_at__isnull=True
        ).exclude(current_step__gt=6)

        for journey in active_journeys:
            # Check if scheduled step is due
            should_run = False
            if journey.next_scheduled_at:
                should_run = (journey.next_scheduled_at <= now)
            else:
                # Default daily check
                days_since = (now.date() - journey.lead.created_at.date()).days
                if days_since >= journey.scheduled_day_offset:
                    should_run = True

            if should_run:
                try:
                    send_lead_journey_step(journey.id)
                except Exception as e:
                    self.stderr.write(f"Error executing journey for lead {journey.lead_id}: {e}")

        # =====================================================================
        # 5. DAILY BUSINESS REPORT AGGREGATOR
        # =====================================================================
        self.stdout.write("5. Generating Daily Business Report...")
        # Production
        prod_batches_today = ProductionBatch.objects.filter(created_at__date=today)
        prod_units = prod_batches_today.aggregate(u=Sum('quantity_produced_units'))['u'] or 0
        prod_cost = prod_batches_today.aggregate(c=Sum('unit_production_cost'))['c'] or Decimal('0.00')

        # Dispatches to dealers
        dispatches_today = InventoryTransactionLedger.objects.filter(
            transaction_type='STOCK_TRANSFER_OUT',
            timestamp__date=today
        )
        dispatch_units = abs(dispatches_today.aggregate(q=Sum('quantity'))['q'] or 0)

        # Dealer purchase invoices (revenue from wholesale dispatches)
        dealer_invoices = Invoice.objects.filter(
            invoice_type='DEALER_PURCHASE_INVOICE',
            issued_at__date=today
        )
        dealer_rev = dealer_invoices.aggregate(t=Sum('grand_total'))['t'] or Decimal('0.00')

        # Direct Company Orders
        direct_orders = Order.objects.filter(
            order_source='DIRECT_COMPANY',
            created_at__date=today
        ).exclude(status__in=['Cancelled', 'CANCELLED'])
        direct_rev = direct_orders.aggregate(t=Sum('grand_total'))['t'] or Decimal('0.00')

        gross_revenue = dealer_rev + direct_rev

        # COGS
        from orders.models import OrderItem
        from django.db.models import F
        cogs_direct = OrderItem.objects.filter(order__in=direct_orders).aggregate(
            c=Sum(F('snapshot_unit_production_cost') * F('quantity'))
        )['c'] or Decimal('0.00')
        cogs_total = cogs_direct

        # Expenses
        expenses_today = Expense.objects.filter(paid_date=today)
        total_exp = expenses_today.aggregate(a=Sum('amount'))['a'] or Decimal('0.00')

        net_profit = gross_revenue - (cogs_total + total_exp)

        # Leads
        new_leads = Lead.objects.filter(created_at__date=today).count()
        converted_leads = Lead.objects.filter(
            created_at__date=today,
            status__in=['CONVERTED', 'FRANCHISE_CONFIRMED', 'converted', 'franchise_confirmed']
        ).count()

        # Update or create DailyBusinessReport
        dbr, created = DailyBusinessReport.objects.update_or_create(
            report_date=today,
            defaults={
                'total_production_volume_units': int(prod_units),
                'total_production_volume_cases': Decimal(int(prod_units) // 24),
                'total_production_cost_inr': Decimal(str(prod_cost)),
                'total_dealer_dispatch_units': int(dispatch_units),
                'total_dealer_dispatch_cases': Decimal(int(dispatch_units) // 24),
                'total_dealer_sales_revenue_inr': dealer_rev,
                'total_direct_company_revenue_inr': direct_rev,
                'total_gross_revenue_inr': gross_revenue,
                'total_cogs_inr': cogs_total,
                'total_expenses_inr': total_exp,
                'net_profit_inr': net_profit,
                'new_leads_count': new_leads,
                'leads_converted_count': converted_leads,
            }
        )

        self.stdout.write(self.style.SUCCESS(
            f"Scheduled tasks completed successfully. Daily Business Report for {today} generated: "
            f"Rev=Rs.{gross_revenue:.2f}, Expenses=Rs.{total_exp:.2f}, Net=Rs.{net_profit:.2f}."
        ))
