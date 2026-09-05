import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'model/model.dart' show CustomerAddress;
import 'models/preesho_models.dart';
import 'orders_page.dart';
import 'cart/cart_controller.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();

  final houseController = TextEditingController();
  final streetController = TextEditingController();
  final cityController = TextEditingController();
  final stateController =
      TextEditingController(text: 'Rajasthan');
  final pincodeController = TextEditingController();
  final landmarkController = TextEditingController();

  List<CustomerAddress> savedAddresses = [];
  CustomerAddress? selectedAddress;

  bool loading = true;
  bool placingOrder = false;
  bool isGiftOrder = false;

  String paymentMethod = 'COD';

  final giftMessageController = TextEditingController();

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

  Future<void> loadCheckoutData() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
      return;
    }

    await CartController.initialize();

    emailController.text =
        user.email ?? '';

    await loadSavedAddresses();

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> loadSavedAddresses() async {
    final user = _auth.currentUser;

    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .get();

      final List<CustomerAddress> addresses = [];

      for (final document in snapshot.docs) {
        final data =
            document.data();

        addresses.add(
          CustomerAddress.fromMap({
            ...data,
            'addressId':
                data['addressId'] ??
                    document.id,
          }),
        );
      }

      addresses.sort(
        (CustomerAddress a, CustomerAddress b) {
          if (a.isDefault && !b.isDefault) {
            return -1;
          }

          if (!a.isDefault && b.isDefault) {
            return 1;
          }

          return 0;
        },
      );

      if (mounted) {
        setState(() {
          savedAddresses = addresses;

          if (addresses.isNotEmpty) {
            selectedAddress = addresses.first;
            fillAddressFromModel(
              addresses.first,
            );
          }
        });
      }
    } catch (e) {
      debugPrint(
        'Address loading error: $e',
      );
    }
  }

  void fillAddressFromModel(
    CustomerAddress address,
  ) {
    nameController.text = address.name;
    phoneController.text = address.phone;
    houseController.text = address.house;
    streetController.text = address.street;
    cityController.text = address.city;
    stateController.text = address.state;
    pincodeController.text = address.pincode;
    landmarkController.text = address.landmark;
  }

  void useNewAddress() {
    setState(() {
      selectedAddress = null;

      houseController.clear();
      streetController.clear();
      cityController.clear();
      stateController.text = 'Rajasthan';
      pincodeController.clear();
      landmarkController.clear();
    });
  }

  Future<void> saveCustomerDetails() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(
      {
        'name':
            nameController.text.trim(),
        'phone':
            phoneController.text.trim(),
        'email':
            emailController.text.trim(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> saveAddressIfNeeded() async {
    final user = _auth.currentUser;

    if (user == null) return;

    if (selectedAddress != null) {
      return;
    }

    final addressId =
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('addresses')
            .doc()
            .id;

    final address =
        CustomerAddress(
      addressId: addressId,
      name: nameController.text.trim(),
      phone: phoneController.text.trim(),
      house: houseController.text.trim(),
      street: streetController.text.trim(),
      city: cityController.text.trim(),
      state: stateController.text.trim(),
      pincode: pincodeController.text.trim(),
      landmark:
          landmarkController.text.trim(),
      isDefault: savedAddresses.isEmpty,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .doc(addressId)
        .set(address.toMap());
  }

  bool validateAddress() {
    if (nameController.text.trim().isEmpty) {
      _showMessage(
        'Please enter your name',
      );
      return false;
    }

    if (phoneController.text.trim().length < 10) {
      _showMessage(
        'Please enter valid mobile number',
      );
      return false;
    }

    if (houseController.text.trim().isEmpty) {
      _showMessage(
        'Please enter house / flat details',
      );
      return false;
    }

    if (streetController.text.trim().isEmpty) {
      _showMessage(
        'Please enter street / area',
      );
      return false;
    }

    if (cityController.text.trim().isEmpty) {
      _showMessage(
        'Please enter city',
      );
      return false;
    }

    if (pincodeController.text.trim().length != 6) {
      _showMessage(
        'Please enter valid 6 digit pincode',
      );
      return false;
    }

    return true;
  }

  List<Map<String, dynamic>>
      buildOrderItems() {
    return CartController.items.map(
      (CartItem item) {
        final Product product =
            item.product;

        return {
          'productId':
              product.id,
          'id':
              product.id,
          'name':
              product.name,
          'category':
              product.category,
          'price':
              product.numericPrice,
          'sellingPrice':
              product.sellingPrice,
          'mrp':
              product.originalPrice,
          'quantity':
              item.quantity,
          'total':
              item.totalPrice,
          'imageUrl':
              product.imageUrl,
          'vendorUid':
              product.vendorUid,
          'vendorName':
              product.vendorName,
        };
      },
    ).toList();
  }

  List<String> getVendorUids() {
    return CartController.items
        .map(
          (item) =>
              item.vendorUid.trim(),
        )
        .where(
          (uid) => uid.isNotEmpty,
        )
        .toSet()
        .toList();
  }

  List<String> getVendorNames() {
    return CartController.items
        .map(
          (item) =>
              item.vendorName.trim(),
        )
        .where(
          (name) => name.isNotEmpty,
        )
        .toSet()
        .toList();
  }

  Future<void> placeOrder() async {
    if (placingOrder) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login before placing order',
      );
      return;
    }

    if (CartController.items.isEmpty) {
      _showMessage(
        'Your cart is empty',
      );
      return;
    }

    if (!validateAddress()) {
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      await CartController.initialize();

      if (CartController.items.isEmpty) {
        throw Exception(
          'Your cart is empty',
        );
      }

      // Check available stock before order.
      for (final item
          in CartController.items) {
        if (item.quantity >
            item.availableStock) {
          throw Exception(
            '${item.name} has only ${item.availableStock} item(s) available.',
          );
        }
      }

      await saveCustomerDetails();
      await saveAddressIfNeeded();

      final orderRef =
          _firestore.collection('orders').doc();

      final orderId = orderRef.id;

      final items =
          buildOrderItems();

      final vendorUids =
          getVendorUids();

      final vendorNames =
          getVendorNames();

      final double subtotal =
          CartController.total;

      final double originalTotal =
          CartController.originalTotal;

      final double savings =
          CartController.productSavings;

      final now =
          FieldValue.serverTimestamp();

      final deliveryAddress =
          [
        houseController.text.trim(),
        streetController.text.trim(),
        cityController.text.trim(),
        stateController.text.trim(),
        pincodeController.text.trim(),
        landmarkController.text.trim(),
      ]
              .where(
                (value) =>
                    value.isNotEmpty,
              )
              .join(', ');

      final orderData =
          <String, dynamic>{
        'orderId':
            orderId,

        'userId':
            user.uid,

        'customerId':
            user.uid,

        'customerName':
            nameController.text.trim(),

        'mobile':
            phoneController.text.trim(),

        'phone':
            phoneController.text.trim(),

        'email':
            emailController.text.trim(),

        'house':
            houseController.text.trim(),

        'street':
            streetController.text.trim(),

        'city':
            cityController.text.trim(),

        'state':
            stateController.text.trim(),

        'pincode':
            pincodeController.text.trim(),

        'landmark':
            landmarkController.text.trim(),

        'deliveryAddress':
            deliveryAddress,

        'address':
            deliveryAddress,

        'items':
            items,

        'itemCount':
            CartController.itemCount,

        'totalItems':
            CartController.itemCount,

        'subtotal':
            subtotal,

        'total':
            subtotal,

        'grandTotal':
            subtotal,

        'totalAmount':
            subtotal,

        'originalTotal':
            originalTotal,

        'savings':
            savings,

        // COD
        'paymentMethod':
            'COD',

        'paymentType':
            'Cash on Delivery',

        'paymentStatus':
            'Pending',

        'codAmount':
            subtotal,

        'isCOD':
            true,

        // Order status
        'orderStatus':
            'Placed',

        'status':
            'Placed',

        'statusHistory': [
          {
            'status':
                'Placed',
            'timestamp':
                Timestamp.now(),
          },
        ],

        // Vendor information
        'vendorUid':
            vendorUids.length == 1
                ? vendorUids.first
                : null,

        'vendorName':
            vendorNames.length == 1
                ? vendorNames.first
                : null,

        'vendorUids':
            vendorUids,

        'vendorNames':
            vendorNames,

        'vendorCount':
            vendorUids.length,

        'isMultiVendor':
            vendorUids.length > 1,

        // Gift order
        'isGiftOrder':
            isGiftOrder,

        'giftMessage':
            isGiftOrder
                ? giftMessageController
                    .text
                    .trim()
                : '',

        // Cancellation
        'isCancelled':
            false,

        'cancelledAt':
            null,

        'cancellationReason':
            null,

        // Courier
        'courierName':
            null,

        'trackingId':
            null,

        'trackingUrl':
            null,

        'updatedBy':
            user.uid,

        'updatedByUid':
            user.uid,

        'createdAt':
            now,

        'updatedAt':
            now,

        'placedAt':
            now,
      };

      await orderRef.set(orderData);

      await CartController.clear();

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Order Placed',
                  ),
                ),
              ],
            ),
            content: Text(
              'Your order has been placed successfully.\n\n'
              'Order ID:\n$orderId\n\n'
              'Payment: Cash on Delivery',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context)
                      .pop();
                },
                child: const Text(
                  'View Order',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const OrdersPage(),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint(
        'Place order error: $e',
      );

      if (mounted) {
        _showMessage(
          'Order failed: ${e.toString()}',
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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration:
            InputDecoration(
          labelText: label,
          border:
              const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _addressCard(
    CustomerAddress address,
  ) {
    final bool selected =
        selectedAddress?.addressId ==
            address.addressId;

    return Card(
      margin:
          const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedAddress = address;
            fillAddressFromModel(
              address,
            );
          });
        },
        child: Padding(
          padding:
              const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Radio<String>(
                value:
                    address.addressId,
                groupValue:
                    selectedAddress
                        ?.addressId,
                onChanged: (_) {
                  setState(() {
                    selectedAddress =
                        address;
                    fillAddressFromModel(
                      address,
                    );
                  });
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      address.phone,
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      [
                        address.house,
                        address.street,
                        address.city,
                        address.state,
                        address.pincode,
                      ]
                          .where(
                            (e) =>
                                e.isNotEmpty,
                          )
                          .join(', '),
                    ),
                    if (address.landmark
                        .isNotEmpty)
                      Text(
                        'Landmark: ${address.landmark}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String title,
    String value, {
    bool bold = false,
  }) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Checkout'),
        ),
        body: const Center(
          child: Text(
            'Please login to continue.',
          ),
        ),
      );
    }

    if (loading) {
      return Scaffold(
        appBar: AppBar(
          title:
              const Text('Checkout'),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Checkout'),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            const Text(
              'Customer Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _textField(
              controller:
                  nameController,
              label: 'Full Name',
            ),

            _textField(
              controller:
                  phoneController,
              label: 'Mobile Number',
              keyboardType:
                  TextInputType.phone,
            ),

            _textField(
              controller:
                  emailController,
              label: 'Email',
              keyboardType:
                  TextInputType.emailAddress,
            ),

            const SizedBox(height: 8),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
              children: [
                const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      useNewAddress,
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: const Text(
                    'New Address',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (savedAddresses
                .isNotEmpty)
              ...savedAddresses.map(
                _addressCard,
              ),

            const SizedBox(height: 8),

            _textField(
              controller:
                  houseController,
              label:
                  'House / Flat / Building',
            ),

            _textField(
              controller:
                  streetController,
              label:
                  'Street / Area',
            ),

            _textField(
              controller:
                  cityController,
              label: 'City',
            ),

            _textField(
              controller:
                  stateController,
              label: 'State',
            ),

            _textField(
              controller:
                  pincodeController,
              label: 'Pincode',
              keyboardType:
                  TextInputType.number,
            ),

            _textField(
              controller:
                  landmarkController,
              label: 'Landmark',
            ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    RadioListTile<String>(
                      contentPadding:
                          EdgeInsets.zero,
                      value: 'COD',
                      groupValue:
                          paymentMethod,
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          paymentMethod =
                              value;
                        });
                      },
                      title: const Text(
                        'Cash on Delivery',
                      ),
                      subtitle:
                          const Text(
                        'Pay when your order is delivered',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Card(
              child: SwitchListTile(
                title: const Text(
                  'This is a gift order',
                ),
                value: isGiftOrder,
                onChanged: (value) {
                  setState(() {
                    isGiftOrder = value;
                  });
                },
              ),
            ),

            if (isGiftOrder)
              _textField(
                controller:
                    giftMessageController,
                label:
                    'Gift Message',
                maxLines: 3,
              ),

            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    ...CartController.items
                        .map(
                      (item) {
                        return _summaryRow(
                          '${item.name} × ${item.quantity}',
                          '₹${item.totalPrice.toStringAsFixed(2)}',
                        );
                      },
                    ),

                    const Divider(),

                    _summaryRow(
                      'Original Total',
                      '₹${CartController.originalTotal.toStringAsFixed(2)}',
                    ),

                    _summaryRow(
                      'Savings',
                      '₹${CartController.productSavings.toStringAsFixed(2)}',
                    ),

                    _summaryRow(
                      'Total Items',
                      '${CartController.itemCount}',
                    ),

                    const Divider(),

                    _summaryRow(
                      'Total Amount',
                      '₹${CartController.total.toStringAsFixed(2)}',
                      bold: true,
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          8,
                        ),
                        border:
                            Border.all(),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .local_shipping,
                          ),
                          SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              'Cash on Delivery selected',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed:
                    placingOrder
                        ? null
                        : placeOrder,
                child: placingOrder
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'PLACE ORDER • ₹${CartController.total.toStringAsFixed(2)}',
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
