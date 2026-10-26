import os
import sys
sys.path.insert(0, r"d:\flutter\Shivnath project\shivnath_backend\shivnath_backend")
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from accounts.models import CityDistrict, ServiceZone, ServiceArea
from billing.models import DeliveryOriginSetting

print("=== CITY / DISTRICTS ===")
for d in CityDistrict.objects.all():
    print(f"District {d.id}: name={d.name}, state={d.state}, active={d.is_active}")

print("\n=== DELIVERY ORIGIN SETTINGS (HUBS) ===")
for h in DeliveryOriginSetting.objects.all():
    print(f"Hub {h.id}: name={h.name}, city={h.city}, lat={h.latitude}, lng={h.longitude}, active={h.is_active}")

print("\n=== SERVICE ZONES ===")
for z in ServiceZone.objects.all():
    areas_count = z.areas.count()
    locs = list(z.areas.values_list('locality_name', flat=True)[:5])
    print(f"Zone {z.id}: name='{z.name}', code='{z.code}', district='{z.district.name if z.district else 'None'}', hub='{z.fulfilment_hub.name if z.fulfilment_hub else 'None'}', active={z.is_active}, total_localities={areas_count}, sample_locs={locs}")

print("\n=== TOTAL SERVICE AREAS (LOCALITIES) ===")
print("Total count:", ServiceArea.objects.count())
print("Active count:", ServiceArea.objects.filter(is_active=True).count())
for a in ServiceArea.objects.all()[:15]:
    print(f"  Area {a.id}: locality='{a.locality_name}', zone='{a.zone.name if a.zone else 'None'}', district='{a.district.name if a.district else 'None'}', pin={a.pincode}, lat={a.latitude}, lng={a.longitude}")
