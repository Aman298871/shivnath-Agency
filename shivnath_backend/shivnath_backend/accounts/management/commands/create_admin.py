import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from accounts.models import UserProfile

class Command(BaseCommand):
    help = 'Automatically create or update the default superuser from environment variables.'

    def handle(self, *args, **options):
        email = os.getenv('ADMIN_EMAIL', os.getenv('DJANGO_SUPERUSER_EMAIL', 'admin@shivnath.com')).strip()
        username = os.getenv('ADMIN_USERNAME', os.getenv('DJANGO_SUPERUSER_USERNAME', email)).strip()
        password = os.getenv('ADMIN_PASSWORD', os.getenv('DJANGO_SUPERUSER_PASSWORD', 'Shivnath@2026!')).strip()

        user, created = User.objects.get_or_create(
            username=username,
            defaults={'email': email, 'is_staff': True, 'is_superuser': True}
        )

        user.email = email
        user.is_staff = True
        user.is_superuser = True
        user.set_password(password)
        user.save()

        # Ensure UserProfile exists with admin role
        profile, _ = UserProfile.objects.get_or_create(
            user=user,
            defaults={'role': 'admin', 'name': 'Shivnath Admin'}
        )
        profile.role = 'admin'
        profile.save()

        if created:
            self.stdout.write(self.style.SUCCESS(f'Successfully created superuser "{username}".'))
        else:
            self.stdout.write(self.style.SUCCESS(f'Successfully updated superuser "{username}".'))
