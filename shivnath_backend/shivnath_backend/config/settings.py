import os
import sys
from pathlib import Path
from dotenv import load_dotenv
from datetime import timedelta

# --------------------------------------------------
# BASE DIRECTORY
# --------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent

# Load .env file
load_dotenv(BASE_DIR / '.env')


# --------------------------------------------------
# SECURITY
# --------------------------------------------------

SECRET_KEY = os.getenv(
    'SECRET_KEY',
    'django-insecure-development-key'
)

DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'

ALLOWED_HOSTS_ENV = os.getenv('ALLOWED_HOSTS')
if ALLOWED_HOSTS_ENV:
    ALLOWED_HOSTS = [h.strip() for h in ALLOWED_HOSTS_ENV.split(',') if h.strip()]
else:
    ALLOWED_HOSTS = [
        '127.0.0.1',
        'localhost',
        '10.0.2.2',
        '*',
    ]



# --------------------------------------------------
# APPLICATIONS
# --------------------------------------------------

INSTALLED_APPS = [
    'jazzmin',
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third Party
    'rest_framework',
    'corsheaders',

    # Our Apps
    'accounts.apps.AccountsConfig',
    'leads',
    'followups',
    'inventory',
    'products',
    'suppliers',
    'orders',
    'billing',
    'chat',
    'reports',
]


# --------------------------------------------------
# MIDDLEWARE
# --------------------------------------------------

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',

    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]


ROOT_URLCONF = 'config.urls'


# --------------------------------------------------
# TEMPLATES
# --------------------------------------------------

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]


WSGI_APPLICATION = 'config.wsgi.application'


# --------------------------------------------------
# DATABASE CONFIGURATION
# --------------------------------------------------
from django.core.exceptions import ImproperlyConfigured

IS_TESTING = 'test' in sys.argv
IS_RENDER = bool(os.getenv('RENDER') or os.getenv('RENDER_SERVICE_ID'))
IS_PRODUCTION = IS_RENDER or (os.getenv('ENVIRONMENT', '').lower() == 'production') or (not DEBUG)

DATABASE_URL = (
    os.getenv('DATABASE_URL') or
    os.getenv('INTERNAL_DATABASE_URL') or
    os.getenv('POSTGRES_URL') or
    os.getenv('POSTGRESQL_URL') or
    ''
).strip()
USE_SQLITE_ENV = os.getenv('USE_SQLITE', '').strip()

if IS_TESTING:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
elif DATABASE_URL:
    try:
        import dj_database_url
        # Render internal PostgreSQL (dpg-xxxx-a) does not use SSL.
        # Only require SSL if connecting via external domain (.render.com)
        is_external_postgres = 'render.com' in DATABASE_URL and not DATABASE_URL.endswith('-a') and not DATABASE_URL.endswith('-a/')
        has_ssl_query = 'sslmode=' in DATABASE_URL
        should_require_ssl = is_external_postgres and not has_ssl_query

        parsed_db = dj_database_url.parse(
            DATABASE_URL,
            conn_max_age=600,
            conn_health_checks=True,
            ssl_require=should_require_ssl,
        )
        if parsed_db and parsed_db.get('ENGINE'):
            options = dict(parsed_db.get('OPTIONS') or {})
            options.setdefault('connect_timeout', 5)
            parsed_db['OPTIONS'] = options
            DATABASES = {'default': parsed_db}
        else:
            raise ValueError("Failed to parse valid database engine from DATABASE_URL")
    except Exception as e:
        import logging
        logging.getLogger('django').critical(
            f"[DATABASE CONFIG WARNING] Failed parsing DATABASE_URL: {e}. Falling back to SQLite."
        )
        DATABASES = {
            'default': {
                'ENGINE': 'django.db.backends.sqlite3',
                'NAME': BASE_DIR / 'db.sqlite3',
            }
        }
elif USE_SQLITE_ENV == '1' or DEBUG or IS_PRODUCTION:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.getenv('DB_NAME', 'shivnath_agency'),
            'USER': os.getenv('DB_USER', 'postgres'),
            'PASSWORD': os.getenv('DB_PASSWORD', ''),
            'HOST': os.getenv('DB_HOST', '127.0.0.1'),
            'PORT': os.getenv('DB_PORT', '5432'),
        }
    }


# --------------------------------------------------
# PASSWORD VALIDATION
# --------------------------------------------------

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME':
        'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# --------------------------------------------------
# INTERNATIONALIZATION
# --------------------------------------------------

LANGUAGE_CODE = 'en-us'

# India timezone
TIME_ZONE = 'Asia/Kolkata'

USE_I18N = True
USE_TZ = True


# --------------------------------------------------
# STATIC & MEDIA FILES
# --------------------------------------------------

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'


# --------------------------------------------------
# DJANGO REST FRAMEWORK
# --------------------------------------------------

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),

    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=30),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=90),

    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': False,

    'UPDATE_LAST_LOGIN': False,

    'ALGORITHM': 'HS256',
    'SIGNING_KEY': SECRET_KEY,

    'AUTH_HEADER_TYPES': ('Bearer',),
    'AUTH_HEADER_NAME': 'HTTP_AUTHORIZATION',
}

# --------------------------------------------------
# CORS
# --------------------------------------------------

CORS_ALLOW_ALL_ORIGINS = os.getenv('CORS_ALLOW_ALL_ORIGINS', 'True').lower() == 'true'
cors_origins_env = os.getenv('CORS_ALLOWED_ORIGINS')
if cors_origins_env:
    CORS_ALLOWED_ORIGINS = [o.strip() for o in cors_origins_env.split(',') if o.strip()]


# --------------------------------------------------
# PRODUCTION SECURITY
# --------------------------------------------------

if not DEBUG:
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    if os.getenv('SECURE_SSL_REDIRECT', 'False').lower() == 'true':
        SECURE_SSL_REDIRECT = True
        SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
        SESSION_COOKIE_SECURE = True
        CSRF_COOKIE_SECURE = True
    if os.getenv('SECURE_HSTS', 'False').lower() == 'true':
        SECURE_HSTS_SECONDS = 31536000  # 1 year
        SECURE_HSTS_INCLUDE_SUBDOMAINS = True
        SECURE_HSTS_PRELOAD = True

# --------------------------------------------------
# RAZORPAY CONFIGURATION
# --------------------------------------------------
RAZORPAY_KEY_ID = os.getenv('RAZORPAY_KEY_ID', 'rzp_live_Tnhqo3i0SyYYdf').strip()
RAZORPAY_KEY_SECRET = os.getenv('RAZORPAY_KEY_SECRET', 'u6BrnyYxz3U9lqPNhSrWI7lB').strip()
RAZORPAY_WEBHOOK_SECRET = os.getenv('RAZORPAY_WEBHOOK_SECRET', '').strip()
RAZORPAY_ENVIRONMENT = os.getenv('RAZORPAY_ENVIRONMENT', 'LIVE').strip().upper()


# --------------------------------------------------
# EMAIL
# --------------------------------------------------

EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
