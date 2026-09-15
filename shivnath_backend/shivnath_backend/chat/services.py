import os
import json
import urllib.request
import urllib.error
from products.models import Product
from orders.models import Order


class AIService:
    @staticmethod
    def get_live_app_context(app_type='customer', user=None):
        try:
            products = Product.objects.filter(status__iexact='Active')
            prod_list = [f"- {p.name} ({p.size}): ₹{p.price}" for p in products]
            products_text = "\n".join(prod_list) if prod_list else "- Packaged Drinking Water 20L Jar: ₹40.00\n- Natural Mineral Water 500ml (Pack of 24): ₹240.00"
        except Exception:
            products_text = "- Packaged Drinking Water 20L Jar: ₹40.00\n- Natural Mineral Water 500ml (Pack of 24): ₹240.00"

        user_info = "Guest User (Not logged in)"
        if user and user.is_authenticated:
            role = getattr(getattr(user, 'profile', None), 'role', 'customer')
            user_info = f"Logged in User: {user.get_full_name() or user.username} (Email: {user.email}, Role: {role})"
            if role == 'franchise' and hasattr(user, 'franchise_profile'):
                fp = user.franchise_profile
                user_info += f" | Business: {fp.business_name}, Status: {fp.status}, Territory: {fp.territory or 'Pending Allocation'}, City: {fp.city}"

        if app_type == 'franchise':
            system_role = (
                "You are the official Pure Water AI Assistant for the Shivnath Agency Franchise Portal. "
                "You assist approved and prospective franchise partners with order placement, plant approvals, "
                "dispatch tracking, territorial rules (5 KM exclusive radius), billing/invoices, commissions (12%), "
                "and business management. Answer accurately based on official Shivnath Agency operations."
            )
        else:
            system_role = (
                "You are the official Pure Water AI Assistant for Shivnath Agency Customer Portal. "
                "You help customers explore drinking water products (20L jars, 500ml packs, 1L bottles), "
                "place delivery orders, track order status, understand pricing, and inquire about franchise opportunities."
            )

        context = f"""
{system_role}

OFFICIAL COMPANY INFORMATION:
- Company: Shivnath Agency (Technology partner: Path Idea Infotech)
- Address: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001
- Official Support Phone / WhatsApp: +91 98062 47194
- Official Email: info@pathideainfotech.com / support@shivnathagency.com
- Available Bottle Sizes: 250ml, 500ml, 1 Litre, 2 Litre, 5 Litre Can, 20 Litre Jar
- Franchise Model: 5 KM exclusive protected territory, plant delivery within 24-48h, 12% commission margin.

CURRENT LIVE PRODUCTS IN SYSTEM:
{products_text}

USER CONTEXT:
{user_info}

INSTRUCTIONS:
1. For questions regarding the app, products, orders, franchise, or company, answer helpfully and accurately using the company information above.
2. For questions outside the application scope (e.g., programming, general knowledge like 'What is Python?', math, science), answer naturally, politely, and informatively.
3. Keep responses clear, professional, and friendly with emojis where appropriate.
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
            except Exception as e:
                pass

        # 2. Check for OpenAI API Key
        openai_key = os.environ.get('OPENAI_API_KEY', '').strip()
        if openai_key:
            try:
                reply = cls._call_openai_api(openai_key, system_context, message, history)
                if reply:
                    return reply
            except Exception as e:
                pass

        # 3. Intelligent Context-Aware Fallback Engine
        return cls._intelligent_fallback_response(message, app_type, user)

    @classmethod
    def _call_gemini_api(cls, api_key, system_context, user_message, history=None):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
        
        contents = []
        contents.append({
            "role": "user",
            "parts": [{"text": f"System Context & Guidelines:\n{system_context}\n\nPlease acknowledge and adhere to these guidelines."}]
        })
        contents.append({
            "role": "model",
            "parts": [{"text": "Understood. I am the Pure Water AI Assistant for Shivnath Agency, ready to assist."}]
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
                "temperature": 0.4,
                "maxOutputTokens": 600,
            }
        }

        req = urllib.request.Request(
            url,
            data=json.dumps(payload).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=12) as response:
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
            "temperature": 0.5,
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
        with urllib.request.urlopen(req, timeout=12) as response:
            res_body = json.loads(response.read().decode('utf-8'))
            choices = res_body.get('choices', [])
            if choices:
                return choices[0].get('message', {}).get('content', '').strip()
        return None

    @classmethod
    def _intelligent_fallback_response(cls, message, app_type='customer', user=None):
        msg = message.strip().lower()

        # Handle Out-of-Scope / General questions
        if 'what is python' in msg or 'python' == msg:
            return "Python is a popular, high-level, general-purpose programming language known for its clear syntax, versatility, and readability. It is widely used in web development (like our Django backend!), automation, artificial intelligence, and data science."

        if 'what is java' in msg:
            return "Java is a class-based, object-oriented programming language designed to have as few implementation dependencies as possible, following the 'Write Once, Run Anywhere' (WORA) philosophy."

        if 'what is flutter' in msg or 'flutter' in msg:
            return "Flutter is Google's open-source UI software development kit used to build natively compiled applications for mobile (Android & iOS), web, and desktop from a single codebase using the Dart language."

        if 'what is mineral water' in msg or 'drinking water' in msg and ('benefit' in msg or 'why' in msg):
            return "Natural mineral water contains essential dissolved minerals such as calcium, magnesium, potassium, and bicarbonates that aid hydration, improve digestion, and support overall health."

        # Franchise-specific questions
        if 'how' in msg and 'manage' in msg and ('franchise' in msg or 'profile' in msg):
            return "To manage your franchise profile:\n1. Open the Franchise Portal sidebar or top profile icon.\n2. You can view your Franchise ID, City, Territory, GST & PAN records.\n3. Keep your documents and contact information updated for smooth plant deliveries."

        if 'order' in msg and ('place' in msg or 'how' in msg or 'new' in msg):
            if app_type == 'franchise':
                return "📦 *Placing Franchise Orders*:\n1. Go to the **Orders** tab in your Franchise portal.\n2. Tap **+ New Order**.\n3. Select product (e.g. 20L Jar, 500ml pack), quantity, and delivery notes.\n4. Submit order — it immediately moves to **Plant Approval** for dispatch preparation."
            else:
                return "🛒 *How to Place an Order*:\n1. Browse products on the Customer Home or Products screen.\n2. Tap **Add to Cart** on your desired water cans or bottle packs.\n3. Open your Cart, review the delivery address, and proceed to Checkout."

        if 'franchise' in msg and ('workflow' in msg or 'process' in msg or 'approval' in msg or 'work' in msg):
            return "🏢 *Shivnath Franchise Workflow*:\n1. **Registration**: Submit your owner & business details.\n2. **Admin Verification**: Admin reviews GST, PAN & assigned territory.\n3. **Approval**: Upon admin approval, your portal unlocks completely.\n4. **Ordering**: Order stock directly from the central plant with 12% commission margins."

        if 'price' in msg or 'cost' in msg or 'product' in msg or 'rate' in msg:
            try:
                products = Product.objects.filter(status__iexact='Active')
                if products.exists():
                    lines = [f"• {p.name} ({p.size}): ₹{p.price}" for p in products]
                    return "💧 *Current Product Pricing*:\n" + "\n".join(lines) + "\n\nAll products undergo multi-stage RO, UV, and ozonization treatment."
            except Exception:
                pass
            return "💧 *Product Catalog*:\n• Packaged Drinking Water 20L Jar: ₹40.00\n• Natural Mineral Water 500ml (Pack of 24): ₹240.00\n• Pure Water 1 Litre Bottle: ₹20.00"

        if 'contact' in msg or 'support' in msg or 'help' in msg or 'phone' in msg or 'email' in msg:
            return "📞 *Shivnath Support & Headquarters*:\n• **Phone / WhatsApp**: +91 98062 47194\n• **Email**: info@pathideainfotech.com\n• **Office**: Farishta Complex, Raipur, Chhattisgarh – 492001\n\nOur team is available 9:00 AM – 7:00 PM (Mon-Sat)."

        if 'status' in msg and ('order' in msg or 'request' in msg):
            if user and user.is_authenticated:
                recent_order = Order.objects.filter(created_by=user).order_by('-created_at').first()
                if recent_order:
                    return f"📦 *Your Latest Order*: #{recent_order.order_code}\n• Product: {recent_order.product_name} (Qty: {recent_order.quantity})\n• Status: *{recent_order.status}*\n• Total: ₹{recent_order.total_amount}"
            return "You can check the live tracking status of all your orders directly under the **Orders** tab."

        # Generic polite fallback
        return f"Namaste! I am your Pure Water AI Assistant. I can help you with product details, pricing, order tracking, franchise registration, and business inquiries. Feel free to ask any question!"
