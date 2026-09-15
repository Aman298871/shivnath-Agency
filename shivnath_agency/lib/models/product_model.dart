class ProductModel {
  final String id;
  final String name;
  final String category;
  final String size;
  final double price;
  final String unit;
  final String image;
  final int stock;
  final String description;

  const ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.size,
    required this.price,
    required this.unit,
    required this.image,
    required this.stock,
    required this.description,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json["id"]?.toString() ?? "",
      name: json["name"]?.toString() ?? "",
      category: json["category"]?.toString() ?? "Water",
      size: json["size"]?.toString() ?? "",
      price: double.tryParse(json["price"]?.toString() ?? "0") ?? 0.0,
      unit: json["unit"]?.toString() ?? json["size"]?.toString() ?? "Bottle",
      image: json["image"]?.toString() ?? "",
      stock: int.tryParse(json["stock"]?.toString() ?? "0") ?? 0,
      description: json["description"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "category": category,
      "size": size,
      "price": price,
      "unit": unit,
      "image": image,
      "stock": stock,
      "description": description,
    };
  }
}