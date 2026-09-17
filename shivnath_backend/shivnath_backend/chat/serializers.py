from rest_framework import serializers
from .models import Quotation, ChatbotOption, ChatSession, ChatMessage
from products.models import Product
from products.serializers import ProductSerializer


class QuotationSerializer(serializers.ModelSerializer):
    product_details = ProductSerializer(source='product', read_only=True)
    product_id = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.all(),
        source='product',
        required=False,
        allow_null=True,
    )

    class Meta:
        model = Quotation
        fields = [
            'id',
            'title',
            'quotation_type',
            'product',
            'product_id',
            'product_details',
            'quantity_tier',
            'unit_price',
            'total_price',
            'applicable_terms',
            'notes',
            'validity',
            'target_audience',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'product_details']


class ChatbotOptionSerializer(serializers.ModelSerializer):
    children = serializers.SerializerMethodField()
    parent_title = serializers.CharField(source='parent.title', read_only=True)
    product_name = serializers.CharField(source='product.name', read_only=True)
    quotation_title = serializers.CharField(source='quotation.title', read_only=True)
    product_details = ProductSerializer(source='product', read_only=True)
    quotation_details = QuotationSerializer(source='quotation', read_only=True)

    class Meta:
        model = ChatbotOption
        fields = [
            'id',
            'title',
            'inquiry_type',
            'parent',
            'parent_title',
            'order',
            'is_active',
            'is_lead_trigger',
            'lead_inquiry_type',
            'answer_text',
            'product',
            'product_name',
            'product_details',
            'quotation',
            'quotation_title',
            'quotation_details',
            'keywords',
            'has_children',
            'children',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'parent_title',
            'product_name',
            'quotation_title',
            'product_details',
            'quotation_details',
            'has_children',
            'created_at',
            'updated_at',
        ]

    def get_children(self, obj):
        active_children = obj.children.filter(is_active=True).order_by('order', 'title')
        return ChatbotOptionSerializer(active_children, many=True).data


class ChatMessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChatMessage
        fields = [
            'id',
            'session',
            'sender',
            'message',
            'quick_replies',
            'created_at',
        ]
        read_only_fields = ['id', 'created_at']


class ChatSessionSerializer(serializers.ModelSerializer):
    messages = ChatMessageSerializer(many=True, read_only=True)

    class Meta:
        model = ChatSession
        fields = [
            'id',
            'session_token',
            'lead',
            'inquiry_type',
            'is_active',
            'created_at',
            'updated_at',
            'messages',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'messages']

