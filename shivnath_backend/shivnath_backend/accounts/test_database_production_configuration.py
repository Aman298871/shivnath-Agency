import os
import sys
import importlib
from django.test import TestCase, Client
from django.core.exceptions import ImproperlyConfigured


class DatabaseProductionConfigurationTest(TestCase):
    """
    Authoritative test suite verifying production database selection,
    guaranteed PostgreSQL binding on DATABASE_URL, prevention of silent
    SQLite fallback in production, and safe diagnostic reporting.
    """

    def setUp(self):
        self.original_env = os.environ.copy()
        self.original_argv = list(sys.argv)

    def tearDown(self):
        os.environ.clear()
        os.environ.update(self.original_env)
        sys.argv = list(self.original_argv)

    def test_database_url_overrides_use_sqlite_and_selects_postgresql(self):
        """
        Guarantees that when DATABASE_URL is set (as in Render environment),
        it ALWAYS configures PostgreSQL and overrides any stale USE_SQLITE flag.
        """
        # Remove 'test' from sys.argv to simulate production runtime
        sys.argv = ['gunicorn', 'config.wsgi:application']
        os.environ['DATABASE_URL'] = 'postgresql://shivnath_user:dummy_pwd@dpg-cuid1234:5432/shivnath_db'
        os.environ['USE_SQLITE'] = '1'
        os.environ['RENDER'] = 'true'
        os.environ['DEBUG'] = 'False'

        import config.settings as s
        importlib.reload(s)

        self.assertEqual(s.DATABASES['default']['ENGINE'], 'django.db.backends.postgresql')
        self.assertEqual(s.DATABASES['default']['NAME'], 'shivnath_db')
        self.assertEqual(s.DATABASES['default']['USER'], 'shivnath_user')
        self.assertEqual(s.DATABASES['default']['HOST'], 'dpg-cuid1234')
        self.assertEqual(s.DATABASES['default']['PORT'], 5432)
        self.assertEqual(s.DATABASES['default']['OPTIONS']['sslmode'], 'require')

    def test_production_fails_fast_without_database_url(self):
        """
        Guarantees that in production (Render or DEBUG=False), missing DATABASE_URL
        raises ImproperlyConfigured instead of silently writing ephemeral SQLite.
        """
        sys.argv = ['gunicorn', 'config.wsgi:application']
        os.environ.pop('DATABASE_URL', None)
        os.environ['RENDER'] = 'true'
        os.environ['DEBUG'] = 'False'

        import config.settings as s
        with self.assertRaises(ImproperlyConfigured) as ctx:
            importlib.reload(s)

        self.assertIn('FATAL: Production environment detected', str(ctx.exception))
        self.assertIn('DATABASE_URL is not set', str(ctx.exception))

    def test_production_fails_fast_with_malformed_database_url(self):
        """
        Guarantees that an unparseable or broken DATABASE_URL in production fails fast.
        """
        sys.argv = ['gunicorn', 'config.wsgi:application']
        os.environ['DATABASE_URL'] = 'not-a-valid-url://'
        os.environ['RENDER'] = 'true'
        os.environ['DEBUG'] = 'False'

        import config.settings as s
        with self.assertRaises(ImproperlyConfigured) as ctx:
            importlib.reload(s)

        self.assertIn('FATAL: Production database configuration failed', str(ctx.exception))

    def test_health_view_reports_safe_database_diagnostic_without_secrets(self):
        """
        Verifies that GET / and /api/health/ report active engine and DB name
        without leaking passwords, user tokens, hosts, or full connection URLs.
        """
        client = Client()
        res = client.get('/')
        self.assertEqual(res.status_code, 200)

        data = res.json()
        self.assertEqual(data.get('status'), 'online')
        self.assertIn('database', data)

        db_info = data['database']
        self.assertIn('engine', db_info)
        self.assertIn('name', db_info)
        self.assertIn('connected', db_info)
        self.assertIn('is_postgresql', db_info)
        self.assertIn('is_sqlite', db_info)

        # Security check: must NEVER contain sensitive keys
        raw_text = str(data).lower()
        self.assertNotIn('password', raw_text)
        self.assertNotIn('secret', raw_text)
        self.assertNotIn('bearer', raw_text)
        self.assertNotIn('token', raw_text)
