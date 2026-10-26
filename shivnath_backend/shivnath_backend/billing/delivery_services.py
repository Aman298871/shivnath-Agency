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



# Comprehensive Curated Localities Database across Chhattisgarh
CURATED_LOCALITIES = [
    # --- RAIPUR ---
    # North / Mowa / Saddu / Vidhan Sabha
    {
        "name": "Mowa, Raipur",
        "city": "Raipur",
        "keywords": ["mowa", "ekta nagar", "pragati nagar", "lic colony", "mowa thana", "saddu road", "central dispatch"],
        "pincode": "492007",
        "lat": 21.2678, "lon": 81.6711
    },
    {
        "name": "Saddu, Raipur",
        "city": "Raipur",
        "keywords": ["saddu", "housing board colony saddu", "daldal seoni", "seoni"],
        "pincode": "492014",
        "lat": 21.2780, "lon": 81.6880
    },
    {
        "name": "Vidhan Sabha Road, Raipur",
        "city": "Raipur",
        "keywords": ["vidhan sabha", "baloda bazar road", "khamtarai road", "amleshwar"],
        "pincode": "492007",
        "lat": 21.2850, "lon": 81.6950
    },
    # Central / Pandri / Devendra Nagar / Shankar Nagar
    {
        "name": "Pandri, Raipur",
        "city": "Raipur",
        "keywords": ["pandri", "cloth market", "city center mall", "pandri bus stand", "devendra nagar sector"],
        "pincode": "492004",
        "lat": 21.2612, "lon": 81.6558
    },
    {
        "name": "Shankar Nagar, Raipur",
        "city": "Raipur",
        "keywords": ["shankar nagar", "ashoka ratna", "khamardih", "bhagwanpur", "canal road", "lodhipara"],
        "pincode": "492007",
        "lat": 21.2460, "lon": 81.6620
    },
    {
        "name": "Devendra Nagar, Raipur",
        "city": "Raipur",
        "keywords": ["devendra nagar", "katora talab", "shailendra nagar", "sector 1", "sector 2", "sector 3", "sector 4", "sector 5"],
        "pincode": "492004",
        "lat": 21.2580, "lon": 81.6450
    },
    {
        "name": "Civil Lines, Raipur",
        "city": "Raipur",
        "keywords": ["civil lines", "raj bhavan", "ghadi chowk", "kalibadi", "collectorate", "rajkumar college", "gpo"],
        "pincode": "492001",
        "lat": 21.2420, "lon": 81.6430
    },
    {
        "name": "Byron Bazar, Raipur",
        "city": "Raipur",
        "keywords": ["byron bazar", "pension bada", "bti ground", "katora talab"],
        "pincode": "492001",
        "lat": 21.2370, "lon": 81.6490
    },
    # East Raipur / VIP Road / Telibandha / Naya Raipur
    {
        "name": "Telibandha, Raipur",
        "city": "Raipur",
        "keywords": ["telibandha", "marine drive", "vip road", "telibandha talab", "ravigram"],
        "pincode": "492006",
        "lat": 21.2330, "lon": 81.6720
    },
    {
        "name": "Avanti Vihar, Raipur",
        "city": "Raipur",
        "keywords": ["avanti vihar", "vishal nagar", "labhandih", "magneto mall", "ge road labhandih"],
        "pincode": "492006",
        "lat": 21.2410, "lon": 81.6850
    },
    {
        "name": "Jora, Raipur",
        "city": "Raipur",
        "keywords": ["jora", "agrasen dham", "agricultural university", "igkv"],
        "pincode": "492012",
        "lat": 21.2370, "lon": 81.7050
    },
    {
        "name": "Naya Raipur (Atal Nagar)",
        "city": "Raipur",
        "keywords": ["naya raipur", "atal nagar", "rakhi", "mantralaya", "sector 24", "sector 27", "sector 29", "uparwara"],
        "pincode": "492101",
        "lat": 21.1600, "lon": 81.7800
    },
    {
        "name": "Mandir Hasaud, Raipur",
        "city": "Raipur",
        "keywords": ["mandir hasaud", "serikhedi", "nawa raipur road"],
        "pincode": "492015",
        "lat": 21.2200, "lon": 81.7800
    },
    {
        "name": "Mana Camp / Airport, Raipur",
        "city": "Raipur",
        "keywords": ["mana camp", "mana", "airport", "swami vivekananda airport", "mana biman talab"],
        "pincode": "492012",
        "lat": 21.1800, "lon": 81.7400
    },
    # West / Central / Old City
    {
        "name": "Station Road / Fafadih, Raipur",
        "city": "Raipur",
        "keywords": ["station road", "railway station", "fafadih", "station chowk"],
        "pincode": "492009",
        "lat": 21.2540, "lon": 81.6280
    },
    {
        "name": "Gudhiyari, Raipur",
        "city": "Raipur",
        "keywords": ["gudhiyari", "ram nagar", "shuklawari", "gudiyari"],
        "pincode": "492002",
        "lat": 21.2630, "lon": 81.6210
    },
    {
        "name": "Samta Colony, Raipur",
        "city": "Raipur",
        "keywords": ["samta colony", "choubey colony", "chauhan colony", "ramkund"],
        "pincode": "492001",
        "lat": 21.2560, "lon": 81.6160
    },
    {
        "name": "Kota / Saraswati Nagar, Raipur",
        "city": "Raipur",
        "keywords": ["kota", "saraswati nagar", "gogaon", "nit raipur", "science college"],
        "pincode": "492010",
        "lat": 21.2500, "lon": 81.6050
    },
    {
        "name": "Tatibandh / AIIMS, Raipur",
        "city": "Raipur",
        "keywords": ["tatibandh", "aiims", "aiims raipur", "sarona", "ge road tatibandh", "mohba bazar", "amanaka"],
        "pincode": "492099",
        "lat": 21.2620, "lon": 81.5640
    },
    {
        "name": "Budhapara / Purani Basti, Raipur",
        "city": "Raipur",
        "keywords": ["budhapara", "budha talab", "purani basti", "tatyapara", "gol bazar", "sadar bazar", "malviya road", "jaistambh chowk"],
        "pincode": "492001",
        "lat": 21.2380, "lon": 81.6310
    },
    # South Raipur / Pachpedi Naka / Bhatagaon
    {
        "name": "Pachpedi Naka, Raipur",
        "city": "Raipur",
        "keywords": ["pachpedi naka", "sundar nagar", "mathpurena", "santoshi nagar", "tikrapara", "dhamtari road"],
        "pincode": "492013",
        "lat": 21.2150, "lon": 81.6420
    },
    {
        "name": "Bhatagaon / ISBT, Raipur",
        "city": "Raipur",
        "keywords": ["bhatagaon", "isbt", "isbt raipur", "bus stand", "dharampura", "walfort city"],
        "pincode": "492013",
        "lat": 21.2190, "lon": 81.6250
    },
    {
        "name": "Dangania / Kushalpur, Raipur",
        "city": "Raipur",
        "keywords": ["dangania", "changurabhata", "kushalpur", "mahadev ghat", "raipura"],
        "pincode": "492013",
        "lat": 21.2280, "lon": 81.6050
    },
    {
        "name": "Kamal Vihar / Boriyakhurd, Raipur",
        "city": "Raipur",
        "keywords": ["kamal vihar", "boriyakhurd", "boriya khurd", "sejdhabar"],
        "pincode": "492015",
        "lat": 21.1980, "lon": 81.6550
    },
    # Industrial Northern Belt
    {
        "name": "Bhanpuri / Rawabhata, Raipur",
        "city": "Raipur",
        "keywords": ["bhanpuri", "industrial area bhanpuri", "rawabhata", "bilaspur road"],
        "pincode": "492003",
        "lat": 21.3060, "lon": 81.6500
    },
    {
        "name": "Urla / Birgaon, Raipur",
        "city": "Raipur",
        "keywords": ["urla", "birgaon", "gondwara", "khamtarai", "wrs colony"],
        "pincode": "492008",
        "lat": 21.3150, "lon": 81.6150
    },
    {
        "name": "Siltara Industrial Area, Raipur",
        "city": "Raipur",
        "keywords": ["siltara", "industrial estate siltara", "dharsiwa"],
        "pincode": "492014",
        "lat": 21.3650, "lon": 81.6900
    },

    # --- DURG / BHILAI ---
    {
        "name": "Kumhari, Durg",
        "city": "Durg",
        "keywords": ["kumhari", "charoda", "toll plaza kumhari", "kumhari station"],
        "pincode": "490042",
        "lat": 21.2400, "lon": 81.5000
    },
    {
        "name": "Supela, Bhilai",
        "city": "Bhilai",
        "keywords": ["supela", "supela chowk", "ghadi chowk supela", "bhilai 3"],
        "pincode": "490023",
        "lat": 21.2050, "lon": 81.3500
    },
    {
        "name": "Nehru Nagar, Bhilai",
        "city": "Bhilai",
        "keywords": ["nehru nagar", "nehru nagar east", "nehru nagar west", "smriti nagar", "junwani", "surya treasure island mall"],
        "pincode": "490020",
        "lat": 21.2250, "lon": 81.3320
    },
    {
        "name": "Sector 6 / Civic Centre, Bhilai",
        "city": "Bhilai",
        "keywords": ["sector 6", "civic centre", "sector 1", "sector 4", "sector 5", "sector 7", "sector 9", "sector 10", "power house"],
        "pincode": "490006",
        "lat": 21.1920, "lon": 81.3620
    },
    {
        "name": "Durg City Center / Mohan Nagar",
        "city": "Durg",
        "keywords": ["durg", "mohan nagar", "durg railway station", "padmanabhpur", "gaya nagar", "rajendra park durg", "indira market durg"],
        "pincode": "491001",
        "lat": 21.1904, "lon": 81.2849
    },

    # --- BILASPUR ---
    {
        "name": "Vyapar Vihar, Bilaspur",
        "city": "Bilaspur",
        "keywords": ["vyapar vihar", "link road", "bus stand bilaspur", "telipara"],
        "pincode": "495001",
        "lat": 22.0750, "lon": 82.1450
    },
    {
        "name": "Bilaspur Railway Station / Torwa",
        "city": "Bilaspur",
        "keywords": ["torwa", "bilaspur station", "budhwari bazar", "hemumagar"],
        "pincode": "495004",
        "lat": 22.0620, "lon": 82.1640
    },
    {
        "name": "Mangla / Nehru Nagar, Bilaspur",
        "city": "Bilaspur",
        "keywords": ["mangla", "mangla chowk", "rama magneto mall bilaspur", "uslapur", "koni"],
        "pincode": "495001",
        "lat": 22.0950, "lon": 82.1220
    },
    {
        "name": "Sirgitti Industrial Area, Bilaspur",
        "city": "Bilaspur",
        "keywords": ["sirgitti", "industrial area sirgitti", "tifra"],
        "pincode": "495004",
        "lat": 22.0350, "lon": 82.1150
    },

    # --- RAJNANDGAON ---
    {
        "name": "Rajnandgaon City Center",
        "city": "Rajnandgaon",
        "keywords": ["rajnandgaon", "gurunanak chowk", "manav mandir", "station road rajnandgaon"],
        "pincode": "491441",
        "lat": 21.0970, "lon": 81.0310
    },

    # --- KORBA ---
    {
        "name": "Korba City / Transport Nagar",
        "city": "Korba",
        "keywords": ["korba", "transport nagar korba", "tpng", "kosabadi", "balco"],
        "pincode": "495677",
        "lat": 22.3595, "lon": 82.7501
    },
]

# Backwards compatibility alias
RAIPUR_LOCALITIES = CURATED_LOCALITIES

# PIN Code Mapping for instant resolution across Chhattisgarh
PINCODE_COORDINATES = {
    # Raipur City & Suburbs
    '492001': (21.2420, 81.6430),  # Civil Lines / GPO / Budhapara / Samta Colony
    '492002': (21.2630, 81.6210),  # Gudhiyari
    '492003': (21.3060, 81.6500),  # Bhanpuri / Birgaon
    '492004': (21.2612, 81.6558),  # Pandri / Devendra Nagar
    '492005': (21.2620, 81.5640),  # Tatibandh / AIIMS
    '492006': (21.2330, 81.6720),  # Telibandha / Avanti Vihar
    '492007': (21.2460, 81.6620),  # Shankar Nagar / Mowa
    '492008': (21.3150, 81.6150),  # Urla Industrial
    '492009': (21.2540, 81.6280),  # Station Road / Fafadih
    '492010': (21.2500, 81.6050),  # Kota / Saraswati Nagar
    '492011': (21.3200, 81.6600),  # Rawabhata
    '492012': (21.1800, 81.7400),  # Mana / Airport / Jora
    '492013': (21.2150, 81.6420),  # Pachpedi Naka / Bhatagaon
    '492014': (21.2780, 81.6880),  # Saddu / Daldal Seoni / Siltara
    '492015': (21.2200, 81.7800),  # Mandir Hasaud / Kamal Vihar
    '492099': (21.2480, 81.6350),  # Raipur City RMS / Amanaka
    '492101': (21.1600, 81.7800),  # Naya Raipur / Atal Nagar

    # Bhilai / Durg
    '490001': (21.1920, 81.3620),  # Bhilai Sector 1
    '490006': (21.1920, 81.3620),  # Bhilai Sector 6
    '490020': (21.2250, 81.3320),  # Bhilai Nehru Nagar / Smriti Nagar
    '490023': (21.2050, 81.3500),  # Supela Bhilai
    '490042': (21.2400, 81.5000),  # Kumhari
    '491001': (21.1904, 81.2849),  # Durg Head Post Office

    # Bilaspur
    '495001': (22.0750, 82.1450),  # Bilaspur Head Post Office / Vyapar Vihar
    '495004': (22.0620, 82.1640),  # Torwa / Sirgitti

    # Rajnandgaon
    '491441': (21.0970, 81.0310),  # Rajnandgaon Head Post Office

    # Korba
    '495677': (22.3595, 82.7501),  # Korba
}


def get_address_suggestions(query_str='', limit=12, city_hint=None):
    """
    Returns suggested delivery areas, localities and PIN codes matching query_str for autocomplete.
    Queries authoritative database models (ServiceArea, ServiceZone, ServiceDistrict) and supplements
    with curated landmarks across Chhattisgarh.
    Returns:
      - name: Formatted area name e.g. "Mowa, Raipur"
      - locality: Exact locality name e.g. "Mowa"
      - city: City/District e.g. "Raipur"
      - district: District name
      - state: State name e.g. "Chhattisgarh"
      - pincode: Postal code
      - zone_id: ID of assigned ServiceZone
      - zone_name: Formatted zone name e.g. "North Raipur"
      - latitude, longitude: GPS coordinates
      - fulfilment_hub: Designated fulfilment center name
      - covered_localities: Other active localities covered by this zone
      - is_configured_zone: True if backed by active backend zone
    """
    q = (query_str or '').strip().lower()
    city_h = (city_hint or '').strip().lower()
    results = []
    seen_names = set()

    # 1. Query Authoritative Backend ServiceArea & ServiceZone database records
    try:
        from accounts.models import ServiceArea
        sa_qs = ServiceArea.objects.filter(is_active=True).select_related('district', 'zone', 'zone__fulfilment_hub')
        if city_h:
            sa_qs = sa_qs.filter(models.Q(district__name__icontains=city_h) | models.Q(locality_name__icontains=city_h))
        if q:
            sa_qs = sa_qs.filter(
                models.Q(locality_name__icontains=q) |
                models.Q(pincode__icontains=q) |
                models.Q(district__name__icontains=q) |
                models.Q(zone__name__icontains=q)
            )

        # Cache sibling localities by zone to minimize DB roundtrips
        zone_localities_cache = {}

        for sa in sa_qs[:limit]:
            clean_name = f"{sa.locality_name}, {sa.district.name}"
            if clean_name.lower() in seen_names:
                continue
            seen_names.add(clean_name.lower())

            zid = sa.zone.id if sa.zone else None
            if zid and zid not in zone_localities_cache:
                siblings = list(ServiceArea.objects.filter(zone_id=zid, is_active=True).values_list('locality_name', flat=True)[:15])
                zone_localities_cache[zid] = siblings

            covered = zone_localities_cache.get(zid, [sa.locality_name])
            lat = float(sa.latitude) if sa.latitude is not None else (PINCODE_COORDINATES.get(sa.pincode, (21.2678, 81.6711))[0])
            lon = float(sa.longitude) if sa.longitude is not None else (PINCODE_COORDINATES.get(sa.pincode, (21.2678, 81.6711))[1])
            hub_name = sa.zone.fulfilment_hub.name if (sa.zone and sa.zone.fulfilment_hub) else "Shivnath Agency Central Dispatch"

            results.append({
                'name': clean_name,
                'locality': sa.locality_name,
                'city': sa.district.name,
                'district': sa.district.name,
                'state': sa.district.state,
                'pincode': sa.pincode,
                'zone_id': zid,
                'zone_name': sa.zone.name if sa.zone else f"{sa.district.name} Central",
                'latitude': lat,
                'longitude': lon,
                'fulfilment_hub': hub_name,
                'covered_localities': covered,
                'is_configured_zone': True,
            })
            if len(results) >= limit:
                return results
    except Exception as e:
        logger.warning("Error querying ServiceArea database records: %s", e)

    # 2. Supplement from Curated Landmarks Database
    for loc in CURATED_LOCALITIES:
        if city_h and city_h not in loc.get('city', '').lower() and city_h not in loc['name'].lower():
            continue

        clean_name = loc['name']
        if clean_name.lower() in seen_names:
            continue

        match = False
        if not q:
            match = True
        else:
            if q in loc['name'].lower() or q in loc['pincode'] or q in loc.get('city', '').lower():
                match = True
            elif any(q in kw for kw in loc.get('keywords', [])):
                match = True

        if match:
            seen_names.add(clean_name.lower())
            results.append({
                'name': loc['name'],
                'locality': loc['name'].split(',')[0].strip(),
                'city': loc.get('city', 'Raipur'),
                'district': loc.get('city', 'Raipur'),
                'state': 'Chhattisgarh',
                'pincode': loc['pincode'],
                'zone_id': None,
                'zone_name': f"{loc.get('city', 'Raipur')} Central",
                'latitude': loc['lat'],
                'longitude': loc['lon'],
                'fulfilment_hub': "Shivnath Agency Central Dispatch",
                'covered_localities': [loc['name'].split(',')[0].strip()],
                'is_configured_zone': True,
            })

        if len(results) >= limit:
            break

    return results


def resolve_address_coordinates(address_str, city_hint=None):
    """
    Resolves Indian address across Chhattisgarh to (latitude, longitude).
    1. Direct coordinate regex (lat, lon) embedded in address string.
    2. Curated multi-city landmark mapping (offline, reliable, instant).
    3. Authoritative database ServiceArea locality match.
    4. Indian 6-digit postal PIN code matching.
    5. OpenStreetMap Nominatim geocoding (online fallback with timeout).
    6. Safe city center fallback based on detected city (Never blindly force everything to Raipur).
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
    city_h = (city_hint or '').strip().lower()

    # 2. Curated offline landmark database for instant, zero-latency resolution
    for loc in CURATED_LOCALITIES:
        if any(kw in clean_addr for kw in loc['keywords']) or loc['name'].lower() in clean_addr:
            return loc['lat'], loc['lon']

    # 3. Database ServiceArea locality lookup
    try:
        from accounts.models import ServiceArea
        for sa in ServiceArea.objects.filter(is_active=True):
            if sa.locality_name.lower() in clean_addr:
                if sa.latitude and sa.longitude:
                    return float(sa.latitude), float(sa.longitude)
                if sa.pincode in PINCODE_COORDINATES:
                    return PINCODE_COORDINATES[sa.pincode]
    except Exception:
        pass

    # 4. Check for 6-digit Indian PIN code in address string
    pin_match = re.search(r'\b(49\d{4})\b', raw_text)
    if pin_match:
        found_pin = pin_match.group(1)
        if found_pin in PINCODE_COORDINATES:
            lat, lon = PINCODE_COORDINATES[found_pin]
            return lat, lon

    # 4. Online OpenStreetMap Nominatim fallback with 2.5-second timeout
    try:
        if city_h:
            query = urllib.parse.quote(f"{raw_text}, {city_h}, Chhattisgarh, India")
        elif any(c in clean_addr for c in ['bhilai', 'durg', 'bilaspur', 'korba', 'rajnandgaon', 'raipur']):
            query = urllib.parse.quote(f"{raw_text}, Chhattisgarh, India")
        else:
            query = urllib.parse.quote(f"{raw_text}, India")

        req_url = f"https://nominatim.openstreetmap.org/search?q={query}&format=json&limit=1"
        req = urllib.request.Request(req_url, headers={'User-Agent': 'ShivnathAgencyDelivery/1.0 (contact: info@shivnath.in)'})
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            data = json.loads(resp.read().decode())
            if data and isinstance(data, list) and len(data) > 0:
                lat = float(data[0]['lat'])
                lon = float(data[0]['lon'])
                return lat, lon
    except Exception as e:
        logger.info("Online geocoding lookup timed out or failed gracefully: %s", type(e).__name__)

    # 5. Safe city center fallback based on detected city (Never blindly force everything to Raipur)
    if 'bhilai' in clean_addr or city_h == 'bhilai':
        return 21.2090, 81.3780
    if 'durg' in clean_addr or city_h == 'durg':
        return 21.1904, 81.2849
    if 'bilaspur' in clean_addr or city_h == 'bilaspur':
        return 22.0797, 82.1409
    if 'rajnandgaon' in clean_addr or city_h == 'rajnandgaon':
        return 21.0970, 81.0310
    if 'korba' in clean_addr or city_h == 'korba':
        return 22.3595, 82.7501
    if 'raipur' in clean_addr or city_h == 'raipur' or 'chhattisgarh' in clean_addr or ' c.g' in clean_addr or ' cg' in clean_addr:
        return 21.2514, 81.6296

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
    city_hint=None,
    channel='ALL'
):
    """
    Authoritative backend calculation of delivery distance and fee from Shivnath Agency's configured origin(s).
    Supports multi-hub dispatch (Raipur, Bhilai, Durg, Bilaspur, etc.) and enforces server-side pricing.
    """
    if dest_lat is None and dest_latitude is not None:
        dest_lat = dest_latitude
    if dest_lon is None and dest_longitude is not None:
        dest_lon = dest_longitude

    seed_default_distance_bands_if_empty()
    active_origins = list(DeliveryOriginSetting.objects.filter(is_active=True))

    # Rule 1: Check origin coordinates & configuration
    if not active_origins or any(o.latitude is None or o.longitude is None for o in active_origins):
        return {
            'is_supported': False,
            'is_blocked': True,
            'message': 'Dispatch origin location is not configured or inactive. Delivery calculation is currently BLOCKED. Please configure origin in Admin Panel.',
            'error_code': 'ORIGIN_CONFIGURATION_BLOCKED',
            'delivery_charge': Decimal('0.00'),
            'distance_km': None,
            'distance_type': 'STRAIGHT_LINE_HAVERSINE',
            'distance_label': 'Straight-line distance (Haversine)',
            'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
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
            'distance_type': 'STRAIGHT_LINE_HAVERSINE',
            'distance_label': 'Straight-line distance (Haversine)',
            'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
        }

    # Rule 2: If coordinates are missing, resolve from address
    if dest_lat is None or dest_lon is None:
        if dest_address and str(dest_address).strip():
            resolved_lat, resolved_lon = resolve_address_coordinates(str(dest_address).strip(), city_hint=city_hint)
            if resolved_lat is not None and resolved_lon is not None:
                dest_lat = resolved_lat
                dest_lon = resolved_lon

    # If coordinates are still missing or cannot be resolved:
    if dest_lat is None or dest_lon is None:
        fallback_origin = active_origins[0]
        return {
            'distance_km': None,
            'distance_method': 'UNRESOLVED_ADDRESS',
            'distance_type': 'STRAIGHT_LINE_HAVERSINE',
            'distance_label': 'Straight-line distance (Haversine)',
            'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
            'delivery_charge': Decimal('0.00'),
            'tier_name': 'Address Unresolved',
            'band_name': 'Address Unresolved',
            'band_id': None,
            'is_supported': False,
            'is_blocked': False,
            'message': 'Unable to determine delivery location coordinates from address. Please select a recognized area or provide map coordinates.',
            'error_code': 'ADDRESS_UNRESOLVABLE',
            'origin': {
                'name': fallback_origin.name,
                'address': fallback_origin.address,
                'city': fallback_origin.city,
                'latitude': float(fallback_origin.latitude),
                'longitude': float(fallback_origin.longitude),
            }
        }

    try:
        lat_val = float(dest_lat)
        lon_val = float(dest_lon)
    except (TypeError, ValueError):
        raise ValidationError("Invalid coordinates supplied for delivery address.")

    # Select the closest active origin hub to serve this customer location
    origin = min(
        active_origins,
        key=lambda o: calculate_haversine_distance(o.latitude, o.longitude, lat_val, lon_val)
    )

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
        max_limit = active_bands.aggregate(m=models.Max('max_distance_km'))['m'] or Decimal('25.00')
        return {
            'is_supported': False,
            'is_blocked': False,
            'distance_km': float(distance_km),
            'distance_type': 'STRAIGHT_LINE_HAVERSINE',
            'distance_label': 'Straight-line distance (Haversine)',
            'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
            'distance_method': 'HAVERSINE_STRAIGHT_LINE',
            'distance_metric': 'HAVERSINE_GREAT_CIRCLE_KM',
            'delivery_charge': Decimal('0.00'),
            'band_name': 'Beyond Serviceable Area',
            'band_id': None,
            'message': (
                f"Delivery distance ({distance_km:.1f} km from {origin.name}) is outside our maximum serviceable delivery radius "
                f"({max_limit} km). Order cannot be fulfilled."
            ),
            'error_code': 'DELIVERY_UNSUPPORTED',
            'origin': {
                'name': origin.name,
                'address': origin.address,
                'city': origin.city,
                'latitude': float(origin.latitude),
                'longitude': float(origin.longitude),
            }
        }

    if matched_band and not matched_band.is_supported:
        return {
            'is_supported': False,
            'is_blocked': False,
            'distance_km': float(distance_km),
            'distance_type': 'STRAIGHT_LINE_HAVERSINE',
            'distance_label': 'Straight-line distance (Haversine)',
            'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
            'distance_method': 'HAVERSINE_STRAIGHT_LINE',
            'distance_metric': 'HAVERSINE_GREAT_CIRCLE_KM',
            'delivery_charge': Decimal('0.00'),
            'band_name': matched_band.name,
            'band_id': matched_band.id,
            'message': (
                f"Delivery distance ({distance_km:.1f} km from {origin.name}) is outside our supported service territory. "
                f"Band '{matched_band.name}' is designated as non-serviceable. Please contact Shivnath Agency."
            ),
            'error_code': 'DELIVERY_UNSUPPORTED',
            'origin': {
                'name': origin.name,
                'address': origin.address,
                'city': origin.city,
                'latitude': float(origin.latitude),
                'longitude': float(origin.longitude),
            }
        }

    fee = matched_band.delivery_charge if matched_band else Decimal('0.00')

    return {
        'distance_km': float(distance_km),
        'distance_type': 'STRAIGHT_LINE_HAVERSINE',
        'distance_label': 'Straight-line distance (Haversine)',
        'distance_explanation': 'Direct point-to-point distance from dispatch hub. Road route distance may be higher.',
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
            'city': origin.city,
            'latitude': float(origin.latitude),
            'longitude': float(origin.longitude),
        }
    }

