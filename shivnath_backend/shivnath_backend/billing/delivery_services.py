import re
import urllib.parse
import urllib.request
import json
import logging
from decimal import Decimal
import math
from django.db import models
from rest_framework.exceptions import ValidationError
from billing.models import DeliveryOriginSetting, DeliveryDistanceBand

logger = logging.getLogger(__name__)


def calculate_haversine_distance(lat1, lon1, lat2, lon2):
    """
    Computes straight-line great-circle distance between two GPS coordinates in kilometers.
    Clearly labeled as straight-line distance from authoritative origin.
    """
    R = 6371.0  # Earth's mean radius in km

    lat1_rad = math.radians(float(lat1))
    lon1_rad = math.radians(float(lon1))
    lat2_rad = math.radians(float(lat2))
    lon2_rad = math.radians(float(lon2))

    dlat = lat2_rad - lat1_rad
    dlon = lon2_rad - lon1_rad

    a = math.sin(dlat / 2.0)**2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2.0)**2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    distance = R * c
    return round(distance, 2)


def resolve_address_coordinates(address_str):
    """
    Resolves Indian address (specifically Raipur, Chhattisgarh) to (latitude, longitude).
    1. Direct coordinate regex (lat, lon) embedded in address string.
    2. Curated Raipur landmark mapping (offline, reliable, instant).
    3. OpenStreetMap Nominatim geocoding (online fallback with timeout).
    """
    if not address_str or not str(address_str).strip():
        return None, None

    raw_text = str(address_str).strip()

    # 1. Check for coordinates in string: e.g. "21.2678, 81.6711" or "Lat: 21.2678, Long: 81.6711"
    coord_match = re.search(r'(-?\d{1,2}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)', raw_text)
    if coord_match:
        try:
            lat = float(coord_match.group(1))
            lon = float(coord_match.group(2))
            if -90 <= lat <= 90 and -180 <= lon <= 180:
                return lat, lon
        except ValueError:
            pass

    clean_addr = raw_text.lower()

    # 2. Curated offline Raipur landmark database for instant, zero-latency resolution
    RAIPUR_AREAS = [
        (['ekta nagar', 'pragati nagar', 'lic colony', 'mowa thana', 'mowa'], 21.2678, 81.6711),
        (['pandri', 'city center', 'cloth market', 'devendra nagar sector'], 21.2612, 81.6558),
        (['shankar nagar', 'ashoka ratna', 'khamardih', 'bhagwanpur'], 21.2460, 81.6620),
        (['devendra nagar', 'katora talab', 'shailendra nagar'], 21.2580, 81.6450),
        (['telibandha', 'marine drive', 'vip road', 'jora'], 21.2330, 81.6720),
        (['ghadi chowk', 'civil lines', 'raj bhavan', 'kalibadi'], 21.2420, 81.6430),
        (['samta colony', 'chauhan colony', 'ramkund'], 21.2560, 81.6160),
        (['station road', 'railway station', 'fafadih', 'gudhiyari'], 21.2540, 81.6280),
        (['pachpedi naka', 'sundar nagar', 'mathpurena'], 21.2150, 81.6420),
        (['bhanpuri', 'urla', 'industrial area bhanpuri', 'rawabhata'], 21.3060, 81.6500),
        (['tatibandh', 'aiims', 'sarona', 'ge road'], 21.2620, 81.5640),
        (['dharampura', 'bhatagaon', 'isbt raipur'], 21.2190, 81.6250),
        (['naya raipur', 'atal nagar', 'rakhi'], 21.1600, 81.7800),
        (['bhilai', 'supela', 'nehru nagar bhilai'], 21.2100, 81.3800),
        (['durg', 'mohan nagar durg'], 21.1900, 81.2800),
        (['raipur', 'chhattisgarh'], 21.2514, 81.6296),
    ]

    for keywords, lat, lon in RAIPUR_AREAS:
        if any(kw in clean_addr for kw in keywords):
            return lat, lon

    # 3. Online OpenStreetMap Nominatim fallback with 2-second timeout
    try:
        query = urllib.parse.quote(f"{raw_text}, Raipur, Chhattisgarh, India")
        req_url = f"https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=1"
        req = urllib.request.Request(req_url, headers={'User-Agent': 'ShivnathAgencyDelivery/1.0'})
        with urllib.request.urlopen(req, timeout=2.0) as resp:
            data = json.loads(resp.read().decode())
            if data and isinstance(data, list) and len(data) > 0:
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                return lat, lon
    except Exception as e:
        logger.warning("Online geocoding lookup timed out or failed: %s", e)

    return None, None


def seed_default_distance_bands_if_empty():
    """
    Idempotently seeds initial realistic distance bands if none exist in the database.
    Allows immediate out-of-the-box operation while remaining 100% editable by Admin.
    """
    if not DeliveryDistanceBand.objects.exists():
        DeliveryDistanceBand.objects.create(
            name="0-2 km Local Delivery",
            min_distance_km=Decimal('0.00'),
            max_distance_km=Decimal('2.00'),
            delivery_charge=Decimal('30.00'),
            is_active=True,
            is_supported=True,
            applies_to='ALL',
            order=1
        )
        DeliveryDistanceBand.objects.create(
            name="Above 2-5 km Sub-Urban Delivery",
            min_distance_km=Decimal('2.00'),
            max_distance_km=Decimal('5.00'),
            delivery_charge=Decimal('60.00'),
            is_active=True,
            is_supported=True,
            applies_to='ALL',
            order=2
        )
        DeliveryDistanceBand.objects.create(
            name="Above 5-10 km Outskirts Delivery",
            min_distance_km=Decimal('5.00'),
            max_distance_km=Decimal('10.00'),
            delivery_charge=Decimal('120.00'),
            is_active=True,
            is_supported=True,
            applies_to='ALL',
            order=3
        )
        DeliveryDistanceBand.objects.create(
            name="Above 10-25 km Extended Delivery",
            min_distance_km=Decimal('10.00'),
            max_distance_km=Decimal('25.00'),
            delivery_charge=Decimal('250.00'),
            is_active=True,
            is_supported=True,
            applies_to='ALL',
            order=4
        )
        DeliveryDistanceBand.objects.create(
            name="Above 25 km Non-Serviceable Area",
            min_distance_km=Decimal('25.00'),
            max_distance_km=None,  # Open-ended
            delivery_charge=Decimal('0.00'),
            is_active=True,
            is_supported=False,
            applies_to='ALL',
            order=5
        )


def get_authoritative_delivery_charge(
    dest_lat=None,
    dest_lon=None,
    dest_latitude=None,
    dest_longitude=None,
    dest_address='',
    channel='ALL'
):
    """
    Authoritative backend calculation of delivery distance and fee from Shivnath Agency's configured origin.
    Enforces Admin-managed settings and prevents client-side price tampering.
    """
    if dest_lat is None and dest_latitude is not None:
        dest_lat = dest_latitude
    if dest_lon is None and dest_longitude is not None:
        dest_lon = dest_longitude

    seed_default_distance_bands_if_empty()
    origin = DeliveryOriginSetting.objects.filter(is_active=True).first()

    # Rule 1: Check origin coordinates & configuration
    if not origin or not origin.is_active or origin.latitude is None or origin.longitude is None:
        return {
            'is_supported': False,
            'is_blocked': True,
            'message': 'Dispatch origin location is not configured or inactive. Delivery calculation is currently BLOCKED. Please configure origin in Admin Panel.',
            'error_code': 'ORIGIN_CONFIGURATION_BLOCKED',
            'delivery_charge': Decimal('0.00'),
            'distance_km': None,
        }

    channel_upper = str(channel).upper() if channel else 'ALL'
    channel_filter = ['ALL']
    if channel_upper in ['CUSTOMER', 'FRANCHISE']:
        channel_filter.append(channel_upper)

    active_bands = DeliveryDistanceBand.objects.filter(
        is_active=True,
        applies_to__in=channel_filter
    ).order_by('order', 'min_distance_km')

    # Rule 1b: Check pricing bands exist
    if not active_bands.exists():
        return {
            'is_supported': False,
            'is_blocked': True,
            'message': 'No active delivery distance pricing bands configured. Delivery calculation is BLOCKED. Please configure pricing bands in Admin Panel.',
            'error_code': 'PRICING_BANDS_BLOCKED',
            'delivery_charge': Decimal('0.00'),
            'distance_km': None,
        }

    # Rule 2: If coordinates are missing, resolve from address
    if dest_lat is None or dest_lon is None:
        if dest_address and str(dest_address).strip():
            resolved_lat, resolved_lon = resolve_address_coordinates(str(dest_address).strip())
            if resolved_lat is not None and resolved_lon is not None:
                dest_lat = resolved_lat
                dest_lon = resolved_lon

    # If coordinates are still missing or cannot be resolved:
    if dest_lat is None or dest_lon is None:
        return {
            'distance_km': None,
            'distance_method': 'UNRESOLVED_ADDRESS',
            'delivery_charge': Decimal('0.00'),
            'tier_name': 'Address Unresolved',
            'band_name': 'Address Unresolved',
            'band_id': None,
            'is_supported': False,
            'is_blocked': False,
            'message': 'Unable to determine delivery location coordinates from address. Please select a recognized area in Raipur or provide map coordinates.',
            'error_code': 'ADDRESS_UNRESOLVABLE',
            'origin': {
                'name': origin.name,
                'address': origin.address,
                'latitude': float(origin.latitude),
                'longitude': float(origin.longitude),
            }
        }

    try:
        lat_val = float(dest_lat)
        lon_val = float(dest_lon)
    except (TypeError, ValueError):
        raise ValidationError("Invalid coordinates supplied for delivery address.")

    distance_km = calculate_haversine_distance(origin.latitude, origin.longitude, lat_val, lon_val)
    distance_dec = Decimal(str(distance_km))

    matched_band = None
    for band in active_bands:
        min_k = band.min_distance_km
        max_k = band.max_distance_km

        # Exact boundary logic:
        # If min_distance is 0: 0 <= distance <= max_distance
        # For higher bands: min_distance < distance <= max_distance
        if min_k == Decimal('0.00'):
            if max_k is not None:
                if Decimal('0.00') <= distance_dec <= max_k:
                    matched_band = band
                    break
            else:
                matched_band = band
                break
        else:
            if max_k is not None:
                if min_k < distance_dec <= max_k:
                    matched_band = band
                    break
            else:
                if distance_dec > min_k:
                    matched_band = band
                    break

    if not matched_band:
        # Distance exceeds all active distance bands
        max_limit = active_bands.aggregate(m=models.Max('max_distance_km'))['m'] or Decimal('15.00')
        return {
            'is_supported': False,
            'is_blocked': False,
            'distance_km': float(distance_km),
            'distance_method': 'HAVERSINE_STRAIGHT_LINE',
            'distance_metric': 'HAVERSINE_GREAT_CIRCLE_KM',
            'delivery_charge': Decimal('0.00'),
            'band_name': 'Beyond Serviceable Area',
            'band_id': None,
            'message': (
                f"Delivery distance ({distance_km:.1f} km from dispatch origin) is outside our maximum serviceable delivery radius "
                f"({max_limit} km). Order cannot be fulfilled."
            ),
            'error_code': 'DELIVERY_UNSUPPORTED',
            'origin': {
                'name': origin.name,
                'address': origin.address,
                'latitude': float(origin.latitude),
                'longitude': float(origin.longitude),
            }
        }

    if matched_band and not matched_band.is_supported:
        return {
            'is_supported': False,
            'is_blocked': False,
            'distance_km': float(distance_km),
            'distance_method': 'HAVERSINE_STRAIGHT_LINE',
            'distance_metric': 'HAVERSINE_GREAT_CIRCLE_KM',
            'delivery_charge': Decimal('0.00'),
            'band_name': matched_band.name,
            'band_id': matched_band.id,
            'message': (
                f"Delivery distance ({distance_km:.1f} km from dispatch origin) is outside our supported service territory. "
                f"Band '{matched_band.name}' is designated as non-serviceable. Please contact Shivnath Agency."
            ),
            'error_code': 'DELIVERY_UNSUPPORTED',
            'origin': {
                'name': origin.name,
                'address': origin.address,
                'latitude': float(origin.latitude),
                'longitude': float(origin.longitude),
            }
        }

    fee = matched_band.delivery_charge if matched_band else Decimal('0.00')

    return {
        'distance_km': float(distance_km),
        'distance_method': 'HAVERSINE_STRAIGHT_LINE',
        'distance_metric': 'HAVERSINE_GREAT_CIRCLE_KM',
        'delivery_charge': fee,
        'band_name': matched_band.name if matched_band else 'Standard Delivery',
        'band_id': matched_band.id if matched_band else None,
        'is_supported': True,
        'is_blocked': False,
        'destination': {
            'latitude': lat_val,
            'longitude': lon_val,
        },
        'origin': {
            'name': origin.name,
            'address': origin.address,
            'latitude': float(origin.latitude),
            'longitude': float(origin.longitude),
        }
    }

