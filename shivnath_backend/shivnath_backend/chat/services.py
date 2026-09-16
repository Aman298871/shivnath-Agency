import os
import re
import json
import urllib.request
import urllib.error
from django.db import models
from products.models import Product
from orders.models import Order
from accounts.models import FranchiseProfile, UserProfile
from leads.models import Lead
from inventory.models import InventoryItem
from suppliers.models import Supplier


class AIService:
    OUT_OF_SCOPE_MESSAGE = (
        "I can only help you with questions related to this application, "
        "its services, products, orders and account."
    )

    @staticmethod
    def get_live_app_context(app_type='customer', user=None):
        role = 'customer'
        if user and user.is_authenticated:
            role = getattr(getattr(user, 'profile', None), 'role', 'customer')
            if user.is_staff or user.is_superuser:
                role = 'admin'

        effective_role = 'admin' if app_type == 'admin' or role == 'admin' else ('franchise' if app_type == 'franchise' or role == 'franchise' else 'customer')

        # 1. Product Context (Safe & Live from DB)
        try:
            products = Product.objects.filter(status__iexact='Active')
            prod_list = [f"- {p.name} ({p.size}): ₹{p.price}" for p in products]
            products_text = "\n".join(prod_list) if prod_list else "- Packaged Drinking Water 20L Jar: ₹40.00\n- Natural Mineral Water 500ml (Pack of 24): ₹240.00\n- Pure Drinking Water 1L Bottle: ₹20.00"
        except Exception:
            products_text = "- Packaged Drinking Water 20L Jar: ₹40.00\n- Natural Mineral Water 500ml (Pack of 24): ₹240.00\n- Pure Drinking Water 1L Bottle: ₹20.00"

        # 2. User-specific Context
        user_info = "Guest User (Not logged in)"
        role_live_data = ""

        if user and user.is_authenticated:
            user_info = f"Logged in User: {user.get_full_name() or user.username} (Email: {user.email}, Role: {effective_role})"

            if effective_role == 'franchise' and hasattr(user, 'franchise_profile'):
                fp = user.franchise_profile
                role_live_data = f"Franchise Details -> Business: {fp.business_name}, Status: {fp.status}, Territory: {fp.territory or 'Pending Allocation'}, City: {fp.city}"

            elif effective_role == 'admin':
                try:
                    total_leads = Lead.objects.count()
                    hot_leads = Lead.objects.filter(score='hot').count()
                    pending_franchises = FranchiseProfile.objects.filter(status='pending').count()
                    active_franchises = FranchiseProfile.objects.filter(status='approved').count()
                    total_orders = Order.objects.count()
                    low_stock_count = InventoryItem.objects.filter(stock__lte=models.F('min_stock')).count()
                    total_suppliers = Supplier.objects.filter(status='Active').count()
                    total_products_count = Product.objects.count()

                    role_live_data = (
                        f"LIVE DATABASE STATS (Admin Only):\n"
                        f"- Total CRM Leads: {total_leads} (Hot Leads: {hot_leads})\n"
                        f"- Franchise Applications: {pending_franchises} Pending, {active_franchises} Approved\n"
                        f"- Total Orders in System: {total_orders}\n"
                        f"- Inventory Alert: {low_stock_count} items below minimum stock level\n"
                        f"- Active Suppliers: {total_suppliers}\n"
                        f"- Total Products: {total_products_count}"
                    )
                except Exception:
                    role_live_data = "LIVE DATABASE STATS: Currently unavailable."

        # 3. System Role Instructions
        if effective_role == 'admin':
            system_role = (
                "You are the official Pure Water AI Operations Assistant for the Shivnath Agency ADMIN Portal. "
                "You assist administrators with CRM leads management, follow-ups, franchise approvals, "
                "inventory tracking, low stock alerts, supplier onboarding, order processing, and live stats."
            )
        elif effective_role == 'franchise':
            system_role = (
                "You are the official Pure Water AI Operations Assistant for the Shivnath Agency FRANCHISE Portal. "
                "You assist franchise partners with plant order placement, dispatch tracking, 12% margins, "
                "5 KM exclusive territory, billing, and plant operations."
            )
        else:
            system_role = (
                "You are the official Pure Water AI Assistant for Shivnath Agency CUSTOMER Portal. "
                "You help customers explore drinking water products (20L jars, 500ml packs, 1L bottles), "
                "place delivery orders, track their orders, check pricing, and inquire about franchise opportunities."
            )

        context = f"""
{system_role}

OFFICIAL COMPANY & SERVICE INFORMATION:
- Company: Shivnath Agency (Technology partner: Path Idea Infotech)
- Address: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001
- Official Support Phone / WhatsApp: +91 98062 47194
- Official Email: info@pathideainfotech.com / support@shivnathagency.com
- Available Bottle Sizes: 250ml, 500ml, 1 Litre, 2 Litre, 5 Litre Can, 20 Litre Jar
- Franchise Business Model: 5 KM exclusive protected territory, plant delivery within 24-48h, 12% operational commission.
- Doorstep Delivery in Raipur: Free delivery for regular & bulk orders. Same day delivery for orders placed before 2:00 PM.

CURRENT LIVE PRODUCTS:
{products_text}

USER & LIVE CONTEXT:
{user_info}
{role_live_data}

CRITICAL RULES & SCOPE ENFORCEMENT:
1. STRICT APP-ONLY SCOPE: You MUST ONLY answer questions strictly related to this Shivnath Agency application, its services, water products, orders, delivery, pricing, inventory, suppliers, leads, follow-ups, franchise opportunities, and user accounts.
2. OUT-OF-SCOPE QUESTIONS: If the user asks ANY question outside this application and business scope (such as writing general code/Python programs, asking about celebrities/politicians/Prime Minister, jokes, weather, science trivia, relationship advice, or general conversation unrelated to the business), you MUST POLITELY REFUSE with:
   "{AIService.OUT_OF_SCOPE_MESSAGE}"
   Do NOT answer any out-of-scope questions under any circumstances.
3. NO FAKE DATA: Do NOT invent fake products, fake prices, fake stock, fake metrics, or fake order numbers. If information is not available, state clearly that it is currently unavailable.
4. ROLE SECURITY: Never expose passwords, API keys, database credentials, or private details of other users or franchisees.
5. NATURAL LANGUAGE: Understand user questions in English, Hindi, or Hinglish (e.g. 'order kaise kare', 'kitne leads hain') and respond helpfully within the application scope.
"""
        return context.strip()

    @classmethod
    def generate_response(cls, message, app_type='customer', user=None, history=None):
        system_context = cls.get_live_app_context(app_type=app_type, user=user)

        # 1. Check for Gemini API Key
        gemini_key = os.environ.get('GEMINI_API_KEY', '').strip()
        if gemini_key:
            try:
                reply = cls._call_gemini_api(gemini_key, system_context, message, history)
                if reply:
                    return reply
            except Exception:
                pass

        # 2. Check for OpenAI API Key
        openai_key = os.environ.get('OPENAI_API_KEY', '').strip()
        if openai_key:
            try:
                reply = cls._call_openai_api(openai_key, system_context, message, history)
                if reply:
                    return reply
            except Exception:
                pass

        # 3. Intelligent Context-Aware & Scope-Guarded Fallback Engine
        return cls._intelligent_fallback_response(message, app_type, user)

    @classmethod
    def _call_gemini_api(cls, api_key, system_context, user_message, history=None):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
        
        contents = []
        contents.append({
            "role": "user",
            "parts": [{"text": f"System Guidelines & Operational Context:\n{system_context}\n\nPlease strictly adhere to the scope and security rules."}]
        })
        contents.append({
            "role": "model",
            "parts": [{"text": "Understood. I am the Pure Water AI Assistant for Shivnath Agency. I will strictly answer only application and business-related questions and refuse all out-of-scope inquiries."}]
        })

        if history:
            for item in history[-6:]:
                role = "user" if item.get('role') == 'user' else "model"
                contents.append({
                    "role": role,
                    "parts": [{"text": item.get('content', '')}]
                })

        contents.append({
            "role": "user",
            "parts": [{"text": user_message}]
        })

        payload = {
            "contents": contents,
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 600,
            }
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            res_body = json.loads(response.read().decode('utf-8'))
            candidates = res_body.get('candidates', [])
            if candidates:
                parts = candidates[0].get('content', {}).get('parts', [])
                if parts:
                    return parts[0].get('text', '').strip()
        return None

    @classmethod
    def _call_openai_api(cls, api_key, system_context, user_message, history=None):
        url = "https://api.openai.com/v1/chat/completions"
        messages = [{"role": "system", "content": system_context}]
        
        if history:
            for item in history[-6:]:
                messages.append({
                    "role": item.get('role', 'user'),
                    "content": item.get('content', '')
                })

        messages.append({"role": "user", "content": user_message})

        payload = {
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 500,
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={
                'Content-Type': 'application/json',
                'Authorization': f'Bearer {api_key}'
            },
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            res_body = json.loads(response.read().decode('utf-8'))
            choices = res_body.get('choices', [])
            if choices:
                return choices[0].get('message', {}).get('content', '').strip()
        return None

    @classmethod
    def _intelligent_fallback_response(cls, message, app_type='customer', user=None):
        raw_msg = message.strip()
        msg = raw_msg.lower()

        role = 'customer'
        if user and user.is_authenticated:
            role = getattr(getattr(user, 'profile', None), 'role', 'customer')
            if user.is_staff or user.is_superuser:
                role = 'admin'

        is_admin = (app_type == 'admin' or role == 'admin')
        is_franchise = (app_type == 'franchise' or role == 'franchise')

        # Robust word/phrase matcher
        def matches(patterns):
            for p in patterns:
                p_clean = p.lower().strip()
                if ' ' in p_clean:
                    if p_clean in msg:
                        return True
                else:
                    if re.search(r'\b' + re.escape(p_clean) + r'\b', msg):
                        return True
            return False

        # =========================================================================
        # 1. OUT-OF-SCOPE STRICT FILTER (Checked using whole-word boundary)
        # =========================================================================
        out_of_scope_words = [
            'python', 'java', 'c++', 'javascript', 'html', 'css', 'flutter', 'dart',
            'programming', 'write code', 'write a program', 'write script', 'sql query',
            'prime minister', 'president', 'modi', 'biden', 'trump', 'politics',
            'joke', 'funny joke', 'riddle', 'weather', 'temperature', 'forecast',
            'girlfriend', 'boyfriend', 'love advice', 'marriage advice',
            'bollywood', 'cricket', 'ipl score', 'actor', 'actress', 'song lyrics'
        ]
        if matches(out_of_scope_words):
            return cls.OUT_OF_SCOPE_MESSAGE

        # =========================================================================
        # 2. GREETINGS & IDENTITY
        # =========================================================================
        if matches(['hi', 'hello', 'hey', 'namaste', 'halo', 'hola', 'good morning', 'good evening', 'pranam', 'namaskar']):
            if is_admin:
                return (
                    "Namaste Admin! 👋\n"
                    "I am your Pure Water AI Operations Assistant.\n\n"
                    "I can assist you with:\n"
                    "• CRM Leads & pipeline management\n"
                    "• Franchise approvals & verification\n"
                    "• Inventory stock levels & low-stock alerts\n"
                    "• Supplier directory & purchase orders\n"
                    "• Order tracking & live operational metrics\n\n"
                    "How can I assist you with operations today?"
                )
            elif is_franchise:
                return (
                    "Namaste Franchise Partner! 👋\n"
                    "I am your Pure Water AI Operations Assistant.\n\n"
                    "How can I assist you with plant orders, stock dispatch, commission margins (12%), or territory rules today?"
                )
            return (
                "Namaste! 🙏\n"
                "Welcome to Shivnath Pure Water.\n\n"
                "I can help you with product pricing, placing orders, delivery status in Raipur, and franchise applications. How can I assist you today?"
            )

        if matches(['who are you', 'what can you do', 'your name', 'aap kaun ho', 'kya kar sakte ho', 'help me', 'madad']):
            if is_admin:
                return (
                    "I am the Shivnath Pure Water AI Admin Assistant 💧.\n\n"
                    "I assist administrators with:\n"
                    "• Managing Leads, Follow-ups, and Franchise applications\n"
                    "• Monitoring real-time inventory and supplier details\n"
                    "• Tracking customer and franchise plant orders\n"
                    "• Providing live system stats and navigation assistance across the Admin portal."
                )
            elif is_franchise:
                return (
                    "I am the Shivnath Pure Water Franchise AI Assistant 💧.\n\n"
                    "I assist franchise partners with:\n"
                    "• Placing new plant orders and tracking approval/dispatch\n"
                    "• Understanding franchise margin (12%) and 5 KM exclusive territory\n"
                    "• Plant delivery schedules and invoice guidelines."
                )
            return (
                "I am the official Pure Water AI Assistant for Shivnath Agency 💧.\n\n"
                "I can help you with:\n"
                "• Packaged drinking water (20L jars, 500ml packs, 1L bottles)\n"
                "• Product pricing & doorstep delivery in Raipur\n"
                "• Placing and tracking your orders\n"
                "• Purity standards (RO, UV, TDS 100-150 ppm)\n"
                "• Franchise partnership opportunities."
            )

        # =========================================================================
        # 3. ORDER TRACKING & STATUS (Prioritized before general order placement)
        # =========================================================================
        if matches(['track', 'status', 'where is my order', 'mera order', 'order check', 'order status', 'my order', 'my orders', 'previous order', 'previous orders', 'past order', 'past orders', 'order history', 'dispatch status', 'order details', 'check order']):
            if user and user.is_authenticated:
                try:
                    if is_admin:
                        recent_order = Order.objects.order_by('-created_at').first()
                        total_orders = Order.objects.count()
                        if recent_order:
                            return (
                                f"📦 *Admin Order Overview*:\n"
                                f"• Total System Orders: **{total_orders}**\n"
                                f"• Latest Order: #{recent_order.order_code} ({recent_order.franchise_name}) - Status: *{recent_order.get_status_display()}*\n\n"
                                f"You can manage and dispatch all orders in the **Orders** tab."
                            )
                    else:
                        recent_order = Order.objects.filter(created_by=user).order_by('-created_at').first()
                        if recent_order:
                            return (
                                f"📦 *Your Latest Order*: #{recent_order.order_code}\n"
                                f"• Amount: ₹{recent_order.amount}\n"
                                f"• Items: {recent_order.items_count}\n"
                                f"• Status: *{recent_order.get_status_display()}*\n"
                                f"• Date: {recent_order.order_date}\n\n"
                                f"You can view all past orders in the **My Orders** screen."
                            )
                except Exception:
                    pass
            return "📍 You can track live dispatch and delivery stages of your orders anytime under the **My Orders** screen."

        # =========================================================================
        # 4. ORDER PLACEMENT (How to order / buy)
        # =========================================================================
        if matches(['how to place', 'place order', 'order kaise', 'buy water', 'how to order', 'how do i place', 'how can i place', 'buy', 'purchase', 'mangwana', 'book', 'booking', 'cart', 'checkout', 'kaise karna']):
            if is_franchise:
                return (
                    "📦 *Placing Franchise Plant Orders*:\n"
                    "1. Open the **Orders** tab in your Franchise portal.\n"
                    "2. Tap **+ New Order**.\n"
                    "3. Choose water size (e.g., 20L Jars, 500ml Boxes), quantity, and delivery date.\n"
                    "4. Submit order — it enters **Plant Approval** and central dispatch within 24-48 hours."
                )
            return (
                "🛒 *How to Place an Order*:\n"
                "1. Tap the **Products** tab or browse on Home.\n"
                "2. Select your required water jars (20L) or bottle packs (500ml, 1L) and tap **Add to Cart**.\n"
                "3. Go to **Cart**, enter your delivery address, choose payment mode (Cash on Delivery or UPI), and tap **Place Order**.\n"
                "4. Track live delivery under **My Orders** screen!"
            )

        # =========================================================================
        # 5. INVENTORY & STOCK
        # =========================================================================
        if matches(['inventory', 'stock', 'raw material', 'caps', 'preforms', 'labels', 'reorder', 'warehouse']):
            if is_admin:
                try:
                    total_items = InventoryItem.objects.count()
                    low_stock = InventoryItem.objects.filter(stock__lte=models.F('min_stock'))
                    low_count = low_stock.count()
                    if low_count > 0:
                        names = [f"• {item.name}: {item.stock} {item.unit} (Min: {item.min_stock})" for item in low_stock[:5]]
                        return (
                            f"⚠️ *Inventory Status Alert*:\n"
                            f"• Total Items: {total_items}\n"
                            f"• **Low Stock Items ({low_count})**:\n" + "\n".join(names) +
                            "\n\nPlease initiate supplier purchase orders in the **Inventory** section."
                        )
                    return f"✅ *Inventory Status*: All {total_items} items are healthy above minimum stock levels."
                except Exception:
                    pass
            return (
                "📦 *Inventory Management*:\n"
                "• Administrators can monitor warehouse raw materials (caps, preforms, labels) and finished water jars.\n"
                "• Real-time low-stock alerts notify when items fall below minimum thresholds in the **Inventory** section."
            )

        # =========================================================================
        # 6. LEADS & CRM
        # =========================================================================
        if matches(['lead', 'leads', 'crm', 'prospect', 'prospects', 'pipeline']):
            if is_admin:
                try:
                    total = Lead.objects.count()
                    hot = Lead.objects.filter(score='hot').count()
                    warm = Lead.objects.filter(score='warm').count()
                    cold = Lead.objects.filter(score='cold').count()
                    return (
                        f"📊 *Live CRM Lead Statistics*:\n"
                        f"• **Total Leads**: {total}\n"
                        f"• **Hot Leads**: {hot} | **Warm Leads**: {warm} | **Cold Leads**: {cold}\n\n"
                        f"📋 *How to Manage Leads*:\n"
                        f"1. Open the **Leads** tab.\n"
                        f"2. Tap **+ Add Lead** to enter new partner prospects.\n"
                        f"3. Move leads through pipeline stages (Contacted -> Follow-up -> Interested -> Confirmed)."
                    )
                except Exception:
                    return (
                        "📋 *Lead Management*:\n"
                        "1. Open the **Leads** section from the admin menu.\n"
                        "2. Tap **+ Add Lead** to record prospective clients or partners.\n"
                        "3. Update pipeline status and assign follow-up schedules."
                    )
            return "💼 Interested in partnering with Shivnath Agency? You can apply for a franchise right here in the chat by tapping 'Apply for Franchise (Qualify Now)'!"

        # =========================================================================
        # 7. FRANCHISE DETAILS, APPROVALS & TERRITORY
        # =========================================================================
        if matches(['franchise', 'franchises', 'partner', 'partnership', 'dealer', 'distributor', 'distributorship', 'agency', 'margin', 'margins', 'commission', 'investment', 'territory', '5 km', '5km', 'exclusive']):
            if is_admin and matches(['how many', 'count', 'pending', 'approve', 'approval', 'verify']):
                try:
                    pending = FranchiseProfile.objects.filter(status='pending').count()
                    approved = FranchiseProfile.objects.filter(status='approved').count()
                    total = FranchiseProfile.objects.count()
                    return (
                        f"🏢 *Live Franchise Statistics*:\n"
                        f"• **Pending Approvals**: {pending}\n"
                        f"• **Active/Approved**: {approved}\n"
                        f"• **Total Registered**: {total}\n\n"
                        f"📋 *To Approve a Franchise*:\n"
                        f"1. Open the **Franchises** tab.\n"
                        f"2. Filter by **Pending**.\n"
                        f"3. Review commercial space & 5 KM exclusive territory allocation.\n"
                        f"4. Tap **Approve Franchise**."
                    )
                except Exception:
                    pass

            return (
                "🏢 *Shivnath Franchise Opportunity & Terms*:\n"
                "• **Exclusive Territory**: Guaranteed **5 KM radius** exclusive sales territory.\n"
                "• **Attractive Margins**: Flat **12% operational commission** on all deliveries.\n"
                "• **Investment Tier**: ₹3 Lakh – ₹10 Lakh (includes refundable security deposit & initial stock).\n"
                "• **Plant Supply**: 24-48 hours guaranteed dispatch from central bottling facility.\n"
                "• **Company Support**: Marketing collateral, CRM portal, and billing support.\n"
                "• **How to Apply**: Tap 'Apply for Franchise (Qualify Now)' in this chat!"
            )

        # =========================================================================
        # 8. PRODUCT COMPARISON & AVAILABILITY (Grounded in Live DB)
        # =========================================================================
        comparison_keywords = ['compare', 'difference', 'cheaper', 'cheapest', 'sasta', 'versus', 'vs', 'which product', 'difference between', 'which is better']
        if matches(comparison_keywords):
            try:
                products = list(Product.objects.filter(status__iexact='Active'))
                if not products:
                    products = list(Product.objects.all())

                if not products:
                    return "💧 *Product Catalog*: No products are currently registered in the database."

                # Case A: Cheapest / low price query
                if any(w in msg for w in ['cheapest', 'cheaper', 'sasta', 'lowest price', 'low price', 'minimum price', 'minimum rate', 'sasti']):
                    cheapest = min(products, key=lambda p: float(p.price))
                    lines = [f"• **{p.name}** ({p.size}): ₹{p.price} / {p.unit} (Stock: {p.stock})" for p in products]
                    return (
                        f"💧 *Product Price Comparison*:\n"
                        f"• **Most Affordable**: **{cheapest.name}** ({cheapest.size}) at **₹{cheapest.price}** per {cheapest.unit}.\n\n"
                        f"📋 *All Available Products & Rates*:\n" + "\n".join(lines) +
                        f"\n\n*All water products are purified with 5-stage RO + UV filtration and meet BIS/FSSAI standards.*"
                    )

                # Case B: Specific product matches (e.g. 500ml vs 1L / 20L)
                matched_prods = []
                for p in products:
                    size_key = p.size.lower().replace(' ', '')
                    name_key = p.name.lower()
                    if size_key in msg.replace(' ', '') or any(tok in msg for tok in size_key.split()) or (p.category.lower() in msg and len(products) <= 3):
                        matched_prods.append(p)

                if len(matched_prods) >= 2:
                    lines = []
                    for p in matched_prods:
                        stock_str = f"{p.stock} units ({'In Stock' if p.stock > 0 else 'Low/Restocking'})"
                        lines.append(
                            f"• **{p.name}**:\n"
                            f"  - Size / Volume: {p.size}\n"
                            f"  - Price: ₹{p.price} per {p.unit}\n"
                            f"  - Category: {p.category}\n"
                            f"  - Available Stock: {stock_str}\n"
                            f"  - Details: {p.description or 'Pure packaged drinking water'}"
                        )
                    return (
                        f"💧 *Product Comparison Breakdown*:\n\n" + "\n\n".join(lines) +
                        f"\n\n*Both options are manufactured in our certified facility using food-grade BPA-free packaging.*"
                    )

                # Case C: General comparison of all available products
                lines = []
                for p in products:
                    lines.append(
                        f"• **{p.name}** ({p.size}): ₹{p.price} / {p.unit} | Stock: {p.stock} | Type: {p.category}"
                    )
                return (
                    f"💧 *Comparison of Available Products*:\n\n" + "\n".join(lines) +
                    f"\n\n*Tip: 20L Jars are best for home & office water dispensers, while 500ml / 1L bottles are ideal for travel & events.*"
                )
            except Exception:
                pass

        # =========================================================================
        # 9. PRODUCTS, CATALOG, SIZES & PRICING
        # =========================================================================
        if matches(['product', 'products', 'price', 'cost', 'rate', 'rates', 'pricing', 'mrp', 'rupees', 'charges', 'paani', 'bottle', 'bottles', 'jar', 'jars', '20l', '500ml', '1l', '2l', '5l', 'can', 'catalog', 'sizes', 'size', 'available']):
            try:
                products = Product.objects.filter(status__iexact='Active')
                if products.exists():
                    lines = [f"• **{p.name}** ({p.size}): ₹{p.price}" for p in products]
                    return "💧 *Live Water Products & Pricing*:\n" + "\n".join(lines) + "\n\n*Free doorstep delivery across Raipur on regular orders!*"
            except Exception:
                pass
            return (
                "💧 *Current Shivnath Water Catalog*:\n"
                "• **Packaged Drinking Water 20L Jar**: ₹40.00\n"
                "• **Natural Mineral Water 500ml (Pack of 24)**: ₹240.00\n"
                "• **Pure Drinking Water 1L Bottle**: ₹20.00\n\n"
                "All bottles use food-grade BPA-free recyclable PET."
            )

        # =========================================================================
        # 9. SUPPLIERS & VENDORS
        # =========================================================================
        if matches(['supplier', 'suppliers', 'vendor', 'vendors', 'procurement', 'purchase order']):
            if is_admin:
                try:
                    count = Supplier.objects.filter(status='Active').count()
                    return (
                        f"🚚 *Supplier Management*:\n"
                        f"• **Active Suppliers in System**: {count}\n"
                        f"• Go to **Suppliers** tab to view vendor contacts, GST, and categories.\n"
                        f"• Tap **+ Add Supplier** to register new material partners."
                    )
                except Exception:
                    pass
            return "🚚 *Suppliers*: Shivnath Agency partners with certified vendors for food-grade BPA-free packaging materials and filtration consumables."

        # =========================================================================
        # 10. FOLLOW-UPS & SCHEDULING
        # =========================================================================
        if matches(['followup', 'followups', 'follow-up', 'follow-ups', 'schedule', 'reminder', 'reminders']):
            return (
                "📅 *Follow-up Scheduling*:\n"
                "1. Open **Follow-ups** tab from the menu.\n"
                "2. Tap **+ Schedule Follow-up** to set reminder date, time, and notes for partner leads.\n"
                "3. Today's priority calls are displayed on the Admin Dashboard."
            )

        # =========================================================================
        # 11. PURITY, WATER QUALITY, TDS & RO
        # =========================================================================
        if matches(['quality', 'purity', 'tds', 'ro', 'uv', 'clean', 'safe', 'mineral', 'pure', 'fssai', 'bis', 'filter', 'filtration']):
            return (
                "✨ *Shivnath Purity Standards*:\n"
                "• **Multi-Stage Purification**: Sand Filter -> Activated Carbon -> Reverse Osmosis (RO) -> UV Treatment -> Ozonization.\n"
                "• **Optimal TDS**: Balanced between 100 - 150 ppm with essential calcium and magnesium electrolytes.\n"
                "• **Certifications**: BIS & FSSAI certified bottling plant ensuring 100% microbiological safety."
            )

        # =========================================================================
        # 12. DELIVERY AREAS, TIMING & RAIPUR
        # =========================================================================
        if matches(['delivery', 'deliver', 'doorstep', 'raipur', 'area', 'timing', 'time', 'shipping', 'service area']):
            return (
                "🚚 *Delivery Details*:\n"
                "• **Service Area**: Fast doorstep delivery across Raipur and surrounding franchise territories.\n"
                "• **Delivery Timing**: Same-day delivery for orders placed before 2:00 PM; within 24 hours for evening orders.\n"
                "• **Working Hours**: Monday to Saturday, 8:00 AM – 8:00 PM."
            )

        # =========================================================================
        # 13. PAYMENT METHODS & COD
        # =========================================================================
        if matches(['payment', 'cod', 'cash on delivery', 'cash', 'upi', 'gpay', 'phonepe', 'paytm', 'pay online', 'invoice', 'bill', 'billing']):
            return (
                "💳 *Accepted Payment Methods*:\n"
                "• **Cash on Delivery (COD)**: Pay cash when your water is delivered at your doorstep.\n"
                "• **UPI / QR Code**: Pay via Google Pay, PhonePe, or Paytm upon delivery.\n"
                "• **Franchise Billing**: Direct bank transfer & credit terms as per agreement."
            )

        # =========================================================================
        # 14. PROFILE, ACCOUNT & SETTINGS
        # =========================================================================
        if matches(['profile', 'account', 'password', 'login', 'logout', 'settings', 'update address', 'change phone']):
            return (
                "👤 *Profile & Account Help*:\n"
                "• You can view and update your name, phone number, and delivery addresses in the **Profile** / **Settings** tab.\n"
                "• Security and notification preferences can also be configured there."
            )

        # =========================================================================
        # 15. CONTACT & OFFICIAL SUPPORT
        # =========================================================================
        if matches(['contact', 'support', 'phone', 'email', 'office', 'call', 'helpline', 'customer care', 'address', 'location', 'reach']):
            return (
                "📞 *Shivnath Agency Contact & Support*:\n"
                "• **Customer Care / WhatsApp**: +91 98062 47194\n"
                "• **Email**: info@pathideainfotech.com / support@shivnathagency.com\n"
                "• **Head Office**: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001\n"
                "• **Hours**: 9:00 AM – 7:00 PM (Mon-Sat)"
            )

        # =========================================================================
        # 16. STRICT OUT-OF-SCOPE REFUSAL
        # =========================================================================
        return cls.OUT_OF_SCOPE_MESSAGE
