import os
import sys
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from rest_framework.test import APIRequestFactory, force_authenticate
from django.contrib.auth.models import User
from accounts.models import UserProfile
from products.models import Product
from chat.models import Quotation, ChatbotOption
from chat.views import QuotationListCreateView, QuotationDetailView, QuotationPDFDownloadView
from chat.services import AIService

print("==================================================")
print("AUDITING QUOTATION CRUD, PDF GENERATION & DYNAMIC PRICE SYNC")
print("==================================================")

# 1. Test Admin Create Quotation
admin_user, _ = User.objects.get_or_create(username='test_admin_audit', is_staff=True, is_superuser=True)
profile, _ = UserProfile.objects.get_or_create(user=admin_user, defaults={'role': 'admin', 'phone': '9876543219'})
product = Product.objects.filter(status='Active').first()

rf = APIRequestFactory()

# Create Quotation
req = rf.post('/api/chat/quotations/', {
    'title': 'Test Bulk Audit Quotation',
    'quotation_type': 'bulk',
    'target_audience': 'both',
    'quantity_tier': '100+ Boxes',
    'unit_price': '180.00',
    'total_price': '18000.00',
    'validity': 'Valid for 15 Days',
    'product_id': product.id if product else None,
}, format='json')
force_authenticate(req, user=admin_user)
res = QuotationListCreateView.as_view()(req)
assert res.status_code == 201, f"Create quotation failed: {res.data}"
q_id = res.data['quotation']['id']
print(f"[TEST 1] Quotation Created Successfully (ID: {q_id}, Title: {res.data['quotation']['title']})")

# 2. Test Admin Patch / Replace Quotation
patch_req = rf.patch(f'/api/chat/quotations/{q_id}/', {
    'title': 'Updated Bulk Audit Quotation 2026',
    'unit_price': '175.00',
    'total_price': '17500.00',
}, format='json')
force_authenticate(patch_req, user=admin_user)
patch_res = QuotationDetailView.as_view()(patch_req, pk=q_id)
assert patch_res.status_code == 200, f"Patch quotation failed: {patch_res.data}"
assert patch_res.data['quotation']['unit_price'] == '175.00'
print(f"[TEST 2] Quotation Updated / Replaced Successfully (New Unit Price: Rs. {patch_res.data['quotation']['unit_price']})")

# 3. Test Quotation PDF Generation
pdf_req = rf.get(f'/api/chat/quotations/{q_id}/pdf/')
pdf_res = QuotationPDFDownloadView.as_view()(pdf_req, pk=q_id)
assert pdf_res.status_code == 200
assert pdf_res['Content-Type'] == 'application/pdf'
assert len(pdf_res.content) > 1000
print(f"[TEST 3] Quotation PDF Generated Successfully with ReportLab ({len(pdf_res.content)} bytes generated)")

# 4. Test Quotation Delete
del_req = rf.delete(f'/api/chat/quotations/{q_id}/')
force_authenticate(del_req, user=admin_user)
del_res = QuotationDetailView.as_view()(del_req, pk=q_id)
assert del_res.status_code == 200
assert not Quotation.objects.filter(id=q_id).exists()
print(f"[TEST 4] Quotation Deleted Successfully from PostgreSQL.")

# 5. Test Dynamic Product Price Sync in Chatbot Live Context
if product:
    original_price = product.price
    product.price = 999.00
    product.save()
    
    ctx = AIService.get_live_app_context('customer')
    matched_prod = next((p for p in ctx['products'] if p['id'] == product.id), None)
    assert matched_prod is not None
    assert str(matched_prod['price']) == '999.00', f"Price not updated in live context: {matched_prod['price']}"
    print(f"[TEST 5] Live Dynamic Product Price Sync Verified: Context reads Rs. {matched_prod['price']} immediately.")
    
    # Revert product price
    product.price = original_price
    product.save()

print("==================================================")
print("ALL QUOTATIONS, PDF & PRICE SYNC AUDIT CHECKS PASSED 100%!")
print("==================================================")
