import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from rest_framework.test import APIRequestFactory, force_authenticate
from accounts.models import UserProfile, AdminAuditLog, FranchiseProfile
from accounts.views import AdminResetUserPasswordView, ChangePasswordView, LoginView

def run_tests():
    print("==================================================================")
    print("STARTING TEST SUITE: SECURE ZERO-EXTERNAL-API PASSWORD RESET")
    print("==================================================================")

    factory = APIRequestFactory()

    # 1. Super Admin authentication & verification
    print("\n[Test 1] Verifying Super Admin credentials preserved...")
    super_admin = User.objects.filter(is_superuser=True).first()
    assert super_admin is not None, "Super admin must exist"
    assert super_admin.check_password("shivnath12"), "Super admin password must be preserved as shivnath12"
    print(f" PASS: Super Admin '{super_admin.email}' password intact.")

    # 2. Identify/Verify test customer
    print("\n[Test 2] Setting up verified test customer...")
    customer = User.objects.filter(profile__role='customer').first()
    if not customer:
        customer = User.objects.create_user(
            username='test_cust_e2e',
            email='test_cust_e2e@example.com',
            password='OldPassword#123'
        )
        UserProfile.objects.create(user=customer, role='customer', name='Test Customer')
    else:
        customer.set_password('OldPassword#123')
        customer.profile.must_change_password = False
        customer.profile.save()
        customer.save()
    
    assert customer.check_password('OldPassword#123'), "Customer initial password should match"
    print(f" PASS: Test customer ready: {customer.username} (ID: {customer.id})")

    # 3. Security: Non-superuser cannot reset Super Admin
    print("\n[Test 3] Verifying regular admin / staff cannot reset Super Admin...")
    regular_admin = User.objects.filter(is_staff=True, is_superuser=False).first()
    if not regular_admin:
        regular_admin = User.objects.create_user(
            username='staff_test_admin',
            email='staff_admin@example.com',
            password='StaffAdminPassword#123',
            is_staff=True,
            is_superuser=False
        )
        UserProfile.objects.create(user=regular_admin, role='admin', name='Staff Admin')
    
    reset_view = AdminResetUserPasswordView.as_view()
    bad_req = factory.post(f'/api/accounts/users/{super_admin.id}/reset-password/', {
        'verification_reason': 'Unauthorized attempt to reset super admin'
    }, format='json')
    force_authenticate(bad_req, user=regular_admin)
    bad_res = reset_view(bad_req, user_id=super_admin.id)
    assert bad_res.status_code == 403, f"Expected 403 Forbidden, got {bad_res.status_code}"
    assert super_admin.check_password("shivnath12"), "Super admin password must remain unchanged"
    print(" PASS: Unauthorized attempt to reset Super Admin properly blocked with 403 Forbidden.")

    # 4. Identity verification requirement
    print("\n[Test 4] Verifying identity verification reason is mandatory...")
    req_no_reason = factory.post(f'/api/accounts/users/{customer.id}/reset-password/', {}, format='json')
    force_authenticate(req_no_reason, user=super_admin)
    res_no_reason = reset_view(req_no_reason, user_id=customer.id)
    assert res_no_reason.status_code == 400, f"Expected 400 Bad Request, got {res_no_reason.status_code}"
    print(" PASS: Reset rejected when identity verification reason is absent.")

    # 5. Super Admin resets customer password with identity verification
    print("\n[Test 5] Super Admin resets customer password with valid identity reference...")
    req_reset = factory.post(f'/api/accounts/users/{customer.id}/reset-password/', {
        'verification_reason': 'Verified caller via registered phone and Aadhaar ending in 4123'
    }, format='json')
    force_authenticate(req_reset, user=super_admin)
    res_reset = reset_view(req_reset, user_id=customer.id)
    assert res_reset.status_code == 200, f"Expected 200 OK, got {res_reset.status_code}: {res_reset.data}"
    temp_password = res_reset.data.get('temporary_password')
    assert temp_password is not None and len(temp_password) >= 12, f"Temporary password must be strong: {temp_password}"
    assert res_reset.data.get('must_change_password') is True, "must_change_password flag must be True"

    customer.refresh_from_db()
    customer.profile.refresh_from_db()
    assert customer.profile.must_change_password is True, "Database must store must_change_password = True"
    assert customer.check_password(temp_password), "Database must authenticate temporary password via set_password()"
    assert not customer.check_password('OldPassword#123'), "Old password must no longer work"
    print(f" PASS: Temporary password generated securely: {temp_password[:4]}...{temp_password[-3:]}")

    # 6. Audit Log security check
    print("\n[Test 6] Verifying AdminAuditLog security (no passwords or credentials logged)...")
    latest_audit = AdminAuditLog.objects.filter(resource_id=str(customer.id), resource_type='User').order_by('-created_at').first()
    assert latest_audit is not None, "Audit log must be created"
    assert latest_audit.actor == super_admin, "Audit log actor must be the super admin"
    assert temp_password not in str(latest_audit.changes), "CRITICAL: Temporary password must NEVER appear in audit log"
    assert 'password' not in str(latest_audit.changes).lower() or 'credential' in str(latest_audit.changes).lower(), "Audit log must not contain raw passwords"
    print(f" PASS: Audit log verified secure without plaintext passwords: Action='{latest_audit.action}'")

    # 7. Customer login with temporary password
    print("\n[Test 7] Customer logs in with temporary password...")
    login_view = LoginView.as_view()
    login_req = factory.post('/api/auth/login/', {
        'email': customer.email or customer.username,
        'password': temp_password,
        'role': 'customer'
    }, format='json')
    login_res = login_view(login_req)
    assert login_res.status_code == 200, f"Expected 200 OK, got {login_res.status_code}: {login_res.data}"
    user_dict = login_res.data.get('user') or login_res.data.get('data', {}).get('user', {})
    assert user_dict.get('must_change_password') is True, f"Login response must indicate must_change_password: True. Got: {user_dict}"
    print(" PASS: Customer successfully authenticated with temporary password and flagged must_change_password=True.")

    # 8. Customer changes temporary password to permanent password
    print("\n[Test 8] Customer changes temporary password to permanent password...")
    change_pw_view = ChangePasswordView.as_view()
    
    # Test wrong current password rejected
    wrong_req = factory.post('/api/auth/change-password/', {
        'current_password': 'WrongPassword#999',
        'new_password': 'PermanentPassword#2026',
        'confirm_password': 'PermanentPassword#2026'
    }, format='json')
    force_authenticate(wrong_req, user=customer)
    wrong_res = change_pw_view(wrong_req)
    assert wrong_res.status_code == 400, f"Expected 400 for wrong password, got {wrong_res.status_code}"

    # Test valid change password
    valid_change_req = factory.post('/api/auth/change-password/', {
        'current_password': temp_password,
        'new_password': 'PermanentPassword#2026',
        'confirm_password': 'PermanentPassword#2026'
    }, format='json')
    force_authenticate(valid_change_req, user=customer)
    valid_change_res = change_pw_view(valid_change_req)
    assert valid_change_res.status_code == 200, f"Expected 200 OK, got {valid_change_res.status_code}: {valid_change_res.data}"
    assert valid_change_res.data.get('user', {}).get('must_change_password') is False, "must_change_password must be False"
    assert 'access' in valid_change_res.data, "Must issue fresh access token"

    customer.refresh_from_db()
    customer.profile.refresh_from_db()
    assert customer.profile.must_change_password is False, "Database must store must_change_password = False"
    assert customer.check_password('PermanentPassword#2026'), "New permanent password must be active"
    assert not customer.check_password(temp_password), "Temporary password must be expired and invalid"
    print(" PASS: Permanent password established; temporary password invalidated; fresh tokens issued.")

    # 9. Customer subsequent login with permanent password
    print("\n[Test 9] Customer logs in with new permanent password...")
    perm_login_req = factory.post('/api/auth/login/', {
        'email': customer.email or customer.username,
        'password': 'PermanentPassword#2026',
        'role': 'customer'
    }, format='json')
    perm_login_res = login_view(perm_login_req)
    assert perm_login_res.status_code == 200, f"Expected 200 OK, got {perm_login_res.status_code}"
    perm_user_dict = perm_login_res.data.get('user') or perm_login_res.data.get('data', {}).get('user', {})
    assert perm_user_dict.get('must_change_password') is False, "must_change_password must be False"
    print(" PASS: Login succeeds smoothly with must_change_password = False.")

    # 10. Franchise password reset flow
    print("\n[Test 10] Testing Franchise password reset flow...")
    franchise = FranchiseProfile.objects.first()
    assert franchise is not None, "Franchise must exist"
    f_user = franchise.user

    f_reset_req = factory.post(f'/api/accounts/users/{f_user.id}/reset-password/', {
        'verification_reason': 'Verified franchise owner KYC and GST registration via direct call'
    }, format='json')
    force_authenticate(f_reset_req, user=super_admin)
    f_reset_res = reset_view(f_reset_req, user_id=f_user.id)
    assert f_reset_res.status_code == 200, f"Expected 200, got {f_reset_res.status_code}"
    f_temp_pw = f_reset_res.data['temporary_password']

    f_user.refresh_from_db()
    assert f_user.profile.must_change_password is True
    assert f_user.check_password(f_temp_pw)

    # Franchise login with temporary password
    f_login_req = factory.post('/api/auth/login/', {
        'email': f_user.email or f_user.username,
        'password': f_temp_pw,
        'role': 'franchise'
    }, format='json')
    f_login_res = login_view(f_login_req)
    assert f_login_res.status_code == 200
    f_user_dict = f_login_res.data.get('user') or f_login_res.data.get('data', {}).get('user', {})
    assert f_user_dict.get('must_change_password') is True

    # Franchise changes to permanent password
    f_change_req = factory.post('/api/auth/change-password/', {
        'current_password': f_temp_pw,
        'new_password': 'FranchisePermanent#2026',
        'confirm_password': 'FranchisePermanent#2026'
    }, format='json')
    force_authenticate(f_change_req, user=f_user)
    f_change_res = change_pw_view(f_change_req)
    assert f_change_res.status_code == 200
    assert f_change_res.data['user']['must_change_password'] is False

    f_user.refresh_from_db()
    assert f_user.profile.must_change_password is False
    assert f_user.check_password('FranchisePermanent#2026')
    print(" PASS: Franchise password reset and update completed successfully.")

    # Reset customer back to shivnath12 for demo consistency
    customer.set_password('shivnath12')
    customer.profile.must_change_password = False
    customer.profile.save()
    customer.save()
    f_user.set_password('shivnath12')
    f_user.profile.must_change_password = False
    f_user.profile.save()
    f_user.save()

    print("\n==================================================================")
    print("ALL 10 VERIFICATION TESTS PASSED PERFECTLY!")
    print("==================================================================")

if __name__ == '__main__':
    run_tests()
