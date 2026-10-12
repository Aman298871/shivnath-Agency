import '../core/constants/app_constants.dart';

class ProductModel {
  final String id;
  final String name;
  final String sku;
  final String category;
  final String size;
  final double price;
  final String unit;
  final String image;
  final int stock;
  final String description;
  final int shelfLifeDays;
  final String status;

  final int? categoryRefId;
  final String? categoryHierarchy;

  const ProductModel({
    required this.id,
    required this.name,
    this.sku = '',
    required this.category,
    this.categoryRefId,
    this.categoryHierarchy,
    required this.size,
    required this.price,
    required this.unit,
    required this.image,
    required this.stock,
    required this.description,
    this.shelfLifeDays = 180,
    this.status = 'Active',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String parsedCategory = "Water";
    int? parsedCatRefId;

    if (json["category"] is Map) {
      parsedCategory = json["category"]["name"]?.toString() ?? "Water";
      if (json["category"]["id"] is int) {
        parsedCatRefId = json["category"]["id"] as int;
      }
    } else if (json["category"] is int) {
      parsedCatRefId = json["category"] as int;
      parsedCategory = json["category_name"]?.toString() ?? "Category $parsedCatRefId";
    } else if (json["category"] != null) {
      parsedCategory = json["category"].toString();
    } else if (json["category_name"] != null) {
      parsedCategory = json["category_name"].toString();
    }

    if (parsedCatRefId == null) {
      if (json["category_ref_id"] is int) {
        parsedCatRefId = json["category_ref_id"] as int;
      } else if (json["category_ref"] is int) {
        parsedCatRefId = json["category_ref"] as int;
      } else if (json["category_ref"] is Map && json["category_ref"]["id"] is int) {
        parsedCatRefId = json["category_ref"]["id"] as int;
      } else {
        parsedCatRefId = int.tryParse(json["category_ref_id"]?.toString() ?? "");
      }
    }

    return ProductModel(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      sku: json["sku"]?.toString() ?? "",
      category: parsedCategory,
      categoryRefId: parsedCatRefId,
      categoryHierarchy: json["category_hierarchy"]?.toString(),
      size: json["size"]?.toString() ?? "",
      price: double.tryParse(json["price"]?.toString() ?? "0") ?? 0.0,
      unit: json["unit"]?.toString() ?? json["size"]?.toString() ?? "Bottle",
      image: json["image"]?.toString() ?? "",
      stock: int.tryParse(json["stock"]?.toString() ?? "0") ?? 0,
      description: json["description"]?.toString() ?? "",
      shelfLifeDays: int.tryParse(json["shelf_life_days"]?.toString() ?? "180") ?? 180,
      status: json["status"]?.toString() ?? "Active",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "sku": sku,
      "category": category,
      "size": size,
      "price": price,
      "unit": unit,
      "image": image,
      "stock": stock,
      "description": description,
      "status": status,
    };
  }

  static String resolveAssetFallback({
    String sku = '',
    String name = '',
    String size = '',
    String category = '',
  }) {
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();

    // 20L / Jar
    if (s.contains('SHV-20L') ||
        s.contains('JAR') ||
        sz.contains('20l') ||
        sz.contains('20 l') ||
        sz.contains('20000') ||
        nm.contains('20 litre') ||
        nm.contains('20l') ||
        nm.contains('jar') ||
        category.toLowerCase().contains('jar')) {
      return 'assets/images/products/shv_20l.jpg';
    }

    // 2L / 1L Bottles
    if (s.contains('BOT-2000') ||
        sz.contains('2l') ||
        sz.contains('2 l') ||
        nm.contains('2 litre') ||
        nm.contains('2l') ||
        s.contains('SHV-1L') ||
        s.contains('1000') ||
        sz.contains('1l') ||
        sz.contains('1 l') ||
        nm.contains('1 litre') ||
        nm.contains('1l') ||
        nm.contains('pure 2l')) {
      return 'assets/images/products/shv_1l.jpg';
    }

    // 500ml Bottle
    if (s.contains('SHV-500') ||
        s.contains('500') ||
        sz.contains('500') ||
        nm.contains('500')) {
      return 'assets/images/products/shv_500.jpg';
    }

    // 250ml Bottle
    if (s.contains('SHV-250') ||
        s.contains('250') ||
        sz.contains('250') ||
        nm.contains('250')) {
      return 'assets/images/products/shv_250.jpg';
    }

    // 200ml Bottle
    if (s.contains('SHV-200') ||
        s.contains('200') ||
        sz.contains('200') ||
        nm.contains('200')) {
      return 'assets/images/products/shv_200.jpg';
    }

    return 'assets/images/products/shv_500.jpg';
  }

  String get assetFallbackImage => resolveAssetFallback(
        sku: sku,
        name: name,
        size: size,
        category: category,
      );

  String get displayImageUrl {
    if (image.isEmpty) return '';
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return image;
    }
    final base = AppConstants.apiBaseUrl.endsWith('/')
        ? AppConstants.apiBaseUrl.substring(0, AppConstants.apiBaseUrl.length - 1)
        : AppConstants.apiBaseUrl;
    final path = image.startsWith('/') ? image : '/$image';
    return '$base$path';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}