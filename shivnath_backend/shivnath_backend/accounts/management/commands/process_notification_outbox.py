import time
import signal
import sys
import logging
from django.core.management.base import BaseCommand
from accounts.fcm_services import process_notification_outbox

logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Process pending and retryable notification outbox items with self-healing recovery.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--once',
            action='store_true',
            help='Run a single sweep batch and exit immediately.',
        )
        parser.add_argument(
            '--continuous',
            action='store_true',
            help='Run continuously as a standing background worker.',
        )
        parser.add_argument(
            '--interval',
            type=int,
            default=15,
            help='Poll interval in seconds for continuous mode (default: 15s).',
        )
        parser.add_argument(
            '--batch-size',
            type=int,
            default=50,
            help='Max records to process per iteration (default: 50).',
        )
        parser.add_argument(
            '--stale-timeout',
            type=int,
            default=5,
            help='Minutes to consider a locked PROCESSING record stale and recover it (default: 5m).',
        )

    def handle(self, *args, **options):
        once = options.get('once')
        continuous = options.get('continuous')
        interval = options.get('interval', 15)
        batch_size = options.get('batch_size', 50)
        stale_timeout = options.get('stale_timeout', 5)

        if once or not continuous:
            self.stdout.write(self.style.NOTICE("FCM Outbox: Running single sweep..."))
            stats = process_notification_outbox(batch_size=batch_size, stale_timeout_minutes=stale_timeout)
            self.stdout.write(self.style.SUCCESS(
                f"FCM Outbox sweep completed: Processed={stats['processed']}, "
                f"Delivered={stats['delivered']}, Retried={stats['retried']}, "
                f"Failed={stats['failed']}, StaleRecovered={stats['stale_recovered']}"
            ))
            return

        self.stdout.write(self.style.SUCCESS(
            f"FCM Outbox Worker started in continuous mode (Interval: {interval}s, Batch: {batch_size}, StaleTimeout: {stale_timeout}m)."
        ))

        running = True
        def _handle_exit(signum, frame):
            nonlocal running
            self.stdout.write(self.style.WARNING("\nFCM Outbox Worker: Graceful shutdown signal received..."))
            running = False

        signal.signal(signal.SIGINT, _handle_exit)
        signal.signal(signal.SIGTERM, _handle_exit)

        while running:
            try:
                stats = process_notification_outbox(batch_size=batch_size, stale_timeout_minutes=stale_timeout)
                if stats['processed'] > 0 or stats['stale_recovered'] > 0:
                    self.stdout.write(
                        f"FCM Outbox [{time.strftime('%Y-%m-%d %H:%M:%S')}]: "
                        f"Processed={stats['processed']}, Delivered={stats['delivered']}, "
                        f"Retried={stats['retried']}, Failed={stats['failed']}, StaleRecovered={stats['stale_recovered']}"
                    )
            except Exception as e:
                self.stderr.write(self.style.ERROR(f"FCM Outbox Worker error: {e}"))
                logger.error("FCM Outbox Worker loop exception: %s", e, exc_info=True)

            # Sleep in 1-second chunks to respond quickly to shutdown signals
            for _ in range(interval):
                if not running:
                    break
                time.sleep(1)

        self.stdout.write(self.style.SUCCESS("FCM Outbox Worker stopped cleanly."))

