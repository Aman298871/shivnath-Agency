import os, sys, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import RequestFactory
from django.contrib.auth import get_user_model
from rest_framework.test import APIRequestFactory, force_authenticate
from leads.views import PublicLeadCaptureView, LeadListCreateView
from accounts.views import CustomerRegisterView, AdminUserListView
from leads.models import Lead, LeadActivity, CRMActivityLog
from accounts.models import AdminNotification, ServiceZone, ServiceDistrict, FranchiseProfile

print("=== 1. VERIFYING PUBLIC CHATBOT -> LEAD PIPELINE ===")
factory = APIRequestFactory()

# Test 1: Submit new public chatbot inquiry
lead_payload = {
    'name': 'Rakesh Verma',
    'phone': '9827198765',
    'email': 'rakesh.verma@example.com',
    'district': 'Raipur',
    'city': 'Raipur',
    'territory': 'Pandri Commercial Zone',
    'location': 'Pandri',
    'inquiry_type': 'franchise',
    'budget': '15-20 Lakhs',
    'space': 'available',
    'notes': 'Interested in establishing 500-jar daily dealership in Pandri',
    'conversation_history': [
        {'role': 'user', 'content': 'Hello, I want to know about dealership in Raipur.'},
        {'role': 'assistant', 'content': 'Namaste! We have dealership opportunities available in Raipur.'}
    ]
}

req = factory.post('/api/leads/public-capture/', lead_payload, format='json')
resp = PublicLeadCaptureView.as_view()(req)
print("Chatbot Lead 1 Response Code:", resp.status_code)
print("Chatbot Lead 1 Success:", resp.data.get('success'))
lead_data = resp.data.get('lead', {})
lead_id = lead_data.get('id')
print("Created Lead ID:", lead_id, "Source:", lead_data.get('source'))
assert lead_data.get('source') == 'PUBLIC_CHATBOT', f"Source mismatch: {lead_data.get('source')}"

# Test 2: Submit inquiry again with same phone/email -> Must NOT create duplicate!
lead_payload_2 = {
    'name': 'Rakesh Verma',
    'phone': '9827198765',
    'email': 'rakesh.verma@example.com',
    'district': 'Raipur',
    'city': 'Raipur',
    'territory': 'Pandri Commercial Zone',
    'inquiry_type': 'franchise',
    'budget': '20 Lakhs',
    'space': 'available',
    'notes': 'Follow up: have 1200 sqft warehouse ready near Pandri market',
}
req2 = factory.post('/api/leads/public-capture/', lead_payload_2, format='json')
resp2 = PublicLeadCaptureView.as_view()(req2)
print("Chatbot Lead 2 (duplicate check) Response Code:", resp2.status_code)
print("Chatbot Lead 2 Is Duplicate:", resp2.data.get('is_duplicate'))
assert resp2.data.get('is_duplicate') == True, "Failed duplicate prevention!"
assert resp2.data.get('lead', {}).get('id') == lead_id, "Duplicate lead was created instead of updating existing!"

# Test 3: Admin Leads list must contain the lead with source='PUBLIC_CHATBOT'
User = get_user_model()
admin_user = User.objects.filter(is_superuser=True).first()
admin_req = factory.get('/api/leads/')
force_authenticate(admin_req, user=admin_user)
admin_resp = LeadListCreateView.as_view()(admin_req)
leads_in_admin = admin_resp.data.get('leads', [])
matching_leads = [l for l in leads_in_admin if l.get('id') == lead_id]
print("Found in Admin Leads:", len(matching_leads) == 1)
if matching_leads:
    ml = matching_leads[0]
    print(f"Admin Lead: name={ml.get('name')}, mobile={ml.get('phone')}, email={ml.get('email')}, source={ml.get('source')}, status={ml.get('status')}")
    assert ml.get('source') == 'PUBLIC_CHATBOT'

print("=== 2. VERIFYING CUSTOMER REGISTRATION -> ADMIN PIPELINE ===")
# Ensure an active zone exists for district Raipur
zone = ServiceZone.objects.filter(is_active=True).first()
if not zone:
    dist, _ = ServiceDistrict.objects.get_or_create(name='Raipur', defaults={'state': 'Chhattisgarh'})
    zone = ServiceZone.objects.create(name='Central Raipur', district=dist, is_active=True)

cust_email = f"test_client_{os.urandom(3).hex()}@example.com"
cust_payload = {
    'name': 'Sunil Dewangan',
    'phone': '9827112345',
    'email': cust_email,
    'password': 'Password123!',
    'confirm_password': 'Password123!',
    'district': zone.district.name,
    'zone_id': zone.id,
    'city': 'Raipur',
    'locality': 'Telibandha',
    'address': 'Plot 45, Ring Road 1',
    'pincode': '492001',
}

cust_req = factory.post('/api/auth/register/customer/', cust_payload, format='json')
cust_resp = CustomerRegisterView.as_view()(cust_req)
print("Customer Register Response Code:", cust_resp.status_code)
print("Customer Register Response:", cust_resp.data)
assert cust_resp.status_code == 201, f"Customer registration failed: {cust_resp.data}"

registered_cust_id = cust_resp.data['user']['id']

# Verify Admin notification exists for customer registration
notif = AdminNotification.objects.filter(reference_id=registered_cust_id, notification_type='customer_registration').first()
print("Admin Notification created for customer registration:", notif is not None)
if notif:
    print("Notification Title:", notif.title)
    print("Notification Message:\n", notif.message)
assert notif is not None, "AdminNotification was not created!"

# Verify Customer appears in Admin Users list
admin_users_req = factory.get(f'/api/accounts/users/?role=customer&search={registered_cust_id}')
force_authenticate(admin_users_req, user=admin_user)
admin_users_resp = AdminUserListView.as_view()(admin_users_req)
print("Admin Users API Status:", admin_users_resp.status_code)
user_results = admin_users_resp.data.get('users', [])
found_user = next((u for u in user_results if u['id'] == registered_cust_id), None)
print("Customer found in Admin Users list:", found_user is not None)
if found_user:
    print(f"Details: ID={found_user['id']}, Code={found_user['customer_code']}, Name={found_user['name']}, Email={found_user['email']}, Phone={found_user['phone']}, DateJoined={found_user['date_joined']}, Source={found_user.get('source')}, Orders={found_user.get('total_orders')}, Rev={found_user.get('total_revenue')}")
assert found_user is not None, "Customer not found in Admin Users list!"

print("\n>>> ALL TESTS PASSED SUCCESSFULLY! <<<")
