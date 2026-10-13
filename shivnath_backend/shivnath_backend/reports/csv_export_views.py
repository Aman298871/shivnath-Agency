"""
Authoritative Report CSV Export Views for WATERNow / Shivnath Agency.
Provides streaming/buffered CSV exports with:
- Formula injection prevention (prefixing dangerous characters =, +, -, @, \\t, \\r with ')
- UTF-8 BOM (\\ufeff) for clean rendering in Microsoft Excel, LibreOffice, and Google Sheets
- Proper HTTP headers (text/csv; charset=utf-8, Content-Disposition: attachment; filename="...")
- Server-side role and territory access control (Admin vs Franchise vs Customer)
- Complete datasets (matching all active filters, not paginated slices)
"""

import csv
from datetime import date, datetime, timedelta
from decimal import Decimal
from django.db.models import Q, Sum
from django.http import HttpResponse, HttpResponseForbidden, HttpResponseBadRequest
from django.utils import timezone
from django.views import View
from rest_framework.permissions import IsAuthenticated
from rest_framework.views import APIView

from accounts.models import FranchiseProfile, UserProfile, ServiceZone
from billing.models import Invoice, PaymentTransaction, DealerCreditProfile
from inventory.models import (
    DealerStockRequest,
    ProductionBatch,
    DealerStockBatch,
    RawMaterial,
    DailyBusinessReport,
)
from leads.models import Lead
from orders.models import Order, OrderItem, Wallet, WalletTransaction
from products.models import Product


def sanitize_csv_cell(val):
    """
    Prevents CSV Formula Injection (CWE-1236).
    If a cell value starts with dangerous spreadsheet formula characters
    (=, +, -, @, \\t, \\r), prefix it with a single quote (').
    """
    if val is None:
        return ""
    if isinstance(val, (int, float, Decimal)):
        return val
    s = str(val)
    if s and s[0] in ('=', '+', '-', '@', '\t', '\r'):
        return "'" + s
    stripped = s.strip()
    if stripped and stripped[0] in ('=', '+', '-', '@'):
        return "'" + stripped
    return stripped


def parse_date_filters(request):
    """
    Extracts start_date and end_date from request query parameters.
    Supports period presets and custom start_date / end_date.
    """
    today = timezone.now().date()
    period = (request.query_params.get('period') or '').strip().lower()
    start_date_str = request.query_params.get('start_date')
    end_date_str = request.query_params.get('end_date')

    start_date = None
    end_date = None

    if period in ['all', 'all_time', 'lifetime']:
        start_date = date(2020, 1, 1)
        end_date = today + timedelta(days=365)
    elif period == 'today':
        start_date = today
        end_date = today
    elif period == 'yesterday':
        start_date = today - timedelta(days=1)
        end_date = today - timedelta(days=1)
    elif period in ['this_week', 'this week', 'week']:
        start_date = today - timedelta(days=today.weekday())
        end_date = today
    elif period in ['this_month', 'this month', 'month']:
        start_date = today.replace(day=1)
        end_date = today
    elif period in ['last_month', 'last month']:
        first_this_month = today.replace(day=1)
        last_day_last_month = first_this_month - timedelta(days=1)
        start_date = last_day_last_month.replace(day=1)
        end_date = last_day_last_month
    elif period in ['last_3_months', 'last 3 months']:
        start_date = (today.replace(day=1) - timedelta(days=60)).replace(day=1)
        end_date = today
    elif period in ['this_year', 'this year']:
        start_date = today.replace(month=1, day=1)
        end_date = today
    elif start_date_str and end_date_str:
        try:
            start_date = date.fromisoformat(start_date_str.split('T')[0])
            end_date = date.fromisoformat(end_date_str.split('T')[0])
        except Exception:
            pass

    if not start_date:
        start_date = today.replace(day=1)
    if not end_date:
        end_date = today

    return start_date, end_date


class ExportReportCSVView(APIView):
    """
    Enterprise-grade CSV export API for Shivnath Agency / WATERNow.
    Accepts report_type, date filters, status, and entity filters.
    Returns text/csv with UTF-8 BOM and sanitized cells.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request, report_type=None):
        user = request.user
        rep_type = (report_type or request.query_params.get('report_type') or 'comprehensive').strip().lower()

        # Authorization check
        is_admin = user.is_staff or user.is_superuser
        franchise_profile = None

        if hasattr(user, 'franchise_profile'):
            franchise_profile = user.franchise_profile
        elif not is_admin:
            # Check if user profile has franchise role
            try:
                prof = user.profile
                if prof.role == 'franchise':
                    franchise_profile = FranchiseProfile.objects.filter(user=user).first()
            except Exception:
                pass

        if not is_admin and not franchise_profile:
            return HttpResponseForbidden("Access Denied: Only Administrators and Franchise Partners may export business reports.")

        start_date, end_date = parse_date_filters(request)
        today_str = timezone.now().strftime('%Y-%m-%d')
        filename = f"waternow_{rep_type}_{today_str}.csv"

        response = HttpResponse(content_type='text/csv; charset=utf-8')
        response['Content-Disposition'] = f'attachment; filename="{filename}"'

        # UTF-8 BOM for Microsoft Excel compatibility
        response.write('\ufeff'.encode('utf-8'))
        writer = csv.writer(response)

        # Route to appropriate report generator
        if rep_type in ['orders', 'customer_orders']:
            self._export_orders(writer, request, is_admin, franchise_profile, start_date, end_date)
        elif rep_type in ['sales_revenue', 'sales', 'revenue', 'pl']:
            self._export_sales_revenue(writer, request, is_admin, franchise_profile, start_date, end_date)
        elif rep_type in ['inventory', 'stock']:
            self._export_inventory(writer, request, is_admin, franchise_profile, start_date, end_date)
        elif rep_type in ['stock_requests', 'dealer_requests', 'franchise_requests']:
            self._export_stock_requests(writer, request, is_admin, franchise_profile, start_date, end_date)
        elif rep_type in ['directory', 'users', 'customers', 'franchises']:
            if not is_admin:
                return HttpResponseForbidden("Access Denied: User Directory export requires Administrative privileges.")
            self._export_directory(writer, request)
        elif rep_type in ['payments', 'wallet', 'refunds', 'transactions']:
            self._export_payments_wallet(writer, request, is_admin, franchise_profile, start_date, end_date)
        elif rep_type in ['production', 'bom', 'raw_materials']:
            if not is_admin:
                return HttpResponseForbidden("Access Denied: Production & BOM reports are restricted to Central Plant Admins.")
            self._export_production_bom(writer, request, start_date, end_date)
        else:
            # Comprehensive Business Summary Report (Default)
            self._export_comprehensive(writer, request, is_admin, franchise_profile, start_date, end_date)

        return response

    # =========================================================================
    # 1. ORDERS REPORT
    # =========================================================================
    def _export_orders(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        qs = Order.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('created_by', 'serving_franchise', 'registered_franchise', 'zone').prefetch_related('items__product').order_by('-created_at')

        # Role scoping
        if not is_admin and franchise_profile:
            qs = qs.filter(
                Q(serving_franchise=franchise_profile) |
                Q(registered_franchise=franchise_profile)
            )

        # Optional filters
        status = request.query_params.get('status')
        if status and status.lower() != 'all':
            qs = qs.filter(status__iexact=status)

        product_sku = request.query_params.get('product_sku') or request.query_params.get('product')
        if product_sku:
            qs = qs.filter(
                Q(items__product__sku__iexact=product_sku) |
                Q(items__product_name__icontains=product_sku)
            ).distinct()

        franchise_id = request.query_params.get('franchise_id')
        if is_admin and franchise_id and franchise_id.isdigit():
            qs = qs.filter(serving_franchise_id=int(franchise_id))

        search = request.query_params.get('search')
        if search:
            s = search.strip()
            clean_s = s.replace('ORD-', '').replace('#', '')
            qs = qs.filter(
                Q(id=clean_s if clean_s.isdigit() else -1) |
                Q(client_name__icontains=s) |
                Q(franchise_name__icontains=s) |
                Q(city__icontains=s) |
                Q(created_by__username__icontains=s) |
                Q(created_by__first_name__icontains=s)
            )

        # Header
        headers = [
            'Order Code',
            'Order Date & Time',
            'Customer Name',
            'Customer Phone',
            'Customer Email',
            'Fulfillment Source',
            'Serving Franchise',
            'City',
            'Territory / Zone',
            'Delivery Address',
            'Items Summary',
            'Total Quantity',
            'Subtotal (INR)',
            'Tax Amount (INR)',
            'Grand Total (INR)',
            'Payment Mode',
            'Payment Status',
            'Order Status',
            'Duration Plan',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        for o in qs:
            items_list = list(o.items.all())
            items_summary = "; ".join([f"{it.product_name} (x{it.quantity})" for it in items_list]) if items_list else f"{o.items_count} items"
            total_qty = sum(it.quantity for it in items_list) or o.items_count

            cust_phone = ""
            cust_email = ""
            if o.created_by:
                cust_email = o.created_by.email or ""
                try:
                    cust_phone = o.created_by.profile.phone or ""
                except Exception:
                    pass

            source_display = "Direct Company (Central Plant)" if o.order_source == 'DIRECT_COMPANY' else "Franchise Fulfilled"
            serving_name = o.serving_franchise.business_name if o.serving_franchise else ("Shivnath Agency (Direct)" if o.order_source == 'DIRECT_COMPANY' else o.franchise_name)
            zone_name = o.zone.name if o.zone else (o.territory or "")

            row = [
                o.order_code,
                o.created_at.strftime('%Y-%m-%d %H:%M:%S') if o.created_at else str(o.order_date),
                o.client_name or (o.created_by.get_full_name() if o.created_by else o.franchise_name),
                cust_phone,
                cust_email,
                source_display,
                serving_name,
                o.city,
                zone_name,
                o.delivery_address,
                items_summary,
                total_qty,
                float(o.amount),
                float(o.tax_amount),
                float(o.grand_total or o.amount),
                o.payment_mode,
                o.get_payment_status_display() if hasattr(o, 'get_payment_status_display') else o.payment_status.upper(),
                o.get_status_display() if hasattr(o, 'get_status_display') else o.status,
                o.duration_choice,
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 2. SALES AND REVENUE REPORT
    # =========================================================================
    def _export_sales_revenue(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        qs = Order.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('created_by', 'serving_franchise', 'invoice').order_by('-created_at')

        if not is_admin and franchise_profile:
            qs = qs.filter(serving_franchise=franchise_profile)

        headers = [
            'Reporting Period',
            'Order / Invoice Code',
            'Order Date',
            'Customer / Client',
            'Fulfillment Source',
            'Serving Franchise',
            'Order Status',
            'Delivered / Completed',
            'Revenue Recognized (Accounting)',
            'Net Sales / Subtotal (INR)',
            'CGST (INR)',
            'SGST (INR)',
            'Total Tax (INR)',
            'Grand Total (INR)',
            'Amount Paid (INR)',
            'Outstanding (INR)',
            'Payment Mode',
            'Payment Status',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        period_label = f"{start_date.isoformat()} to {end_date.isoformat()}"

        for o in qs:
            is_delivered = o.status in ['delivered', 'DELIVERED', 'Delivered']
            is_cancelled = o.status in ['cancelled', 'CANCELLED', 'Cancelled']
            # Authoritative Revenue Recognition: Only delivered orders count as earned revenue
            rev_recognized = "YES - DELIVERED" if is_delivered else ("NO - CANCELLED" if is_cancelled else "NO - PENDING FULFILLMENT")

            inv = getattr(o, 'invoice', None)
            cgst = float(inv.cgst_amount) if inv else 0.0
            sgst = float(inv.sgst_amount) if inv else 0.0
            tax = float(o.tax_amount or (cgst + sgst))
            subtotal = float(o.amount)
            grand = float(o.grand_total or o.amount)
            paid = float(inv.amount_paid) if inv else (grand if o.payment_status == 'paid' else 0.0)
            out = max(0.0, grand - paid)

            serving_name = o.serving_franchise.business_name if o.serving_franchise else "Shivnath Central Plant"

            row = [
                period_label,
                o.order_code,
                o.created_at.strftime('%Y-%m-%d %H:%M') if o.created_at else str(o.order_date),
                o.client_name or (o.created_by.get_full_name() if o.created_by else 'Customer'),
                o.order_source,
                serving_name,
                o.get_status_display() if hasattr(o, 'get_status_display') else o.status,
                "YES" if is_delivered else "NO",
                rev_recognized,
                subtotal,
                cgst,
                sgst,
                tax,
                grand,
                paid,
                out,
                o.payment_mode,
                o.payment_status.upper(),
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 3. INVENTORY REPORT
    # =========================================================================
    def _export_inventory(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        now_str = timezone.now().strftime('%Y-%m-%d %H:%M:%S')

        headers = [
            'Inventory Scope',
            'Location / Facility',
            'Product / Material SKU',
            'Item Name',
            'Batch / Lot #',
            'Category',
            'Unit of Measure',
            'Manufacture Date',
            'Expiry Date',
            'Total Stock Received / Produced',
            'Remaining Current Stock',
            'Reserved Stock',
            'Available Stock',
            'Unit Cost / Transfer Price (INR)',
            'Low Stock Level',
            'Stock Health Status',
            'Report Timestamp',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        today = timezone.now().date()

        # 1. Central Plant Production Batches (Admins only)
        if is_admin:
            batches = ProductionBatch.objects.select_related('product').order_by('-manufacture_date')
            for b in batches:
                is_expired = b.expiry_date and b.expiry_date < today
                status_str = "EXPIRED" if is_expired else b.status
                row = [
                    'Central Plant Finished Goods',
                    'Shivnath Agency Central Plant',
                    b.product.sku if b.product else 'N/A',
                    b.product.name if b.product else 'Bottled Water',
                    b.batch_number,
                    'Finished Water Bottle / Jar',
                    'Pcs / Units',
                    b.manufacture_date.isoformat() if b.manufacture_date else '',
                    b.expiry_date.isoformat() if b.expiry_date else '',
                    b.quantity_produced_units,
                    b.quantity_remaining_company,
                    0,
                    b.quantity_remaining_company,
                    float(b.unit_production_cost or 0.0),
                    100,
                    status_str,
                    now_str,
                ]
                writer.writerow([sanitize_csv_cell(c) for c in row])

            # 2. Raw Materials Master (Admins only)
            rms = RawMaterial.objects.all().order_by('category', 'name')
            for rm in rms:
                is_low = rm.current_stock <= rm.reorder_level
                row = [
                    'Central Plant Raw Material',
                    'Shivnath Agency Central Warehouse',
                    rm.sku,
                    rm.name,
                    'N/A',
                    rm.get_category_display() if hasattr(rm, 'get_category_display') else rm.category,
                    rm.unit_of_measure,
                    '',
                    '',
                    float(rm.current_stock),
                    float(rm.current_stock),
                    0,
                    float(rm.current_stock),
                    float(rm.unit_cost),
                    float(rm.reorder_level),
                    "LOW_STOCK" if is_low else "IN_STOCK",
                    now_str,
                ]
                writer.writerow([sanitize_csv_cell(c) for c in row])

        # 3. Dealer Stock Batches
        dealer_batches = DealerStockBatch.objects.select_related('dealer', 'product').order_by('-created_at')
        if not is_admin and franchise_profile:
            dealer_batches = dealer_batches.filter(dealer=franchise_profile)

        for db in dealer_batches:
            is_expired = db.expiry_date and db.expiry_date < today
            is_low = db.remaining_quantity <= 20
            health = "EXPIRED" if is_expired else ("LOW_STOCK" if is_low else "IN_STOCK")
            row = [
                'Franchise Warehouse Stock',
                db.dealer.business_name if db.dealer else 'Franchise Partner',
                db.product.sku if db.product else 'N/A',
                db.product.name if db.product else 'Water Bottle',
                db.batch_number,
                'Dealer Finished Goods',
                'Pcs / Units',
                db.manufacture_date.isoformat() if db.manufacture_date else '',
                db.expiry_date.isoformat() if db.expiry_date else '',
                db.received_quantity,
                db.remaining_quantity,
                db.reserved_quantity,
                db.available_quantity,
                float(db.unit_transfer_price),
                20,
                health,
                now_str,
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 4. FRANCHISE STOCK REQUESTS REPORT
    # =========================================================================
    def _export_stock_requests(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        qs = DealerStockRequest.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('dealer', 'product', 'approved_by', 'dispatched_by').order_by('-created_at')

        if not is_admin and franchise_profile:
            qs = qs.filter(dealer=franchise_profile)

        headers = [
            'Request #',
            'Request Date & Time',
            'Franchise Name',
            'Contact Person',
            'Phone',
            'City',
            'Territory',
            'Product SKU',
            'Product Name',
            'Requested Qty',
            'Approved Qty',
            'Prepared Qty',
            'Dispatched Qty',
            'Received Qty',
            'Damaged Qty',
            'Pending Qty',
            'Status',
            'Approved By',
            'Received Timestamp',
            'Dealer Notes',
            'Admin Notes',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        for r in qs:
            dealer_name = r.dealer.business_name if r.dealer else 'Franchise'
            contact = r.dealer.user.get_full_name() if (r.dealer and r.dealer.user) else ''
            phone = r.dealer.user.profile.phone if (r.dealer and r.dealer.user and hasattr(r.dealer.user, 'profile')) else ''
            city = r.dealer.city if r.dealer else ''
            territory = r.dealer.territory if r.dealer else ''
            sku = r.product.sku if r.product else ''
            pname = r.product.name if r.product else ''
            pending_qty = max(0, r.requested_quantity - (r.received_quantity or 0))
            app_by = r.approved_by.get_full_name() or r.approved_by.username if r.approved_by else ''

            row = [
                r.request_number,
                r.created_at.strftime('%Y-%m-%d %H:%M:%S') if r.created_at else '',
                dealer_name,
                contact,
                phone,
                city,
                territory,
                sku,
                pname,
                r.requested_quantity,
                r.approved_quantity,
                r.prepared_quantity,
                r.dispatched_quantity,
                r.received_quantity,
                r.damaged_in_transit_quantity,
                pending_qty,
                r.get_status_display() if hasattr(r, 'get_status_display') else r.status,
                app_by,
                r.received_at.strftime('%Y-%m-%d %H:%M:%S') if r.received_at else '',
                r.dealer_notes,
                r.admin_notes,
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 5. USER & FRANCHISE DIRECTORY REPORT
    # =========================================================================
    def _export_directory(self, writer, request):
        from django.contrib.auth.models import User
        role_filter = request.query_params.get('role')

        users = User.objects.all().select_related('profile', 'franchise_profile').order_by('-date_joined')
        if role_filter and role_filter != 'all':
            users = users.filter(profile__role=role_filter)

        headers = [
            'User ID',
            'Code',
            'Role',
            'Full Name',
            'Username',
            'Phone',
            'Email',
            'City',
            'District',
            'Pincode',
            'Zone / Territory',
            'Address',
            'Account Status',
            'Order Count',
            'Serving Franchise',
            'Registration Date',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        for u in users:
            prof = getattr(u, 'profile', None)
            fp = getattr(u, 'franchise_profile', None)
            role = prof.role if prof else ('franchise' if fp else 'customer')

            code = f"CUST-{1000 + u.id}" if role == 'customer' else f"FRAN-{1000 + u.id}"
            name = prof.name if (prof and prof.name) else (u.get_full_name() or u.username)
            phone = prof.phone if prof else ''
            city = prof.city if (prof and prof.city) else (fp.city if fp else '')
            district = prof.district if (prof and prof.district) else (fp.territory if fp and fp.territory else '')
            pincode = prof.pincode if prof else ''
            zone = prof.zone.name if (prof and prof.zone) else (fp.territory if fp else '')
            addr = prof.address if (prof and prof.address) else (fp.address if fp else '')
            status = prof.status if prof else ('active' if u.is_active else 'inactive')
            orders_count = Order.objects.filter(created_by=u).count()

            # Serving franchise for customer
            serving_fran = ""
            if role == 'customer':
                latest_ord = Order.objects.filter(created_by=u).select_related('serving_franchise').order_by('-created_at').first()
                if latest_ord and latest_ord.serving_franchise:
                    serving_fran = latest_ord.serving_franchise.business_name

            row = [
                u.id,
                code,
                role.capitalize(),
                name,
                u.username,
                phone,
                u.email,
                city,
                district,
                pincode,
                zone,
                addr,
                status,
                orders_count,
                serving_fran,
                u.date_joined.strftime('%Y-%m-%d %H:%M'),
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 6. PAYMENTS & WALLET REPORT
    # =========================================================================
    def _export_payments_wallet(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        headers = [
            'Transaction Ref',
            'Date & Time',
            'Source Type',
            'Party Name',
            'Linked Reference',
            'Payment Method',
            'Amount (INR)',
            'Currency',
            'Verified Status',
            'Public Gateway / UTR Ref',
            'Balance After (Wallet)',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        # 1. Invoice Payment Transactions
        txns = PaymentTransaction.objects.filter(
            invoice__issued_at__date__gte=start_date,
            invoice__issued_at__date__lte=end_date
        ).select_related('invoice__order', 'invoice__stock_request').order_by('-id')

        for t in txns:
            order_ref = t.invoice.order.order_code if (t.invoice and t.invoice.order) else (t.invoice.invoice_number if t.invoice else '')
            party = t.invoice.billed_to_name if t.invoice else 'Customer'
            row = [
                t.transaction_number,
                t.invoice.issued_at.strftime('%Y-%m-%d %H:%M') if (t.invoice and t.invoice.issued_at) else '',
                'Invoice Payment',
                party,
                order_ref,
                t.payment_method,
                float(t.amount_paid),
                'INR',
                t.status,
                t.reference_number or t.razorpay_payment_id or '',
                'N/A',
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

        # 2. Wallet Transactions (Credits, debits, refunds)
        wallet_txns = WalletTransaction.objects.filter(
            created_at__date__gte=start_date,
            created_at__date__lte=end_date
        ).select_related('wallet__user').order_by('-created_at')

        if not is_admin and franchise_profile:
            # Franchise cannot view other users' wallets
            wallet_txns = wallet_txns.none()

        for wt in wallet_txns:
            uname = wt.wallet.user.get_full_name() or wt.wallet.user.username if wt.wallet else 'User'
            order_ref = wt.order.order_code if wt.order else (wt.description or '')
            row = [
                wt.transaction_id,
                wt.created_at.strftime('%Y-%m-%d %H:%M:%S') if wt.created_at else '',
                f"Water Wallet ({wt.transaction_type})",
                uname,
                order_ref,
                wt.payment_method or 'WALLET',
                float(wt.amount),
                'INR',
                wt.status,
                wt.razorpay_payment_id or wt.gateway_transaction_id or '',
                float(wt.balance_after),
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 7. PRODUCTION, BOM & RAW MATERIALS REPORT
    # =========================================================================
    def _export_production_bom(self, writer, request, start_date, end_date):
        batches = ProductionBatch.objects.filter(
            manufacture_date__gte=start_date,
            manufacture_date__lte=end_date
        ).select_related('product').order_by('-manufacture_date')

        headers = [
            'Batch #',
            'Product SKU',
            'Product Name',
            'Planned / Produced Qty',
            'Remaining Units',
            'Manufacturing Date',
            'Expiry Date',
            'Unit Production Cost (INR)',
            'Total Batch COGS (INR)',
            'Batch Status',
            'Water Standard',
            'FSSAI Standard',
        ]
        writer.writerow([sanitize_csv_cell(h) for h in headers])

        for b in batches:
            total_cogs = float((b.unit_production_cost or 0) * b.quantity_produced_units)
            row = [
                b.batch_number,
                b.product.sku if b.product else 'N/A',
                b.product.name if b.product else 'Bottled Water',
                b.quantity_produced_units,
                b.quantity_remaining_company,
                b.manufacture_date.isoformat() if b.manufacture_date else '',
                b.expiry_date.isoformat() if b.expiry_date else '',
                float(b.unit_production_cost or 0.0),
                total_cogs,
                b.status,
                'IS 14543 Packaged Drinking Water Compliant',
                'FSSAI Certified Plant Standard',
            ]
            writer.writerow([sanitize_csv_cell(c) for c in row])

    # =========================================================================
    # 8. COMPREHENSIVE BUSINESS REPORT
    # =========================================================================
    def _export_comprehensive(self, writer, request, is_admin, franchise_profile, start_date, end_date):
        period_label = f"{start_date.isoformat()} to {end_date.isoformat()}"
        now_str = timezone.now().strftime('%Y-%m-%d %H:%M:%S')

        writer.writerow([sanitize_csv_cell('SHIVNATH AGENCY / WATERNow - ENTERPRISE BUSINESS REPORT')])
        writer.writerow([sanitize_csv_cell('Period'), sanitize_csv_cell(period_label)])
        writer.writerow([sanitize_csv_cell('Generated At'), sanitize_csv_cell(now_str)])
        writer.writerow([])

        # Section 1: Financial & Operational Summary
        orders_qs = Order.objects.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
        if not is_admin and franchise_profile:
            orders_qs = orders_qs.filter(serving_franchise=franchise_profile)

        deliv_orders = orders_qs.filter(status__in=['delivered', 'DELIVERED', 'Delivered'])
        total_rev = deliv_orders.aggregate(t=Sum('amount'))['t'] or Decimal('0.00')

        stock_reqs_qs = DealerStockRequest.objects.filter(created_at__date__gte=start_date, created_at__date__lte=end_date)
        if not is_admin and franchise_profile:
            stock_reqs_qs = stock_reqs_qs.filter(dealer=franchise_profile)

        writer.writerow([sanitize_csv_cell('--- FINANCIAL & OPERATIONAL SUMMARY ---')])
        writer.writerow([sanitize_csv_cell('Metric'), sanitize_csv_cell('Value')])
        writer.writerow([sanitize_csv_cell('Recognized Delivered Revenue (INR)'), float(total_rev)])
        writer.writerow([sanitize_csv_cell('Total Orders Count'), orders_qs.count()])
        writer.writerow([sanitize_csv_cell('Delivered Orders Count'), deliv_orders.count()])
        writer.writerow([sanitize_csv_cell('Franchise Stock Requests Count'), stock_reqs_qs.count()])
        writer.writerow([])

        # Section 2: Order Activity
        writer.writerow([sanitize_csv_cell('--- MATCHING CUSTOMER ORDERS ---')])
        self._export_orders(writer, request, is_admin, franchise_profile, start_date, end_date)
        writer.writerow([])

        # Section 3: Stock Requests
        writer.writerow([sanitize_csv_cell('--- MATCHING FRANCHISE STOCK REQUESTS ---')])
        self._export_stock_requests(writer, request, is_admin, franchise_profile, start_date, end_date)
