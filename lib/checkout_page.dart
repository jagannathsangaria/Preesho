Future<void> placeOrder() async {
  final user = currentUser;

  // ============================================================
  // LOGIN CHECK
  // ============================================================

  if (user == null) {
    await goToLogin();
    return;
  }

  // ============================================================
  // DUPLICATE ORDER PREVENTION
  // ============================================================

  if (placingOrder) {
    return;
  }

  // ============================================================
  // ADDRESS VALIDATION
  // ============================================================

  if (!validateAddress()) {
    return;
  }

  // ============================================================
  // CART CHECK
  // ============================================================

  final cartItems = CartController.items;

  if (cartItems.isEmpty) {
    showMessage('Your cart is empty.');
    return;
  }

  setState(() {
    placingOrder = true;
  });

  try {
    // ==========================================================
    // SAVE CUSTOMER DETAILS
    // ==========================================================

    await saveCustomerDetails(user.uid);

    // ==========================================================
    // SELECT ADDRESS
    // ==========================================================

    CustomerAddress selectedAddress;

    final hasSelectedSavedAddress =
        selectedAddressId != null &&
        savedAddresses.any(
          (address) =>
              address.addressId ==
              selectedAddressId,
        );

    if (hasSelectedSavedAddress) {
      selectedAddress =
          savedAddresses.firstWhere(
        (address) =>
            address.addressId ==
            selectedAddressId,
      );
    } else {
      selectedAddress = _addressFromForm(
        addressId: createAddressId(),
        isDefault: true,
      );
    }

    // ==========================================================
    // VENDOR HELPERS
    // ==========================================================

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

    // ==========================================================
    // BUILD ORDER ITEMS
    // ==========================================================

    double total = 0;

    final List<Map<String, dynamic>> items = [];

    final Set<String> vendorUidSet = {};
    final Set<String> vendorNameSet = {};

    for (final cartItem in cartItems) {
      final dynamic product =
          cartItem.product;

      final int quantity =
          cartItem.quantity;

      final double price =
          cartItem.numericPrice;

      final double itemTotal =
          price * quantity;

      total += itemTotal;

      final String vendorUid =
          getVendorUid(product);

      final String vendorName =
          getVendorName(product);

      if (vendorUid.isNotEmpty) {
        vendorUidSet.add(
          vendorUid,
        );
      }

      if (vendorName.isNotEmpty) {
        vendorNameSet.add(
          vendorName,
        );
      }

      items.add({
        // Product
        'productId':
            product.id,

        'name':
            product.name,

        'category':
            product.category,

        // Pricing
        'price':
            price,

        'quantity':
            quantity,

        'total':
            itemTotal,

        // Image
        'imageUrl':
            product.imageUrl,

        // Vendor
        'vendorUid':
            vendorUid.isNotEmpty
                ? vendorUid
                : null,

        'vendorName':
            vendorName.isNotEmpty
                ? vendorName
                : null,
      });
    }

    // ==========================================================
    // VENDOR INFORMATION
    // ==========================================================

    final List<String> vendorUids =
        vendorUidSet.toList();

    final List<String> vendorNames =
        vendorNameSet.toList();

    final bool isMultiVendor =
        vendorUids.length > 1;

    String? primaryVendorUid;

    String? primaryVendorName;

    if (vendorUids.length == 1) {
      primaryVendorUid =
          vendorUids.first;
    }

    if (vendorNames.length == 1) {
      primaryVendorName =
          vendorNames.first;
    }

    // ==========================================================
    // CREATE FIRESTORE ORDER REFERENCE
    // ==========================================================

    final FirebaseFirestore db =
        FirebaseFirestore.instance;

    final orderRef =
        db.collection('orders').doc();

    // ==========================================================
    // ORDER DATA
    // ==========================================================

    final Map<String, dynamic> orderData = {
      // --------------------------------------------------------
      // ORDER IDENTIFICATION
      // --------------------------------------------------------

      'orderId':
          orderRef.id,

      // --------------------------------------------------------
      // CUSTOMER
      // --------------------------------------------------------

      'userId':
          user.uid,

      'customerName':
          nameController.text.trim(),

      'customerMobile':
          cleanPhoneNumber(
        mobileController.text.trim(),
      ),

      'customerEmail':
          emailController.text.trim(),

      // --------------------------------------------------------
      // DELIVERY ADDRESS SNAPSHOT
      // --------------------------------------------------------

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

      // --------------------------------------------------------
      // ORDER ITEMS
      // --------------------------------------------------------

      'items':
          items,

      'itemCount':
          cartItems.fold<int>(
        0,
        (sum, item) =>
            sum + item.quantity,
      ),

      // --------------------------------------------------------
      // TOTAL
      // --------------------------------------------------------

      'totalAmount':
          total,

      // Also save total for compatibility
      // with existing ActiveOrderTracking.

      'total':
          total,

      // --------------------------------------------------------
      // VENDOR
      // --------------------------------------------------------

      'vendorUid':
          primaryVendorUid,

      'vendorName':
          primaryVendorName,

      'vendorUids':
          vendorUids,

      'vendorNames':
          vendorNames,

      'isMultiVendor':
          isMultiVendor,

      'vendorCount':
          vendorUids.length,

      // --------------------------------------------------------
      // PAYMENT
      // --------------------------------------------------------

      'paymentMethod':
          'COD',

      'paymentStatus':
          'Pending',

      // --------------------------------------------------------
      // ORDER STATUS
      // --------------------------------------------------------

      'orderStatus':
          'Placed',

      // Compatibility with older code
      'status':
          'Placed',

      // --------------------------------------------------------
      // STATUS HISTORY
      // --------------------------------------------------------

      'statusHistory': [
        {
          'status':
              'Placed',

          'timestamp':
              Timestamp.now(),

          'updatedBy':
              'Customer',

          'updatedByUid':
              user.uid,
        },
      ],

      // --------------------------------------------------------
      // STATUS TIMESTAMPS
      // --------------------------------------------------------

      'placedAt':
          FieldValue.serverTimestamp(),

      'confirmedAt':
          null,

      'processingAt':
          null,

      'packedAt':
          null,

      'shippedAt':
          null,

      'courierPickedAt':
          null,

      'outForDeliveryAt':
          null,

      'deliveredAt':
          null,

      'cancelledAt':
          null,

      // --------------------------------------------------------
      // CANCELLATION
      // --------------------------------------------------------

      'cancelled':
          false,

      'cancellationReason':
          null,

      'cancelledBy':
          null,

      'cancelledByUid':
          null,

      // --------------------------------------------------------
      // CUSTOMER LOCATION
      // --------------------------------------------------------

      'latitude':
          latitude,

      'longitude':
          longitude,

      // --------------------------------------------------------
      // GIFT ORDER
      // --------------------------------------------------------

      'isGift':
          isGift,

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

      // --------------------------------------------------------
      // COURIER
      // --------------------------------------------------------

      'courierId':
          null,

      'courierName':
          null,

      'courierMobile':
          null,

      'courierPartner':
          null,

      'courierPersonName':
          null,

      'courierPhone':
          null,

      'courierAssignedAt':
          null,

      // --------------------------------------------------------
      // TRACKING
      // --------------------------------------------------------

      'trackingNumber':
          null,

      'trackingUrl':
          null,

      'trackingEnabled':
          false,

      'trackingStatus':
          'Not Started',

      'courierLatitude':
          null,

      'courierLongitude':
          null,

      'lastLocationUpdate':
          null,

      // --------------------------------------------------------
      // CREATED / UPDATED
      // --------------------------------------------------------

      'createdAt':
          FieldValue.serverTimestamp(),

      'updatedAt':
          FieldValue.serverTimestamp(),
    };

    // ==========================================================
    // SAVE ORDER
    // ==========================================================

    await orderRef.set(
      orderData,
    );

    // ==========================================================
    // CLEAR CART ONLY AFTER SUCCESSFUL ORDER CREATION
    // ==========================================================

    await CartController.clear();

    if (!mounted) {
      return;
    }

    // ==========================================================
    // SUCCESS
    // ==========================================================

    showMessage(
      'Order placed successfully.',
    );

    // ==========================================================
    // OPEN ORDERS PAGE
    // ==========================================================

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const OrdersPage(),
      ),
    );
  } catch (e) {
    if (mounted) {
      showMessage(
        'Could not place order. Please try again.',
      );
    }

    debugPrint(
      'PLACE ORDER ERROR: $e',
    );
  } finally {
    if (mounted) {
      setState(() {
        placingOrder = false;
      });
    }
  }
}
