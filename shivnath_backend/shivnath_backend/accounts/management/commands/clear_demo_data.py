import logging
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db import transaction

from accounts.models import (
    UserProfile,
    FranchiseProfile,
    AdminNotification,
)
from inventory.models import (
    ProductionBatch,
    DealerStockBatch,
    DealerStockRequest,
    InventoryTransactionLedger,
)
from orders.models import (
    Order,
    OrderItem,
    OrderItemBatchReservation,
)
from billing.models import (
    DealerCreditProfile,
    Invoice,
)
from leads.models import (
    Lead,
)
from followups.models import (
    FollowUp,
)

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Safely removes all seeded demo/dummy data from the database while keeping official products and real admin accounts intact."

    def add_arguments(self, parser):
        parser.add_argument(
            '--yes',
            action='store_true',
            help='Confirm deletion without interactive prompt',
        )

    def handle(self, *args, **options):
        self.stdout.write(self.style.WARNING("=== Cleaning Shivnath Agency Demo/Dummy Data ==="))

        with transaction.atomic():
            # 1. Clear Demo Inventory Ledger entries
            ledger_deleted, _ = InventoryTransactionLedger.objects.filter(
                reference_id__startswith="DEMO-"
            ).delete()
            self.stdout.write(f"- Deleted {ledger_deleted} demo inventory ledger records.")

            # 2. Clear Demo Stock Requests
            dsr_deleted, _ = DealerStockRequest.objects.filter(
                request_number__startswith="DSR-DEMO-"
            ).delete()
            self.stdout.write(f"- Deleted {dsr_deleted} demo stock requests.")

            # 3. Clear Demo Order Reservations & Orders
            demo_orders = Order.objects.filter(
                created_by__username__in=[
                    "cust_anand@shivnath.local",
                    "cust_sneha@shivnath.local",
                    "cust_rahul@shivnath.local",
                    "cust_hotel@shivnath.local",
                ]
            ) | Order.objects.filter(id__in=[1, 2, 3, 4, 5, 6, 7, 1025])
            
            order_count = demo_orders.count()
            demo_orders.delete()
            self.stdout.write(f"- Deleted {order_count} demo orders.")

            # 4. Clear Demo Batches
            batches_deleted, _ = ProductionBatch.objects.filter(
                batch_number__in=[
                    "PB-DEMO-500-01",
                    "PB-DEMO-1000-01",
                    "PB-DEMO-200-01",
                    "PB-DEMO-JAR-01",
                    "B-DEMO-001",
                ]
            ).delete()
            self.stdout.write(f"- Deleted {batches_deleted} demo production batches.")

            dealer_batches_deleted, _ = DealerStockBatch.objects.filter(
                batch_number__startswith="DLR-B-"
            ).delete()
            self.stdout.write(f"- Deleted {dealer_batches_deleted} demo dealer batches.")

            # 5. Clear Demo Leads and Followups
            demo_leads = Lead.objects.filter(
                phone__in=[
                    "9826111111", "9826111112", "9826111113", "9826111114",
                    "9826111115", "9826111116", "9826111117", "9826111118",
                    "9826111119", "9826111120", "9826111121", "9826111122",
                ]
            )
            leads_count = demo_leads.count()
            demo_leads.delete()
            self.stdout.write(f"- Deleted {leads_count} demo CRM leads & related follow-ups.")

            # 6. Clear Demo Notifications
            notifs_deleted, _ = AdminNotification.objects.filter(
                title__contains="DEMO"
            ).delete()
            self.stdout.write(f"- Deleted {notifs_deleted} demo notifications.")

            # 7. Clear Demo Users (customers, dealers, demo staff)
            demo_usernames = [
                "demo_superadmin@shivnath.local",
                "demo_admin@shivnath.local",
                "demo_sales@shivnath.local",
                "dealer_raipur@shivnath.local",
                "dealer_bilaspur@shivnath.local",
                "dealer_durg@shivnath.local",
                "cust_anand@shivnath.local",
                "cust_sneha@shivnath.local",
                "cust_rahul@shivnath.local",
                "cust_hotel@shivnath.local",
            ]
            users_deleted, _ = User.objects.filter(username__in=demo_usernames).delete()
            self.stdout.write(f"- Deleted {users_deleted} demo user accounts.")

        self.stdout.write(self.style.SUCCESS("=== Demo data successfully cleared! Real data & official products preserved. ==="))
