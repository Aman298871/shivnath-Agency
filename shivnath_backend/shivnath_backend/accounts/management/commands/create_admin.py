import os
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from accounts.models import UserProfile

class Command(BaseCommand):
    help = 'Automatically create or update the default superuser accounts.'

    def handle(self, *args, **options):
        default_pwd = os.getenv('ADMIN_PASSWORD', os.getenv('DJANGO_SUPERUSER_PASSWORD', 'shivnath12')).strip()

        admins = [
            {'email': 'admin@gmail.com', 'username': 'admin@gmail.com', 'name': 'Super Admin'},
            {'email': 'admin@shivnath.com', 'username': 'admin@shivnath.com', 'name': 'Shivnath Admin'},
        ]

        for adm in admins:
            user, created = User.objects.get_or_create(
                email__iexact=adm['email'],
                defaults={
                    'username': adm['username'],
                    'email': adm['email'],
                    'is_staff': True,
                    'is_superuser': True,
                    'first_name': adm['name'],
                }
            )
            user.username = adm['username']
            user.email = adm['email']
            user.is_staff = True
            user.is_superuser = True
            user.set_password(default_pwd)
            user.save()

            profile, _ = UserProfile.objects.get_or_create(
                user=user,
                defaults={'role': 'super_admin', 'name': adm['name'], 'status': 'active'}
            )
            profile.role = 'super_admin'
            profile.status = 'active'
            profile.save()

            action = 'created' if created else 'updated'
            self.stdout.write(self.style.SUCCESS(f'Successfully {action} superuser "{adm["email"]}" with password "{default_pwd}".'))

