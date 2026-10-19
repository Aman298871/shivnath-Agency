from django.test import TestCase
from django.contrib.auth import get_user_model
from decimal import Decimal
from rest_framework.test import APIClient
from rest_framework import status

from accounts.models import (
    UserProfile, FranchiseProfile, ServiceDistrict, ServiceZone,
    AdminNotification, FranchiseNotification, CustomerNotification
)
from products.models import Product
from orders.models import Order, OrderItem, OrderStatusHistory
from orders.serializers import OrderSerializer
from orders.services import (
    validate_order_status_transition,
    validate_payment_stage,
    transition_order_status,
    repair_historical_orders_lifecycle,
)
from accounts.fcm_services import notify_order_created

User = get_user_model()


class OrderLifecycleAndTransitionAuditTest(TestCase):
    def setUp(self):
        self.client = APIClient()

        # 1. Admin
        self.admin_user, _ = User.objects.get_or_create(
            username='admin_lifecycle_test',
            defaults={'email': 'admin_life@example.com', 'is_superuser': True, 'is_staff': True}
        )
        prof = getattr(self.admin_user, 'profile', None)
        if prof:
            prof.role = 'super_admin'
            prof.name = 'Super Admin'
            prof.save()

        # 2. Franchise A
        self.franchise_user, _ = User.objects.get_or_create(
            username='franchise_alpha_user',
            defaults={'email': 'alpha@example.com'}
        )
        self.district, _ = ServiceDistrict.objects.get_or_create(name='Raipur Dist', defaults={'state': 'Chhattisgarh'})
        self.zone, _ = ServiceZone.objects.get_or_create(name='Raipur Zone Alpha', defaults={'district': self.district})
        self.franchise, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_user,
            defaults={
                'business_name': 'Alpha Franchise Water',
                'city': 'Raipur',
                'address': 'Main Road Alpha',
                'status': 'approved',
            }
        )

        # 3. Unrelated Franchise B
        self.unrelated_user, _ = User.objects.get_or_create(
            username='franchise_beta_user',
            defaults={'email': 'beta@example.com'}
        )
        self.unrelated_franchise, _ = FranchiseProfile.objects.get_or_create(
            user=self.unrelated_user,
            defaults={
                'business_name': 'Beta Franchise Water',
                'city': 'Bilaspur',
                'address': 'Main Road Beta',
                'status': 'approved',
            }
        )

        # 4. Customer
        self.customer_user, _ = User.objects.get_or_create(
            username='customer_aman',
            defaults={'email': 'aman@example.com'}
        )
        c_prof = getattr(self.customer_user, 'profile', None)
        if c_prof:
            c_prof.role = 'customer'
            c_prof.name = 'Aman Singh'
            c_prof.phone = '9827199999'
            c_prof.save()

        # 5. Product
        self.product, _ = Product.objects.get_or_create(
            sku='SHV-500ML-LIFECYCLE',
            defaults={
                'name': 'Shivnath 500ml Bottle',
                'size': '500ml',
                'price': Decimal('10.00'),
                'stock': 1000,
                'status': 'Active'
            }
        )

    def test_1_franchise_order_creation_routing_and_lifecycle(self):
        """Test 1: Franchise Order creation, notifications, and strict sequential lifecycle."""
        AdminNotification.objects.all().delete()
        FranchiseNotification.objects.all().delete()

        # Customer places order fulfilled by Franchise Alpha
        order = Order.objects.create(
            client_name='Aman Singh',
            created_by=self.customer_user,
            serving_franchise=self.franchise,
            order_source='FRANCHISE',
            franchise_name='Alpha Franchise Water',
            amount=Decimal('1000.00'),
            items_count=100,
            status='order_placement',
            payment_status='pending',
            delivery_address='Civic Center, Raipur',
        )
        OrderItem.objects.create(
            order=order, product=self.product, product_name=self.product.name,
            quantity=100, unit_price=10.0, total_price=1000.0
        )

        # 1. Initial OrderStatusHistory
        OrderStatusHistory.objects.create(
            order=order,
            old_status='',
            new_status='order_placement',
            changed_by=self.customer_user,
            notes='Order placed by customer.',
        )

        notify_order_created(order)

        # Admin Notification check
        admin_notifs = AdminNotification.objects.filter(reference_id=order.id)
        self.assertTrue(admin_notifs.exists())
        self.assertIn('Alpha Franchise Water', admin_notifs.first().message)

        # Serving Franchise Alpha Notification check
        alpha_notifs = FranchiseNotification.objects.filter(franchise=self.franchise, reference_id=order.id)
        self.assertTrue(alpha_notifs.exists())
        self.assertIn('Aman Singh', alpha_notifs.first().message)

        # Unrelated Franchise Beta must receive ZERO notifications
        beta_notifs = FranchiseNotification.objects.filter(franchise=self.unrelated_franchise, reference_id=order.id)
        self.assertFalse(beta_notifs.exists())

        # 2. Sequential Lifecycle Transitions
        # Step A: plant_approval
        transition_order_status(order, 'plant_approval', actor=self.admin_user, notes='Approved by admin')
        self.assertEqual(order.status, 'plant_approval')

        # Step B: invoice_generated
        transition_order_status(order, 'invoice_generated', actor=self.admin_user, notes='Invoice generated')
        self.assertEqual(order.status, 'invoice_generated')

        # Step C: preparing
        transition_order_status(order, 'preparing', actor=self.franchise_user, notes='Bottles packed and staged')
        self.assertEqual(order.status, 'preparing')

        # Step D: dispatch
        transition_order_status(order, 'dispatch', actor=self.franchise_user, notes='Dispatched in delivery van')
        self.assertEqual(order.status, 'dispatch')

        # Step E: delivered
        transition_order_status(order, 'delivered', actor=self.franchise_user, notes='Delivered to client')
        self.assertEqual(order.status, 'delivered')

        # Verify OrderStatusHistory count and sequence
        history = list(order.status_history.all().order_by('created_at', 'id'))
        statuses = [h.new_status for h in history]
        self.assertIn('order_placement', statuses)
        self.assertIn('plant_approval', statuses)
        self.assertIn('invoice_generated', statuses)
        self.assertIn('preparing', statuses)
        self.assertIn('dispatch', statuses)
        self.assertIn('delivered', statuses)

    def test_2_direct_company_order_no_franchise_leak(self):
        """Test 2: Direct Company Order never shows franchise or routes notifications to franchise."""
        AdminNotification.objects.all().delete()
        FranchiseNotification.objects.all().delete()

        order = Order.objects.create(
            client_name='Aman Singh',
            created_by=self.customer_user,
            serving_franchise=None,
            order_source='DIRECT_COMPANY',
            franchise_name='Shivnath Agency (Direct)',
            amount=Decimal('500.00'),
            items_count=50,
            status='order_placement',
            payment_status='paid',
            delivery_address='Industrial Area, Raipur',
        )
        OrderItem.objects.create(
            order=order, product=self.product, product_name=self.product.name,
            quantity=50, unit_price=10.0, total_price=500.0
        )

        notify_order_created(order)

        # Serializer check
        ser = OrderSerializer(order).data
        self.assertEqual(ser['fulfilling_entity']['type'], 'CENTRAL_COMPANY')
        self.assertEqual(ser['fulfilling_entity']['name'], 'Shivnath Agency (Direct Company)')
        self.assertEqual(ser['serving_franchise_name'], '')

        # Unrelated Franchises must have ZERO notifications
        self.assertFalse(FranchiseNotification.objects.filter(reference_id=order.id).exists())

    def test_3_invalid_status_transitions_rejected_by_backend(self):
        """Test 3: Backend strictly rejects invalid or jumping status transitions."""
        order = Order.objects.create(
            client_name='Aman Singh',
            created_by=self.customer_user,
            status='order_placement',
            amount=Decimal('100.00'),
            items_count=10,
        )

        self.client.force_authenticate(user=self.admin_user)

        # Attempt 1: order_placement -> delivered (Invalid jump)
        resp1 = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'delivered'}, format='json')
        self.assertEqual(resp1.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Invalid order status transition', resp1.data.get('message', ''))

        # Attempt 2: order_placement -> dispatch (Invalid jump)
        resp2 = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'dispatch'}, format='json')
        self.assertEqual(resp2.status_code, status.HTTP_400_BAD_REQUEST)

        # Advance to preparing
        transition_order_status(order, 'plant_approval', actor=self.admin_user)
        transition_order_status(order, 'preparing', actor=self.admin_user)

        # Valid Transition: preparing -> invoice_generated (Plant bottling completed -> invoice issued)
        resp_inv = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'invoice_generated'}, format='json')
        self.assertEqual(resp_inv.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, 'invoice_generated')

    def test_4_payment_stage_lock_enforcement(self):
        """Test 4: Manual payment status update is locked until dispatch/delivered stage."""
        order = Order.objects.create(
            client_name='Aman Singh',
            created_by=self.customer_user,
            status='order_placement',
            payment_status='pending',
            amount=Decimal('200.00'),
            items_count=20,
        )

        self.client.force_authenticate(user=self.admin_user)

        # Attempt to mark paid when order is in order_placement -> MUST BE REJECTED
        resp = self.client.patch(f'/api/orders/{order.id}/', {'payment_status': 'paid'}, format='json')
        self.assertEqual(resp.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(resp.data.get('error_code'), 'PAYMENT_STAGE_LOCKED')

        # Advance order to dispatch
        transition_order_status(order, 'plant_approval', actor=self.admin_user)
        transition_order_status(order, 'preparing', actor=self.admin_user)
        transition_order_status(order, 'dispatch', actor=self.admin_user)

        # Now update payment_status when in dispatch stage -> MUST SUCCEED
        resp_valid = self.client.patch(f'/api/orders/{order.id}/', {'payment_status': 'paid'}, format='json')
        self.assertEqual(resp_valid.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.payment_status, 'paid')

    def test_5_historical_orders_idempotent_backfill(self):
        """Test 5: Reconstructs missing OrderStatusHistory safely and idempotently."""
        order = Order.objects.create(
            client_name='Historical Client',
            created_by=self.customer_user,
            status='delivered',
            amount=Decimal('300.00'),
            items_count=30,
        )
        # Order has zero initial history
        order.status_history.all().delete()
        self.assertEqual(order.status_history.count(), 0)

        # Run backfill
        res = repair_historical_orders_lifecycle()
        self.assertEqual(res['status'], 'completed')

        # Check history was safely reconstructed
        history = list(order.status_history.all())
        statuses = [h.new_status for h in history]
        self.assertIn('order_placement', statuses)
        self.assertIn('plant_approval', statuses)
        self.assertIn('invoice_generated', statuses)
        self.assertIn('preparing', statuses)
        self.assertIn('dispatch', statuses)
        self.assertIn('delivered', statuses)

        count_first_run = order.status_history.count()

        # Re-run backfill to verify idempotency (zero duplicates)
        repair_historical_orders_lifecycle()
        self.assertEqual(order.status_history.count(), count_first_run)

    def test_6_franchise_order_status_transitions_and_permissions(self):
        """Test 6: Franchise order status transitions, error handling, alias normalization, and permission isolation."""
        # 1. Create order assigned to Franchise Alpha
        order = Order.objects.create(
            client_name='Aman Franchise Order',
            created_by=self.customer_user,
            serving_franchise=self.franchise,
            status='invoice_generated',
            amount=Decimal('450.00'),
            items_count=15,
        )

        # Set up franchise profile on UserProfile so role is franchise
        prof_alpha = getattr(self.franchise_user, 'profile', None)
        if prof_alpha:
            prof_alpha.role = 'franchise'
            prof_alpha.save()

        prof_beta = getattr(self.unrelated_user, 'profile', None)
        if prof_beta:
            prof_beta.role = 'franchise'
            prof_beta.save()

        # A: Unrelated Franchise Beta tries to update Franchise Alpha's order -> MUST RETURN 403 FORBIDDEN
        self.client.force_authenticate(user=self.unrelated_user)
        resp_unauth = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'preparing'}, format='json')
        self.assertEqual(resp_unauth.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(resp_unauth.data.get('success'))

        # B: Authorized Franchise Alpha tries invalid jump: invoice_generated -> delivered -> MUST BE REJECTED (400)
        self.client.force_authenticate(user=self.franchise_user)
        resp_invalid_jump = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'delivered'}, format='json')
        self.assertEqual(resp_invalid_jump.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(resp_invalid_jump.data.get('error_code'), 'INVALID_STATUS_TRANSITION')
        self.assertIn("Invalid order status transition from 'invoice_generated' to 'delivered'", resp_invalid_jump.data.get('message', ''))
        self.assertIn('preparing', resp_invalid_jump.data.get('allowed_transitions', []))
        self.assertIn('dispatch', resp_invalid_jump.data.get('allowed_transitions', []))

        # C: Authorized Franchise Alpha transitions using colloquial alias 'dispatched' -> MUST SUCCEED and normalize to 'dispatch'
        resp_dispatch = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'dispatched'}, format='json')
        self.assertEqual(resp_dispatch.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, 'dispatch')
        self.assertEqual(resp_dispatch.data.get('current_status'), 'dispatch')
        self.assertIn('delivered', resp_dispatch.data.get('allowed_transitions', []))

        # D: From dispatch -> delivered -> MUST SUCCEED
        resp_delivered = self.client.patch(f'/api/orders/{order.id}/status/', {'status': 'delivered'}, format='json')
        self.assertEqual(resp_delivered.status_code, status.HTTP_200_OK)
        order.refresh_from_db()
        self.assertEqual(order.status, 'delivered')
        self.assertEqual(resp_delivered.data.get('allowed_transitions'), [])
