import os
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
    pdf_url = serializers.SerializerMethodField()
    pdf_name = serializers.SerializerMethodField()
    has_pdf = serializers.SerializerMethodField()
    remove_pdf = serializers.BooleanField(required=False, write_only=True, default=False)

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
            'pdf_file',
            'pdf_url',
            'pdf_name',
            'has_pdf',
            'remove_pdf',
            'is_active',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'product_details', 'pdf_url', 'pdf_name', 'has_pdf']

    def get_has_pdf(self, obj):
        return bool(obj.pdf_file and hasattr(obj.pdf_file, 'name') and obj.pdf_file.name)

    def get_pdf_name(self, obj):
        if obj.pdf_file and hasattr(obj.pdf_file, 'name') and obj.pdf_file.name:
            return os.path.basename(obj.pdf_file.name)
        return None

    def get_pdf_url(self, obj):
        if obj.pdf_file and hasattr(obj.pdf_file, 'url'):
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.pdf_file.url)
            return obj.pdf_file.url
        return None

    def validate_pdf_file(self, value):
        if value:
            # Check extension
            ext = os.path.splitext(value.name)[1].lower()
            if ext != '.pdf':
                raise serializers.ValidationError("Only PDF files (.pdf) are allowed.")
            # Check max size (15MB)
            if value.size > 15 * 1024 * 1024:
                raise serializers.ValidationError("PDF file size cannot exceed 15MB.")
        return value

    def create(self, validated_data):
        validated_data.pop('remove_pdf', None)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        remove_pdf = validated_data.pop('remove_pdf', False)
        if remove_pdf:
            if instance.pdf_file:
                instance.pdf_file.delete(save=False)
            instance.pdf_file = None
        return super().update(instance, validated_data)


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
        inquiry_type = self.context.get('inquiry_type')
        active_children = obj.children.filter(is_active=True).order_by('order', 'title')
        if inquiry_type == 'customer':
            from django.db.models import Q
            active_children = active_children.filter(
                Q(inquiry_type="customer") | Q(inquiry_type="both")
            ).exclude(Q(title__icontains="quotation") | Q(title__icontains="franchise"))
        elif inquiry_type == 'franchise':
            from django.db.models import Q
            active_children = active_children.filter(
                Q(inquiry_type="franchise") | Q(inquiry_type="both")
            )
        return ChatbotOptionSerializer(active_children, many=True, context=self.context).data


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

