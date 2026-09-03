Future<void> placeOrder() async {
  final user = currentUser;

  if (user == null) {
    await goToLogin();
    return;
  }

  if (placingOrder) {
    return;
  }

  if (!validateAddress()) {
    return;
  }

  final cartItems = CartController.items;

  if (cartItems.isEmpty) {
    showMessage('Your cart is empty.');
    return;
  }

  setState(() {
    placingOrder = true;
  });

  try {
    // ========================================================
    // SAVE CUSTOMER + ADDRESS
    // ========================================================

    await saveCustomerDetails(user.uid);

    CustomerAddress selectedAddress;

    if (selectedAddressId != null &&
        savedAddresses.any(
          (a) => a.addressId == selectedAddressId,
        )) {
      selectedAddress = savedAddresses.firstWhere(
        (a) => a.addressId == selectedAddressId,
      );
    } else {
      selectedAddress = _addressFromForm(
        addressId: createAddressId(),
        isDefault: true,
      );
    }

    // ========================================================
    // VENDOR MAPPING
    // ========================================================

    String getVendorUid(dynamic product) {
      try {
        final value = product.vendorUid;

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      } catch (_) {}

      try {
        final value = product.vendorId;

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      } catch (_) {}

      return '';
    }

    String getVendorName(dynamic product) {
      try {
        final value = product.vendorName;

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      } catch (_) {}

      try {
        final value = product.vendor;

        if (value != null &&
            value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      } catch (_) {}

      return '';
    }

    // ========================================================
    // CREATE ORDER ITEMS
    // ========================================================

    double total = 0;

    final List<Map<String, dynamic>> items = [];

    final Set<String> vendorUidSet = {};
    final Set<String> vendorNameSet = {};

    for (final cartItem in cartItems) {
      final dynamic product = cartItem.product;

      final int quantity = cartItem.quantity;
      final double price = cartItem.numericPrice;
      final double itemTotal = price * quantity;

      total += itemTotal;

      final String vendorUid = getVendorUid(product);
      final String vendorName = getVendorName(product);

      if (vendorUid.isNotEmpty) {
        vendorUidSet.add(vendorUid);
      }

      if (vendorName.isNotEmpty) {
        vendorNameSet.add(vendorName);
      }

      // ======================================================
      // ORDER ITEM
      // ======================================================

      items.add({
        'productId': product.id,

        'name': product.name,

        'category': product.category,

        'price': price,

        'quantity': quantity,

        'total': itemTotal,

        'imageUrl': product.imageUrl,

        // ====================================================
        // VENDOR INFORMATION
        // ====================================================

        'vendorUid': vendorUid.isNotEmpty
            ? vendorUid
            : null,

        'vendorName': vendorName.isNotEmpty
            ? vendorName
            : null,
      });
    }

    // ========================================================
    // VENDOR LIST
    // ========================================================

    final List<String> vendorUids =
        vendorUidSet.toList();

    final List<String> vendorNames =
        vendorNameSet.toList();

    // ========================================================
    // SINGLE / MULTI VENDOR
    // ========================================================

    final bool isMultiVendor =
        vendorUids.length > 1;

    String? primaryVendorUid;
    String? primaryVendorName;

    if (vendorUids.length == 1) {
      primaryVendorUid = vendorUids.first;
    }

    if (vendorNames.length == 1) {
      primaryVendorName = vendorNames.first;
    }

    // ========================================================
    // CREATE ORDER REFERENCE
    // ========================================================

    final orderRef = FirebaseFirestore.instance
        .collection('orders')
        .doc();

    // ========================================================
    // ORDER DATA
    // ========================================================

    final Map<String, dynamic> orderData = {
      // ======================================================
      // ORDER ID
      // ======================================================

      'orderId': orderRef.id,

      // ======================================================
      // CUSTOMER
      // ======================================================

      'userId': user.uid,

      'customerName':
          nameController.text.trim(),

      'customerMobile':
          cleanPhoneNumber(
        mobileController.text.trim(),
      ),

      'customerEmail':
          emailController.text.trim(),

      // ======================================================
      // DELIVERY ADDRESS SNAPSHOT
      // ======================================================

      'deliveryAddress':
          selectedAddress.toMap(),

      'address':
          selectedAddress.fullAddress,

      'city':
          selectedAddress.city,

      'state':
          selectedAddress.state,

      'pincode':
          selectedAddress.pincode,

      // ======================================================
      // ORDER ITEMS
      // ======================================================

      'items': items,

      'totalAmount': total,

      // ======================================================
      // VENDOR MAPPING
      // ======================================================

      // Single vendor:
      // vendorUid contains the vendor UID.
      //
      // Multi vendor:
      // vendorUid remains null and vendorUids contains
      // all participating vendors.

      'vendorUid': primaryVendorUid,

      'vendorName': primaryVendorName,

      'vendorUids': vendorUids,

      'vendorNames': vendorNames,

      'isMultiVendor': isMultiVendor,

      'vendorCount': vendorUids.length,

      // ======================================================
      // PAYMENT
      // ======================================================

      'paymentMethod': 'COD',

      'paymentStatus': 'Pending',

      // ======================================================
      // ORDER STATUS
      // ======================================================

      'orderStatus': 'Placed',

      // ======================================================
      // STATUS HISTORY
      // ======================================================

      'statusHistory': [
        {
          'status': 'Placed',
          'timestamp': Timestamp.now(),
          'updatedBy': 'Customer',
        },
      ],

      // ======================================================
      // STATUS TIMESTAMPS
      // ======================================================

      'placedAt':
          FieldValue.serverTimestamp(),

      'confirmedAt': null,

      'processingAt': null,

      'packedAt': null,

      'shippedAt': null,

      'courierPickedAt': null,

      'outForDeliveryAt': null,

      'deliveredAt': null,

      'cancelledAt': null,

      // ======================================================
      // CANCELLATION
      // ======================================================

      'cancelled': false,

      'cancellationReason': null,

      // ======================================================
      // CUSTOMER LOCATION
      // ======================================================

      'latitude': latitude,

      'longitude': longitude,

      // ======================================================
      // GIFT ORDER
      // ======================================================

      'isGift': isGift,

      'giftDetails': isGift
          ? {
              'name':
                  giftNameController.text.trim(),

              'mobile':
                  cleanPhoneNumber(
                giftMobileController.text.trim(),
              ),

              'address':
                  giftAddressController.text.trim(),

              'city':
                  giftCityController.text.trim(),

              'pincode':
                  giftPincodeController.text.trim(),
            }
          : null,

      // ======================================================
      // COURIER
      // ======================================================

      'courierId': null,

      'courierName': null,

      'courierMobile': null,

      'courierAssignedAt': null,

      'courierPickedAt': null,

      // ======================================================
      // LIVE TRACKING
      // ======================================================

      'trackingEnabled': false,

      'trackingStatus': 'Not Started',

      'courierLatitude': null,

      'courierLongitude': null,

      'lastLocationUpdate': null,

      // ======================================================
      // CREATED / UPDATED
      // ======================================================

      'createdAt':
          FieldValue.serverTimestamp(),

      'updatedAt':
          FieldValue.serverTimestamp(),
    };

    // ========================================================
    // SAVE ORDER TO FIRESTORE
    // ========================================================

    await orderRef.set(orderData);

    // ========================================================
    // CLEAR CART
    // ========================================================

    await CartController.clear();

    if (!mounted) {
      return;
    }

    // ========================================================
    // SUCCESS MESSAGE
    // ========================================================

    showMessage(
      'Order placed successfully.',
    );

    // ========================================================
    // OPEN MY ORDERS
    // ========================================================

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const OrdersPage(),
      ),
    );
  } catch (e) {
    if (mounted) {
      showMessage(
        'Could not place order. Please try again.',
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        placingOrder = false;
      });
    }
  }
}
