import os
import sys
import django
import json
import hashlib
from io import BytesIO
from django.core.files.uploadedfile import SimpleUploadedFile

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import RequestFactory
from django.contrib.auth.models import User
from django.db import connection
from django.conf import settings
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import (
    UserProfile, FranchiseProfile, DealerDocument,
    DealerDocumentVerificationLog, AdminAuditLog
)
from accounts.views import (
    DealerKYCDocumentView, DealerKYCVerifyView, ProtectedDealerDocumentView,
    ApproveFranchiseView
)
from products.views import CategoryListCreateView
from products.models import ProductCategory, Product
from orders.models import Order
from orders.views import OrderStatusUpdateView

factory = RequestFactory()

def print_section(title):
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def get_tokens(user):
    refresh = RefreshToken.for_user(user)
    return str(refresh.access_token)

def run_tests():
    print_section("RUNNING COMPREHENSIVE FSSAI, STORAGE, AUDIT & ORDER AUDIT SUITE")
    passed = 0
    failed = 0

    # 1. Setup Admin User
    admin_user, _ = User.objects.get_or_create(
        username='admin_audit_tester@shivnath.com',
        defaults={'email': 'admin_audit_tester@shivnath.com', 'first_name': 'Audit', 'last_name': 'Admin', 'is_staff': True, 'is_superuser': True}
    )
    admin_user.set_password('AdminPass@123')
    admin_user.save()
    admin_profile, _ = UserProfile.objects.get_or_create(user=admin_user)
    admin_profile.role = 'admin'
    admin_profile.phone = '9999900001'
    admin_profile.save()

    # 2. Setup Franchise User A
    user_a, _ = User.objects.get_or_create(
        username='franchise_alpha@shivnath.com',
        defaults={'email': 'franchise_alpha@shivnath.com', 'first_name': 'Alpha', 'last_name': 'Dealer'}
    )
    user_a.set_password('AlphaPass@123')
    user_a.save()
    profile_a, _ = UserProfile.objects.get_or_create(user=user_a)
    profile_a.role = 'franchise'
    profile_a.phone = '9888800001'
    profile_a.save()

    franchise_a, _ = FranchiseProfile.objects.get_or_create(
        user=user_a,
        defaults={
            'business_name': 'Alpha Water Agency',
            'city': 'Raipur',
            'address': 'Industrial Area, Ring Road',
            'territory': 'Raipur Central',
            'status': 'pending',
            'fssai_verification_status': 'PENDING_VERIFICATION'
        }
    )

    # 3. Setup Franchise User B
    user_b, _ = User.objects.get_or_create(
        username='franchise_beta@shivnath.com',
        defaults={'email': 'franchise_beta@shivnath.com', 'first_name': 'Beta', 'last_name': 'Dealer'}
    )
    user_b.set_password('BetaPass@123')
    user_b.save()
    profile_b, _ = UserProfile.objects.get_or_create(user=user_b)
    profile_b.role = 'franchise'
    profile_b.phone = '9888800002'
    profile_b.save()

    franchise_b, _ = FranchiseProfile.objects.get_or_create(
        user=user_b,
        defaults={
            'business_name': 'Beta Water Agency',
            'city': 'Bhilai',
            'address': 'Sector 6, Main Market',
            'territory': 'Durg/Bhilai',
            'status': 'pending',
            'fssai_verification_status': 'PENDING_VERIFICATION'
        }
    )

    admin_token = get_tokens(admin_user)
    token_a = get_tokens(user_a)
    token_b = get_tokens(user_b)

    # Clean existing test documents for isolated run
    DealerDocument.objects.filter(dealer__in=[franchise_a, franchise_b]).delete()
    DealerDocumentVerificationLog.objects.filter(franchise__in=[franchise_a, franchise_b]).delete()

    # ---------------------------------------------------------
    # TEST 1: Actual Upload of FSSAI PDF & Image (Criteria 1 & 2)
    # ---------------------------------------------------------
    print_section("TEST 1: Actual Upload of FSSAI PDF & Image via KYC API")
    pdf_content = b"%PDF-1.4\n%Shivnath Pure Water Authorized FSSAI License\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R >>\n%%EOF"
    pdf_file = SimpleUploadedFile("fssai_cert_v1.pdf", pdf_content, content_type="application/pdf")
    pdf_hash = hashlib.sha256(pdf_content).hexdigest()

    req_upload_pdf = factory.post(
        '/api/accounts/dealers/documents/',
        {
            'document_type': 'FSSAI_CERTIFICATE',
            'document_number': '10022000009999',
            'document_file': pdf_file,
        },
        HTTP_AUTHORIZATION=f'Bearer {token_a}'
    )
    view_kyc = DealerKYCDocumentView.as_view()
    resp_upload_pdf = view_kyc(req_upload_pdf)

    if resp_upload_pdf.status_code == 201:
        doc_id_v1 = resp_upload_pdf.data['data']['id']
        doc_v1 = DealerDocument.objects.get(id=doc_id_v1)
        file_path_v1 = doc_v1.document_file.path
        
        # Verify file exists on disk and bytes match
        if os.path.exists(file_path_v1):
            with open(file_path_v1, 'rb') as f:
                disk_content = f.read()
            if disk_content == pdf_content and doc_v1.version == 1:
                print(f"[PASS] PDF stored on disk at: {file_path_v1}")
                print(f"       Document ID: {doc_id_v1}, Version: {doc_v1.version}, SHA256: {pdf_hash[:16]}...")
                passed += 1
            else:
                print(f"[FAIL] Content or version mismatch on disk")
                failed += 1
        else:
            print(f"[FAIL] Physical file not found at {file_path_v1}")
            failed += 1
    else:
        print(f"[FAIL] PDF Upload failed: {resp_upload_pdf.status_code} {resp_upload_pdf.data}")
        failed += 1

    # Upload replacement image version (v2) of the FSSAI certificate
    image_content = b"\xFF\xD8\xFF\xE0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xFF\xDB\x00C\x00ShivnathFssaiTestImageBytes\xFF\xD9"
    img_file = SimpleUploadedFile("fssai_cert_v2.jpg", image_content, content_type="image/jpeg")
    req_upload_img = factory.post(
        '/api/accounts/dealers/documents/',
        {
            'document_type': 'FSSAI_CERTIFICATE',
            'document_number': '10022000009999',
            'document_file': img_file,
        },
        HTTP_AUTHORIZATION=f'Bearer {token_a}'
    )
    resp_upload_img = view_kyc(req_upload_img)
    if resp_upload_img.status_code == 201:
        doc_id_v2 = resp_upload_img.data['data']['id']
        doc_v2 = DealerDocument.objects.get(id=doc_id_v2)
        doc_v1.refresh_from_db()
        if doc_v2.version == 2 and doc_v1.version == 1 and doc_id_v2 != doc_id_v1:
            print(f"[PASS] Replacement image stored as Version 2: Doc ID {doc_id_v2}, Version {doc_v2.version}")
            print(f"       Previous Version 1 preserved: Doc ID {doc_id_v1}, Version {doc_v1.version}")
            passed += 1
        else:
            print(f"[FAIL] Versioning mismatch: v1={doc_v1.version}, v2={doc_v2.version}")
            failed += 1
    else:
        print(f"[FAIL] Image upload failed: {resp_upload_img.status_code} {resp_upload_img.data}")
        failed += 1

    # ---------------------------------------------------------
    # TEST 2: Storage Persistence / Backend Restart Simulation (Criteria 2)
    # ---------------------------------------------------------
    print_section("TEST 2: Storage Persistence Across Backend Restart Simulation")
    connection.close()
    persisted_doc = DealerDocument.objects.get(id=doc_id_v2)
    storage_path = persisted_doc.document_file.path
    if os.path.exists(storage_path) and os.path.getsize(storage_path) == len(image_content):
        req_admin_view = factory.get(
            f'/api/accounts/dealers/documents/{doc_id_v2}/view/',
            HTTP_AUTHORIZATION=f'Bearer {admin_token}'
        )
        resp_admin_view = ProtectedDealerDocumentView.as_view()(req_admin_view, pk=doc_id_v2)
        if resp_admin_view.status_code == 200 and resp_admin_view.getvalue() == image_content:
            print(f"[PASS] File survived restart simulation at {storage_path}")
            print(f"       Admin authorized retrieval returned exact {len(image_content)} bytes")
            passed += 1
        else:
            print(f"[FAIL] Admin retrieval failed: {resp_admin_view.status_code}")
            failed += 1
    else:
        print(f"[FAIL] File not found or size mismatch after restart simulation")
        failed += 1

    # ---------------------------------------------------------
    # TEST 3: Persistent Audit Trail (Criteria 3)
    # ---------------------------------------------------------
    print_section("TEST 3: Mandatory Rejection Reason & Persistent Audit Trail")
    view_verify = DealerKYCVerifyView.as_view()

    # Empty rejection reason must be rejected with 400
    req_rej_empty = factory.post(
        f'/api/accounts/dealers/documents/{doc_id_v2}/verify/',
        {'action': 'REJECTED', 'rejection_reason': '   '},
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_rej_empty = view_verify(req_rej_empty, pk=doc_id_v2)
    if resp_rej_empty.status_code == 400 and 'rejection' in resp_rej_empty.data.get('message', '').lower():
        print("[PASS] Rejection without reason rejected by backend validation (400 Bad Request)")
        passed += 1
    else:
        print(f"[FAIL] Empty rejection reason was not blocked: {resp_rej_empty.status_code} {resp_rej_empty.data}")
        failed += 1

    # Valid Rejection with reason
    rejection_note = "Certificate blurry and FSSAI number mismatch on official registry"
    req_rej_valid = factory.post(
        f'/api/accounts/dealers/documents/{doc_id_v2}/verify/',
        {'action': 'REJECTED', 'rejection_reason': rejection_note},
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_rej_valid = view_verify(req_rej_valid, pk=doc_id_v2)
    if resp_rej_valid.status_code == 200:
        doc_v2.refresh_from_db()
        franchise_a.refresh_from_db()
        log_entry = DealerDocumentVerificationLog.objects.filter(document=doc_v2).latest('created_at')
        if (doc_v2.verification_status == 'REJECTED' and
            franchise_a.fssai_verification_status == 'REJECTED' and
            log_entry.decision == 'REJECTED' and
            log_entry.rejection_reason == rejection_note and
            log_entry.reviewer == admin_user):
            print(f"[PASS] Rejection persisted with server timestamp {log_entry.created_at}")
            print(f"       Reviewer derived from token: {log_entry.reviewer.email}")
            print(f"       Audit note recorded: '{log_entry.rejection_reason}'")
            passed += 1
        else:
            print(f"[FAIL] Rejection audit log or status mismatch: decision={log_entry.decision}, reason={log_entry.rejection_reason}")
            failed += 1
    else:
        print(f"[FAIL] Valid rejection failed: {resp_rej_valid.status_code} {resp_rej_valid.data}")
        failed += 1

    # Admin verification approval of v1
    req_verify_ok = factory.post(
        f'/api/accounts/dealers/documents/{doc_id_v1}/verify/',
        {'action': 'VERIFIED', 'notes': 'Original PDF verified directly with FoSCoS portal'},
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_verify_ok = view_verify(req_verify_ok, pk=doc_id_v1)
    if resp_verify_ok.status_code == 200:
        log_v1 = DealerDocumentVerificationLog.objects.filter(document=doc_v1).latest('created_at')
        print(f"[PASS] Approval decision persisted: Decision={log_v1.decision}, Reviewer={log_v1.reviewer.email}")
        passed += 1
    else:
        print(f"[FAIL] Approval failed: {resp_verify_ok.status_code}")
        failed += 1

    # ---------------------------------------------------------
    # TEST 4: Unauthorized Access & Activation Security (Criteria 4)
    # ---------------------------------------------------------
    print_section("TEST 4: Unauthorized Access & Activation Isolation")
    view_protected = ProtectedDealerDocumentView.as_view()

    # 4.1 Unauthenticated access blocked (401)
    req_unauth = factory.get(f'/api/accounts/dealers/documents/{doc_id_v1}/view/')
    resp_unauth = view_protected(req_unauth, pk=doc_id_v1)
    if resp_unauth.status_code == 401:
        print("[PASS] Unauthenticated request correctly rejected with 401 Unauthorized")
        passed += 1
    else:
        print(f"[FAIL] Unauthenticated request returned {resp_unauth.status_code}")
        failed += 1

    # 4.2 Cross-tenant access blocked (Franchise B accessing Franchise A's doc -> 403)
    req_cross_tenant = factory.get(
        f'/api/accounts/dealers/documents/{doc_id_v1}/view/',
        HTTP_AUTHORIZATION=f'Bearer {token_b}'
    )
    resp_cross_tenant = view_protected(req_cross_tenant, pk=doc_id_v1)
    if resp_cross_tenant.status_code == 403:
        print("[PASS] Cross-tenant access (Franchise B -> Franchise A doc) rejected with 403 Forbidden")
        passed += 1
    else:
        print(f"[FAIL] Cross-tenant request returned {resp_cross_tenant.status_code}")
        failed += 1

    # 4.3 Direct media URL access interceptor
    filename_v1 = os.path.basename(doc_v1.document_file.name)
    req_direct_media_unauth = factory.get(f'/media/dealer_documents/{filename_v1}')
    resp_direct_media_unauth = view_protected(req_direct_media_unauth, filename=filename_v1)
    if resp_direct_media_unauth.status_code == 401:
        print(f"[PASS] Direct storage media URL (/media/dealer_documents/{filename_v1}) blocked with 401")
        passed += 1
    else:
        print(f"[FAIL] Direct storage media returned {resp_direct_media_unauth.status_code}")
        failed += 1

    # 4.4 Franchise user attempting to verify document -> 403
    req_franchise_verify = factory.post(
        f'/api/accounts/dealers/documents/{doc_id_v1}/verify/',
        {'action': 'VERIFIED'},
        HTTP_AUTHORIZATION=f'Bearer {token_a}'
    )
    resp_franchise_verify = view_verify(req_franchise_verify, pk=doc_id_v1)
    if resp_franchise_verify.status_code == 403:
        print("[PASS] Franchise user cannot call verification endpoint (403 Forbidden)")
        passed += 1
    else:
        print(f"[FAIL] Franchise user verify returned {resp_franchise_verify.status_code}")
        failed += 1

    # 4.5 Activation tests:
    # A) Missing FSSAI document blocks activation
    franchise_b.status = 'pending'
    franchise_b.fssai_verification_status = 'PENDING_VERIFICATION'
    franchise_b.save()
    DealerDocument.objects.filter(dealer=franchise_b).delete()

    req_approve_b = factory.post(
        f'/api/accounts/franchises/{franchise_b.id}/approve/',
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_approve_b = ApproveFranchiseView.as_view()(req_approve_b, pk=franchise_b.id)
    if resp_approve_b.status_code == 400 and 'fssai' in resp_approve_b.data.get('message', '').lower():
        print("[PASS] Franchise activation BLOCKED when required FSSAI document is missing (400 Bad Request)")
        passed += 1
    else:
        print(f"[FAIL] Missing FSSAI activation check failed: {resp_approve_b.status_code} {resp_approve_b.data}")
        failed += 1

    # B) Rejected FSSAI document blocks activation
    franchise_a.status = 'pending'
    franchise_a.fssai_verification_status = 'REJECTED'
    franchise_a.save()
    req_approve_a_rej = factory.post(
        f'/api/accounts/franchises/{franchise_a.id}/approve/',
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_approve_a_rej = ApproveFranchiseView.as_view()(req_approve_a_rej, pk=franchise_a.id)
    if resp_approve_a_rej.status_code == 400 and 'fssai' in resp_approve_a_rej.data.get('message', '').lower():
        print("[PASS] Franchise activation BLOCKED when FSSAI document is REJECTED (400 Bad Request)")
        passed += 1
    else:
        print(f"[FAIL] Rejected FSSAI activation check failed: {resp_approve_a_rej.status_code} {resp_approve_a_rej.data}")
        failed += 1

    # C) Verified FSSAI satisfies requirement
    franchise_a.fssai_verification_status = 'VERIFIED'
    franchise_a.status = 'pending'
    franchise_a.save()
    resp_approve_a_ok = ApproveFranchiseView.as_view()(req_approve_a_rej, pk=franchise_a.id)
    franchise_a.refresh_from_db()
    if resp_approve_a_ok.status_code == 200 and franchise_a.status == 'approved':
        print("[PASS] Verified FSSAI document permits franchise approval (Status: approved)")
        passed += 1
    else:
        print(f"[FAIL] Verified FSSAI approval failed: {resp_approve_a_ok.status_code} {resp_approve_a_ok.data}")
        failed += 1

    # ---------------------------------------------------------
    # TEST 5: Category Filtering - Issue 1 Fix Verification
    # ---------------------------------------------------------
    print_section("TEST 5: Catalogue Filter with has_active_products=true (Issue 1)")
    req_cats = factory.get('/api/products/categories/?has_active_products=true')
    resp_cats = CategoryListCreateView.as_view()(req_cats)
    if resp_cats.status_code == 200:
        categories = resp_cats.data.get('categories', []) if isinstance(resp_cats.data, dict) else (resp_cats.data or [])
        empty_cats = [c for c in categories if c.get('product_count', 0) == 0]
        active_cats = [c for c in categories if c.get('product_count', 0) > 0]
        cat_names = [c['name'] for c in active_cats]
        if len(empty_cats) == 0 and len(active_cats) > 0:
            print(f"[PASS] has_active_products=true returned {len(active_cats)} categories, 0 empty categories.")
            print(f"       Active categories visible to customer: {', '.join(cat_names)}")
            passed += 1
        else:
            print(f"[FAIL] Empty categories returned: {empty_cats}")
            failed += 1
    else:
        print(f"[FAIL] Categories endpoint returned {resp_cats.status_code}")
        failed += 1

    # ---------------------------------------------------------
    # TEST 6: Admin Order Status Transition & Diagnostic Error (Issue 4)
    # ---------------------------------------------------------
    print_section("TEST 6: Admin Order Status Transition & Validation (Issue 4)")
    test_order = Order.objects.filter(status='order_placement').first()
    if not test_order:
        test_order = Order.objects.create(
            user=user_a,
            order_type='customer_delivery',
            total_amount=100.0,
            status='order_placement',
            payment_status='pending'
        )

    # 6.1 Invalid transition: order_placement -> dispatch (must fail with 400 Bad Request)
    view_order_status = OrderStatusUpdateView.as_view()
    req_invalid_status = factory.patch(
        f'/api/orders/{test_order.id}/status/',
        data=json.dumps({'status': 'dispatch'}),
        content_type='application/json',
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_invalid_status = view_order_status(req_invalid_status, pk=test_order.id)
    if resp_invalid_status.status_code == 400 and ('invalid' in resp_invalid_status.data.get('message', '').lower() or resp_invalid_status.data.get('error_code') == 'INVALID_STATUS_TRANSITION'):
        print(f"[PASS] Prohibited status transition blocked with 400: '{resp_invalid_status.data.get('message')}'")
        passed += 1
    else:
        print(f"[FAIL] Invalid transition not rejected with 400: {resp_invalid_status.status_code} {resp_invalid_status.data}")
        failed += 1

    # 6.2 Valid transition: order_placement -> plant_approval
    req_valid_status = factory.patch(
        f'/api/orders/{test_order.id}/status/',
        data=json.dumps({'status': 'plant_approval'}),
        content_type='application/json',
        HTTP_AUTHORIZATION=f'Bearer {admin_token}'
    )
    resp_valid_status = view_order_status(req_valid_status, pk=test_order.id)
    if resp_valid_status.status_code == 200:
        test_order.refresh_from_db()
        if test_order.status == 'plant_approval':
            print(f"[PASS] Valid status transition succeeded: Order status updated to '{test_order.status}'")
            passed += 1
        else:
            print(f"[FAIL] Order status in DB not updated")
            failed += 1
    else:
        print(f"[FAIL] Valid transition failed: {resp_valid_status.status_code} {resp_valid_status.data}")
        failed += 1

    # Final Summary
    print_section(f"TEST SUITE COMPLETE: {passed} PASSED, {failed} FAILED")
    return failed == 0

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
