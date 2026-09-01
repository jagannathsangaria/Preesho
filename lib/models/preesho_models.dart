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
      addressId: _stringValue(
        map['addressId'],
      ),
      name: _stringValue(
        map['name'],
      ),
      phone: _stringValue(
        map['phone'] ??
            map['mobile'],
      ),
      house: _stringValue(
        map['house'],
      ),
      street: _stringValue(
        map['street'] ??
            map['address'],
      ),
      city: _stringValue(
        map['city'],
      ),
      state: _stringValue(
        map['state'],
        fallback: 'Rajasthan',
      ),
      pincode: _stringValue(
        map['pincode'] ??
            map['pin'],
      ),
      landmark: _stringValue(
        map['landmark'],
      ),
      isDefault:
          map['isDefault'] == true,
    );
  }

  // ============================================================
  // SAFE STRING CONVERSION
  // ============================================================

  static String _stringValue(
    dynamic value, {
    String fallback = '',
  }) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty
        ? fallback
        : result;
  }

  // ============================================================
  // MODEL → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'addressId': addressId.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'house': house.trim(),
      'street': street.trim(),
      'city': city.trim(),
      'state': state.trim().isEmpty
          ? 'Rajasthan'
          : state.trim(),
      'pincode': pincode.trim(),
      'landmark': landmark.trim(),
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
