import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

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
  // GIFT RECIPIENT DETAILS
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

  // false = Myself
  // true = Gift
  bool isGift = false;

  @override
  void initState() {
    super.initState();

    loadCustomerData();
  }

  // ============================================================
  // LOAD CUSTOMER DATA
  // ============================================================

  Future<void> loadCustomerData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snapshot.data() ?? {};

    if (!mounted) return;

    setState(() {
      nameController.text =
          data['name']?.toString() ??
              user.displayName ??
              '';

      mobileController.text =
          cleanMobile(
        data['mobile']?.toString() ??
            user.phoneNumber ??
            '',
      );

      emailController.text =
          data['email']?.toString() ?? '';

      addressController.text =
          data['address']?.toString() ?? '';

      cityController.text =
          data['city']?.toString() ?? '';

      pincodeController.text =
          data['pincode']?.toString() ?? '';
    });
  }

  // ============================================================
  // CLEAN MOBILE
  // ============================================================

  String cleanMobile(String value) {
    String mobile = value.trim();

    if (mobile.startsWith('+91')) {
      mobile = mobile.substring(3);
    }

    if (mobile.startsWith('91') &&
        mobile.length == 12) {
      mobile = mobile.substring(2);
    }

    return mobile;
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // PLACE ORDER
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

    final user =
        FirebaseAuth.instance.currentUser;

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

    // ==========================================================
    // RULE 1: CUSTOMER MOBILE MUST BE 10 DIGITS
    // ==========================================================

    final customerMobile =
        cleanMobile(mobileController.text);

    if (!RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(customerMobile)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customer mobile number must be exactly 10 digits.',
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // GIFT MOBILE VALIDATION
    // ==========================================================

    String giftMobile = '';

    if (isGift) {
      giftMobile =
          cleanMobile(giftMobileController.text);

      if (!RegExp(
        r'^[0-9]{10}$',
      ).hasMatch(giftMobile)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gift recipient mobile number must be exactly 10 digits.',
            ),
          ),
        );
        return;
      }
    }

    // ==========================================================
    // OPTIONAL LOCATION
    // ==========================================================

    final latitude =
        latitudeController.text.trim();

    final longitude =
        longitudeController.text.trim();

    if (latitude.isNotEmpty) {
      final lat = double.tryParse(latitude);

      if (lat == null || lat < -90 || lat > 90) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter a valid latitude.',
            ),
          ),
        );
        return;
      }
    }

    if (longitude.isNotEmpty) {
      final lng = double.tryParse(longitude);

      if (lng == null || lng < -180 || lng > 180) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please enter a valid longitude.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      placingOrder = true;
    });

    try {
      final firestore =
          FirebaseFirestore.instance;

      final cartItems =
          List<CartItem>.from(
        CartController.items,
      );

      final totalAmount =
          cartItems.fold<double>(
        0,
        (sum, item) =>
            sum + item.totalPrice,
      );

      final orderRef =
          firestore.collection('orders').doc();

      final orderItems =
          <Map<String, dynamic>>[];

      // ==========================================================
      // FIRESTORE TRANSACTION
      // ==========================================================

      await firestore.runTransaction(
        (transaction) async {
          final productSnapshots =
              <String,
                  DocumentSnapshot<
                      Map<String, dynamic>>>{};

          // ======================================================
          // READ PRODUCTS FIRST
          // ======================================================

          for (final cartItem in cartItems) {
            final productRef =
                firestore
                    .collection('products')
                    .doc(cartItem.product.id);

            final snapshot =
                await transaction.get(
              productRef,
            );

            productSnapshots[
                    cartItem.product.id] =
                snapshot;
          }

          // ======================================================
          // CHECK STOCK + UPDATE STOCK
          // ======================================================

          for (final cartItem in cartItems) {
            final productSnapshot =
                productSnapshots[
                    cartItem.product.id];

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
                      data['Stock']
                              ?.toString() ??
                          '0',
                    ) ??
                    0;

            if (currentStock <= 0) {
              throw Exception(
                '${cartItem.name} is Out of Stock.',
              );
            }

            if (currentStock <
                cartItem.quantity) {
              throw Exception(
                'Only $currentStock stock available for ${cartItem.name}.',
              );
            }

            final newStock =
                currentStock -
                    cartItem.quantity;

            final productRef =
                firestore
                    .collection('products')
                    .doc(cartItem.product.id);

            transaction.update(
              productRef,
              {
                'Stock': newStock,
              },
            );

            // ====================================================
            // ORDER ITEM
            // ====================================================

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
                  data['Imageurl']
                          ?.toString() ??
                      cartItem.imageUrl,
            });
          }

          // ======================================================
          // WHATSAPP RECIPIENTS
          // ======================================================

          final whatsappRecipients =
              <Map<String, dynamic>>[
            {
              'type': 'customer',
              'mobile': customerMobile,
            },
          ];

          if (isGift) {
            whatsappRecipients.add({
              'type': 'gift_recipient',
              'mobile': giftMobile,
            });
          }

          // ======================================================
          // ORDER DATA
          // ======================================================

          final orderData =
              <String, dynamic>{
            'userId': user.uid,

            'customerName':
                nameController.text.trim(),

            'mobile':
                customerMobile,

            'email':
                emailController.text.trim(),

            'address':
                addressController.text.trim(),

            'city':
                cityController.text.trim(),

            'pincode':
                pincodeController.text.trim(),

            // ==================================================
            // SELF / GIFT
            // ==================================================

            'orderFor':
                isGift ? 'Gift' : 'Myself',

            'isGift':
                isGift,

            // ==================================================
            // GIFT DETAILS
            // ==================================================

            'giftRecipient':
                isGift
                    ? {
                        'name':
                            giftNameController
                                .text
                                .trim(),
                        'mobile':
                            giftMobile,
                        'address':
                            giftAddressController
                                .text
                                .trim(),
                        'city':
                            giftCityController
                                .text
                                .trim(),
                        'pincode':
                            giftPincodeController
                                .text
                                .trim(),
                      }
                    : null,

            // ==================================================
            // OPTIONAL GPS
            // ==================================================

            'deliveryLocation':
                latitude.isNotEmpty &&
                        longitude.isNotEmpty
                    ? {
                        'latitude':
                            double.parse(
                          latitude,
                        ),
                        'longitude':
                            double.parse(
                          longitude,
                        ),
                      }
                    : null,

            // ==================================================
            // PRODUCTS
            // ==================================================

            'items':
                orderItems,

            'totalAmount':
                totalAmount,

            'status':
                'Placed',

            'paymentMethod':
                'Cash on Delivery',

            // ==================================================
            // WHATSAPP DATA
            // ==================================================

            'whatsappRecipients':
                whatsappRecipients,

            'whatsappStatus':
                'Pending',

            'createdAt':
                FieldValue.serverTimestamp(),
          };

          // ======================================================
          // CREATE ORDER
          // ======================================================

          transaction.set(
            orderRef,
            orderData,
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // SAVE CUSTOMER PROFILE
      // ========================================================

      await firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'uid': user.uid,
          'name':
              nameController.text.trim(),
          'mobile':
              customerMobile,
          'email':
              emailController.text.trim(),
          'address':
              addressController.text.trim(),
          'city':
              cityController.text.trim(),
          'pincode':
              pincodeController.text.trim(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // ========================================================
      // CLEAR CART ONLY AFTER SUCCESS
      // ========================================================

      CartController.clear();

      // ========================================================
      // SUCCESS DIALOG
      // ========================================================

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
                  child: Text(
                    'Order Placed',
                  ),
                ),
              ],
            ),
            content: Text(
              'Your order has been placed successfully.\n\n'
              'Order ID:\n${orderRef.id}\n\n'
              'Order for: '
              '${isGift ? 'Gift' : 'Myself'}\n\n'
              'Stock has been updated.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
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
            'Order failed:\n'
            '${e.message ?? e.code}',
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
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
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
    final items =
        CartController.items;

    final total =
        items.fold<double>(
      0,
      (sum, item) =>
          sum + item.totalPrice,
    );

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
                  fontWeight:
                      FontWeight.bold,
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
                      value.trim().length < 2) {
                    return
                        'Enter your name';
                  }

                  return null;
                },
              ),

              // ==================================================
              // MOBILE - VERIFIED
              // ==================================================

              inputField(
                controller:
                    mobileController,
                label: 'Mobile Number',
                hint:
                    '10 digit mobile number',
                icon:
                    Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                enabled: false,
                validator: (value) {
                  if (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(
                    cleanMobile(
                      value ?? '',
                    ),
                  )) {
                    return
                        'Invalid mobile number';
                  }

                  return null;
                },
              ),

              // ==================================================
              // EMAIL OPTIONAL
              // ==================================================

              inputField(
                controller:
                    emailController,
                label:
                    'Email (Optional)',
                hint:
                    'Enter email if available',
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
                    return
                        'Enter a valid email';
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
                        'Enter complete address';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    cityController,
                label: 'City',
                hint: 'Enter city',
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
                    '6 digit PIN code',
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
                        'Enter valid 6 digit PIN';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              // ==================================================
              // RULE 2: OPTIONAL GPS
              // ==================================================

              const Text(
                'Delivery Location (Optional)',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Latitude and longitude can help us locate the delivery address more accurately.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: inputField(
                      controller:
                          latitudeController,
                      label: 'Latitude',
                      hint: 'e.g. 29.92',
                      icon:
                          Icons.my_location,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: inputField(
                      controller:
                          longitudeController,
                      label: 'Longitude',
                      hint: 'e.g. 74.88',
                      icon:
                          Icons.location_on_outlined,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ==================================================
              // RULE 3: ORDER FOR MYSELF / GIFT
              // ==================================================

              const Text(
                'Who is this order for?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      groupValue: isGift,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  setState(() {
                                    isGift =
                                        false;
                                  });
                                },
                      title: const Text(
                        'Myself',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle:
                          const Text(
                        'Deliver to my address',
                      ),
                      secondary:
                          const Icon(
                        Icons.person,
                      ),
                    ),

                    RadioListTile<bool>(
                      value: true,
                      groupValue: isGift,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  setState(() {
                                    isGift =
                                        true;
                                  });
                                },
                      title: const Text(
                        'Gift for someone',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle:
                          const Text(
                        'Enter recipient details',
                      ),
                      secondary:
                          const Icon(
                        Icons.card_giftcard,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GIFT DETAILS
              // ==================================================

              if (isGift) ...[
                const SizedBox(height: 14),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Gift Recipient Details',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 14,
                        ),

                        inputField(
                          controller:
                              giftNameController,
                          label:
                              'Recipient Name',
                          hint:
                              'Enter recipient name',
                          icon:
                              Icons.person_outline,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value.trim()
                                        .length <
                                    2) {
                              return
                                  'Enter recipient name';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftMobileController,
                          label:
                              'Recipient Mobile',
                          hint:
                              '10 digit mobile number',
                          icon:
                              Icons.phone_outlined,
                          keyboardType:
                              TextInputType.phone,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (!RegExp(
                              r'^[0-9]{10}$',
                            ).hasMatch(
                              cleanMobile(
                                value ?? '',
                              ),
                            )) {
                              return
                                  'Enter valid 10 digit mobile';
                            }

                            return null;
                          },
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
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value.trim()
                                        .length <
                                    5) {
                              return
                                  'Enter complete recipient address';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftCityController,
                          label:
                              'Recipient City',
                          hint:
                              'Enter recipient city',
                          icon:
                              Icons.location_city,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value.trim()
                                    .isEmpty) {
                              return
                                  'Enter recipient city';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftPincodeController,
                          label:
                              'Recipient PIN Code',
                          hint:
                              '6 digit PIN code',
                          icon:
                              Icons.pin_drop_outlined,
                          keyboardType:
                              TextInputType.number,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (!RegExp(
                              r'^[0-9]{6}$',
                            ).hasMatch(
                              value?.trim() ??
                                  '',
                            )) {
                              return
                                  'Enter valid 6 digit PIN';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ==================================================
              // PAYMENT
              // ==================================================

              Card(
                child: ListTile(
                  leading:
                      const Icon(
                    Icons.payments_outlined,
                  ),
                  title: const Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  subtitle:
                      const Text(
                    'Pay when your order is delivered',
                  ),
                  trailing:
                      const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ==================================================
              // ORDER SUMMARY
              // ==================================================

              const Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    children: [
                      ...items.map(
                        (item) {
                          return Padding(
                            padding:
                                const EdgeInsets
                                    .only(
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
                                        FontWeight
                                            .bold,
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
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          Text(
                            money(total),
                            style:
                                const TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight
                                      .bold,
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
                child:
                    FilledButton.icon(
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
                'Stock is reduced only after the order is successfully created.',
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
}
