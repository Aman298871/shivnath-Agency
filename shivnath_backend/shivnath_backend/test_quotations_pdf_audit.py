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

from django.core.files.uploadedfile import SimpleUploadedFile

# 1. Test Admin Create Quotation with Uploaded PDF
admin_user, _ = User.objects.get_or_create(username='test_admin_audit', is_staff=True, is_superuser=True)
profile, _ = UserProfile.objects.get_or_create(user=admin_user, defaults={'role': 'admin', 'phone': '9876543219'})
product = Product.objects.filter(status='Active').first()

rf = APIRequestFactory()

pdf_content = b"%PDF-1.4 Official Shivnath Packaged Drinking Water Quotation PDF File Test Content"
uploaded_pdf = SimpleUploadedFile("shivnath_official_rate_card.pdf", pdf_content, content_type="application/pdf")

# Create Quotation with PDF
req = rf.post('/api/chat/quotations/', {
    'title': 'Test Bulk Audit Quotation with PDF',
    'quotation_type': 'bulk',
    'target_audience': 'both',
    'quantity_tier': '100+ Boxes',
    'unit_price': '180.00',
    'total_price': '18000.00',
    'validity': 'Valid for 15 Days',
    'product_id': product.id if product else None,
    'pdf_file': uploaded_pdf,
}, format='multipart')
force_authenticate(req, user=admin_user)
res = QuotationListCreateView.as_view()(req)
assert res.status_code == 201, f"Create quotation failed: {res.data}"
q_id = res.data['quotation']['id']
assert res.data['quotation']['has_pdf'] is True
assert 'shivnath_official_rate_card' in res.data['quotation']['pdf_name']
print(f"[TEST 1] Quotation Created with Real Uploaded PDF (ID: {q_id}, PDF: {res.data['quotation']['pdf_name']})")

# 2. Test Download of Real Uploaded PDF
pdf_req = rf.get(f'/api/chat/quotations/{q_id}/pdf/')
pdf_res = QuotationPDFDownloadView.as_view()(pdf_req, pk=q_id)
assert pdf_res.status_code == 200
assert pdf_res['Content-Type'] == 'application/pdf'
assert b"Official Shivnath Packaged Drinking Water" in b"".join(pdf_res.streaming_content)
print(f"[TEST 2] Verified Real Uploaded PDF Download from Database.")

# 3. Test Admin Replace PDF
new_pdf_content = b"%PDF-1.4 Replaced 2026 Rate Card"
new_uploaded_pdf = SimpleUploadedFile("updated_rates_2026.pdf", new_pdf_content, content_type="application/pdf")
patch_req = rf.patch(f'/api/chat/quotations/{q_id}/', {
    'title': 'Updated Bulk Audit Quotation 2026',
    'unit_price': '175.00',
    'pdf_file': new_uploaded_pdf,
}, format='multipart')
force_authenticate(patch_req, user=admin_user)
patch_res = QuotationDetailView.as_view()(patch_req, pk=q_id)
assert patch_res.status_code == 200, f"Patch quotation failed: {patch_res.data}"
assert 'updated_rates_2026' in patch_res.data['quotation']['pdf_name']
print(f"[TEST 3] Quotation PDF Replaced Successfully (New File: {patch_res.data['quotation']['pdf_name']})")

# 4. Test Remove PDF
remove_req = rf.patch(f'/api/chat/quotations/{q_id}/', {
    'remove_pdf': True,
}, format='json')
force_authenticate(remove_req, user=admin_user)
remove_res = QuotationDetailView.as_view()(remove_req, pk=q_id)
assert remove_res.status_code == 200
assert remove_res.data['quotation']['has_pdf'] is False
print(f"[TEST 4] Quotation PDF Removed Successfully from Database.")

# 5. Test Download without PDF (Must return structured data with has_pdf=False)
pdf_req2 = rf.get(f'/api/chat/quotations/{q_id}/pdf/')
pdf_res2 = QuotationPDFDownloadView.as_view()(pdf_req2, pk=q_id)
assert pdf_res2.status_code == 404
assert pdf_res2.data['has_pdf'] is False
print(f"[TEST 5] Verified No-PDF Behavior: Returns 404 with structured notification and has_pdf: False.")

# 6. Test Quotation Delete
del_req = rf.delete(f'/api/chat/quotations/{q_id}/')
force_authenticate(del_req, user=admin_user)
del_res = QuotationDetailView.as_view()(del_req, pk=q_id)
assert del_res.status_code == 200
assert not Quotation.objects.filter(id=q_id).exists()
print(f"[TEST 6] Quotation Deleted Successfully from PostgreSQL.")

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
