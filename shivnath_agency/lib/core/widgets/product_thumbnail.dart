import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../../models/product_model.dart';

/// Production-ready Product Thumbnail widget that displays real product images:
/// 1. Attempts to load network image (resolving relative URLs against AppConstants.apiBaseUrl).
/// 2. Gracefully falls back to local high-resolution asset images (shv_200.jpg, shv_500.jpg, shv_1l.jpg, shv_20l.jpg).
/// 3. If asset fails, displays a styled themed vector icon.
class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String sku;
  final String name;
  final String size;
  final String category;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const ProductThumbnail({
    super.key,
    this.imageUrl,
    this.sku = '',
    this.name = '',
    this.size = '',
    this.category = '',
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius,
    this.backgroundColor = const Color(0xFFE0F2FE),
    this.padding = EdgeInsets.zero,
  });

  factory ProductThumbnail.fromProduct({
    Key? key,
    required ProductModel product,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
    Color backgroundColor = const Color(0xFFE0F2FE),
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    return ProductThumbnail(
      key: key,
      imageUrl: product.displayImageUrl,
      sku: product.sku,
      name: product.name,
      size: product.size,
      category: product.category,
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      padding: padding,
    );
  }

  factory ProductThumbnail.fromMap({
    Key? key,
    required Map<String, dynamic> data,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    BorderRadius? borderRadius,
    Color backgroundColor = const Color(0xFFE0F2FE),
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) {
    final rawImg = data['image']?.toString() ??
        data['product_image']?.toString() ??
        data['img']?.toString() ??
        '';
    String finalUrl = '';
    if (rawImg.isNotEmpty) {
      if (rawImg.startsWith('http://') || rawImg.startsWith('https://')) {
        finalUrl = rawImg;
      } else {
        final base = AppConstants.apiBaseUrl.endsWith('/')
            ? AppConstants.apiBaseUrl.substring(0, AppConstants.apiBaseUrl.length - 1)
            : AppConstants.apiBaseUrl;
        final path = rawImg.startsWith('/') ? rawImg : '/$rawImg';
        finalUrl = '$base$path';
      }
    }

    return ProductThumbnail(
      key: key,
      imageUrl: finalUrl,
      sku: data['sku']?.toString() ?? data['product_sku']?.toString() ?? '',
      name: data['name']?.toString() ?? data['product_name']?.toString() ?? '',
      size: data['size']?.toString() ?? data['product_size']?.toString() ?? '',
      category: data['category']?.toString() ?? data['category_name']?.toString() ?? '',
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackAsset = ProductModel.resolveAssetFallback(
      sku: sku,
      name: name,
      size: size,
      category: category,
    );

    final resolvedBorderRadius = borderRadius ?? BorderRadius.circular(12);

    Widget imageWidget;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = Image.network(
        imageUrl!,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            _assetFallback(fallbackAsset),
      );
    } else {
      imageWidget = _assetFallback(fallbackAsset);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: resolvedBorderRadius,
      ),
      child: ClipRRect(
        borderRadius: resolvedBorderRadius,
        child: Padding(
          padding: padding,
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _assetFallback(String assetPath) {
    final double iconSize = (height != null ? height! * 0.5 : 32.0)
        .toDouble()
        .clamp(18.0, 64.0);

    return Image.asset(
      assetPath,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          category.toLowerCase().contains('jar') ||
                  name.toLowerCase().contains('jar')
              ? Icons.water_drop_rounded
              : Icons.local_drink_rounded,
          color: const Color(0xFF0284C7),
          size: iconSize,
        ),
      ),
    );
  }
}
