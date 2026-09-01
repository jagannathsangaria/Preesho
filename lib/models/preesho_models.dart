class CustomerAddress {
  final String addressId;
  final String name;
  final String phone;
  final String house;
  final String street;
  final String city;
  final String state;
  final String pincode;
  final String landmark;
  final bool isDefault;

  const CustomerAddress({
    required this.addressId,
    required this.name,
    required this.phone,
    this.house = '',
    required this.street,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark = '',
    this.isDefault = false,
  });

  // ============================================================
  // COMPLETE ADDRESS
  // ============================================================

  String get fullAddress {
    final parts = <String>[];

    if (house.trim().isNotEmpty) {
      parts.add(house.trim());
    }

    if (street.trim().isNotEmpty) {
      parts.add(street.trim());
    }

    if (landmark.trim().isNotEmpty) {
      parts.add('Near ${landmark.trim()}');
    }

    if (city.trim().isNotEmpty) {
      parts.add(city.trim());
    }

    if (state.trim().isNotEmpty) {
      parts.add(state.trim());
    }

    if (pincode.trim().isNotEmpty) {
      parts.add(pincode.trim());
    }

    return parts.join(', ');
  }

  // ============================================================
  // FIRESTORE → MODEL
  // ============================================================

  factory CustomerAddress.fromMap(
    Map<String, dynamic> map,
  ) {
    return CustomerAddress(
      addressId:
          (map['addressId'] ?? '').toString(),

      name:
          (map['name'] ?? '').toString(),

      phone:
          (map['phone'] ?? '').toString(),

      house:
          (map['house'] ?? '').toString(),

      street:
          (map['street'] ?? '').toString(),

      city:
          (map['city'] ?? '').toString(),

      state:
          (map['state'] ?? 'Rajasthan').toString(),

      pincode:
          (map['pincode'] ??
                  map['pin'] ??
                  '')
              .toString(),

      landmark:
          (map['landmark'] ?? '').toString(),

      isDefault:
          map['isDefault'] == true,
    );
  }

  // ============================================================
  // MODEL → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'addressId': addressId,
      'name': name,
      'phone': phone,
      'house': house,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'isDefault': isDefault,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  CustomerAddress copyWith({
    String? addressId,
    String? name,
    String? phone,
    String? house,
    String? street,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
    bool? isDefault,
  }) {
    return CustomerAddress(
      addressId:
          addressId ?? this.addressId,
      name:
          name ?? this.name,
      phone:
          phone ?? this.phone,
      house:
          house ?? this.house,
      street:
          street ?? this.street,
      city:
          city ?? this.city,
      state:
          state ?? this.state,
      pincode:
          pincode ?? this.pincode,
      landmark:
          landmark ?? this.landmark,
      isDefault:
          isDefault ?? this.isDefault,
    );
  }
}
