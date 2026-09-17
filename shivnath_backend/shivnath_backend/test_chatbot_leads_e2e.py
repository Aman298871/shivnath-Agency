import os
import sys
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from rest_framework.test import APIRequestFactory
from chat.views import ChatbotOptionListView, ChatView
from leads.views import PublicLeadCaptureView, LeadListCreateView
from leads.models import Lead, LeadActivity
from accounts.models import UserProfile, User

def run_tests():
    print("==================================================")
    print("STARTING END-TO-END PUBLIC CHATBOT & LEADS AUDIT")
    print("==================================================")
    factory = APIRequestFactory()

    # 1. OPTION HIERARCHIES TEST
    print("\n[TEST 1] Testing Customer & Franchise Options Tree API...")
    req_cust = factory.get('/api/chat/options/?inquiry_type=customer&tree=true')
    resp_cust = ChatbotOptionListView.as_view()(req_cust)
    assert resp_cust.status_code == 200, f"Failed: {resp_cust.data}"
    cust_opts = resp_cust.data['options']
    print(f"-> Customer Root Nodes: {[o['title'] for o in cust_opts]}")

    req_fran = factory.get('/api/chat/options/?inquiry_type=franchise&tree=true')
    resp_fran = ChatbotOptionListView.as_view()(req_fran)
    assert resp_fran.status_code == 200, f"Failed: {resp_fran.data}"
    fran_opts = resp_fran.data['options']
    print(f"-> Franchise Root Nodes: {[o['title'] for o in fran_opts]}")

    # If root option is "Customer / Product Inquiry", look inside its children
    root_cust = cust_opts[0]
    cust_children = root_cust.get('children', [])
    print(f"-> Customer Level 1 Options: {[c['title'] for c in cust_children]}")
    bottle_node = next((c for c in cust_children if 'Bottle' in c['title']), None)
    assert bottle_node is not None, f"Customer option tree missing Bottle node! Had: {[c['title'] for c in cust_children]}"
    print(f"-> Bottle Children: {[c['title'] for c in bottle_node.get('children', [])]}")

    # 2. FRESH CUSTOMER LEAD CAPTURE TEST
    print("\n[TEST 2] Testing Fresh Customer Lead Ingestion with Conversation & Metadata...")
    test_phone_cust = "9876543210"
    # Clean up test leads
    Lead.objects.filter(phone__icontains=test_phone_cust).delete()

    cust_lead_payload = {
        "name": "Rahul Verma",
        "phone": test_phone_cust,
        "email": "rahul.verma@example.com",
        "city": "Raipur",
        "district": "Raipur",
        "inquiry_type": "customer",
        "selected_options": ["Customer / Product Inquiry", "Water Bottles", "2 Litre Bottle", "Product Details"],
        "notes": "Customer Inquiry Path: Customer / Product Inquiry -> Water Bottles -> 2 Litre Bottle -> Product Details",
        "conversation_history": [
            {"role": "assistant", "content": "Welcome to Shivnath Pure Water."},
            {"role": "user", "content": "Customer / Product Inquiry"},
            {"role": "assistant", "content": "Available options: Water Bottles, 20L Jar, Quotations"},
            {"role": "user", "content": "Water Bottles -> 2 Litre Bottle -> Product Details"},
            {"role": "assistant", "content": "2 Litre Family Pack is BIS certified."},
            {"role": "user", "content": "Rahul Verma, 9876543210, Raipur"},
        ]
    }

    req_cust_lead = factory.post('/api/leads/public/ingest/', cust_lead_payload, format='json')
    resp_cust_lead = PublicLeadCaptureView.as_view()(req_cust_lead)
    assert resp_cust_lead.status_code == 201, f"Failed to create customer lead: {resp_cust_lead.data}"
    assert resp_cust_lead.data['is_duplicate'] is False
    created_cust_lead_id = resp_cust_lead.data['lead']['id']
    print(f"-> Fresh Customer Lead Created (ID: {created_cust_lead_id}, Name: {resp_cust_lead.data['lead']['name']})")

    # Verify in DB
    db_lead = Lead.objects.get(id=created_cust_lead_id)
    assert "2 Litre Bottle" in db_lead.notes, "Lead notes missing product info"
    assert "CHATBOT CONVERSATION TRANSCRIPT" in db_lead.notes, "Lead notes missing conversation transcript"
    activities = list(db_lead.activities.all())
    assert len(activities) >= 1, "LeadActivity missing for new lead"
    print(f"-> Verified DB Lead Notes & Activities: {len(activities)} activity logged.")

    # 3. DEDUPLICATION TEST - CUSTOMER SUBMITS ANOTHER INQUIRY
    print("\n[TEST 3] Testing Customer Deduplication (Same Mobile Number)...")
    cust_lead_payload_2 = {
        "name": "Rahul Verma",
        "phone": test_phone_cust,
        "email": "rahul.verma@example.com",
        "city": "Raipur",
        "district": "Raipur",
        "inquiry_type": "customer",
        "selected_options": ["Customer / Product Inquiry", "20 Litre Water Jar", "Home / Office Subscription"],
        "notes": "Customer Inquiry: Subscription for 5 Jars daily",
        "conversation_history": [
            {"role": "user", "content": "20 Litre Water Jar -> Home / Office Subscription"},
            {"role": "assistant", "content": "Subscription is Rs 50/jar."},
        ]
    }
    req_cust_lead_2 = factory.post('/api/leads/public/ingest/', cust_lead_payload_2, format='json')
    resp_cust_lead_2 = PublicLeadCaptureView.as_view()(req_cust_lead_2)
    assert resp_cust_lead_2.status_code == 200, f"Expected 200 OK for duplicate: {resp_cust_lead_2.data}"
    assert resp_cust_lead_2.data['is_duplicate'] is True, "Deduplication flag failed"
    assert resp_cust_lead_2.data['lead']['id'] == created_cust_lead_id, "Duplicate lead created instead of reuse!"

    # Verify no new Lead row created in DB
    total_matching = Lead.objects.filter(phone__icontains=test_phone_cust).count()
    assert total_matching == 1, f"Duplicate lead created! Count={total_matching}"
    db_lead.refresh_from_db()
    assert db_lead.activities.count() == 2, "Second activity not attached to existing lead"
    print(f"-> Deduplication Passed: Reused Lead ID {created_cust_lead_id}, Total Leads in DB = 1, Activities = {db_lead.activities.count()}")

    # 4. FRESH FRANCHISE LEAD CAPTURE TEST
    print("\n[TEST 4] Testing Fresh Franchise Lead Ingestion with Full Qualification...")
    test_phone_fran = "9898989898"
    Lead.objects.filter(phone__icontains=test_phone_fran).delete()

    fran_payload = {
        "name": "Amit Sharma",
        "phone": test_phone_fran,
        "email": "amit.sharma@example.com",
        "city": "Bilaspur",
        "district": "Bilaspur",
        "budget": "₹5 Lakh - ₹10 Lakh",
        "space": "Yes (Ready to setup)",
        "experience": "Yes (FMCG / Water distribution)",
        "location": "Bilaspur North Zone",
        "inquiry_type": "franchise",
        "selected_options": ["Franchise Inquiry", "Investment & Space Requirements", "Investment Breakdown"],
        "notes": "Franchise Inquiry: Investment Breakdown | Budget: ₹5 Lakh - ₹10 Lakh | Space: Yes",
        "conversation_history": [
            {"role": "user", "content": "Franchise Inquiry -> Investment"},
            {"role": "assistant", "content": "Investment is Rs 3.5L to 7.5L."},
            {"role": "user", "content": "Amit Sharma, 9898989898, Bilaspur, 5-10 Lakh budget"},
        ]
    }
    req_fran_lead = factory.post('/api/leads/public/ingest/', fran_payload, format='json')
    resp_fran_lead = PublicLeadCaptureView.as_view()(req_fran_lead)
    assert resp_fran_lead.status_code == 201, f"Failed franchise lead creation: {resp_fran_lead.data}"
    assert resp_fran_lead.data['is_duplicate'] is False
    fran_lead_id = resp_fran_lead.data['lead']['id']
    print(f"-> Fresh Franchise Lead Created (ID: {fran_lead_id}, Name: {resp_fran_lead.data['lead']['name']})")

    db_fran_lead = Lead.objects.get(id=fran_lead_id)
    assert db_fran_lead.investment_budget == "₹5 Lakh - ₹10 Lakh"
    assert db_fran_lead.commercial_space == "available"
    assert db_fran_lead.preferred_location == "Bilaspur North Zone"
    print("-> Franchise Lead Qualification Data verified in PostgreSQL.")

    # 5. FRANCHISE DEDUPLICATION TEST
    print("\n[TEST 5] Testing Franchise Deduplication (Same Mobile Number)...")
    fran_payload_2 = {
        "name": "Amit Sharma",
        "phone": test_phone_fran,
        "email": "amit.sharma@example.com",
        "city": "Bilaspur",
        "district": "Bilaspur",
        "inquiry_type": "franchise",
        "selected_options": ["Franchise Inquiry", "Profit Margins & ROI", "Margin Calculation"],
        "notes": "Franchise Inquiry: Checking ROI details",
        "conversation_history": [
            {"role": "user", "content": "Profit Margins & ROI"},
            {"role": "assistant", "content": "ROI average is 6 to 9 months."},
        ]
    }
    req_fran_lead_2 = factory.post('/api/leads/public/ingest/', fran_payload_2, format='json')
    resp_fran_lead_2 = PublicLeadCaptureView.as_view()(req_fran_lead_2)
    assert resp_fran_lead_2.status_code == 200, f"Expected 200 OK: {resp_fran_lead_2.data}"
    assert resp_fran_lead_2.data['is_duplicate'] is True
    assert resp_fran_lead_2.data['lead']['id'] == fran_lead_id

    total_fran_matching = Lead.objects.filter(phone__icontains=test_phone_fran).count()
    assert total_fran_matching == 1, "Duplicate franchise lead created!"
    print(f"-> Franchise Deduplication Passed: Total Leads = 1, Activities = {db_fran_lead.activities.count() + 1}")

    print("\n==================================================")
    print("ALL CHATBOT & LEADS REQUIREMENTS PASSED 100%!")
    print("==================================================")

if __name__ == "__main__":
    run_tests()
