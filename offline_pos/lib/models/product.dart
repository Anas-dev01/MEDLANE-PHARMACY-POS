class Product {
  final int? id;
  final String barcode;
  final String name;
  final String category;
  int quantity; // (Ensure this is not 'final' if you update it locally)
  final double priceSingle;
  final double? priceWholesale;
  final String? expiryDate;
  final String? imagePath;
  final int minStock;

  Product({
    this.id,
    required this.barcode,
    required this.name,
    required this.category,
    required this.quantity,
    required this.priceSingle,
    this.priceWholesale,
    this.expiryDate,
    this.imagePath,
    this.minStock = 5,
  });

  // Convert a Product into a Map for SQLite insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'quantity': quantity,
      'price_single': priceSingle,
      'price_wholesale': priceWholesale,
      'expiry_date': expiryDate,
      'image_path': imagePath,
      'min_stock': minStock,
    };
  }

  // Convert a Map from SQLite back into a Product object
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      priceSingle: map['price_single'],
      priceWholesale: map['price_wholesale'],
      expiryDate: map['expiry_date'],
      imagePath: map['image_path'],
      minStock: map['min_stock'] ?? 5,
    );
  }
}