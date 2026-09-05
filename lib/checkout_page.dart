import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'orders_page.dart';
import 'preesho_models.dart';
import 'cart/cart_controller.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();

  final houseController = TextEditingController();
  final streetController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController(text: 'Rajasthan');
  final pincodeController = TextEditingController();
  final landmarkController = TextEditingController();

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  List<CustomerAddress> savedAddresses = [];

  String? selectedAddressId;

  bool loading = true;
  bool placingOrder = false;
  bool isGift = false;

  double? latitude;
  double? longitude;

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();

    houseController.dispose();
    streetController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    landmarkController.dispose();

    giftNameController.dispose();
    giftMobileController.dispose();
    giftAddressController.dispose();
    giftCityController.dispose();
    giftPincodeController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD CUSTOMER + ADDRESSES
  // ============================================================

  Future<void> _loadCheckoutData() async {
    final user = currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    try {
      final userDoc =
          await _db.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        nameController.text =
            (data['name'] ?? data['displayName'] ?? '').toString();

        mobileController.text =
            (data['mobile'] ??
                    data['phoneNumber'] ??
                    data['phone'] ??
                    '')
                .toString();

        emailController.text =
            (data['email'] ?? user.email ?? '').toString();
      } else {
        emailController.text = user.email ?? '';
        nameController.text = user.displayName ?? '';
      }

      await _loadSavedAddresses(user.uid);
    } catch (e) {
      debugPrint('CHECKOUT LOAD ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadSavedAddresses(String uid) async {
    try {
      final snapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('addresses')
          .get();

      final List<CustomerAddress> addresses = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        addresses.add(
          CustomerAddress.fromMap({
            ...data,
            'addressId':
                data['addressId'] ?? doc.id,
          }),
        );
      }

      addresses.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return 0;
      });

      if (!mounted) return;

      setState(() {
        savedAddresses = addresses;

        if (addresses.isNotEmpty) {
          final defaultAddress = addresses.firstWhere(
            (address) => address.isDefault,
            orElse: () => addresses.first,
          );

          selectedAddressId = defaultAddress.addressId;
        }
      });

      if (addresses.isNotEmpty) {
        _fillAddressForm(addresses.first);
      }
    } catch (e) {
      debugPrint('LOAD ADDRESSES ERROR: $e');
    }
  }

  // ============================================================
  // SELECT SAVED ADDRESS
  // ============================================================

  void _selectAddress(CustomerAddress address) {
    setState(() {
      selectedAddressId = address.addressId;
    });

    _fillAddressForm(address);
  }

  void _fillAddressForm(CustomerAddress address) {
    nameController.text = address.name;
    mobileController.text = address.phone;

    houseController.text = address.house;
    streetController.text = address.street;
    cityController.text = address.city;
    stateController.text = address.state;
    pincodeController.text = address.pincode;
    landmarkController.text = address.landmark;
  }

  // ============================================================
  // ADDRESS FROM FORM
  // ============================================================

  CustomerAddress _addressFromForm({
    required String addressId,
    bool isDefault = false,
  }) {
    return CustomerAddress(
      addressId: addressId,
      name: nameController.text.trim(),
      phone: cleanPhoneNumber(
        mobileController.text.trim(),
      ),
      house: houseController.text.trim(),
      street: streetController.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim().isEmpty
          ? 'Rajasthan'
          : stateController.text.trim(),
      pincode: pincodeController.text.trim(),
      landmark: landmarkController.text.trim(),
      isDefault: isDefault,
    );
  }

  // ============================================================
  // ADDRESS ID
  // ============================================================

  String createAddressId() {
    return _db
        .collection('users')
        .doc(currentUser?.uid)
        .collection('addresses')
        .doc()
        .id;
  }

  // ============================================================
  // PHONE CLEAN
  // ============================================================

  String cleanPhoneNumber(String value) {
    String phone = value.trim();

    phone = phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    if (phone.startsWith('+91')) {
      phone = phone.substring(3);
    }

    if (phone.startsWith('91') && phone.length == 12) {
      phone = phone.substring(2);
    }

    return phone;
  }

  // ============================================================
  // SAVE CUSTOMER DETAILS
  // ============================================================

  Future<void> saveCustomerDetails(String uid) async {
    final phone = cleanPhoneNumber(
      mobileController.text.trim(),
    );

    await _db.collection('users').doc(uid).set(
      {
        'uid': uid,
        'name': nameController.text.trim(),
        'mobile': phone,
        'phoneNumber': phone,
        'email': emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // SAVE ADDRESS
  // ============================================================

  Future<void> _saveAddress(
    CustomerAddress address,
  ) async {
    final user = currentUser;

    if (user == null) return;

    try {
      await _db
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc(address.addressId)
          .set(
            address.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('SAVE ADDRESS ERROR: $e');
    }
  }

  // ============================================================
  // ADDRESS VALIDATION
  // ============================================================

  bool validateAddress() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (nameController.text.trim().isEmpty) {
      showMessage('Please enter your name.');
      return false;
    }

    if (cleanPhoneNumber(
          mobileController.text.trim(),
        ).length !=
        10) {
      showMessage('Please enter a valid 10 digit mobile number.');
      return false;
    }

    if (houseController.text.trim().isEmpty) {
      showMessage('Please enter house / flat details.');
      return false;
    }

    if (streetController.text.trim().isEmpty) {
      showMessage('Please enter street / area.');
      return false;
    }

    if (cityController.text.trim().isEmpty) {
      showMessage('Please enter city.');
      return false;
    }

    if (pincodeController.text.trim().length != 6) {
      showMessage('Please enter a valid 6 digit pincode.');
      return false;
    }

    if (isGift) {
      if (giftNameController.text.trim().isEmpty ||
          giftMobileController.text.trim().isEmpty ||
          giftAddressController.text.trim().isEmpty ||
          giftCityController.text.trim().isEmpty ||
          giftPincodeController.text.trim().length != 6) {
        showMessage(
          'Please complete gift delivery details.',
        );
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> goToLogin() async {
    if (!mounted) return;

    final result = await Navigator.pushNamed(
      context,
      '/login',
    );

    if (result == true && mounted) {
      await _loadCheckoutData();
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> placeOrder() async {
    final user = currentUser;

    // LOGIN CHECK
    if (user == null) {
      await goToLogin();
      return;
    }

    // DUPLICATE ORDER PREVENTION
    if (placingOrder) {
      return;
    }

    // ADDRESS VALIDATION
    if (!validateAddress()) {
      return;
    }

    // CART CHECK
    final cartItems = CartController.items;

    if (cartItems.isEmpty) {
      showMessage('Your cart is empty.');
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      // SAVE CUSTOMER
      await saveCustomerDetails(user.uid);

      // SELECT ADDRESS
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

        await _saveAddress(selectedAddress);
      }

      // ========================================================
      // VENDOR HELPERS
      // ========================================================

      String getVendorUid(dynamic product) {
        return product.vendorUid?.trim() ?? '';
      }

      String getVendorName(dynamic product) {
        return product.vendorName?.trim() ?? '';
      }

      // ========================================================
      // BUILD ORDER ITEMS
      // ========================================================

      double total = 0;

      final List<Map<String, dynamic>> items = [];

      final Set<String> vendorUidSet = {};
      final Set<String> vendorNameSet = {};

      for (final cartItem in cartItems) {
        final dynamic product = cartItem.product;

        final int quantity = cartItem.quantity;

        final double price = cartItem.numericPrice;

        if (quantity <= 0) {
          continue;
        }

        if (price <= 0) {
          throw Exception(
            'Invalid product price for ${product.name}',
          );
        }

        final double itemTotal =
            price * quantity;

        total += itemTotal;

        final String vendorUid =
            getVendorUid(product);

        final String vendorName =
            getVendorName(product);

        if (vendorUid.isNotEmpty) {
          vendorUidSet.add(vendorUid);
        }

        if (vendorName.isNotEmpty) {
          vendorNameSet.add(vendorName);
        }

        items.add({
          'productId': product.id,
          'name': product.name,
          'category': product.category,
          'price': price,
          'quantity': quantity,
          'total': itemTotal,
          'imageUrl': product.imageUrl,
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

      if (items.isEmpty || total <= 0) {
        showMessage('Your cart contains invalid products.');
        return;
      }

      // ========================================================
      // VENDOR INFORMATION
      // ========================================================

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

      // ========================================================
      // CREATE ORDER
      // ========================================================

      final orderRef =
          _db.collection('orders').doc();

      final Map<String, dynamic> orderData = {
        // ORDER
        'orderId': orderRef.id,

        // CUSTOMER
        'userId': user.uid,

        'customerName':
            nameController.text.trim(),

        'customerMobile':
            cleanPhoneNumber(
          mobileController.text.trim(),
        ),

        'customerEmail':
            emailController.text.trim(),

        // ADDRESS
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

        // ITEMS
        'items': items,

        'itemCount':
            cartItems.fold<int>(
          0,
          (sum, item) =>
              sum + item.quantity,
        ),

        // TOTAL
        'totalAmount': total,

        'total': total,

        // VENDOR
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

        // PAYMENT
        'paymentMethod': 'COD',

        'paymentStatus': 'Pending',

        // STATUS
        'orderStatus': 'Placed',

        'status': 'Placed',

        // HISTORY
        'statusHistory': [
          {
            'status': 'Placed',
            'timestamp': Timestamp.now(),
            'updatedBy': 'Customer',
            'updatedByUid': user.uid,
          },
        ],

        // TIMESTAMPS
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

        // CANCELLATION
        'cancelled': false,

        'cancellationReason': null,

        'cancelledBy': null,

        'cancelledByUid': null,

        // LOCATION
        'latitude': latitude,

        'longitude': longitude,

        // GIFT
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

        // COURIER
        'courierId': null,

        'courierName': null,

        'courierMobile': null,

        'courierPartner': null,

        'courierPersonName': null,

        'courierPhone': null,

        'courierAssignedAt': null,

        // TRACKING
        'trackingNumber': null,

        'trackingUrl': null,

        'trackingEnabled': false,

        'trackingStatus': 'Not Started',

        'courierLatitude': null,

        'courierLongitude': null,

        'lastLocationUpdate': null,

        // CREATED
        'createdAt':
            FieldValue.serverTimestamp(),

        'updatedAt':
            FieldValue.serverTimestamp(),
      };

      // SAVE ORDER
      await orderRef.set(orderData);

      // CLEAR CART
      await CartController.clear();

      if (!mounted) return;

      showMessage(
        'Order placed successfully.',
      );

      // OPEN ORDERS
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const OrdersPage(),
        ),
      );
    } catch (e) {
      debugPrint(
        'PLACE ORDER ERROR: $e',
      );

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

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final cartItems = CartController.items;

    final double total =
        CartController.total;

    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ==================================================
            // ORDER SUMMARY
            // ==================================================

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${cartItems.length} product(s)',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total: ₹${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // CUSTOMER DETAILS
            // ==================================================

            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter your name';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              validator: (value) {
                if (cleanPhoneNumber(
                      value ?? '',
                    ).length !=
                    10) {
                  return 'Enter valid mobile number';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: emailController,
              keyboardType:
                  TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // SAVED ADDRESSES
            // ==================================================

            if (savedAddresses.isNotEmpty) ...[
              const Text(
                'Saved Addresses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...savedAddresses.map(
                (address) {
                  final selected =
                      selectedAddressId ==
                          address.addressId;

                  return Card(
                    child: RadioListTile<String>(
                      value:
                          address.addressId,
                      groupValue:
                          selectedAddressId,
                      onChanged: (_) {
                        _selectAddress(address);
                      },
                      title: Text(
                        address.name,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        address.fullAddress,
                      ),
                      selected: selected,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            // ==================================================
            // DELIVERY ADDRESS
            // ==================================================

            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            TextFormField(
              controller: houseController,
              decoration: const InputDecoration(
                labelText: 'House / Flat',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter house / flat';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: streetController,
              decoration: const InputDecoration(
                labelText: 'Street / Area',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter street / area';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter city';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: stateController,
              decoration: const InputDecoration(
                labelText: 'State',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: pincodeController,
              keyboardType:
                  TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'Pincode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().length != 6) {
                  return 'Enter valid pincode';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: landmarkController,
              decoration: const InputDecoration(
                labelText: 'Landmark (Optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // GIFT ORDER
            // ==================================================

            Card(
              child: SwitchListTile(
                title: const Text(
                  'Send as Gift',
                ),
                subtitle: const Text(
                  'Deliver this order to another person',
                ),
                value: isGift,
                onChanged: (value) {
                  setState(() {
                    isGift = value;
                  });
                },
              ),
            ),

            if (isGift) ...[
              const SizedBox(height: 12),

              const Text(
                'Gift Delivery Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              TextFormField(
                controller: giftNameController,
                decoration: const InputDecoration(
                  labelText: 'Gift Receiver Name',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: giftMobileController,
                keyboardType:
                    TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Gift Receiver Mobile',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: giftAddressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Gift Address',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: giftCityController,
                decoration: const InputDecoration(
                  labelText: 'Gift City',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: giftPincodeController,
                keyboardType:
                    TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Gift Pincode',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ==================================================
            // PAYMENT
            // ==================================================

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.payments,
                ),
                title: const Text(
                  'Cash on Delivery',
                ),
                subtitle: const Text(
                  'Pay when your order is delivered',
                ),
                trailing: const Icon(
                  Icons.check_circle,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // PLACE ORDER BUTTON
            // ==================================================

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed:
                    placingOrder
                        ? null
                        : placeOrder,
                child: placingOrder
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Place Order • ₹${total.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
