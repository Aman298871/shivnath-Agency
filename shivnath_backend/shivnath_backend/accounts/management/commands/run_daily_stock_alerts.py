from django.core.management.base import BaseCommand
from datetime import datetime
from accounts.services import trigger_daily_low_stock_alerts


class Command(BaseCommand):
    help = "Run the daily low-stock alert engine to dispatch targeted alerts (Customer, Serving Franchise, Admin)"

    def add_arguments(self, parser):
        parser.add_argument(
            '--date',
            type=str,
            help='Optional target date in YYYY-MM-DD format for simulation/testing',
        )

    def handle(self, *args, **options):
        target_date = None
        date_str = options.get('date')
        if date_str:
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                self.stderr.write(self.style.ERROR(f"Invalid date format: {date_str}. Use YYYY-MM-DD."))
                return

        self.stdout.write(self.style.NOTICE(f"Running daily stock alert job for date: {target_date or 'Today'}..."))
        dispatched = trigger_daily_low_stock_alerts(target_date=target_date)
        count = len(dispatched)
        self.stdout.write(self.style.SUCCESS(f"Successfully processed stock cycles. {count} low-stock alert batch(es) dispatched."))
        for item in dispatched:
            self.stdout.write(f" - Cycle #{item['cycle_id']}: {item['customer']} ({item['days_remaining']} days left) -> {item['serving_franchise']}")
