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
  final String packageType;
  final int unitsPerCase;
  final double dealerTransferPrice;
  final double mrp;
  final int gst;
  final bool isPriceInclusiveGst;
  final double cartonPrice;
  final double discountPrice;

  final int? categoryRefId;
  final String? categoryHierarchy;

  double get effectivePrice =>
      (discountPrice > 0 && discountPrice < price) ? discountPrice : price;

  double get calculatedCartonPrice =>
      cartonPrice > 0 ? cartonPrice : (effectivePrice * unitsPerCase);

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
    this.packageType = 'BOTTLE',
    this.unitsPerCase = 1,
    this.dealerTransferPrice = 0.0,
    this.mrp = 0.0,
    this.gst = 18,
    this.isPriceInclusiveGst = true,
    this.cartonPrice = 0.0,
    this.discountPrice = 0.0,
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

    final rawPkgType = json["package_type"]?.toString();
    final parsedSku = json["sku"]?.toString() ?? "";
    final parsedName = json["name"]?.toString() ?? "";
    final parsedSize = json["size"]?.toString() ?? "";
    final parsedCat = parsedCategory.toLowerCase();

    final bool detectedJar = (rawPkgType?.toUpperCase() == 'JAR') ||
        parsedSku.toUpperCase().contains('20L') ||
        parsedSku.toUpperCase().contains('JAR') ||
        parsedSize.toLowerCase().contains('20l') ||
        parsedName.toLowerCase().contains('jar') ||
        parsedCat.contains('jar');

    final String resolvedPkgType = rawPkgType?.toUpperCase() ?? (detectedJar ? 'JAR' : 'BOTTLE');

    int defaultUpc = 1;
    if (!detectedJar) {
      final sLower = parsedSize.toLowerCase();
      final nLower = parsedName.toLowerCase();
      if (sLower.contains('1l') || sLower.contains('1 l') || sLower.contains('1000') || nLower.contains('1 litre') || nLower.contains('1l')) {
        defaultUpc = 12;
      } else {
        defaultUpc = 24;
      }
    }

    final parsedUpc = int.tryParse(json["units_per_case"]?.toString() ?? "") ?? defaultUpc;

    return ProductModel(
      id: json["id"]?.toString() ?? "",
      name: parsedName,
      sku: parsedSku,
      category: parsedCategory,
      categoryRefId: parsedCatRefId,
      categoryHierarchy: json["category_hierarchy"]?.toString(),
      size: parsedSize,
      price: double.tryParse(json["price"]?.toString() ?? "0") ?? 0.0,
      unit: json["unit"]?.toString() ?? json["size"]?.toString() ?? (detectedJar ? "Jar" : "Bottle"),
      image: json["image"]?.toString() ?? "",
      stock: int.tryParse(json["stock"]?.toString() ?? "0") ?? 0,
      description: json["description"]?.toString() ?? "",
      shelfLifeDays: int.tryParse(json["shelf_life_days"]?.toString() ?? "180") ?? 180,
      status: json["status"]?.toString() ?? "Active",
      packageType: resolvedPkgType,
      unitsPerCase: parsedUpc > 0 ? parsedUpc : 1,
      dealerTransferPrice: double.tryParse(json["dealer_transfer_price"]?.toString() ?? "") ??
          (double.tryParse(json["price"]?.toString() ?? "0") ?? 0.0),
      mrp: double.tryParse(json["mrp"]?.toString() ?? "") ??
          (double.tryParse(json["price"]?.toString() ?? "0") ?? 0.0),
      gst: int.tryParse(json["gst"]?.toString() ?? json["gst_rate"]?.toString() ?? "") ?? 18,
      isPriceInclusiveGst: json["is_price_inclusive_gst"] is bool
          ? json["is_price_inclusive_gst"] as bool
          : (json["is_price_inclusive_gst"]?.toString().toLowerCase() != 'false'),
      cartonPrice: double.tryParse(json["carton_price"]?.toString() ?? "") ?? 0.0,
      discountPrice: double.tryParse(json["discount_price"]?.toString() ?? "") ?? 0.0,
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
      "package_type": packageType,
      "units_per_case": unitsPerCase,
      "dealer_transfer_price": dealerTransferPrice,
      "mrp": mrp,
      "gst": gst,
      "is_price_inclusive_gst": isPriceInclusiveGst,
      "carton_price": cartonPrice,
      "discount_price": discountPrice,
      "effective_price": effectivePrice,
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

    // 1L Bottles
    if (s.contains('SHV-1L') ||
        s.contains('1000') ||
        sz.contains('1l') ||
        sz.contains('1 l') ||
        nm.contains('1 litre') ||
        nm.contains('1l')) {
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

  bool get isJar {
    if (packageType.toUpperCase() == 'JAR') return true;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();
    final cat = category.toLowerCase();
    return s.contains('SHV-20L') ||
        s.contains('JAR') ||
        sz.contains('20l') ||
        sz.contains('20 l') ||
        sz.contains('20000') ||
        nm.contains('20 litre') ||
        nm.contains('20l') ||
        nm.contains('jar') ||
        cat.contains('jar');
  }

  bool get isBottle {
    if (isJar) return false;
    if (packageType.toUpperCase() == 'BOTTLE') return true;
    final s = sku.toUpperCase();
    final sz = size.toLowerCase();
    final nm = name.toLowerCase();
    final cat = category.toLowerCase();
    final u = unit.toLowerCase();
    return s.contains('BOT') ||
        s.contains('SHV-') ||
        sz.contains('ml') ||
        sz.contains('1l') ||
        sz.contains('2l') ||
        nm.contains('bottle') ||
        nm.contains('box') ||
        nm.contains('carton') ||
        cat.contains('bottle') ||
        cat.contains('water') ||
        u.contains('bottle') ||
        u.contains('box') ||
        u.contains('case');
  }

  int get minOrderBoxes {
    if (isJar) return 5;
    if (isBottle) return 5;
    return 1;
  }

  int get minOrderQuantity {
    if (isJar) return 5;
    if (isBottle) return 5 * (unitsPerCase > 0 ? unitsPerCase : 24);
    return 1;
  }

  int get stepQuantity {
    if (isBottle) return unitsPerCase > 0 ? unitsPerCase : 24;
    return 1;
  }

  String get moqUnitLabel {
    if (isJar) return 'jars';
    if (isBottle) return 'boxes ($unitsPerCase btls/box)';
    return 'units';
  }

  String get moqDisplayText {
    if (isJar) return 'Min order: 5 water jars';
    if (isBottle) return 'Min order: 5 boxes ($minOrderQuantity bottles)';
    return 'Min order: 1 unit';
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