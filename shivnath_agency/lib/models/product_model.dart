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
    return ProductModel(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      sku: json["sku"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "Water",
      categoryRefId: json["category_ref_id"] is int
          ? json["category_ref_id"]
          : int.tryParse(json["category_ref_id"]?.toString() ?? ""),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}