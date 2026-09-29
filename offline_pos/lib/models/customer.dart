class Customer {
  final int? id;
  final String name;
  final String? phone;

  Customer({
    this.id,
    required this.name,
    this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
    };
  }
}