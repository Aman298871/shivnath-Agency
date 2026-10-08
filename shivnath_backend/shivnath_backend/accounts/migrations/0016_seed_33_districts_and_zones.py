# Generated data migration to ensure all 33 Chhattisgarh Districts and Territory Zones exist in production database

from django.db import migrations

CG_DISTRICTS_DATA = {
    "Raipur": [("East Raipur", "RPR-EAST"), ("West Raipur", "RPR-WEST"), ("North Raipur", "RPR-NORTH"), ("South Raipur", "RPR-SOUTH")],
    "Durg": [("Central Durg", "DURG-CENTRAL"), ("Bhilai Urban", "DURG-BHL-URBAN"), ("Durg Rural", "DURG-RURAL")],
    "Bilaspur": [("Bilaspur Central", "BIL-CENTRAL"), ("Bilaspur North", "BIL-NORTH"), ("Bilaspur South", "BIL-SOUTH")],
    "Rajnandgaon": [("Rajnandgaon Central", "RJN-CENTRAL"), ("Rajnandgaon Rural", "RJN-RURAL")],
    "Korba": [("Korba City", "KRB-CITY"), ("Korba Industrial", "KRB-IND")],
    "Raigarh": [("Raigarh City", "RGH-CITY"), ("Raigarh Rural", "RGH-RURAL")],
    "Bastar": [("Jagdalpur City", "BST-JGD-CITY"), ("Bastar Rural", "BST-RURAL")],
    "Surguja": [("Ambikapur City", "SRG-AMB-CITY"), ("Surguja Rural", "SRG-RURAL")],
    "Dhamtari": [("Dhamtari City", "DHM-CITY"), ("Dhamtari Rural", "DHM-RURAL")],
    "Mahasamund": [("Mahasamund Central", "MHS-CENTRAL"), ("Saraipali", "MHS-SRP")],
    "Balod": [("Balod Central", "BLD-CENTRAL"), ("Dondi Lohara", "BLD-DND")],
    "Bemetara": [("Bemetara Central", "BMT-CENTRAL"), ("Berla", "BMT-BRL")],
    "Baloda Bazar - Bhatapara": [("Baloda Bazar Central", "BBB-CENTRAL"), ("Bhatapara Urban", "BBB-BHT")],
    "Gariaband": [("Gariaband Central", "GRB-CENTRAL"), ("Rajim", "GRB-RJM")],
    "Janjgir-Champa": [("Janjgir City", "JJC-CITY"), ("Champa Urban", "JJC-CMP")],
    "Sakti": [("Sakti Central", "SKT-CENTRAL"), ("Jaijaipur", "SKT-JJP")],
    "Mungeli": [("Mungeli Central", "MNG-CENTRAL"), ("Lormi", "MNG-LRM")],
    "Gaurela-Pendra-Marwahi": [("Gaurela Central", "GPM-CENTRAL"), ("Pendra", "GPM-PND")],
    "Kabirdham (Kawardha)": [("Kawardha City", "KBD-KWD-CITY"), ("Pandariya", "KBD-PND")],
    "Khairagarh-Chhuikhadan-Gandai": [("Khairagarh Central", "KCG-CENTRAL"), ("Chhuikhadan", "KCG-CHK")],
    "Mohla-Manpur-Ambagarh Chowki": [("Mohla Central", "MMA-CENTRAL"), ("Manpur", "MMA-MNP")],
    "Kanker": [("Kanker Central", "KNK-CENTRAL"), ("Charama", "KNK-CHM")],
    "Kondagaon": [("Kondagaon Central", "KND-CENTRAL"), ("Keshkal", "KND-KSH")],
    "Narayanpur": [("Narayanpur Central", "NRY-CENTRAL"), ("Orchha", "NRY-ORC")],
    "Dantewada": [("Dantewada Central", "DNT-CENTRAL"), ("Kirandul", "DNT-KRN")],
    "Bijapur": [("Bijapur Central", "BJP-CENTRAL"), ("Bhopalpatnam", "BJP-BHP")],
    "Sukma": [("Sukma Central", "SKM-CENTRAL"), ("Konta", "SKM-KNT")],
    "Koriya": [("Baikunthpur Central", "KRY-BKP"), ("Sonhat", "KRY-SNH")],
    "Manendragarh-Chirmiri-Bharatpur": [("Manendragarh City", "MCB-MND"), ("Chirmiri Urban", "MCB-CHM")],
    "Surajpur": [("Surajpur Central", "SRP-CENTRAL"), ("Bhaiyathan", "SRP-BHY")],
    "Balrampur-Ramanujganj": [("Balrampur Central", "BLR-CENTRAL"), ("Ramanujganj", "BLR-RMN")],
    "Jashpur": [("Jashpur Nagar", "JSH-NGR"), ("Kunkuri", "JSH-KNK")],
    "Sarangarh-Bilaigarh": [("Sarangarh Central", "SGB-CENTRAL"), ("Bilaigarh", "SGB-BLG")],
}

def seed_districts_and_zones(apps, schema_editor):
    ServiceDistrict = apps.get_model('accounts', 'ServiceDistrict')
    ServiceZone = apps.get_model('accounts', 'ServiceZone')

    for dist_name, zones_list in CG_DISTRICTS_DATA.items():
        district, _ = ServiceDistrict.objects.get_or_create(
            name=dist_name,
            defaults={'state': 'Chhattisgarh', 'is_active': True}
        )
        if not district.is_active:
            district.is_active = True
            district.save(update_fields=['is_active'])

        for z_name, z_code in zones_list:
            zone, _ = ServiceZone.objects.get_or_create(
                district=district,
                name=z_name,
                defaults={'code': z_code, 'is_active': True}
            )
            if not zone.is_active:
                zone.is_active = True
                zone.save(update_fields=['is_active'])

def reverse_seed(apps, schema_editor):
    pass

class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0015_adminnotification_accounts_ad_created_fcdf73_idx_and_more'),
    ]

    operations = [
        migrations.RunPython(seed_districts_and_zones, reverse_seed),
    ]
