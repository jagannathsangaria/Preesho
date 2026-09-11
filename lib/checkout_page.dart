import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/preesho_models.dart';
import 'orders_page.dart';
import 'cart/cart_controller.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  final houseController = TextEditingController();
  final streetController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController(text: 'Rajasthan');
  final pincodeController = TextEditingController();
  final landmarkController = TextEditingController();

  final giftMessageController = TextEditingController();

  List<CustomerAddress> savedAddresses = [];
  CustomerAddress? selectedAddress;

  bool loading = true;
  bool placingOrder = false;
  bool isGiftOrder = false;

  String paymentMethod = 'COD';

  @override
  void initState() {
    super.initState();
    loadCheckoutData();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    houseController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    landmarkController.dispose();
    giftMessageController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // BACK NAVIGATION
  // ------------------------------------------------------------

  void _goBack() {
    if (placingOrder) return;

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    }
  }

  Future<bool> _handleBack() async {
    if (placingOrder) {
      return false;
    }

    final navigator = Navigator.of(context);

    if (navigator.canPop()) {
      return true;
    }

    navigator.pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );

    return false;
  }

  // ------------------------------------------------------------
  // CHECKOUT DATA
  // ------------------------------------------------------------

  Future<void> loadCheckoutData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => loading = false);
        }
        return;
      }

      await CartController.initialize();

      emailController.text = user.email ?? '';

      await loadSavedAddresses();

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);

        _showSnackBar(
          'Checkout load nahi ho paya: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> loadSavedAddresses() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      // Address is stored in the user's main document. This is important
      // because the current Firestore rules allow the customer to update
      // address/pinCode on /users/{uid}, while a nested /addresses write
      // can otherwise be rejected with permission-denied.
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return;

      final data = userDoc.data() ?? <String, dynamic>{};

      final rootAddress = (data['address'] ?? '').toString().trim();
      final rootPinCode = (data['pinCode'] ?? data['pincode'] ?? '')
          .toString()
          .trim();
      final rootName = (data['name'] ?? '').toString().trim();
      final rootPhone = (data['phone'] ?? data['mobile'] ?? '')
          .toString()
          .trim();

      // First support the newer root `addresses` list if it already exists.
      final addressesValue = data['addresses'];
      List<CustomerAddress> addresses = [];

      if (addressesValue is List) {
        addresses = addressesValue
            .whereType<Map>()
            .map((item) => CustomerAddress.fromMap(
                  Map<String, dynamic>.from(item),
                ))
            .where((a) => [a.house, a.street, a.city, a.state, a.pincode, a.landmark]
                .any((value) => value.trim().isNotEmpty))
            .toList();
      }

      addresses.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return 0;
      });

      if (mounted) {
        setState(() {
          savedAddresses = addresses;
          selectedAddress = addresses.isNotEmpty ? addresses.first : null;
        });

        if (addresses.isNotEmpty) {
          fillAddressFromModel(addresses.first);
        } else {
          nameController.text = rootName;
          phoneController.text = rootPhone;
          if (rootAddress.isNotEmpty) {
            streetController.text = rootAddress;
          }
          if (rootPinCode.isNotEmpty) {
            pincodeController.text = rootPinCode;
          }
        }
      }
    } catch (e) {
      debugPrint('Load addresses error: $e');
    }
  }

  void fillAddressFromModel(CustomerAddress address) {
    nameController.text = address.name;
    phoneController.text = address.phone;
    houseController.text = address.house;
    streetController.text = address.street;
    cityController.text = address.city;
    stateController.text =
        address.state.isEmpty ? 'Rajasthan' : address.state;
    pincodeController.text = address.pincode;
    landmarkController.text = address.landmark;
  }

  void useNewAddress() {
    setState(() {
      selectedAddress = null;
    });

    nameController.clear();
    phoneController.clear();
    houseController.clear();
    streetController.clear();
    cityController.clear();
    stateController.text = 'Rajasthan';
    pincodeController.clear();
    landmarkController.clear();
  }

  String _buildCustomerAddress() {
    return [
      houseController.text.trim(),
      streetController.text.trim(),
      cityController.text.trim(),
      stateController.text.trim(),
      pincodeController.text.trim(),
      if (landmarkController.text.trim().isNotEmpty)
        landmarkController.text.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
  }

  Future<void> saveCustomerDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final fullAddress = _buildCustomerAddress();

    // Save the complete customer address directly on users/{uid}.
    // This matches the existing customer Firestore rules and also matches
    // main.dart, which reads the legacy `address` + `pinCode` fields.
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'address': fullAddress,
        'pinCode': pincodeController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAddressIfNeeded() async {
    // Address is already saved by saveCustomerDetails().
    // Do not write to users/{uid}/addresses here because that nested
    // collection is not covered by the current customer self-update rule.
    return;
  }

  bool validateAddress() {
    if (nameController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter your full name',
        isError: true,
      );
      return false;
    }

    final phone = phoneController.text.trim();

    if (phone.length < 10) {
      _showSnackBar(
        'Please enter a valid mobile number',
        isError: true,
      );
      return false;
    }

    if (houseController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter House / Flat details',
        isError: true,
      );
      return false;
    }

    if (streetController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter Street / Area',
        isError: true,
      );
      return false;
    }

    if (cityController.text.trim().isEmpty) {
      _showSnackBar(
        'Please enter City',
        isError: true,
      );
      return false;
    }

    final pincode = pincodeController.text.trim();

    if (pincode.length != 6 ||
        int.tryParse(pincode) == null) {
      _showSnackBar(
        'Please enter a valid 6 digit pincode',
        isError: true,
      );
      return false;
    }

    return true;
  }

  // ------------------------------------------------------------
  // ORDER DATA
  // ------------------------------------------------------------

  List<Map<String, dynamic>> buildOrderItems() {
    return CartController.items.map((item) {
      return {
        'productId': item.product.id,
        'id': item.product.id,
        'name': item.product.name,
        'category': item.product.category,
        'price': item.numericPrice,
        'sellingPrice': item.numericPrice,
        'mrp': item.originalPrice,
        'quantity': item.quantity,
        'total': item.totalPrice,
        'imageUrl': item.imageUrl,
        'vendorUid': item.vendorUid,
        'vendorName': item.vendorName,
      };
    }).toList();
  }

  List<String> getVendorUids() {
    final values = <String>{};

    for (final item in CartController.items) {
      final uid = item.vendorUid.trim();

      if (uid.isNotEmpty) {
        values.add(uid);
      }
    }

    return values.toList();
  }

  List<String> getVendorNames() {
    final values = <String>{};

    for (final item in CartController.items) {
      final name = item.vendorName.trim();

      if (name.isNotEmpty) {
        values.add(name);
      }
    }

    return values.toList();
  }

  // ------------------------------------------------------------
  // PLACE ORDER
  // ------------------------------------------------------------

  Future<void> placeOrder() async {
    if (placingOrder) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showSnackBar(
        'Please login before placing order',
        isError: true,
      );
      return;
    }

    await CartController.initialize();

    if (CartController.items.isEmpty) {
      _showSnackBar(
        'Your cart is empty',
        isError: true,
      );
      return;
    }

    if (!validateAddress()) return;

    setState(() {
      placingOrder = true;
    });

    try {
      await CartController.initialize();

      // Stock validation
      for (final item in CartController.items) {
        final availableStock = item.availableStock;

        if (item.quantity > availableStock) {
          throw Exception(
            '${item.name} ke liye sirf $availableStock stock available hai.',
          );
        }

        if (availableStock <= 0) {
          throw Exception(
            '${item.name} abhi out of stock hai.',
          );
        }
      }

      await saveCustomerDetails();
      await saveAddressIfNeeded();

      final orderRef =
          FirebaseFirestore.instance.collection('orders').doc();

      final orderId = orderRef.id;

      final items = buildOrderItems();
      final vendorUids = getVendorUids();
      final vendorNames = getVendorNames();

      final subtotal = CartController.total;
      final originalTotal = CartController.originalTotal;
      final savings = CartController.productSavings;

      final deliveryAddress = _buildCustomerAddress();

      final now = Timestamp.now();

      final orderData = {
        'orderId': orderId,
        'userId': user.uid,
        'customerId': user.uid,
        'customerName': nameController.text.trim(),
        'mobile': phoneController.text.trim(),
        'phone': phoneController.text.trim(),
        'email': emailController.text.trim(),

        'house': houseController.text.trim(),
        'street': streetController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode': pincodeController.text.trim(),
        'landmark': landmarkController.text.trim(),

        'deliveryAddress': deliveryAddress,
        'address': deliveryAddress,

        'items': items,
        'itemCount': CartController.itemCount,
        'totalItems': CartController.itemCount,

        'subtotal': subtotal,
        'total': subtotal,
        'grandTotal': subtotal,
        'totalAmount': subtotal,

        'originalTotal': originalTotal,
        'savings': savings,

        // ------------------------------------------------------
        // COD - KEEP COMPLETE
        // ------------------------------------------------------
        'paymentMethod': 'COD',
        'paymentType': 'Cash on Delivery',
        'paymentStatus': 'Pending',
        'codAmount': subtotal,
        'isCOD': true,

        // ------------------------------------------------------
        // ORDER STATUS
        // ------------------------------------------------------
        'orderStatus': 'Placed',
        'status': 'Placed',

        'statusHistory': [
          {
            'status': 'Placed',
            'timestamp': Timestamp.now(),
          },
        ],

        // ------------------------------------------------------
        // VENDOR
        // ------------------------------------------------------
        'vendorUid':
            vendorUids.length == 1
                ? vendorUids.first
                : null,

        'vendorName':
            vendorNames.length == 1
                ? vendorNames.first
                : null,

        'vendorUids': vendorUids,
        'vendorNames': vendorNames,
        'vendorCount': vendorUids.length,
        'isMultiVendor': vendorUids.length > 1,

        // ------------------------------------------------------
        // GIFT
        // ------------------------------------------------------
        'isGiftOrder': isGiftOrder,

        'giftMessage': isGiftOrder
            ? giftMessageController.text.trim()
            : '',

        // ------------------------------------------------------
        // CANCELLATION
        // ------------------------------------------------------
        'isCancelled': false,
        'cancelledAt': null,
        'cancellationReason': null,

        // ------------------------------------------------------
        // COURIER
        // ------------------------------------------------------
        'courierName': null,
        'trackingId': null,
        'trackingUrl': null,

        'updatedBy': user.uid,
        'updatedByUid': user.uid,

        'createdAt': now,
        'updatedAt': now,
        'placedAt': now,
      };

      await orderRef.set(orderData);

      await CartController.clear();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            contentPadding: const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              20,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color:
                        Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.green,
                    size: 42,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Order Placed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Your order has been successfully placed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 18),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xffF6F6FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Order ID',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        orderId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.payments_rounded,
                            size: 18,
                            color: Colors.green,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Cash on Delivery',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xff5B35D5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'View My Orders',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const OrdersPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Order failed: $e',
          isError: true,
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

  // ------------------------------------------------------------
  // SNACKBAR
  // ------------------------------------------------------------

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              isError
                  ? const Color(0xffD32F2F)
                  : Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
  }

  double get deliveryCharge {
    return 0;
  }

  double get finalTotal {
    return CartController.total + deliveryCharge;
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: _handleBack,
      child: _buildPage(context, user),
    );
  }

  Widget _buildPage(
    BuildContext context,
    User? user,
  ) {
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xffF7F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
            onPressed: _goBack,
          ),
          title: const Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: _loginRequired(),
      );
    }

    if (loading) {
      return Scaffold(
        backgroundColor: const Color(0xffF7F7FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
            onPressed: _goBack,
          ),
          title: const Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF7F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,

        // EXPLICIT BACK BUTTON
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
          onPressed: _goBack,
        ),

        title: const Text(
          'Checkout',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),

      bottomNavigationBar:
          _bottomPlaceOrderBar(),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            125,
          ),
          children: [
            _checkoutProgress(),

            const SizedBox(height: 16),

            _sectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Customer Details',
              subtitle:
                  'Your contact information',
              child: Column(
                children: [
                  _textField(
                    controller: nameController,
                    label: 'Full Name',
                    hint:
                        'Enter your full name',
                    icon:
                        Icons.person_outline_rounded,
                    textInputAction:
                        TextInputAction.next,
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller: phoneController,
                    label: 'Mobile Number',
                    hint:
                        'Enter 10 digit mobile number',
                    icon:
                        Icons.phone_outlined,
                    keyboardType:
                        TextInputType.phone,
                    textInputAction:
                        TextInputAction.next,
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller: emailController,
                    label: 'Email',
                    hint:
                        'Enter email address',
                    icon:
                        Icons.email_outlined,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.done,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _sectionCard(
              icon:
                  Icons.location_on_outlined,
              title: 'Delivery Address',
              subtitle:
                  'Where should we deliver your order?',
              trailing: TextButton.icon(
                onPressed: useNewAddress,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 18,
                ),
                label: const Text(
                  'New Address',
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (savedAddresses.isNotEmpty) ...[
                    const Text(
                      'Saved Addresses',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ...savedAddresses.map(
                      (address) =>
                          _addressCard(address),
                    ),

                    const SizedBox(height: 8),
                  ],

                  _textField(
                    controller: houseController,
                    label: 'House / Flat',
                    hint:
                        'House number, flat, building',
                    icon:
                        Icons.home_outlined,
                    textInputAction:
                        TextInputAction.next,
                  ),

                  const SizedBox(height: 12),

                  _textField(
                    controller: streetController,
                    label: 'Street / Area',
                    hint:
                        'Street, colony, area',
                    icon:
                        Icons.signpost_outlined,
                    textInputAction:
                        TextInputAction.next,
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller:
                              cityController,
                          label: 'City',
                          hint: 'City',
                          icon: Icons
                              .location_city_outlined,
                          textInputAction:
                              TextInputAction.next,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _textField(
                          controller:
                              stateController,
                          label: 'State',
                          hint: 'State',
                          icon:
                              Icons.map_outlined,
                          textInputAction:
                              TextInputAction.next,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _textField(
                          controller:
                              pincodeController,
                          label: 'Pincode',
                          hint:
                              '6 digit pincode',
                          icon:
                              Icons.pin_drop_outlined,
                          keyboardType:
                              TextInputType.number,
                          textInputAction:
                              TextInputAction.next,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _textField(
                          controller:
                              landmarkController,
                          label: 'Landmark',
                          hint: 'Optional',
                          icon:
                              Icons.place_outlined,
                          textInputAction:
                              TextInputAction.done,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _sectionCard(
              icon:
                  Icons.payments_outlined,
              title: 'Payment Method',
              subtitle:
                  'Secure payment option',
              child: _codPaymentCard(),
            ),

            const SizedBox(height: 14),

            _sectionCard(
              icon:
                  Icons.card_giftcard_rounded,
              title: 'Gift Order',
              subtitle:
                  'Send this order as a gift',
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding:
                        EdgeInsets.zero,
                    value: isGiftOrder,
                    onChanged: (value) {
                      setState(() {
                        isGiftOrder = value;
                      });
                    },
                    title: const Text(
                      'This is a gift',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Add a personal message',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),

                  if (isGiftOrder) ...[
                    const SizedBox(height: 8),

                    _textField(
                      controller:
                          giftMessageController,
                      label: 'Gift Message',
                      hint:
                          'Write a message...',
                      icon:
                          Icons.message_outlined,
                      maxLines: 3,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            _orderSummary(),

            const SizedBox(height: 14),

            _trustBanner(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGIN REQUIRED
  // ------------------------------------------------------------

  Widget _loginRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color:
                    const Color(0xff5B35D5)
                        .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                size: 42,
                color:
                    Color(0xff5B35D5),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Please login to continue with checkout.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // PROGRESS
  // ------------------------------------------------------------

  Widget _checkoutProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xff5B35D5),
            Color(0xff7C4DFF),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xff5B35D5)
                    .withValues(alpha: 0.2),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _progressCircle(
            '1',
            'Address',
            active: true,
          ),

          _progressLine(),

          _progressCircle(
            '2',
            'Payment',
            active: true,
          ),

          _progressLine(),

          _progressCircle(
            '3',
            'Place Order',
            active: true,
          ),
        ],
      ),
    );
  }

  Widget _progressCircle(
    String number,
    String label, {
    required bool active,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(
                      alpha: 0.3,
                    ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight:
                      FontWeight.w900,
                  color: active
                      ? const Color(
                          0xff5B35D5,
                        )
                      : Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressLine() {
    return Container(
      width: 20,
      height: 2,
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),
      color:
          Colors.white.withValues(
        alpha: 0.5,
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION CARD
  // ------------------------------------------------------------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.045,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      const Color(
                        0xff5B35D5,
                      ).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xff5B35D5,
                  ),
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 11,
                        color:
                            Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              if (trailing != null)
                trailing,
            ],
          ),

          const SizedBox(height: 16),

          child,
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 21,
        ),
        filled: true,
        fillColor:
            const Color(0xffF7F7FA),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              BorderSide.none,
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(15),
          borderSide:
              const BorderSide(
            color:
                Color(0xff5B35D5),
            width: 1.2,
          ),
        ),
        labelStyle:
            const TextStyle(
          color: Colors.black54,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ADDRESS CARD
  // ------------------------------------------------------------

  Widget _addressCard(
    CustomerAddress address,
  ) {
    final isSelected =
        selectedAddress?.addressId ==
            address.addressId;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAddress = address;
        });

        fillAddressFromModel(address);
      },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 200,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(
                  0xff5B35D5,
                ).withValues(alpha: 0.06)
              : const Color(
                  0xffF7F7FA,
                ),
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(
                    0xff5B35D5,
                  )
                : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              isSelected
                  ? Icons
                      .radio_button_checked_rounded
                  : Icons
                      .radio_button_off_rounded,
              color: isSelected
                  ? const Color(
                      0xff5B35D5,
                    )
                  : Colors.black38,
              size: 22,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.name,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      if (address.isDefault) ...[
                        const SizedBox(
                          width: 7,
                        ),

                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration:
                              BoxDecoration(
                            color: Colors.green
                                .withValues(
                              alpha: 0.1,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child:
                              const Text(
                            'DEFAULT',
                            style:
                                TextStyle(
                              color:
                                  Colors.green,
                              fontSize: 8,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    address.phone,
                    style:
                        const TextStyle(
                      color:
                          Colors.black54,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    [
                      address.house,
                      address.street,
                      address.city,
                      address.state,
                      address.pincode,
                      if (address.landmark
                          .isNotEmpty)
                        address.landmark,
                    ]
                        .where(
                          (e) =>
                              e.trim()
                                  .isNotEmpty,
                        )
                        .join(', '),
                    style:
                        const TextStyle(
                      color:
                          Colors.black87,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // COD PAYMENT
  // ------------------------------------------------------------

  Widget _codPaymentCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          paymentMethod = 'COD';
        });
      },
      child: Container(
        padding:
            const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color:
              Colors.green.withValues(
            alpha: 0.055,
          ),
          borderRadius:
              BorderRadius.circular(17),
          border: Border.all(
            color:
                Colors.green.withValues(
              alpha: 0.3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    Colors.green.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: Colors.green,
                size: 25,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Pay when your order arrives',
                    style: TextStyle(
                      color:
                          Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            Radio<String>(
              value: 'COD',
              groupValue:
                  paymentMethod,
              activeColor:
                  Colors.green,
              onChanged: (value) {
                setState(() {
                  paymentMethod =
                      'COD';
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ORDER SUMMARY
  // ------------------------------------------------------------

  Widget _orderSummary() {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.045,
            ),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color:
                    Color(0xff5B35D5),
              ),
              SizedBox(width: 10),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          ...CartController.items.map(
            (item) =>
                _orderItemRow(item),
          ),

          const Divider(height: 28),

          _summaryRow(
            'Original Total',
            '₹${CartController.originalTotal.toStringAsFixed(0)}',
          ),

          const SizedBox(height: 10),

          _summaryRow(
            'Product Savings',
            '-₹${CartController.productSavings.toStringAsFixed(0)}',
            valueColor:
                Colors.green,
          ),

          const SizedBox(height: 10),

          _summaryRow(
            'Delivery',
            deliveryCharge == 0
                ? 'FREE'
                : '₹${deliveryCharge.toStringAsFixed(0)}',
            valueColor:
                Colors.green,
          ),

          const SizedBox(height: 10),

          _summaryRow(
            'Total Items',
            '${CartController.itemCount}',
          ),

          const Divider(height: 28),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              Text(
                '₹${finalTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xff5B35D5),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color:
                  Colors.green.withValues(
                alpha: 0.07,
              ),
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons
                      .verified_user_outlined,
                  color: Colors.green,
                  size: 20,
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Text(
                    'COD selected • Pay ₹${finalTotal.toStringAsFixed(0)} at delivery',
                    style:
                        const TextStyle(
                      color:
                          Colors.green,
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ORDER ITEM
  // ------------------------------------------------------------

  Widget _orderItemRow(
    CartItem item,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 13,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(12),
            child: Container(
              width: 58,
              height: 58,
              color:
                  const Color(0xffF3F3F6),
              child:
                  item.imageUrl.trim()
                          .isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) {
                            return const Icon(
                              Icons
                                  .image_not_supported_outlined,
                              color:
                                  Colors.black26,
                            );
                          },
                        )
                      : const Icon(
                          Icons
                              .shopping_bag_outlined,
                          color:
                              Colors.black26,
                        ),
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${item.category} • Qty ${item.quantity}',
                  style:
                      const TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUMMARY ROW
  // ------------------------------------------------------------

  Widget _summaryRow(
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
      children: [
        Text(
          title,
          style:
              const TextStyle(
            color: Colors.black54,
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        Text(
          value,
          style: TextStyle(
            color:
                valueColor ??
                    Colors.black87,
            fontSize: 13,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // TRUST BANNER
  // ------------------------------------------------------------

  Widget _trustBanner() {
    return Container(
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.security_rounded,
            color: Colors.green,
            size: 22,
          ),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              'Your order information is securely stored and used only for delivery.',
              style: TextStyle(
                fontSize: 11,
                color:
                    Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BOTTOM PLACE ORDER BAR
  // ------------------------------------------------------------

  Widget _bottomPlaceOrderBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.1,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Payable',
                    style:
                        TextStyle(
                      color:
                          Colors.black54,
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    '₹${finalTotal.toStringAsFixed(0)}',
                    style:
                        const TextStyle(
                      fontSize: 21,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child:
                    ElevatedButton(
                  onPressed:
                      placingOrder
                          ? null
                          : placeOrder,
                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        const Color(
                      0xff5B35D5,
                    ),
                    foregroundColor:
                        Colors.white,
                    disabledBackgroundColor:
                        const Color(
                      0xffB9B1D5,
                    ),
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        17,
                      ),
                    ),
                  ),
                  child: placingOrder
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2.5,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons
                                  .lock_outline_rounded,
                              size: 19,
                            ),
                            SizedBox(
                              width: 7,
                            ),
                            Text(
                              'PLACE ORDER',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .w900,
                                letterSpacing:
                                    0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
