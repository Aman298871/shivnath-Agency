import logging
from django.core.management.base import BaseCommand
from django.db import transaction
from orders.models import Order

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = "Audits and safely repairs historical order records with incorrect customer-to-franchise attribution."

    def add_arguments(self, parser):
        parser.add_argument(
            "--commit",
            action="store_true",
            help="Commit database repairs. Defaults to dry-run mode.",
        )

    def handle(self, *args, **options):
        commit = options.get("commit", False)
        mode_str = "COMMIT MODE" if commit else "DRY-RUN MODE (No changes will be saved)"
        self.stdout.write(self.style.NOTICE(f"=== Order Attribution Audit & Safe Repair: {mode_str} ==="))

        mismatched_orders = []
        orders_qs = Order.objects.select_related("created_by", "serving_franchise", "created_by__profile").all()

        for ord_obj in orders_qs:
            client_name = (ord_obj.client_name or "").strip()
            creator_name = (ord_obj.created_by.get_full_name() or ord_obj.created_by.username) if ord_obj.created_by else ""
            franchise_str = (ord_obj.franchise_name or "").strip()

            is_attributed_to_customer = False
            if franchise_str and (
                (client_name and franchise_str.lower() == client_name.lower()) or
                (creator_name and franchise_str.lower() == creator_name.lower())
            ):
                is_attributed_to_customer = True

            if is_attributed_to_customer:
                if ord_obj.serving_franchise:
                    target_franchise = ord_obj.serving_franchise.business_name
                    target_source = "FRANCHISE"
                else:
                    target_franchise = "Shivnath Central Admin (Direct)"
                    target_source = "DIRECT_COMPANY"

                mismatched_orders.append({
                    "order_id": ord_obj.id,
                    "order_code": ord_obj.order_code,
                    "client_name": client_name or creator_name,
                    "current_franchise": franchise_str,
                    "proposed_franchise": target_franchise,
                    "proposed_source": target_source,
                })

        if not mismatched_orders:
            self.stdout.write(self.style.SUCCESS("Audit clean: No customer-to-franchise misattributions detected!"))
            return

        self.stdout.write(self.style.WARNING(f"Identified {len(mismatched_orders)} misattributed order record(s):"))
        for rec in mismatched_orders:
            self.stdout.write(
                f"  - Order #{rec['order_id']} ({rec['order_code']}): Customer '{rec['client_name']}' was attributed as Franchise '{rec['current_franchise']}'. "
                f"Proposed correction: '{rec['proposed_franchise']}' (Source: {rec['proposed_source']})"
            )

        if commit:
            with transaction.atomic():
                repaired_count = 0
                for rec in mismatched_orders:
                    Order.objects.filter(id=rec["order_id"]).update(
                        franchise_name=rec["proposed_franchise"],
                        order_source=rec["proposed_source"],
                    )
                    repaired_count += 1
                self.stdout.write(self.style.SUCCESS(f"Successfully repaired {repaired_count} order record(s) with full transaction safety."))
        else:
            self.stdout.write(self.style.NOTICE("\nDry run completed. To commit these safe auditable repairs, run: python manage.py audit_order_attribution --commit"))
