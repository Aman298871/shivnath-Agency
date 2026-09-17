import json
import logging
import os
import re
import urllib.request
import urllib.error
from decimal import Decimal
from django.conf import settings
from django.db.models import Q, Sum

logger = logging.getLogger(__name__)


class AIService:
    """
    Intelligent Grounded AI & Rule-Engine Service for Pure Water Operations.
    Strictly answers relevant business, product, and franchise inquiries based on
    actual PostgreSQL database records (Products, Quotations, ChatbotOptions, Orders).
    Never fabricates prices, stock, margins, or fake quotations.
    """

    OUT_OF_SCOPE_MESSAGE = (
        "I am the Shivnath Agency Pure Water Operations Assistant. "
        "I can only assist with packaged drinking water products, pricing, "
        "orders, delivery, quotations, franchise opportunities, and operations. "
        "Please ask a question related to Shivnath Agency services."
    )

    @staticmethod
    def get_live_app_context(app_type='customer', user=None):
        """
        Retrieves live data from PostgreSQL to ground AI responses in actual database facts.
        """
        from products.models import Product, ProductCategory
        from chat.models import Quotation, ChatbotOption
        from orders.models import Order

        products = list(Product.objects.filter(status='Active').values(
            'id', 'name', 'size', 'category', 'price', 'stock', 'unit', 'description'
        ))

        categories = list(ProductCategory.objects.filter(is_active=True).values(
            'id', 'name', 'description'
        ))

        target_filter = ['both']
        if app_type == 'franchise':
            target_filter.append('franchise')
        else:
            target_filter.append('customer')

        quotations = list(Quotation.objects.filter(is_active=True, target_audience__in=target_filter).values(
            'id', 'title', 'quotation_type', 'quantity_tier', 'unit_price', 'total_price',
            'applicable_terms', 'validity', 'target_audience'
        ))

        chatbot_options = list(ChatbotOption.objects.filter(is_active=True).values(
            'id', 'title', 'inquiry_type', 'answer_text', 'keywords', 'is_lead_trigger'
        ))

        stats = {
            'total_active_products': len(products),
            'total_categories': len(categories),
            'total_quotations': len(quotations),
        }

        if user and user.is_authenticated:
            user_orders = Order.objects.filter(created_by=user).count()
            stats['user_orders_count'] = user_orders

        return {
            'app_type': app_type,
            'products': products,
            'categories': categories,
            'quotations': quotations,
            'chatbot_options': chatbot_options,
            'stats': stats,
            'company': {
                'name': 'Shivnath Agency (Pure Packaged Drinking Water)',
                'brand': 'Pure Water / Shivnath Packaged Drinking Water',
                'head_office': 'H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh - 492001',
                'contact_phone': '+91 98062 47194',
                'contact_email': 'info@pathideainfotech.com / support@shivnathagency.com',
                'plant_location': 'Industrial Area, Phase 2, Raipur, CG',
                'standards': 'BIS Certified (IS 14543), FSSAI Approved, 7-Stage RO + UV + Ozonation Purification',
                'hours': '9:00 AM - 7:00 PM (Monday to Saturday)',
            }
        }

    @classmethod
    def generate_response(cls, message, app_type='customer', user=None, history=None):
        """
        Generates grounded, safe responses.
        1. Checks for strict out-of-scope topics.
        2. Tries external AI (Gemini / OpenAI) grounded with database context if keys available.
        3. Uses intelligent deterministic rule-engine grounded in PostgreSQL.
        """
        if not message or not str(message).strip():
            return "How can I assist you with Shivnath Agency products, quotations, or orders today?"

        raw_msg = str(message).strip()
        msg_lower = raw_msg.lower()

        # Strict Out of scope check
        if cls._is_out_of_scope(msg_lower):
            return cls.OUT_OF_SCOPE_MESSAGE

        # Try LLM if configured
        gemini_key = getattr(settings, 'GEMINI_API_KEY', None) or os.getenv('GEMINI_API_KEY')
        openai_key = getattr(settings, 'OPENAI_API_KEY', None) or os.getenv('OPENAI_API_KEY')

        if gemini_key and gemini_key.strip() and not gemini_key.startswith('your_'):
            try:
                context = cls.get_live_app_context(app_type=app_type, user=user)
                llm_reply = cls._call_gemini_api(gemini_key, context, raw_msg, history=history)
                if llm_reply and len(llm_reply.strip()) > 5:
                    return llm_reply.strip()
            except Exception as e:
                logger.warning(f"Gemini API error, falling back to local engine: {e}")

        if openai_key and openai_key.strip() and not openai_key.startswith('your_'):
            try:
                context = cls.get_live_app_context(app_type=app_type, user=user)
                llm_reply = cls._call_openai_api(openai_key, context, raw_msg, history=history)
                if llm_reply and len(llm_reply.strip()) > 5:
                    return llm_reply.strip()
            except Exception as e:
                logger.warning(f"OpenAI API error, falling back to local engine: {e}")

        # Intelligent Fallback Engine grounded on Database
        return cls._intelligent_fallback_response(raw_msg, app_type=app_type, user=user)

    @classmethod
    def _is_out_of_scope(cls, msg_lower):
        out_of_scope_patterns = [
            r'\bpython\b', r'\bjava\b', r'\bc\+\+\b', r'\bjavascript\b', r'\bhtml\b', r'\bcss\b',
            r'\bflutter\b', r'\bdart\b', r'\bprogramming\b', r'\bwrite code\b', r'\bsql query\b',
            r'\bprime minister\b', r'\bpresident\b', r'\bmodi\b', r'\bbiden\b', r'\btrump\b', r'\bpolitics\b',
            r'\bjoke\b', r'\briddle\b', r'\bweather\b', r'\btemperature\b', r'\bforecast\b',
            r'\bgirlfriend\b', r'\bboyfriend\b', r'\blove advice\b', r'\bmarriage advice\b',
            r'\bbollywood\b', r'\bcricket\b', r'\bipl score\b', r'\bactor\b', r'\bactress\b', r'\bsong lyrics\b',
            r'\bwho is\b.*\b(actor|singer|hero|politician)\b',
        ]
        for pattern in out_of_scope_patterns:
            if re.search(pattern, msg_lower):
                return True
        return False

    @classmethod
    def _call_gemini_api(cls, api_key, system_context, user_message, history=None):
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
        headers = {"Content-Type": "application/json"}

        system_instruction = (
            "You are the AI Operations Assistant for Shivnath Agency (Pure Packaged Drinking Water).\n"
            "STRICT RULES:\n"
            "1. You must ONLY answer questions about Shivnath Agency water products, pricing, orders, delivery, quotations, and franchise business.\n"
            "2. Ground all answers strictly on the provided live database context.\n"
            "3. NEVER fabricate or hallucinate prices, stock, margins, or quotations. If a quotation or price is not in context, state actual product prices or direct the user to contact +91 98062 47194.\n"
            "4. If the user asks anything outside of Shivnath Agency water business, refuse with: "
            f"'{cls.OUT_OF_SCOPE_MESSAGE}'\n\n"
            f"Live Database Context:\n{json.dumps(system_context, default=str)}"
        )

        contents = []
        if history and isinstance(history, list):
            for h in history[-6:]:
                role = "user" if h.get("role") == "user" else "model"
                contents.append({"role": role, "parts": [{"text": str(h.get("content", ""))}]})

        contents.append({"role": "user", "parts": [{"text": user_message}]})

        body = {
            "systemInstruction": {"parts": [{"text": system_instruction}]},
            "contents": contents,
            "generationConfig": {
                "temperature": 0.2,
                "maxOutputTokens": 600,
            }
        }

        req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers=headers, method='POST')
        with urllib.request.urlopen(req, timeout=8) as response:
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
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}"
        }

        system_prompt = (
            "You are the AI Operations Assistant for Shivnath Agency (Pure Packaged Drinking Water).\n"
            "STRICT RULES:\n"
            "1. Only answer about Shivnath Agency products, orders, quotations, pricing, franchise, and operations.\n"
            "2. Ground answers strictly on live context. Never fabricate prices, stock, or quotations.\n"
            f"Context:\n{json.dumps(system_context, default=str)}"
        )

        messages = [{"role": "system", "content": system_prompt}]
        if history and isinstance(history, list):
            for h in history[-6:]:
                messages.append({"role": h.get("role", "user"), "content": str(h.get("content", ""))})
        messages.append({"role": "user", "content": user_message})

        body = {
            "model": "gpt-4o-mini",
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 500
        }

        req = urllib.request.Request(url, data=json.dumps(body).encode('utf-8'), headers=headers, method='POST')
        with urllib.request.urlopen(req, timeout=8) as response:
            res_body = json.loads(response.read().decode('utf-8'))
            choices = res_body.get('choices', [])
            if choices:
                return choices[0].get('message', {}).get('content', '').strip()
        return None

    @classmethod
    def _intelligent_fallback_response(cls, message, app_type='customer', user=None):
        raw_msg = message.strip()
        msg = raw_msg.lower()

        from products.models import Product, ProductCategory
        from chat.models import Quotation, ChatbotOption

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
        # 1. MATCH CONFIGURED CHATBOT OPTIONS & KEYWORDS
        # =========================================================================
        active_options = ChatbotOption.objects.filter(is_active=True).select_related('product', 'quotation')
        for opt in active_options:
            keywords = [k.strip().lower() for k in opt.keywords.split(',') if k.strip()]
            keywords.append(opt.title.lower())
            if any(k in msg for k in keywords):
                if opt.answer_text:
                    return opt.answer_text
                if opt.quotation:
                    q = opt.quotation
                    return (
                        f"Quotation: {q.title}\n"
                        f"* Quantity Tier: {q.quantity_tier}\n"
                        f"* Rate: Rs.{q.total_price or q.unit_price}\n"
                        f"* Terms: {q.applicable_terms}\n"
                        f"* Validity: {q.validity}"
                    )
                if opt.product:
                    p = opt.product
                    return (
                        f"{p.name} ({p.size})\n"
                        f"* Price: Rs.{p.price} per {p.unit}\n"
                        f"* Availability: {'In Stock (' + str(p.stock) + ' units)' if p.stock > 0 else 'Out of Stock'}\n"
                        f"* Category: {p.category}\n"
                        f"* Description: {p.description or 'Pure packaged drinking water'}"
                    )

        # =========================================================================
        # 2. MATCH QUOTATIONS (Admin Created & Dynamic Database Quotations)
        # =========================================================================
        is_quote_query = matches(['quotation', 'quote', 'rate chart', 'wholesale price', 'bulk rate', 'price list', 'rate list', 'tier price', 'bulk quantity', 'custom quote', 'discount'])
        if is_quote_query:
            active_quotations = Quotation.objects.filter(is_active=True).select_related('product')
            if app_type == 'franchise':
                active_quotations = active_quotations.filter(Q(target_audience='franchise') | Q(target_audience='both'))
            else:
                active_quotations = active_quotations.filter(Q(target_audience='customer') | Q(target_audience='both'))

            matched_quotes = []
            for q in active_quotations:
                q_terms = [q.title.lower(), q.quotation_type.lower(), q.quantity_tier.lower()]
                if q.product:
                    q_terms.extend([q.product.name.lower(), q.product.size.lower(), q.product.category.lower()])
                if any(term in msg for term in q_terms if term):
                    matched_quotes.append(q)

            if not matched_quotes and active_quotations.exists():
                matched_quotes = list(active_quotations[:3])

            if matched_quotes:
                resp_lines = ["Available Official Quotations & Tiers:"]
                for q in matched_quotes:
                    prod_info = f" ({q.product.name})" if q.product else ""
                    price_str = f"Rs.{q.total_price}" if q.total_price > 0 else f"Rs.{q.unit_price}/unit"
                    resp_lines.append(
                        f"\n* {q.title}{prod_info}\n"
                        f"  - Tier: {q.quantity_tier}\n"
                        f"  - Price: {price_str}\n"
                        f"  - Terms: {q.applicable_terms}\n"
                        f"  - Validity: {q.validity}"
                    )
                resp_lines.append("\nFor customized corporate or institutional contracts, contact our sales desk at +91 98062 47194.")
                return "\n".join(resp_lines)
            else:
                products = Product.objects.filter(status='Active')
                resp_lines = ["Standard Product Price List:"]
                for p in products:
                    resp_lines.append(f"* {p.name} ({p.size}): Rs.{p.price} per {p.unit} [Stock: {p.stock}]")
                resp_lines.append("\nFor bulk quantities (100+ units) or specialized quotations, our Sales team will prepare an instant proposal. Please call +91 98062 47194.")
                return "\n".join(resp_lines)

        # =========================================================================
        # 3. MATCH SPECIFIC PRODUCT QUERIES (Price, Stock, Details)
        # =========================================================================
        all_products = Product.objects.filter(status='Active')
        for prod in all_products:
            name_lower = prod.name.lower()
            size_lower = prod.size.lower()
            sku_lower = prod.sku.lower()
            if name_lower in msg or (size_lower and size_lower in msg) or sku_lower in msg:
                stock_status = f"In Stock ({prod.stock} units available)" if prod.stock > 0 else "Currently Out of Stock"
                return (
                    f"{prod.name}\n"
                    f"* Size / Unit: {prod.size} ({prod.unit})\n"
                    f"* Category: {prod.category}\n"
                    f"* Official Price: Rs.{prod.price} per {prod.unit}\n"
                    f"* Stock Availability: {stock_status}\n"
                    f"* Description: {prod.description or 'Pure packaged drinking water with 7-stage purification.'}\n\n"
                    f"You can add this to your cart in the app or order via customer support."
                )

        # =========================================================================
        # 4. GENERAL PRODUCT CATALOG & AVAILABILITY
        # =========================================================================
        if matches(['product', 'products', 'items', 'water', 'bottle', 'jar', 'stock', 'catalogue', 'catalog', 'available', 'menu']):
            categories = ProductCategory.objects.filter(is_active=True)
            prods = Product.objects.filter(status='Active')

            if not prods.exists():
                return "We currently have no active products listed in the catalog. Please contact +91 98062 47194."

            lines = ["Shivnath Agency Product Catalog:"]
            for p in prods:
                stock_txt = f"{p.stock} units" if p.stock > 0 else "Out of stock"
                lines.append(f"* {p.name} ({p.size}) - Rs.{p.price}/{p.unit} [{stock_txt}]")

            if categories.exists():
                cat_names = [c.name for c in categories]
                lines.append(f"\nCategories: {', '.join(cat_names)}")

            lines.append("\nYou can select any product to place an order or view details.")
            return "\n".join(lines)

        # =========================================================================
        # 5. FRANCHISE INQUIRIES & QUALIFICATION
        # =========================================================================
        if matches(['franchise', 'dealership', 'distributor', 'partner', 'agency', 'investment', 'apply for franchise', 'qualify']):
            return (
                "Shivnath Agency Franchise Opportunity:\n\n"
                "* Model: Exclusive City / District Territory Distribution\n"
                "* Investment Range: Rs.3 Lakh - Rs.20 Lakh (Based on territory tier)\n"
                "* Requirement: 500-1200 sq.ft commercial storage space & local delivery vehicle\n"
                "* Gross Profit Margin: 25% - 35% on direct plant supply\n"
                "* Support Provided: Plant dispatch priority, CRM app, branded marketing materials, and dedicated territory protection.\n\n"
                "To apply immediately, select 'Apply for Franchise (Qualify Now)' or contact +91 98062 47194."
            )

        # =========================================================================
        # 6. ORDER PLACEMENT & TRACKING
        # =========================================================================
        if matches(['order', 'how to order', 'buy', 'place order', 'track', 'delivery', 'dispatch', 'status']):
            return (
                "How Ordering Works:\n"
                "1. Browse Products: Add 250ml/500ml/1L/2L bottles or 20L jars to your cart.\n"
                "2. Checkout: Enter your delivery address and choose Payment on Delivery / Online.\n"
                "3. Real-time Tracking: Monitor order stages (Placement -> Plant Approval -> Dispatch -> Delivered).\n\n"
                "Orders within Raipur and surrounding territories are delivered within same day or next business morning."
            )

        # =========================================================================
        # 7. WATER PURITY, QUALITY, CERTIFICATIONS
        # =========================================================================
        if matches(['quality', 'purity', 'ro', 'tds', 'bis', 'fssai', 'safe', 'test', 'clean', 'hygiene', 'health']):
            return (
                "Quality & Purity Standards:\n"
                "* Purification: 7-Stage Advanced Reverse Osmosis (RO) + UV Sterilization + Ozonation.\n"
                "* Certifications: Fully BIS Certified (IS 14543) and FSSAI Licensed.\n"
                "* Mineral Balance: Retains optimal essential minerals (calcium, magnesium) with balanced TDS for sweet taste.\n"
                "* Packaging: 100% Food-Grade, virgin PET bottles and automated touch-free filling."
            )

        # =========================================================================
        # 8. CONTACT & SUPPORT
        # =========================================================================
        if matches(['contact', 'support', 'phone', 'email', 'office', 'call', 'helpline', 'customer care', 'address', 'location', 'reach']):
            return (
                "Shivnath Agency Contact & Support:\n"
                "* Customer Care / WhatsApp: +91 98062 47194\n"
                "* Email: info@pathideainfotech.com / support@shivnathagency.com\n"
                "* Head Office: H Block, 2nd Floor, Farishta Complex, Raipur, Chhattisgarh - 492001\n"
                "* Hours: 9:00 AM - 7:00 PM (Monday to Saturday)"
            )

        # =========================================================================
        # 9. GREETING
        # =========================================================================
        if matches(['hi', 'hello', 'hey', 'namaste', 'good morning', 'good afternoon', 'good evening', 'start']):
            return (
                "Namaste! Welcome to Shivnath Agency Pure Packaged Drinking Water.\n\n"
                "I can assist you with:\n"
                "1. Product Catalog & Current Stock\n"
                "2. Official Price Quotes & Wholesale Tiers\n"
                "3. Placing or Tracking Orders\n"
                "4. Franchise Partnership & Territory Inquiries\n\n"
                "What would you like to know?"
            )

        # =========================================================================
        # 10. DEFAULT HELPFUL FALLBACK (RELEVANT TO PURE WATER)
        # =========================================================================
        return (
            "Thank you for reaching out to Shivnath Agency. "
            "You can ask about our water products, pricing tiers, quotations, order placement, or franchise opportunities. "
            "For direct sales assistance, please contact +91 98062 47194."
        )
