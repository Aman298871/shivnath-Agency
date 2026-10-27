from decimal import Decimal
from rest_framework import serializers

from .models import (
    Order, OrderItem, OrderStatusHistory,
    CustomBrandedOrderRequest, CustomOrderQuotation,
)


class OrderItemSerializer(serializers.ModelSerializer):
    sku = serializers.CharField(source='product.sku', read_only=True)
    product_sku = serializers.CharField(source='product.sku', read_only=True)
    product_image = serializers.SerializerMethodField()
    gst_percent = serializers.SerializerMethodField()
    package_type = serializers.SerializerMethodField()
    sales_unit = serializers.SerializerMethodField()
    sales_unit_display = serializers.SerializerMethodField()
    packaging_display = serializers.SerializerMethodField()
    uom_display = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = [
            'id',
            'product',
            'sku',
            'product_sku',
            'product_name',
            'product_image',
            'size',
            'quantity',
            'unit_price',
            'total_price',
            'gst_percent',
            'package_type',
            'sales_unit',
            'sales_unit_display',
            'packaging_display',
            'uom_display',
        ]

    def get_product_image(self, obj):
        if obj.product and obj.product.image:
            try:
                url = obj.product.image.url
                if not url.startswith('http'):
                    return f"https://shivnath-agency.onrender.com{url}"
                return url
            except Exception:
                return ''
        return ''

    def get_gst_percent(self, obj):
        if obj.product and hasattr(obj.product, 'gst'):
            return float(obj.product.gst)
        return 18.0

    def get_package_type(self, obj):
        if obj.product and hasattr(obj.product, 'package_type'):
            return obj.product.package_type
        size_str = str(obj.size or '').upper().strip()
        name_str = str(obj.product_name or '').upper().strip()
        is_jar = (
            'JAR' in name_str or
            any(x in size_str for x in ['20L', '20 L', '20-L', '20LTR', '20 LITRE', '20 LITER'])
        ) and ('ML' not in size_str)
        if is_jar:
            return 'JAR'
        return 'BOTTLE'

    def get_sales_unit(self, obj):
        if obj.product:
            from products.packaging_services import get_product_moq_info
            moq = get_product_moq_info(obj.product)
            if moq and 'sales_unit' in moq:
                return moq['sales_unit']
        return 'JAR' if self.get_package_type(obj) == 'JAR' else 'CARTON'

    def get_sales_unit_display(self, obj):
        unit = self.get_sales_unit(obj)
        qty = obj.quantity or 1
        if unit == 'JAR':
            return 'Jars' if qty > 1 else 'Jar'
        elif unit in ['CARTON', 'BOX']:
            return 'Boxes' if qty > 1 else 'Box'
        elif unit == 'BOTTLE':
            return 'Bottles' if qty > 1 else 'Bottle'
        return 'Units' if qty > 1 else 'Unit'

    def get_packaging_display(self, obj):
        qty = obj.quantity or 1
        pkg_type = self.get_package_type(obj)
        units_per_carton = 1
        if obj.product:
            from products.models import MinimumOrderPackagingRule
            rule = MinimumOrderPackagingRule.objects.filter(product=obj.product).first()
            if not rule and getattr(obj.product, 'category_id', None):
                rule = MinimumOrderPackagingRule.objects.filter(category_id=obj.product.category_id).first()
            if rule and rule.units_per_carton:
                units_per_carton = rule.units_per_carton

        name_upper = str(obj.product_name or (obj.product.name if obj.product else '')).upper()
        size_upper = str(obj.size or (obj.product.size if obj.product else '')).upper()
        is_bottle = pkg_type == 'BOTTLE' or 'BOTTLE' in name_upper or 'ML' in size_upper or 'ML' in name_upper or 'LITRE' in size_upper
        is_jar = not is_bottle and (pkg_type == 'JAR' or 'JAR' in name_upper or '20L' in size_upper or '20L' in name_upper)

        if is_jar:
            return f"{qty} Jars" if qty > 1 else f"{qty} Jar"
        elif units_per_carton > 1 and qty >= units_per_carton:
            cartons = qty // units_per_carton
            rem = qty % units_per_carton
            if rem == 0:
                return f"{cartons} Cartons ({qty} Bottles)"
            return f"{cartons} Cartons + {rem} Bottles ({qty} Bottles)"
        elif is_bottle:
            return f"{qty} Bottles" if qty > 1 else f"{qty} Bottle"
        return f"{qty} Units" if qty > 1 else f"{qty} Unit"

    def get_uom_display(self, obj):
        return self.get_packaging_display(obj)



class OrderStatusHistorySerializer(serializers.ModelSerializer):
    changed_by_name = serializers.SerializerMethodField()
    performer_role = serializers.SerializerMethodField()
    client_name = serializers.SerializerMethodField()
    franchise_name = serializers.SerializerMethodField()
    display_title = serializers.SerializerMethodField()
    display_notes = serializers.SerializerMethodField()

    class Meta:
        model = OrderStatusHistory
        fields = [
            'id',
            'old_status',
            'new_status',
            'changed_by',
            'changed_by_name',
            'performer_role',
            'client_name',
            'franchise_name',
            'display_title',
            'display_notes',
            'notes',
            'created_at',
        ]

    def _resolve_client_name(self, order):
        if not order:
            return 'Client'
        if order.client_name:
            return order.client_name
        if order.created_by:
            name = order.created_by.get_full_name()
            if name:
                return name
            if hasattr(order.created_by, 'customer_profile') and order.created_by.customer_profile:
                return order.created_by.customer_profile.business_name or order.created_by.customer_profile.contact_person
            return order.created_by.username
        return 'Client'

    def _resolve_franchise_name(self, order):
        if not order:
            return 'Shivnath Central Plant'
        if order.snapshot_serving_dealer_name:
            return order.snapshot_serving_dealer_name
        if order.serving_franchise:
            return order.serving_franchise.business_name
        if order.franchise_name and order.franchise_name.lower() != 'direct company':
            return order.franchise_name
        return 'Shivnath Central Plant'

    def get_client_name(self, obj):
        return self._resolve_client_name(obj.order)

    def get_franchise_name(self, obj):
        return self._resolve_franchise_name(obj.order)

    def get_performer_role(self, obj):
        st = (obj.new_status or '').lower()
        if st in ['order_placement', 'created', 'cancelled_by_customer']:
            return 'Client'
        if st in ['plant_approval', 'admin_approved']:
            return 'Admin'
        if st in ['invoice_generated', 'preparing', 'dispatch', 'delivered']:
            if obj.order and obj.order.serving_franchise:
                return 'Franchise'
            return 'Admin'
        if obj.changed_by:
            if hasattr(obj.changed_by, 'franchise_profile'):
                return 'Franchise'
            if obj.changed_by.is_staff or obj.changed_by.is_superuser:
                return 'Admin'
            if hasattr(obj.changed_by, 'customer_profile'):
                return 'Client'
        return 'System'

    def get_changed_by_name(self, obj):
        st = (obj.new_status or '').lower()
        order = obj.order

        # 1. Order placement is always by the Client
        if st in ['order_placement', 'created', 'placed']:
            return self._resolve_client_name(order)

        # 2. Plant approval is by Central Admin
        if st in ['plant_approval', 'admin_approved']:
            if obj.changed_by and (obj.changed_by.is_staff or obj.changed_by.is_superuser):
                return obj.changed_by.get_full_name() or 'Shivnath Plant Admin'
            return 'Shivnath Central Admin'

        # 3. Invoice generation, preparation, dispatch, delivery
        if st in ['invoice_generated', 'preparing', 'dispatch', 'delivered']:
            if order and order.serving_franchise:
                return f"{order.serving_franchise.business_name} (Franchise)"
            if order and order.snapshot_serving_dealer_name:
                return f"{order.snapshot_serving_dealer_name} (Franchise)"
            return 'Shivnath Agency Admin'

        # Fallback to user with role badge
        if obj.changed_by:
            if hasattr(obj.changed_by, 'franchise_profile'):
                return f"{obj.changed_by.franchise_profile.business_name} (Franchise)"
            if obj.changed_by.is_staff or obj.changed_by.is_superuser:
                return f"{obj.changed_by.get_full_name() or obj.changed_by.username} (Admin)"
            if hasattr(obj.changed_by, 'customer_profile'):
                return f"{obj.changed_by.get_full_name() or obj.changed_by.username} (Client)"
            return obj.changed_by.get_full_name() or obj.changed_by.username

        return 'System'

    def get_display_title(self, obj):
        st = (obj.new_status or '').lower()
        titles = {
            'order_placement': 'Order Placed by Client',
            'plant_approval': 'Plant Approval Confirmed',
            'invoice_generated': 'Tax Invoice Generated',
            'preparing': 'Bottles Packaged & Staged',
            'dispatch': 'Dispatched for Delivery',
            'delivered': 'Delivered Successfully',
            'cancelled': 'Order Cancelled',
        }
        return titles.get(st, f"Status: {obj.new_status}")

    def get_display_notes(self, obj):
        order = obj.order
        st = (obj.new_status or '').lower()
        client = self._resolve_client_name(order)
        franchise = self._resolve_franchise_name(order)

        if st == 'order_placement':
            return f"Order placed by client {client}"
        elif st == 'plant_approval':
            return "Production and fulfillment approved by Shivnath Central Plant Admin"
        elif st == 'invoice_generated':
            return f"Official Tax Invoice generated by {franchise}"
        elif st == 'preparing':
            return f"Goods packaged and staged at {franchise} distribution hub"
        elif st == 'dispatch':
            return f"Dispatched on delivery vehicle by {franchise}"
        elif st == 'delivered':
            return f"Successfully delivered to {client} by {franchise}"
        elif st == 'cancelled':
            return obj.notes or f"Order cancelled"

        return obj.notes or f"Status changed to {obj.new_status}"



class OrderSerializer(serializers.ModelSerializer):

    order_id = serializers.CharField(
        source='order_code',
        read_only=True,
    )

    status_display = serializers.CharField(
        source='get_status_display',
        read_only=True,
    )

    payment_display = serializers.CharField(
        source='get_payment_status_display',
        read_only=True,
    )

    created_by_name = serializers.SerializerMethodField()
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    customer_email = serializers.SerializerMethodField()
    serving_franchise_name = serializers.SerializerMethodField()
    serving_franchise_code = serializers.SerializerMethodField()
    registered_franchise_name = serializers.SerializerMethodField()
    zone_name = serializers.SerializerMethodField()
    order_source_display = serializers.SerializerMethodField()
    items = OrderItemSerializer(many=True, read_only=True)
    status_history = OrderStatusHistorySerializer(many=True, read_only=True)

    payment_status = serializers.SerializerMethodField()
    payment = serializers.SerializerMethodField()
    amount_paid = serializers.SerializerMethodField()
    outstanding_balance = serializers.SerializerMethodField()
    outstanding_amount = serializers.SerializerMethodField()
    payment_collected = serializers.SerializerMethodField()
    is_pending_verification = serializers.SerializerMethodField()

    previous_outstanding = serializers.SerializerMethodField()
    current_order_amount = serializers.SerializerMethodField()
    total_exposure = serializers.SerializerMethodField()
    credit_limit = serializers.SerializerMethodField()
    payment_terms_days = serializers.SerializerMethodField()
    credit_status = serializers.SerializerMethodField()

    invoice_id = serializers.SerializerMethodField()
    invoice_number = serializers.SerializerMethodField()
    invoice_status = serializers.SerializerMethodField()
    invoice_subtotal = serializers.SerializerMethodField()
    invoice_tax = serializers.SerializerMethodField()
    invoice_grand_total = serializers.SerializerMethodField()
    delivery_charges = serializers.SerializerMethodField()
    discount_amount = serializers.SerializerMethodField()
    payment_mode = serializers.SerializerMethodField()
    order_notes = serializers.SerializerMethodField()
    subtotal = serializers.DecimalField(source='amount', max_digits=12, decimal_places=2, read_only=True)
    fulfilling_entity = serializers.SerializerMethodField()

    class Meta:
        model = Order

        fields = [
            'id',
            'order_id',
            'amount_paid',
            'outstanding_balance',
            'outstanding_amount',
            'payment_collected',
            'is_pending_verification',

            'franchise_name',
            'serving_franchise',
            'serving_franchise_name',
            'serving_franchise_code',
            'registered_franchise',
            'registered_franchise_name',
            'zone',
            'zone_name',
            'city',
            'territory',
            'delivery_address',
            'order_source',
            'order_source_display',


            'client_name',
            'customer_name',
            'customer_phone',
            'customer_email',
            'label_requirement',
            'printing_requirement',
            'branding_requirement',
            'custom_shelf_life_days',
            'total_produced_units',
            'total_delivered_units',
            'total_pending_stock_units',

            'order_date',
            'duration_choice',
            'duration_days',
            'expected_end_date',

            'items_count',
            'amount',
            'subtotal',
            'tax_amount',
            'grand_total',

            'previous_outstanding',
            'current_order_amount',
            'total_exposure',
            'credit_limit',
            'payment_terms_days',
            'credit_status',

            'invoice_id',
            'invoice_number',
            'invoice_status',
            'invoice_subtotal',
            'invoice_tax',
            'invoice_grand_total',
            'delivery_charges',
            'delivery_distance_km',
            'delivery_latitude',
            'delivery_longitude',
            'is_gst_requested',
            'gstin',
            'gst_legal_name',
            'gst_billing_address',
            'gst_state_name',
            'gst_pincode',
            'discount_amount',
            'payment_mode',
            'razorpay_order_id',
            'razorpay_payment_id',
            'order_notes',
            'fulfilling_entity',

            'points_redeemed',
            'points_discount_amount',
            'wallet_amount_debited',
            'remaining_payable_amount',

            'status',
            'status_display',

            'payment_status',
            'payment',
            'payment_display',

            'created_by',
            'created_by_name',
            'items',
            'status_history',

            'created_at',
            'updated_at',
        ]

        read_only_fields = [
            'id',
            'order_id',
            'order_date',
            'previous_outstanding',
            'current_order_amount',
            'total_exposure',
            'credit_limit',
            'payment_terms_days',
            'credit_status',
            'amount_paid',
            'outstanding_balance',
            'outstanding_amount',
            'payment_collected',
            'is_pending_verification',
            'invoice_id',
            'invoice_number',
            'invoice_status',
            'invoice_subtotal',
            'invoice_tax',
            'invoice_grand_total',
            'delivery_charges',
            'delivery_distance_km',
            'delivery_latitude',
            'delivery_longitude',
            'is_gst_requested',
            'gstin',
            'gst_legal_name',
            'gst_billing_address',
            'gst_state_name',
            'gst_pincode',
            'discount_amount',
            'payment_mode',
            'order_notes',
            'fulfilling_entity',
            'status_display',
            'payment_status',
            'payment',
            'payment_display',
            'created_by',
            'created_by_name',
            'customer_name',
            'customer_phone',
            'customer_email',
            'serving_franchise_name',
            'registered_franchise_name',
            'zone_name',
            'items',
            'status_history',
            'created_at',
            'updated_at',
        ]


    def _get_invoice(self, obj):
        try:
            from billing.models import Invoice
            return Invoice.objects.filter(order_id=obj.id).first()
        except Exception:
            return None

    def get_payment_status(self, obj):
        if getattr(obj, 'order_source', '') == 'WATER_WALLET_REDEMPTION':
            return 'paid'
        rem = getattr(obj, 'remaining_payable_amount', None)
        if rem is not None and rem <= Decimal('0.00') and ((getattr(obj, 'points_discount_amount', 0) or 0) > 0 or (getattr(obj, 'wallet_amount_debited', 0) or 0) > 0):
            return 'paid'
        inv = self._get_invoice(obj)
        if inv:
            if inv.status == 'PAID' or (inv.grand_total > Decimal('0.00') and (inv.grand_total - (inv.amount_paid or Decimal('0.00'))) <= Decimal('0.05')):
                return 'paid'
            if inv.amount_paid and inv.amount_paid > Decimal('0.00'):
                return 'partial'
        raw = getattr(obj, 'payment_status', '').lower()
        if raw == 'paid' or getattr(obj, 'payment', '').lower() == 'paid':
            return 'paid'
        if raw == 'partial':
            return 'partial'
        return 'pending'

    def get_payment(self, obj):
        return self.get_payment_status(obj)

    def get_amount_paid(self, obj):
        if getattr(obj, 'payment_status', '').lower() == 'paid':
            return float(obj.grand_total or obj.amount or 0.0)
        inv = self._get_invoice(obj)
        if inv:
            if inv.status == 'PAID' or (inv.grand_total > Decimal('0.00') and (inv.grand_total - (inv.amount_paid or Decimal('0.00'))) <= Decimal('0.05')):
                return float(inv.grand_total)
            return float(inv.amount_paid or 0.0)
        return 0.0

    def get_outstanding_balance(self, obj):
        if getattr(obj, 'payment_status', '').lower() == 'paid' or getattr(obj, 'order_source', '') == 'WATER_WALLET_REDEMPTION':
            return 0.0
        if getattr(obj, 'status', '').lower() in ['cancelled', 'order_placement', 'created']:
            return 0.0
        rem = getattr(obj, 'remaining_payable_amount', None)
        if rem is not None and rem <= Decimal('0.00') and ((getattr(obj, 'points_discount_amount', 0) or 0) > 0 or (getattr(obj, 'wallet_amount_debited', 0) or 0) > 0):
            return 0.0
        inv = self._get_invoice(obj)
        if inv:
            if inv.status == 'PAID' or (inv.grand_total > Decimal('0.00') and (inv.grand_total - (inv.amount_paid or Decimal('0.00'))) <= Decimal('0.05')):
                return 0.0
            return float(inv.outstanding_balance)
        if rem is not None and ((getattr(obj, 'points_discount_amount', 0) or 0) > 0 or (getattr(obj, 'wallet_amount_debited', 0) or 0) > 0):
            return float(rem)
        if getattr(obj, 'status', '').lower() == 'delivered':
            return float(obj.grand_total or obj.amount or 0.0)
        return 0.0

    def get_outstanding_amount(self, obj):
        return self.get_outstanding_balance(obj)

    def get_payment_collected(self, obj):
        if getattr(obj, 'payment_status', '').lower() == 'paid' or getattr(obj, 'order_source', '') == 'WATER_WALLET_REDEMPTION':
            return True
        rem = getattr(obj, 'remaining_payable_amount', None)
        if rem is not None and rem <= Decimal('0.00') and ((getattr(obj, 'points_discount_amount', 0) or 0) > 0 or (getattr(obj, 'wallet_amount_debited', 0) or 0) > 0):
            return True
        inv = self._get_invoice(obj)
        if inv and (inv.status == 'PAID' or (inv.grand_total > Decimal('0.00') and (inv.grand_total - (inv.amount_paid or Decimal('0.00'))) <= Decimal('0.05'))):
            return True
        return False

    def get_is_pending_verification(self, obj):
        if getattr(obj, 'payment_status', '').lower() == 'paid':
            return False
        inv = self._get_invoice(obj)
        if inv:
            if inv.status == 'PAYMENT_PENDING_VERIFICATION':
                return True
            from billing.models import PaymentTransaction
            if PaymentTransaction.objects.filter(invoice=inv, payment_status__in=['PENDING', 'PENDING_VERIFICATION']).exists():
                return True
        return getattr(obj, 'payment_status', '').lower() == 'pending_verification'

    def get_invoice_id(self, obj):
        inv = self._get_invoice(obj)
        return inv.id if inv else None

    def get_invoice_number(self, obj):
        inv = self._get_invoice(obj)
        return inv.invoice_number if inv else ''

    def get_invoice_status(self, obj):
        if getattr(obj, 'payment_status', '').lower() == 'paid':
            return 'PAID'
        inv = self._get_invoice(obj)
        if inv:
            if inv.status == 'PAID' or (inv.grand_total > Decimal('0.00') and (inv.grand_total - (inv.amount_paid or Decimal('0.00'))) <= Decimal('0.05')):
                return 'PAID'
            return inv.status
        return 'UNPAID'

    def get_invoice_subtotal(self, obj):
        inv = self._get_invoice(obj)
        if inv:
            return float(inv.subtotal)
        return float(obj.amount or 0.0)

    def get_invoice_tax(self, obj):
        inv = self._get_invoice(obj)
        if inv:
            return float(float(inv.cgst_amount or 0) + float(inv.sgst_amount or 0) + float(inv.igst_amount or 0))
        return float(obj.tax_amount or 0.0)

    def get_invoice_grand_total(self, obj):
        inv = self._get_invoice(obj)
        if inv:
            return float(inv.grand_total)
        return float(obj.grand_total or obj.amount or 0.0)

    def get_delivery_charges(self, obj):
        dc = getattr(obj, 'delivery_charges', None)
        if dc is not None:
            return float(dc)
        inv = self._get_invoice(obj)
        if inv and getattr(inv, 'delivery_charges', None) is not None:
            return float(inv.delivery_charges)
        return 0.0

    def get_discount_amount(self, obj):
        disc = getattr(obj, 'discount_amount', None)
        if disc is not None:
            return float(disc)
        inv = self._get_invoice(obj)
        if inv and getattr(inv, 'discount_amount', None) is not None:
            return float(inv.discount_amount)
        return 0.0

    def get_payment_mode(self, obj):
        inv = self._get_invoice(obj)
        if inv and inv.payments.exists():
            last_p = inv.payments.last()
            return last_p.get_payment_method_display() or last_p.payment_method
        pm = getattr(obj, 'payment_mode', '')
        if pm == 'FRANCHISE_COLLECTION':
            return 'Franchise Collection (Pay on Delivery)'
        if pm == 'WALLET':
            return 'Water Wallet'
        if getattr(obj, 'razorpay_payment_id', ''):
            return f"Razorpay Online ({obj.razorpay_payment_id})"
        if pm and pm.upper() == 'RAZORPAY':
            return 'Online Payment (Razorpay)'
        return pm or 'Online Payment (Razorpay)'

    def get_order_notes(self, obj):
        notes = []
        if obj.label_requirement:
            notes.append(f"Label: {obj.label_requirement}")
        if obj.printing_requirement:
            notes.append(f"Printing: {obj.printing_requirement}")
        if obj.branding_requirement:
            notes.append(f"Branding: {obj.branding_requirement}")
        return " | ".join(notes)

    def get_fulfilling_entity(self, obj):
        is_direct = getattr(obj, 'order_source', '') == 'DIRECT_COMPANY' or not obj.serving_franchise
        if not is_direct and obj.serving_franchise:
            fp = obj.serving_franchise
            user = fp.user
            phone = ''
            if user:
                prof = getattr(user, 'profile', None)
                if prof and prof.phone:
                    phone = prof.phone
            return {
                'type': 'FRANCHISE',
                'name': fp.business_name,
                'phone': phone,
                'address': getattr(fp, 'address', '') or fp.city,
                'city': fp.city,
                'territory': getattr(fp, 'territory', '') or (fp.zone.name if hasattr(fp, 'zone') and fp.zone else ''),
                'contact_info': f"{fp.business_name} ({phone})" if phone else fp.business_name,
            }

        # Authoritative Company Billing Profile (Never hardcode fake phone or address)
        company_name = 'Shivnath Agency (Direct Company)'
        company_phone = ''
        company_address = 'Raipur, Chhattisgarh'
        company_city = 'Raipur'
        try:
            from billing.models import CompanyBillingProfile
            profile = CompanyBillingProfile.objects.first()
            if profile:
                company_name = profile.trade_name or profile.legal_name or company_name
                company_phone = profile.phone or ''
                company_address = profile.registered_address or company_address
                company_city = profile.state_name or company_city
        except Exception:
            pass

        contact_info = f"{company_name} ({company_phone})" if company_phone else company_name
        return {
            'type': 'CENTRAL_COMPANY',
            'name': company_name,
            'phone': company_phone,
            'address': company_address,
            'city': company_city,
            'territory': 'Central Plant Dispatch',
            'contact_info': contact_info,
        }


    def get_customer_name(self, obj):
        if obj.client_name and obj.client_name.strip():
            return obj.client_name.strip()
        if obj.created_by:
            name = obj.created_by.get_full_name() or obj.created_by.username
            if name and name.strip():
                return name.strip()
        return 'Customer'

    def get_customer_phone(self, obj):
        if obj.created_by:
            prof = getattr(obj.created_by, 'profile', None)
            if prof and prof.phone:
                return prof.phone
        return ''

    def get_customer_email(self, obj):
        if obj.created_by:
            return obj.created_by.email or ''
        return ''

    def get_serving_franchise_name(self, obj):
        is_direct = getattr(obj, 'order_source', '') == 'DIRECT_COMPANY' or not obj.serving_franchise
        if is_direct:
            return ''
        if obj.serving_franchise:
            return obj.serving_franchise.business_name
        return ''

    def get_registered_franchise_name(self, obj):
        if obj.registered_franchise:
            return obj.registered_franchise.business_name
        return ''

    def get_zone_name(self, obj):
        if obj.zone:
            return obj.zone.name
        return ''

    def get_created_by_name(self, obj):
        if not obj.created_by:
            return ''

        return (
            obj.created_by.get_full_name()
            or obj.created_by.username
        )

    def get_serving_franchise_code(self, obj):
        if obj.serving_franchise:
            return f"FRN-{obj.serving_franchise.id:04d}"
        if obj.snapshot_serving_dealer_id:
            return f"FRN-{obj.snapshot_serving_dealer_id:04d}"
        return ''

    def get_order_source_display(self, obj):
        src = getattr(obj, 'order_source', '')
        if src == 'DIRECT_COMPANY':
            return 'Direct Shivnath (Central Plant Dispatch)'
        elif src == 'FRANCHISE':
            fname = obj.snapshot_serving_dealer_name or (obj.serving_franchise.business_name if obj.serving_franchise else '')
            fcode = self.get_serving_franchise_code(obj)
            return f"Franchise-Assisted: {fname} ({fcode})" if fname else 'Franchise-Assisted'
        elif src in ['WATER_WALLET', 'WATER_WALLET_REDEMPTION']:
            return 'Direct Shivnath (Water Wallet Redemption)'
        return src or 'Direct Shivnath'

    def get_previous_outstanding(self, obj):
        try:
            from billing.models import Invoice
            # Dealer credit profile is strictly for wholesale dealer orders
            is_dealer_order = bool(obj.created_by and hasattr(obj.created_by, 'franchise_profile'))
            if is_dealer_order:
                cp = getattr(obj.created_by.franchise_profile, 'credit_profile', None)
                if cp:
                    return float(cp.current_outstanding)

            # For customer orders, only genuine verified unpaid customer invoices apply
            if obj.created_by:
                invs = Invoice.objects.filter(
                    order__created_by=obj.created_by,
                    invoice_type__in=['CUSTOMER_SALE_INVOICE', 'DIRECT_COMPANY_SALE_INVOICE']
                ).exclude(
                    order_id=obj.id
                ).exclude(
                    status__in=['PAID', 'CANCELLED']
                ).exclude(
                    order__status__in=['cancelled', 'order_placement', 'created']
                ).exclude(
                    order__payment_status__in=['paid', 'PAID']
                ).exclude(
                    order__order_source__in=['WATER_WALLET_REDEMPTION', 'WATER_WALLET']
                )
                total_prev = sum(float(inv.outstanding_balance) for inv in invs if inv.outstanding_balance > Decimal('0.05'))
                return round(total_prev, 2)
        except Exception:
            pass
        return 0.0

    def get_current_order_amount(self, obj):
        return round(float(obj.amount or 0.0), 2)

    def get_total_exposure(self, obj):
        prev = self.get_previous_outstanding(obj)
        curr = self.get_current_order_amount(obj)
        return round(prev + curr, 2)

    def get_credit_limit(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return float(cp.credit_limit)
        return 0.0

    def get_payment_terms_days(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return cp.payment_terms_days
        return 15

    def get_credit_status(self, obj):
        if obj.serving_franchise:
            cp = getattr(obj.serving_franchise, 'credit_profile', None)
            if cp:
                return cp.credit_status
        return 'GOOD_STANDING'

    def validate_franchise_name(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'Franchise name is required.'
            )

        return value

    def validate_city(self, value):
        value = value.strip()

        if not value:
            raise serializers.ValidationError(
                'City is required.'
            )

        return value

    def validate_items_count(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Items count cannot be negative.'
            )
        return value

    def validate_amount(self, value):
        if value < 0:
            raise serializers.ValidationError(
                'Amount cannot be negative.'
            )
        return value

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # Authoritative franchise name and fulfilling entity for wallet redemption & wallet orders
        if instance.order_source in ['WATER_WALLET_REDEMPTION', 'WATER_WALLET']:
            data['franchise_name'] = 'Shivnath Central Admin (Water Wallet)'
            c_name = 'Shivnath Central Admin Plant'
            c_phone = ''
            c_address = 'Raipur, Chhattisgarh'
            c_city = 'Raipur'
            try:
                from billing.models import CompanyBillingProfile
                profile = CompanyBillingProfile.objects.first()
                if profile:
                    c_name = profile.trade_name or profile.legal_name or c_name
                    c_phone = profile.phone or ''
                    c_address = profile.registered_address or c_address
                    c_city = profile.state_name or c_city
            except Exception:
                pass
            data['fulfilling_entity'] = {
                'type': 'CENTRAL_COMPANY',
                'name': c_name,
                'phone': c_phone,
                'address': c_address,
                'city': c_city,
                'territory': 'Central Admin Fulfilment',
                'contact_info': f"{c_name} ({c_phone})" if c_phone else c_name,
            }
            return data


        # Authoritative franchise name: always show serving/registered franchise business name, never customer name
        if instance.serving_franchise:
            data['franchise_name'] = instance.serving_franchise.business_name
        elif instance.registered_franchise:
            data['franchise_name'] = instance.registered_franchise.business_name
        elif instance.order_source == 'DIRECT_COMPANY':
            data['franchise_name'] = 'Shivnath Agency (Direct)'
        else:
            fn = str(data.get('franchise_name') or '').strip()
            cust = str(data.get('customer_name') or '').strip()
            if not fn or fn.lower() == cust.lower() or fn.lower() == 'customer order':
                data['franchise_name'] = 'Shivnath Agency (Direct)'
        return data


class CustomOrderQuotationSerializer(serializers.ModelSerializer):
    created_by_name = serializers.SerializerMethodField()
    request_details = serializers.SerializerMethodField()

    class Meta:
        model = CustomOrderQuotation
        fields = [
            'id',
            'request',
            'request_details',
            'version',
            'created_by',
            'created_by_name',
            # Itemized Cost Breakdown (Admin internal by default)
            'bottle_water_cost',
            'sticker_material_cost',
            'printing_cost',
            'packaging_cost',
            'labour_production_cost',
            'transport_delivery_cost',
            'setup_design_cost',
            'wastage_allowance_cost',
            'other_charges',
            # Calculation
            'calculation_type',
            'target_percentage',
            'total_cost',
            'selling_price_before_charges',
            'final_quotation_total',
            'unit_quotation_price',
            # Terms & Settings
            'include_breakdown_to_customer',
            'quotation_validity_days',
            'valid_until',
            'payment_terms',
            'delivery_estimate_days',
            'admin_notes',
            'customer_notes',
            'status',
            'accepted_at',
            'converted_order',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'version',
            'total_cost',
            'selling_price_before_charges',
            'final_quotation_total',
            'unit_quotation_price',
            'created_by',
            'created_at',
            'updated_at',
            'converted_order',
        ]

    def get_created_by_name(self, obj):
        if obj.created_by:
            return obj.created_by.get_full_name() or obj.created_by.username
        return 'Admin'

    def get_request_details(self, obj):
        r = obj.request
        return {
            'id': r.id,
            'client_name': r.client_name,
            'bottle_size': r.bottle_size,
            'package_type': r.package_type,
            'quantity': r.quantity,
            'delivery_city': r.delivery_city,
            'customer_username': r.customer.username,
        }

    def to_representation(self, instance):
        data = super().to_representation(instance)
        request = self.context.get('request')
        user = getattr(request, 'user', None) if request else None
        is_admin_or_staff = user and (user.is_staff or user.is_superuser or getattr(getattr(user, 'profile', None), 'role', '') in ['admin', 'staff'])

        # Cost and pricing safeguards: Do not expose internal supplier/production costs or internal margin to customers unless explicitly intended
        if not is_admin_or_staff and not instance.include_breakdown_to_customer:
            hidden_fields = [
                'bottle_water_cost',
                'sticker_material_cost',
                'printing_cost',
                'packaging_cost',
                'labour_production_cost',
                'transport_delivery_cost',
                'setup_design_cost',
                'wastage_allowance_cost',
                'calculation_type',
                'target_percentage',
                'total_cost',
                'selling_price_before_charges',
                'admin_notes',
            ]
            for hf in hidden_fields:
                data.pop(hf, None)
        return data


class CustomBrandedOrderRequestSerializer(serializers.ModelSerializer):
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()
    artwork_url = serializers.SerializerMethodField()
    active_quotation = serializers.SerializerMethodField()
    quotations = serializers.SerializerMethodField()

    class Meta:
        model = CustomBrandedOrderRequest
        fields = [
            'id',
            'customer',
            'customer_name',
            'customer_phone',
            'client_name',
            'bottle_size',
            'package_type',
            'quantity',
            'label_requirement',
            'printing_requirement',
            'artwork_file',
            'artwork_url',
            'delivery_address',
            'delivery_city',
            'requested_delivery_date',
            'additional_notes',
            'status',
            'active_quotation',
            'quotations',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'customer', 'status', 'created_at', 'updated_at']

    def get_customer_name(self, obj):
        return obj.customer.get_full_name() or obj.customer.username

    def get_customer_phone(self, obj):
        profile = getattr(obj.customer, 'profile', None)
        return getattr(profile, 'phone', '') or ''

    def get_artwork_url(self, obj):
        if obj.artwork_file:
            try:
                url = obj.artwork_file.url
                request = self.context.get('request')
                if request and not url.startswith('http'):
                    return request.build_absolute_uri(url)
                return url
            except Exception:
                return ''
        return ''

    def get_active_quotation(self, obj):
        # Latest active / sent / accepted quotation
        quote = obj.quotations.order_by('-version').first()
        if quote:
            return CustomOrderQuotationSerializer(quote, context=self.context).data
        return None

    def get_quotations(self, obj):
        quotes = obj.quotations.order_by('-version').all()
        return CustomOrderQuotationSerializer(quotes, many=True, context=self.context).data

    def validate_quantity(self, value):
        if value is None or value <= 0:
            raise serializers.ValidationError("Quantity must be greater than zero.")
        return value