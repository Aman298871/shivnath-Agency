from django.contrib import admin
from .models import Quotation, ChatbotOption, ChatSession, ChatMessage


@admin.register(Quotation)
class QuotationAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'title',
        'quotation_type',
        'product',
        'quantity_tier',
        'unit_price',
        'total_price',
        'target_audience',
        'is_active',
        'updated_at',
    )
    list_filter = ('quotation_type', 'target_audience', 'is_active')
    search_fields = ('title', 'product__name', 'notes', 'applicable_terms')
    readonly_fields = ('created_at', 'updated_at')


@admin.register(ChatbotOption)
class ChatbotOptionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'title',
        'inquiry_type',
        'parent',
        'order',
        'is_active',
        'is_lead_trigger',
        'product',
        'quotation',
    )
    list_filter = ('inquiry_type', 'is_active', 'is_lead_trigger')
    search_fields = ('title', 'answer_text', 'keywords')
    readonly_fields = ('created_at', 'updated_at')


class ChatMessageInline(admin.TabularInline):
    model = ChatMessage
    extra = 0
    readonly_fields = ('role', 'content', 'timestamp')
    can_delete = False


@admin.register(ChatSession)
class ChatSessionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'session_id',
        'user',
        'customer_name',
        'customer_phone',
        'app_type',
        'chatbot_mode',
        'inquiry_type',
        'lead_capture_completed',
        'status',
        'updated_at',
    )
    list_filter = ('app_type', 'chatbot_mode', 'inquiry_type', 'lead_capture_completed', 'status')
    search_fields = ('session_id', 'customer_name', 'customer_phone', 'customer_email', 'user__username')
    readonly_fields = ('created_at', 'updated_at')
    inlines = [ChatMessageInline]


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ('id', 'session', 'role', 'content_snippet', 'timestamp')
    list_filter = ('role', 'timestamp')
    search_fields = ('content', 'session__customer_name', 'session__customer_phone')
    readonly_fields = ('timestamp',)

    @admin.display(description='Content')
    def content_snippet(self, obj):
        return obj.content[:60] + ('...' if len(obj.content) > 60 else '')
