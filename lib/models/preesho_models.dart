// ============================================================
// PRODUCT MODEL
// ============================================================

class Product {
  final String id;
  final String name;
  final String category;
  final dynamic price;
  final int stock;
  final String imageUrl;
  final String description;
  final bool active;
  final dynamic mrp;
  final dynamic discountPercent;

  // ============================================================
  // VENDOR DETAILS
  // ============================================================

  final String? vendorUid;
  final String? vendorName;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.description,
    required this.active,
    this.mrp,
    this.discountPercent,

    // Vendor fields
    this.vendorUid,
    this.vendorName,
  });

  // ============================================================
  // NUMERIC PRICE
  // ============================================================

  double get numericPrice {
    if (price is num) {
      return (price as num).toDouble();
    }

    return double.tryParse(
          price
              .toString()
              .replaceAll(',', '')
              .trim(),
        ) ??
        0.0;
  }

  // ============================================================
  // SELLING PRICE
  // ============================================================

  double get sellingPrice {
    return numericPrice;
  }

  // ============================================================
  // ORIGINAL / MRP PRICE
  // ============================================================

  double get originalPrice {
    if (mrp is num) {
      return (mrp as num).toDouble();
    }

    return double.tryParse(
          mrp
              .toString()
              .replaceAll(',', '')
              .trim(),
        ) ??
        numericPrice;
  }

  // ============================================================
  // DISCOUNT CHECK
  // ============================================================

  bool get hasDiscount {
    return originalPrice > sellingPrice;
  }

  // ============================================================
  // VENDOR UID
  // ============================================================

  String get safeVendorUid {
    return vendorUid?.trim() ?? '';
  }

  // ============================================================
  // VENDOR NAME
  // ============================================================

  String get safeVendorName {
    return vendorName?.trim() ?? '';
  }

  // ============================================================
  // FIRESTORE → PRODUCT
  // ============================================================

  factory Product.fromMap(
    Map<String, dynamic> map,
  ) {
    return Product(
      id: _stringValue(map['id']),
      name: _stringValue(map['name']),
      category: _stringValue(map['category']),
      price: map['price'] ?? 0,
      stock: _toInt(map['stock']),
      imageUrl: _stringValue(
        map['imageUrl'] ?? map['image'],
      ),
      description: _stringValue(
        map['description'],
      ),
      active: map['active'] != false,
      mrp: map['mrp'] ?? map['originalPrice'] ?? 0,
      discountPercent:
          map['discountPercent'] ?? 0,

      vendorUid: _nullableString(
        map['vendorUid'] ??
            map['vendorId'] ??
            map['sellerUid'] ??
            map['sellerId'],
      ),

      vendorName: _nullableString(
        map['vendorName'] ??
            map['vendor'] ??
            map['sellerName'] ??
            map['seller'],
      ),
    );
  }

  // ============================================================
  // PRODUCT → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'id': id.trim(),
      'name': name.trim(),
      'category': category.trim(),
      'price': numericPrice,
      'stock': stock,
      'imageUrl': imageUrl.trim(),
      'description': description.trim(),
      'active': active,
      'mrp': originalPrice,
      'discountPercent': discountPercent,

      'vendorUid': safeVendorUid.isEmpty
          ? null
          : safeVendorUid,

      'vendorName': safeVendorName.isEmpty
          ? null
          : safeVendorName,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Product copyWith({
    String? id,
    String? name,
    String? category,
    dynamic price,
    int? stock,
    String? imageUrl,
    String? description,
    bool? active,
    dynamic mrp,
    dynamic discountPercent,
    String? vendorUid,
    String? vendorName,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      description:
          description ?? this.description,
      active: active ?? this.active,
      mrp: mrp ?? this.mrp,
      discountPercent:
          discountPercent ?? this.discountPercent,
      vendorUid:
          vendorUid ?? this.vendorUid,
      vendorName:
          vendorName ?? this.vendorName,
    );
  }

  // ============================================================
  // SAFE STRING
  // ============================================================

  static String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  // ============================================================
  // NULLABLE STRING
  // ============================================================

  static String? _nullableString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final String result =
        value.toString().trim();

    return result.isEmpty ? null : result;
  }

  // ============================================================
  // SAFE INT
  // ============================================================

  static int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}
