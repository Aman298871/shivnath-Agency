import os
import sys
sys.path.insert(0, r"d:\flutter\Shivnath project\shivnath_backend\shivnath_backend")
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from django.contrib.auth import get_user_model
from orders.models import Order, OrderItem
from billing.models import Invoice, PaymentTransaction
from accounts.models import UserProfile

User = get_user_model()

print("==================================================")
print("AUDITING EVERY ORDER AND INVOICE IN DATABASE")
print("==================================================")

for o in Order.objects.all().order_by('id'):
    inv = getattr(o, 'invoice', None)
    if not inv:
        inv = Invoice.objects.filter(order=o).first()
    
    # Calculate sum of payments
    txns = PaymentTransaction.objects.filter(invoice=inv) if inv else []
    txns_total = sum(t.amount_paid for t in txns if t.payment_status == 'SUCCESS')
    
    # Check outstanding
    inv_out = getattr(inv, 'outstanding_balance', 0) if inv else 0
    inv_total = getattr(inv, 'grand_total', 0) if inv else 0
    inv_paid = getattr(inv, 'amount_paid', 0) if inv else 0
    inv_num = getattr(inv, 'invoice_number', 'NO_INV') if inv else 'NO_INV'
    inv_status = getattr(inv, 'status', 'NO_INV') if inv else 'NO_INV'
    
    user = o.created_by.username if o.created_by else 'NO_USER'
    user_email = o.created_by.email if o.created_by else ''
    
    print(f"Order #{o.id} ({o.order_code}): user={user} ({user_email})")
    print(f"   status={o.status}, payment_status={o.payment_status}, grand_total={o.grand_total}, source={o.order_source}")
    print(f"   serving_franchise={o.serving_franchise.business_name if o.serving_franchise else 'None'}")
    print(f"   Invoice: {inv_num}, inv_status={inv_status}, total={inv_total}, paid={inv_paid}, out={inv_out}")
    print(f"   Transactions: count={len(txns)}, txns_total={txns_total}")
    for item in o.items.all():
        print(f"     Item: {item.product_name} x {item.quantity} (unit_price={item.unit_price}, total={item.total_price})")
    print("-" * 50)
