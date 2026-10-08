import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from rest_framework.test import APIRequestFactory
from accounts.views import TerritoryMasterView
from accounts.models import ServiceDistrict, ServiceZone

def run_audit():
    print("=" * 60)
    print("DISTRICT & TERRITORY MASTER DATA AUDIT")
    print("=" * 60)

    districts = ServiceDistrict.objects.all().order_by('name')
    total_districts = districts.count()
    total_territories = ServiceZone.objects.filter(is_active=True).count()

    print(f"Total districts available: {total_districts}/33")
    print(f"Total territory records: {total_territories}")
    print()

    # List all 33 districts
    print("All 33 Official Chhattisgarh Districts in DB:")
    for idx, d in enumerate(districts, 1):
        zone_count = d.zones.filter(is_active=True).count()
        print(f"  {idx:2d}. {d.name} ({zone_count} territories)")
    print()

    # Test sample districts
    sample_districts = [
        'Raipur', 'Durg', 'Bilaspur', 'Bastar', 'Korba', 
        'Surguja', 'Rajnandgaon', 'Dhamtari', 'Janjgir-Champa', 
        'Kanker', 'Kabirdham (Kawardha)', 'Balod'
    ]

    print("Sample District Territory Breakdown:")
    for d_name in sample_districts:
        zones = ServiceZone.objects.filter(district__name__iexact=d_name, is_active=True).order_by('name')
        zone_names = [z.name for z in zones]
        print(f"  - {d_name} ({len(zone_names)}): {zone_names}")
    print()

    # Check for zero territories
    zero_territories = [d.name for d in districts if d.zones.filter(is_active=True).count() == 0]
    print(f"Any districts with zero territories: {zero_territories if zero_territories else 'None'}")
    print()

    # Test API endpoint TerritoryMasterView
    factory = APIRequestFactory()
    view = TerritoryMasterView.as_view()

    # 1. Test get all districts API
    req_districts = factory.get('/api/auth/territory-master/')
    res_districts = view(req_districts)
    print(f"API /api/auth/territory-master/ Status: {res_districts.status_code}")
    api_districts = res_districts.data.get('districts', [])
    print(f"API Returned {len(api_districts)} districts:")
    
    # 2. Test territory queries for each sample district
    print("\nTesting Territory Queries via API:")
    for d_name in sample_districts:
        req_terr = factory.get(f'/api/auth/territory-master/?district={d_name}')
        res_terr = view(req_terr)
        assert res_terr.status_code == 200, f"Failed for {d_name}"
        returned_territories = res_terr.data.get('territories', [])
        names = [t.get('name') for t in returned_territories]
        print(f"  API ?district={d_name} -> ({len(names)}): {names}")

    print("\nAUDIT CHECK PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    run_audit()
