import os
import sys
sys.path.insert(0, r"d:\flutter\Shivnath project\shivnath_backend\shivnath_backend")
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
import django
django.setup()

from orders.models import Order, OrderItem
from billing.models import Invoice, PaymentTransaction
from accounts.models import UserProfile
from django.contrib.auth import get_user_model
User = get_user_model()

print("=== INVOICE 21 (Order 129) ===")
try:
    inv = Invoice.objects.get(id=21)
    for field in inv._meta.fields:
        print(f"  {field.name}: {getattr(inv, field.name)}")
except Exception as e:
    print(f"Error getting invoice 21: {e}")

print("\n=== ORDER 129 ===")
try:
    order = Order.objects.get(id=129)
    for field in order._meta.fields:
        print(f"  {field.name}: {getattr(order, field.name)}")
    print("  Items:")
    for item in order.items.all():
        for f in item._meta.fields:
            print(f"    {f.name}: {getattr(item, f.name)}")
except Exception as e:
    print(f"Error getting order 129: {e}")

print("\n=== CHECKING ALL CUSTOMERS FOR OUTSTANDING OR 47 ===")
for u in User.objects.all():
    profile = getattr(u, 'profile', None)
    bal = getattr(profile, 'outstanding_balance', None)
    credit = getattr(profile, 'credit_limit', None)
    print(f"User: id={u.id}, email={u.email}, role={getattr(u, 'role', '')}, profile_bal={bal}, credit={credit}")

print("\n=== CHECKING ALL ORDERS FOR TOTAL OR OUTSTANDING AROUND 47 ===")
for o in Order.objects.all():
    if 40 <= float(o.grand_total) <= 55 or '47' in str(o.grand_total):
        print(f"Order {o.id} ({o.order_code}): total={o.grand_total}, pay_status={o.payment_status}, status={o.status}")

print("\n=== CHECKING ALL INVOICES FOR TOTAL OR OUTSTANDING AROUND 47 ===")
for i in Invoice.objects.all():
    if 40 <= float(i.grand_total) <= 55 or 40 <= float(i.outstanding_balance) <= 55:
        print(f"Invoice {i.id} ({i.invoice_number}): total={i.grand_total}, out={i.outstanding_balance}, paid={i.amount_paid}, status={i.status}")
