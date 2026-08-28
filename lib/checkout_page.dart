import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  // ============================================================
  // CUSTOMER DETAILS
  // ============================================================

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final emailController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();

  // ============================================================
  // GIFT DETAILS
  // ============================================================

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  // ============================================================
  // LOCATION
  // ============================================================

  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  bool placingOrder = false;
  bool isGift = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      mobileController.text =
          _mobileFromFirebaseUser(user);
    }
  }

  // ============================================================
  // GET LOGIN MOBILE NUMBER
  // ============================================================

  String _mobileFromFirebaseUser(User user) {
    final phone = user.phoneNumber ?? '';

    if (phone.startsWith('+91')) {
      return phone.substring(3);
    }

    if (phone.startsWith('+')) {
      return phone.substring(1);
    }

    return phone;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    emailController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();

    giftNameController.dispose();
    giftMobileController.dispose();
    giftAddressController.dispose();
    giftCityController.dispose();
    giftPincodeController.dispose();

    latitudeController.dispose();
    longitudeController.dispose();

    super.dispose();
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // VALIDATE MOBILE
  // ============================================================

  String? validateMobile(String? value) {
    final mobile = value?.trim() ?? '';

    if (!RegExp(r'^[0-9]{10}$').hasMatch(mobile)) {
      return 'Enter a valid 10 digit mobile number';
    }

    return null;
  }

  // ============================================================
  // PLACE ORDER
  // STOCK REDUCES ONLY AFTER SUCCESSFUL ORDER CREATION
  // ============================================================

  Future<void> placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (CartController.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please login with your mobile number before placing an order.',
          ),
        ),
      );
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final cartItems =
          List<CartItem>.from(CartController.items);

      final totalAmount = cartItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      );

      final orderRef =
          firestore.collection('orders').doc();

      final orderItems =
          <Map<String, dynamic>>[];

      await firestore.runTransaction(
        (transaction) async {
          // ======================================================
          // FIRST READ ALL PRODUCTS
          // ======================================================

          final productSnapshots =
              <String,
                  DocumentSnapshot<Map<String, dynamic>>>{};

          for (final cartItem in cartItems) {
            final productRef = firestore
                .collection('products')
                .doc(cartItem.product.id);

            final snapshot =
                await transaction.get(productRef);

            productSnapshots[cartItem.product.id] =
                snapshot;
          }

          // ======================================================
          // CHECK STOCK + PREPARE ORDER ITEMS
          // ======================================================

          for (final cartItem in cartItems) {
            final productSnapshot =
                productSnapshots[cartItem.product.id];

            if (productSnapshot == null ||
                !productSnapshot.exists) {
              throw Exception(
                '${cartItem.name} is no longer available.',
              );
            }

            final data =
                productSnapshot.data() ?? {};

            final active =
                data['Active'] == true;

            if (!active) {
              throw Exception(
                '${cartItem.name} is currently unavailable.',
              );
            }

            final currentStock =
                int.tryParse(
                      data['Stock']?.toString() ?? '0',
                    ) ??
                    0;

            if (currentStock <= 0) {
              throw Exception(
                '${cartItem.name} is Out of Stock.',
              );
            }

            if (currentStock < cartItem.quantity) {
              throw Exception(
                'Only $currentStock stock available for '
                '${cartItem.name}. Please reduce the quantity.',
              );
            }

            final newStock =
                currentStock - cartItem.quantity;

            final productRef = firestore
                .collection('products')
                .doc(cartItem.product.id);

            // ==================================================
            // REDUCE STOCK
            // ==================================================

            transaction.update(
              productRef,
              {
                'Stock': newStock,
              },
            );

            // ==================================================
            // ORDER ITEM
            // ==================================================

            orderItems.add({
              'productId':
                  cartItem.product.id,
              'name':
                  cartItem.name,
              'category':
                  cartItem.category,
              'price':
                  cartItem.numericPrice,
              'quantity':
                  cartItem.quantity,
              'total':
                  cartItem.totalPrice,
              'imageUrl':
                  data['Imageurl']?.toString() ??
                      cartItem.imageUrl,
            });
          }

          // ======================================================
          // CUSTOMER DATA
          // ======================================================

          final customerData =
              <String, dynamic>{
            'name':
                nameController.text.trim(),

            'mobile':
                mobileController.text.trim(),

            'address':
                addressController.text.trim(),

            'city':
                cityController.text.trim(),

            'pincode':
                pincodeController.text.trim(),
          };

          // ======================================================
          // OPTIONAL EMAIL
          // ======================================================

          final email =
              emailController.text.trim();

          if (email.isNotEmpty) {
            customerData['email'] = email;
          }

          // ======================================================
          // OPTIONAL LOCATION
          // ======================================================

          final latitude =
              double.tryParse(
            latitudeController.text.trim(),
          );

          final longitude =
              double.tryParse(
            longitudeController.text.trim(),
          );

          if (latitude != null &&
              longitude != null) {
            customerData['latitude'] =
                latitude;

            customerData['longitude'] =
                longitude;
          }

          // ======================================================
          // GIFT DATA
          // ======================================================

          Map<String, dynamic>? giftData;

          if (isGift) {
            giftData = {
              'name':
                  giftNameController.text.trim(),

              'mobile':
                  giftMobileController.text.trim(),

              'address':
                  giftAddressController.text.trim(),

              'city':
                  giftCityController.text.trim(),

              'pincode':
                  giftPincodeController.text.trim(),
            };
          }

          // ======================================================
          // CREATE ORDER
          // ======================================================

          transaction.set(
            orderRef,
            {
              'userId':
                  user.uid,

              'customer':
                  customerData,

              'orderFor':
                  isGift ? 'Gift' : 'Self',

              'giftRecipient':
                  giftData,

              'items':
                  orderItems,

              'totalAmount':
                  totalAmount,

              'status':
                  'Placed',

              'paymentMethod':
                  'Cash on Delivery',

              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // CLEAR CART ONLY AFTER SUCCESS
      // ========================================================

      CartController.clear();

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Order Placed'),
                ),
              ],
            ),
            content: Text(
              'Your order has been placed successfully.\n\n'
              'Order ID:\n${orderRef.id}\n\n'
              'Order for: ${isGift ? 'Gift' : 'Self'}\n\n'
              'Stock has been updated.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text(
                  'Continue Shopping',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order failed:\n${e.message ?? e.code}',
          ),
          duration:
              const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
          duration:
              const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  // ============================================================
  // INPUT FIELD
  // ============================================================

  Widget inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,

          child: ListView(
            padding:
                const EdgeInsets.all(16),

            children: [
              // ==================================================
              // DELIVERY DETAILS
              // ==================================================

              const Text(
                'Delivery Details',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              inputField(
                controller:
                    nameController,
                label: 'Full Name',
                hint:
                    'Enter your full name',
                icon:
                    Icons.person_outline,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter your name';
                  }

                  if (value.trim().length < 2) {
                    return 'Enter a valid name';
                  }

                  return null;
                },
              ),

              // ==================================================
              // CUSTOMER MOBILE
              // ==================================================

              inputField(
                controller:
                    mobileController,
                label: 'Mobile Number',
                hint:
                    'Login mobile number',
                icon:
                    Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                enabled: false,
                validator:
                    validateMobile,
              ),

              // ==================================================
              // OPTIONAL EMAIL
              // ==================================================

              inputField(
                controller:
                    emailController,
                label: 'Email (Optional)',
                hint:
                    'Enter email for order updates',
                icon:
                    Icons.email_outlined,
                keyboardType:
                    TextInputType.emailAddress,
                validator: (value) {
                  final email =
                      value?.trim() ?? '';

                  if (email.isEmpty) {
                    return null;
                  }

                  if (!RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email)) {
                    return 'Enter a valid email';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    addressController,
                label: 'Address',
                hint:
                    'House no., street, area',
                icon:
                    Icons.home_outlined,
                maxLines: 3,
                validator: (value) {
                  if (value == null ||
                      value.trim().length < 5) {
                    return
                        'Enter a complete address';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    cityController,
                label: 'City',
                hint:
                    'Enter your city',
                icon:
                    Icons.location_city_outlined,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter city';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    pincodeController,
                label: 'PIN Code',
                hint:
                    'Enter 6 digit PIN code',
                icon:
                    Icons.pin_drop_outlined,
                keyboardType:
                    TextInputType.number,
                validator: (value) {
                  if (!RegExp(
                    r'^[0-9]{6}$',
                  ).hasMatch(
                    value?.trim() ?? '',
                  )) {
                    return
                        'Enter a valid 6 digit PIN code';
                  }

                  return null;
                },
              ),

              // ==================================================
              // OPTIONAL LOCATION
              // ==================================================

              const SizedBox(height: 4),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delivery Location',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        'Optional: Latitude and Longitude can help with better delivery.',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller:
                                  latitudeController,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Latitude',
                                hintText:
                                    'Optional',
                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: TextFormField(
                              controller:
                                  longitudeController,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Longitude',
                                hintText:
                                    'Optional',
                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // SELF / GIFT
              // ==================================================

              const Text(
                'Who is this order for?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      groupValue: isGift,
                      onChanged: placingOrder
                          ? null
                          : (value) {
                              setState(() {
                                isGift = false;
                              });
                            },
                      title: const Text(
                        'For Myself',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'I am ordering for myself',
                      ),
                    ),

                    RadioListTile<bool>(
                      value: true,
                      groupValue: isGift,
                      onChanged: placingOrder
                          ? null
                          : (value) {
                              setState(() {
                                isGift = true;
                              });
                            },
                      title: const Text(
                        '🎁 Gift for Someone',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'I want to send this order to someone else',
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GIFT RECIPIENT
              // ==================================================

              if (isGift) ...[
                const SizedBox(height: 18),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎁 Gift Recipient Details',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'All recipient details are required for gift delivery.',
                          style: TextStyle(
                            color:
                                Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 16),

                        inputField(
                          controller:
                              giftNameController,
                          label:
                              'Recipient Full Name',
                          hint:
                              'Enter recipient name',
                          icon:
                              Icons.person_outline,
                          validator:
                              isGift
                                  ? (value) {
                                      if (value ==
                                              null ||
                                          value
                                              .trim()
                                              .isEmpty) {
                                        return
                                            'Enter recipient name';
                                      }

                                      if (value
                                              .trim()
                                              .length <
                                          2) {
                                        return
                                            'Enter a valid recipient name';
                                      }

                                      return null;
                                    }
                                  : null,
                        ),

                        inputField(
                          controller:
                              giftMobileController,
                          label:
                              'Recipient Mobile Number',
                          hint:
                              'Enter 10 digit mobile number',
                          icon:
                              Icons.phone_outlined,
                          keyboardType:
                              TextInputType.phone,
                          validator:
                              isGift
                                  ? validateMobile
                                  : null,
                        ),

                        inputField(
                          controller:
                              giftAddressController,
                          label:
                              'Recipient Address',
                          hint:
                              'House no., street, area',
                          icon:
                              Icons.home_outlined,
                          maxLines: 3,
                          validator:
                              isGift
                                  ? (value) {
                                      if (value ==
                                              null ||
                                          value
                                              .trim()
                                              .length <
                                              5) {
                                        return
                                            'Enter complete recipient address';
                                      }

                                      return null;
                                    }
                                  : null,
                        ),

                        inputField(
                          controller:
                              giftCityController,
                          label:
                              'Recipient City',
                          hint:
                              'Enter recipient city',
                          icon:
                              Icons.location_city_outlined,
                          validator:
                              isGift
                                  ? (value) {
                                      if (value ==
                                              null ||
                                          value
                                              .trim()
                                              .isEmpty) {
                                        return
                                            'Enter recipient city';
                                      }

                                      return null;
                                    }
                                  : null,
                        ),

                        inputField(
                          controller:
                              giftPincodeController,
                          label:
                              'Recipient PIN Code',
                          hint:
                              'Enter 6 digit PIN code',
                          icon:
                              Icons.pin_drop_outlined,
                          keyboardType:
                              TextInputType.number,
                          validator:
                              isGift
                                  ? (value) {
                                      if (!RegExp(
                                        r'^[0-9]{6}$',
                                      ).hasMatch(
                                        value?.trim() ??
                                            '',
                                      )) {
                                        return
                                            'Enter a valid 6 digit PIN code';
                                      }

                                      return null;
                                    }
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ==================================================
              // PAYMENT
              // ==================================================

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.payments_outlined,
                  ),
                  title: const Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Pay when your order is delivered',
                  ),
                  trailing:
                      const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // ORDER SUMMARY
              // ==================================================

              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      ...items.map(
                        (item) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.name} × ${item.quantity}',
                                  ),
                                ),
                                Text(
                                  money(
                                    item.totalPrice,
                                  ),
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const Divider(),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(
                              items.fold<double>(
                                0,
                                (sum, item) =>
                                    sum +
                                    item.totalPrice,
                              ),
                            ),
                            style:
                                const TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // PLACE ORDER
              // ==================================================

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      placingOrder
                          ? null
                          : placeOrder,
                  icon: placingOrder
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .shopping_bag_outlined,
                        ),
                  label: Text(
                    placingOrder
                        ? 'Placing Order...'
                        : 'Place Order',
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Stock is reduced only when your order is successfully placed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Adding an item to Cart does not reduce stock.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
