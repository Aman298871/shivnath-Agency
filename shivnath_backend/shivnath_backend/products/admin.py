from django.contrib import admin
from .models import ProductCategory, Product


@admin.register(ProductCategory)
class ProductCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'parent', 'order', 'is_active', 'created_at')
    list_filter = ('is_active', 'parent')
    search_fields = ('name', 'slug', 'description')
    prepopulated_fields = {'slug': ('name',)}


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'name',
        'sku',
        'size',
        'category_ref',
        'category',
        'price',
        'gst',
        'stock',
        'status',
        'created_at',
    )
    list_filter = ('status', 'category_ref', 'category', 'size')
    search_fields = ('name', 'sku', 'description')
    readonly_fields = ('created_at', 'updated_at')

