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

        # Greetings & identity
        if msg in ['hi', 'hello', 'hey', 'namaste', 'halo', 'hola', 'good morning', 'good evening']:
            if app_type == 'franchise':
                return "Namaste Franchise Partner! 👋\nI am your Pure Water AI Operations Assistant. How can I assist you with orders, dispatch, margins, or franchise operations today?"
            return "Namaste! 🙏\nWelcome to Shivnath Pure Water. I can help you with product pricing, placing orders, delivery status, franchise applications, and quality details. How can I help you today?"

        if 'who are you' in msg or 'what can you do' in msg or 'your name' in msg:
            return "I am the Shivnath Pure Water AI Assistant 💧.\nI can answer questions about:\n• Our packaged drinking water and natural mineral water products\n• Current bottle sizes (250ml, 500ml, 1L, 2L, 5L, 20L)\n• Pricing, discounts, and checkout methods (COD, UPI)\n• Home & office doorstep delivery in Raipur\n• Franchise partnership terms, 12% margins & 5 KM territory protection\n• General technical, science, and educational queries."

        # Technical / General Knowledge
        if 'what is python' in msg or 'python' == msg:
            return "Python is a popular, high-level, interpreted programming language known for its simplicity and readability. It is used extensively in backend development (powering our Django server!), data analysis, machine learning, and automation."

        if 'what is java' in msg:
            return "Java is a class-based, object-oriented programming language designed for platform independence with the 'Write Once, Run Anywhere' (WORA) capability."

        if 'what is flutter' in msg or 'what is dart' in msg or 'flutter' in msg:
            return "Flutter is Google's open-source UI software toolkit for building natively compiled applications for mobile, web, and desktop from a single Dart codebase."

        # Payment Methods & COD
        if any(w in msg for w in ['payment', 'cod', 'cash on delivery', 'upi', 'gpay', 'phonepe', 'paytm', 'pay online', 'credit card', 'debit card']):
            return "💳 *Accepted Payment Methods*:\n• **Cash on Delivery (COD)**: Pay cash when your water is delivered at your doorstep.\n• **UPI / QR Code**: Pay via Google Pay, PhonePe, or Paytm upon delivery.\n• **Franchise Billing**: Direct bank transfer & credit terms as per agreement."

        # Pricing, Rates & Cost
        if any(w in msg for w in ['price', 'cost', 'rate', 'how much', 'mrp', 'rupees', 'charges', 'pricing']):
            try:
                products = Product.objects.filter(status__iexact='Active')
                if products.exists():
                    lines = [f"• **{p.name}** ({p.size}): ₹{p.price}" for p in products]
                    return "💧 *Live Product Pricing*:\n" + "\n".join(lines) + "\n\n*Free delivery on regular and subscription orders in Raipur!*"
            except Exception:
                pass
            return "💧 *Current Pricing*:\n• **Packaged Drinking Water 20L Jar**: ₹40.00\n• **Natural Mineral Water 500ml (Pack of 24)**: ₹240.00\n• **Pure Drinking Water 1L Bottle**: ₹20.00"

        # Water Purity, Quality, RO & TDS
        if any(w in msg for w in ['quality', 'tds', 'purif', 'ro', 'uv', 'clean', 'safe', 'mineral', 'is it pure', 'ph', 'certification', 'fssai']):
            return "✨ *Shivnath Purity Standards*:\n• **Multi-Stage Filtration**: Sand Filtration -> Activated Carbon -> Reverse Osmosis (RO) -> Ultra Violet (UV) Treatment -> Ozonization.\n• **Optimal TDS**: Balanced between 100 - 150 ppm with essential calcium and magnesium electrolytes.\n• **Certifications**: BIS & FSSAI certified bottling plant ensuring 100% microbiological safety."

        # Product Sizes & Catalog
        if any(w in msg for w in ['size', 'bottle', 'jar', 'can size', 'catalog', 'volume', '20l', '500ml', '1l', '2l', '5l', 'litres', 'water bottle', 'products available']):
            return "💧 *Shivnath Water Product Catalog & Sizes*:\n• **20 Litre Jar**: ₹40 (Standard home/office dispenser jar)\n• **500ml Pack of 24**: ₹240 (Natural mineral water bottles)\n• **1 Litre Bottle**: ₹20 (Individual travel bottle)\n• **250ml Cup / Bottle**: Available for events and bulk catering\n• **5 Litre Can**: Family pack with ergonomic handle\n\nAll bottles are manufactured using food-grade BPA-free recyclable PET."

        # Franchise Information, Margins & Territory
        if 'franchise' in msg or 'dealer' in msg or 'distributor' in msg or 'partner' in msg or 'margin' in msg or 'investment' in msg or 'commission' in msg:
            return "🏢 *Shivnath Franchise Opportunity*:\n• **Exclusive Territory**: Guaranteed 5 KM radius exclusive sales zone.\n• **Profit Margins**: Attractive 12% operational commission on all plant deliveries.\n• **Investment Range**: ₹3 Lakh – ₹10 Lakh (includes refundable security deposit & initial stock).\n• **Company Support**: Branding, CRM software, marketing collateral, and guaranteed supply.\n• **How to Apply**: Tap 'Apply for Franchise (Qualify Now)' in chat or fill the registration form on login."

        # Order Tracking & Status
        if 'track' in msg or 'status' in msg or 'where is my order' in msg:
            if user and user.is_authenticated:
                recent_order = Order.objects.filter(created_by=user).order_by('-created_at').first()
                if recent_order:
                    return f"📦 *Your Latest Order*: #{recent_order.order_code}\n• Product: {recent_order.product_name} (Qty: {recent_order.quantity})\n• Status: *{recent_order.status}*\n• Total Amount: ₹{recent_order.total_amount}"
            return "📍 You can track live dispatch and delivery stages of any order anytime under the **My Orders** screen."

        # Contact & Office Support
        if 'contact' in msg or 'support' in msg or 'phone' in msg or 'email' in msg or 'office' in msg or 'call' in msg or 'owner' in msg or 'address' in msg:
            return "📞 *Shivnath Agency Contact & Support*:\n• **Customer Care / WhatsApp**: +91 98062 47194\n• **Email**: info@pathideainfotech.com / support@shivnathagency.com\n• **Head Office**: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh – 492001\n• **Hours**: 9:00 AM – 7:00 PM (Mon-Sat)"

        # General / Catch-all response
        return "I am here to assist you with Shivnath Pure Water! 💧\nYou can ask about our 20L jars, 500ml packs, current prices, delivery in Raipur, order placement, franchise applications, or any technical question."
