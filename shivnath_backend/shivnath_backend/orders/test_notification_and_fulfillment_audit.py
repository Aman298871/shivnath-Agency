from django.test import TestCase
from django.contrib.auth import get_user_model
from decimal import Decimal
from accounts.models import (
    UserProfile, FranchiseProfile, ServiceDistrict, ServiceZone,
    AdminNotification, FranchiseNotification, CustomerNotification
)
from products.models import Product
from orders.models import Order, OrderItem
from orders.serializers import OrderSerializer
from accounts.fcm_services import (
    notify_order_created, notify_stock_request_created,
    notify_lead_created, notify_payment_received, notify_stock_request_status_update
)
from leads.models import Lead
from inventory.models import DealerStockRequest

User = get_user_model()


class NotificationAndFulfillmentAuditTest(TestCase):
    def setUp(self):
        # 1. Admin
        self.admin_user, _ = User.objects.get_or_create(
            username='superadmin_audit',
            defaults={'email': 'admin_audit@example.com', 'is_superuser': True, 'is_staff': True}
        )
        prof = getattr(self.admin_user, 'profile', None)
        if prof:
            prof.role = 'super_admin'
            prof.name = 'Central Admin'
            prof.save()

        # 2. Franchise
        self.franchise_user, _ = User.objects.get_or_create(
            username='franchise_abc',
            defaults={'email': 'abc@example.com'}
        )
        self.district, _ = ServiceDistrict.objects.get_or_create(name='Raipur Audit', defaults={'state': 'Chhattisgarh'})
        self.zone, _ = ServiceZone.objects.get_or_create(name='Raipur West Audit', defaults={'district': self.district})
        self.franchise, _ = FranchiseProfile.objects.get_or_create(
            user=self.franchise_user,
            defaults={
                'business_name': 'Franchise ABC',
                'city': 'Raipur',
                'address': 'Main Road Raipur',
                'status': 'approved'
            }
        )

        # 3. Customer
        self.customer_user, _ = User.objects.get_or_create(
            username='customer_ramesh',
            defaults={'email': 'ramesh@example.com'}
        )
        c_prof = getattr(self.customer_user, 'profile', None)
        if c_prof:
            c_prof.role = 'customer'
            c_prof.name = 'Ramesh Kumar'
            c_prof.phone = '9876543210'
            c_prof.save()

        # 4. Product
        self.product, _ = Product.objects.get_or_create(
            sku='SHV-AUDIT-20L',
            defaults={
                'name': 'Shivnath Pure 20L Jar',
                'size': '20L',
                'price': Decimal('90.00'),
                'stock': 500,
                'status': 'Active'
            }
        )

    def test_a_direct_company_order_no_franchise_leak(self):
        """Test A: Direct Company Order must never show Franchise name or notify Franchise."""
        AdminNotification.objects.all().delete()
        FranchiseNotification.objects.all().delete()

        order = Order.objects.create(
            client_name='Ramesh Kumar',
            created_by=self.customer_user,
            serving_franchise=None,
            order_source='DIRECT_COMPANY',
            franchise_name='Shivnath Agency (Direct)',
            amount=Decimal('450.00'),
            items_count=5,
            status='order_placement',
            payment_status='paid'
        )
        OrderItem.objects.create(order=order, product=self.product, product_name=self.product.name, quantity=5, unit_price=90.0, total_price=450.0)

        # Serializer check
        ser_data = OrderSerializer(order).data
        self.assertEqual(ser_data['fulfilling_entity']['type'], 'CENTRAL_COMPANY')
        self.assertEqual(ser_data['fulfilling_entity']['name'], 'Shivnath Agency (Direct Company)')
        self.assertEqual(ser_data['serving_franchise_name'], '')

        # Notification check
        notify_order_created(order)

        # Admin must have notification
        admin_notifs = AdminNotification.objects.filter(reference_id=order.id)
        self.assertTrue(admin_notifs.exists())
        admin_msg = admin_notifs.first().message
        self.assertIn('Direct Company Order', admin_msg)
        self.assertNotIn('Franchise ABC', admin_msg)

        # Franchise ABC must have ZERO notifications
        franchise_notifs = FranchiseNotification.objects.filter(franchise=self.franchise, reference_id=order.id)
        self.assertFalse(franchise_notifs.exists(), "Franchise must NOT receive notifications for Direct Company Orders!")

    def test_b_franchise_order_routing_and_notification(self):
        """Test B: Franchise Order shows Franchise name and notifies Serving Franchise."""
        AdminNotification.objects.all().delete()
        FranchiseNotification.objects.all().delete()

        order = Order.objects.create(
            client_name='Ramesh Kumar',
            created_by=self.customer_user,
            serving_franchise=self.franchise,
            order_source='FRANCHISE',
            franchise_name='Franchise ABC',
            amount=Decimal('270.00'),
            items_count=3,
            status='order_placement',
            payment_status='paid'
        )
        OrderItem.objects.create(order=order, product=self.product, product_name=self.product.name, quantity=3, unit_price=90.0, total_price=270.0)

        # Serializer check
        ser_data = OrderSerializer(order).data
        self.assertEqual(ser_data['fulfilling_entity']['type'], 'FRANCHISE')
        self.assertEqual(ser_data['fulfilling_entity']['name'], 'Franchise ABC')
        self.assertEqual(ser_data['serving_franchise_name'], 'Franchise ABC')

        # Notification check
        notify_order_created(order)

        # Admin must see Fulfilled by Franchise ABC
        admin_notifs = AdminNotification.objects.filter(reference_id=order.id)
        self.assertTrue(admin_notifs.exists())
        self.assertIn('Fulfilled by Franchise ABC', admin_notifs.first().message)

        # Serving Franchise must receive notification
        f_notifs = FranchiseNotification.objects.filter(franchise=self.franchise, reference_id=order.id)
        self.assertTrue(f_notifs.exists(), "Serving Franchise must receive notification for assigned franchise order!")
        self.assertIn('Ramesh Kumar', f_notifs.first().message)

    def test_c_franchise_unavailable_fallback_to_company(self):
        """Test C: When franchise unavailable, order becomes Direct Company with zero franchise leakage."""
        order = Order.objects.create(
            client_name='Ramesh Kumar',
            created_by=self.customer_user,
            serving_franchise=None,
            order_source='DIRECT_COMPANY',
            franchise_name='Shivnath Agency (Direct)',
            amount=Decimal('180.00'),
            items_count=2,
            status='order_placement',
            payment_status='paid'
        )
        notify_order_created(order)

        admin_notif = AdminNotification.objects.filter(reference_id=order.id).first()
        self.assertIn('Direct Company Order', admin_notif.message)
        self.assertNotIn('Franchise ABC', admin_notif.message)

    def test_d_stock_request_and_lead_and_dispatch_notifications(self):
        """Test D: All business notifications show specific meaningful titles and dynamic data."""
        # 1. Franchise Stock Request
        stock_req = DealerStockRequest.objects.create(
            dealer=self.franchise,
            product=self.product,
            request_number='SR-999',
            requested_quantity=200,
            status='PENDING'
        )
        notify_stock_request_created(stock_req)
        s_notif = AdminNotification.objects.filter(reference_id=stock_req.id, notification_type='stock_alert').first()
        self.assertIsNotNone(s_notif)
        self.assertIn('Franchise ABC', s_notif.message)
        self.assertIn('200', s_notif.message)

        # 2. Stock Dispatch
        stock_req.status = 'DISPATCHED'
        stock_req.dispatched_quantity = 200
        stock_req.save()
        notify_stock_request_status_update(stock_req, 'DISPATCHED')
        f_disp_notif = FranchiseNotification.objects.filter(franchise=self.franchise, reference_id=stock_req.id).first()
        self.assertIsNotNone(f_disp_notif)
        self.assertEqual(f_disp_notif.title, 'Stock Dispatched')
        self.assertIn('200 units dispatched', f_disp_notif.message)

        # 3. New Lead
        lead = Lead.objects.create(
            name='Vikas Sharma',
            phone='9827012345',
            city='Durg',
            district='Durg',
            source='PUBLIC_CHATBOT',
            status='NEW'
        )
        notify_lead_created(lead)
        l_notif = AdminNotification.objects.filter(reference_id=lead.id, notification_type='general').first()
        self.assertIsNotNone(l_notif)
        self.assertIn('Vikas Sharma', l_notif.message)
        self.assertIn('Durg', l_notif.message)
