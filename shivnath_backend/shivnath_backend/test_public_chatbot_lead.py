import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from rest_framework.test import APIClient
from leads.models import Lead, CRMActivityLog, LeadActivity
from chat.models import ChatSession, ChatMessage

def test_chatbot_lead_integration():
    client = APIClient()

    # Clean up test records first
    test_phone = '9876543210'
    test_email = 'rahul.demo@example.com'
    Lead.objects.filter(phone=test_phone).delete()
    Lead.objects.filter(email=test_email).delete()
    ChatSession.objects.filter(customer_phone=test_phone).delete()

    print("--- 1. Testing ChatView Message Endpoint with customer info ---")
    resp = client.post('/api/chat/message/', {
        'message': 'Hello, I want to inquire about 20L jars for my office in Raipur.',
        'customer_name': 'Rahul Sharma',
        'customer_phone': test_phone,
        'customer_email': test_email,
        'app_type': 'customer',
        'session_id': 'session_rahul_001',
    }, content_type='application/json')
    print("ChatView status:", resp.status_code)
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"

    # Verify Lead created
    lead = Lead.objects.filter(phone=test_phone).first()
    assert lead is not None, "Lead was not created!"
    print(f"[PASS] Lead Created: ID={lead.id}, Name={lead.name}, Phone={lead.phone}, Email={lead.email}")
    print(f"[PASS] Lead Source: {lead.source}")
    assert lead.source == 'PUBLIC_CHATBOT', f"Expected PUBLIC_CHATBOT, got {lead.source}"
    assert lead.email == test_email, f"Expected {test_email}, got {lead.email}"

    # Verify CRM Activity
    crm_log = CRMActivityLog.objects.filter(lead=lead).first()
    assert crm_log is not None, "CRMActivityLog not created!"
    print(f"[PASS] CRM Activity: {crm_log.activity_type} - {crm_log.description}")

    # Verify ChatSession is linked to Lead
    session = ChatSession.objects.filter(session_id='session_rahul_001').first()
    assert session is not None, "ChatSession not found!"
    assert session.lead == lead, f"ChatSession not linked to lead! Found {session.lead}"
    print(f"[PASS] ChatSession linked to Lead: Session ID={session.id}, Lead ID={session.lead.id}")

    print("\n--- 2. Testing Repeated Message (Deduplication Check) ---")
    initial_count = Lead.objects.filter(phone=test_phone).count()
    resp2 = client.post('/api/chat/message/', {
        'message': 'Can you share price of 500ml bottles?',
        'customer_name': 'Rahul Sharma',
        'customer_phone': test_phone,
        'customer_email': test_email,
        'app_type': 'customer',
        'session_id': 'session_rahul_001',
    }, content_type='application/json')
    assert resp2.status_code == 200

    new_count = Lead.objects.filter(phone=test_phone).count()
    assert initial_count == new_count == 1, f"Duplicate lead created! Count={new_count}"
    print(f"[PASS] Deduplication verified: Still exactly 1 Lead for phone {test_phone}")

    print("\n--- 3. Testing Public Capture View (/api/leads/public-capture/) with existing phone ---")
    resp3 = client.post('/api/leads/public-capture/', {
        'name': 'Rahul Sharma Updated',
        'phone': test_phone,
        'email': test_email,
        'district': 'Raipur',
        'city': 'Raipur',
        'territory': 'Pandri',
        'inquiry_type': 'customer',
        'session_id': 'session_rahul_001',
        'notes': 'Looking for wholesale supply for retail store',
    }, content_type='application/json')
    print("Public-capture status:", resp3.status_code)
    assert resp3.status_code in [200, 201], f"Expected 200/201, got {resp3.status_code}"
    lead.refresh_from_db()
    assert Lead.objects.filter(phone=test_phone).count() == 1, "Duplicate lead created via public-capture!"
    print(f"[PASS] Existing Lead updated without duplicates: Name={lead.name}, Territory={lead.territory}")

    print("\n--- 4. Testing Admin Leads API (/api/leads/) ---")
    from django.contrib.auth.models import User
    from accounts.models import UserProfile
    admin_user = User.objects.filter(is_superuser=True).first()
    if not admin_user:
        admin_user = User.objects.create_superuser('admin_test', 'admin@test.com', 'AdminPass123!')
        UserProfile.objects.get_or_create(user=admin_user, defaults={'role': 'admin'})
    
    client.force_authenticate(user=admin_user)
    resp_admin = client.get('/api/leads/')
    assert resp_admin.status_code == 200, f"Expected 200, got {resp_admin.status_code}"
    leads_data = resp_admin.json().get('leads', [])
    found_in_admin = any(l['phone'] == test_phone for l in leads_data)
    assert found_in_admin, "Lead not found in Admin Leads API!"
    target_data = next(l for l in leads_data if l['phone'] == test_phone)
    print(f"[PASS] Lead visible in Admin Leads API: Name={target_data['name']}, Source={target_data['source']}, Sessions={len(target_data.get('chat_sessions', []))}")

    print("\n[SUCCESS] ALL PUBLIC CHATBOT LEAD TESTS PASSED SUCCESSFULLY!")

if __name__ == '__main__':
    test_chatbot_lead_integration()
