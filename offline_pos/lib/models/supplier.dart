class Supplier {
  final int? id;
  final String name;
  final String? contactInfo;

  Supplier({
    this.id,
    required this.name,
    this.contactInfo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact_info': contactInfo,
    };
  }
}