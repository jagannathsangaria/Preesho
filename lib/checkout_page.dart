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
      nameController.text = user.displayName ?? '';

      // If Firebase phone authentication is used,
      // Firebase may already have the customer's phone number.
      final phone = user.phoneNumber;

      if (phone != null && phone.isNotEmpty) {
        final cleanPhone = phone.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );

        if (cleanPhone.length >= 10) {
          mobileController.text =
              cleanPhone.substring(cleanPhone.length - 10);
        }
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
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
  // MOBILE VALIDATION
  // EXACTLY 10 DIGITS
  // ============================================================

  bool isValidMobile(String value) {
    return RegExp(r'^[0-9]{10}$').hasMatch(value.trim());
  }

  // ============================================================
  // WHATSAPP MESSAGE
  // ============================================================

  String buildWhatsAppMessage({
    required String customerName,
    required String customerMobile,
    required String orderId,
    required double totalAmount,
    required String address,
    required String city,
    required String pincode,
    required List<CartItem> items,
    String? giftName,
    String? giftMobile,
  }) {
    final itemLines = items.map((item) {
      return '• ${item.name} x ${item.quantity} = '
          '${money(item.totalPrice)}';
    }).join('\n');

    String message = '''
🛍️ *Preesho Order Confirmed*

Order ID:
$orderId

Customer:
$customerName

Customer Mobile:
$customerMobile

Delivery Address:
$address
$city - $pincode
''';

    if (giftName != null && giftName.isNotEmpty) {
      message += '''

🎁 *Gift Order*

Recipient:
$giftName

Recipient Mobile:
$giftMobile
''';
    }

    message += '''

📦 *Order Items*
$itemLines

💰 *Total Amount: ${money(totalAmount)}*

💳 Payment:
Cash on Delivery

Thank you for shopping with *Preesho*.
''';

    return message;
  }

  // ============================================================
  // OPEN WHATSAPP
  // ============================================================

  Future<bool> openWhatsApp({
    required String mobile,
    required String message,
  }) async {
    final cleanMobile =
        mobile.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanMobile.length != 10) {
      return false;
    }

    // India country code
    final whatsappNumber = '91$cleanMobile';

    final uri = Uri.parse(
      'https://wa.me/$whatsappNumber?text='
      '${Uri.encodeComponent(message)}',
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {}

    return false;
  }

  // ============================================================
  // LOCATION
  //
  // LOCATION IS OPTIONAL.
  //
  // We are intentionally NOT forcing GPS permission here.
  // If latitude/longitude are entered by another part of the app,
  // they will be saved.
  // ============================================================

  double? get latitude {
    final value = double.tryParse(
      latitudeController.text.trim(),
    );

    return value;
  }

  double? get longitude {
    final value = double.tryParse(
      longitudeController.text.trim(),
    );

    return value;
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

    // ==========================================================
    // RULE 1: CUSTOMER MOBILE MUST BE EXACTLY 10 DIGITS
    // ==========================================================

    final customerMobile =
        mobileController.text.trim();

    if (!isValidMobile(customerMobile)) {
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
    // RULE 3: GIFT DETAILS
    // ==========================================================

    if (isGift) {
      final giftMobile =
          giftMobileController.text.trim();

      if (!isValidMobile(giftMobile)) {
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

      // ========================================================
      // FIRESTORE TRANSACTION
      // STOCK + ORDER TOGETHER
      // ========================================================

      await firestore.runTransaction(
        (transaction) async {
          // ----------------------------------------------------
          // READ ALL PRODUCTS FIRST
          // ----------------------------------------------------

          final productSnapshots = <
              String,
              DocumentSnapshot<
                  Map<String, dynamic>>>{
          };

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

          // ----------------------------------------------------
          // CHECK STOCK
          // ----------------------------------------------------

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
                'Only $currentStock stock available for '
                '${cartItem.name}.',
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

            // --------------------------------------------------
            // ORDER ITEM
            // --------------------------------------------------

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

          // ====================================================
          // ORDER DATA
          // ====================================================

          final orderData =
              <String, dynamic>{
            'userId':
                user.uid,

            // Customer
            'customerName':
                nameController.text.trim(),

            'mobile':
                customerMobile,

            'address':
                addressController.text.trim(),

            'city':
                cityController.text.trim(),

            'pincode':
                pincodeController.text.trim(),

            // Order type
            'orderFor':
                isGift ? 'Gift' : 'Self',

            'isGift':
                isGift,

            // Items
            'items':
                orderItems,

            'totalAmount':
                totalAmount,

            // Payment
            'status':
                'Placed',

            'paymentMethod':
                'Cash on Delivery',

            // Optional location
            'latitude':
                latitude,

            'longitude':
                longitude,

            // Email if available in Firebase Auth
            'customerEmail':
                user.email,

            'createdAt':
                FieldValue.serverTimestamp(),
          };

          // ====================================================
          // GIFT INFORMATION
          // ====================================================

          if (isGift) {
            orderData['giftRecipient'] = {
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

          // ====================================================
          // CREATE ORDER
          // ====================================================

          transaction.set(
            orderRef,
            orderData,
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // CLEAR CART ONLY AFTER SUCCESS
      // ========================================================

      CartController.clear();

      // ========================================================
      // WHATSAPP MESSAGE
      // ========================================================

      final message =
          buildWhatsAppMessage(
        customerName:
            nameController.text.trim(),
        customerMobile:
            customerMobile,
        orderId:
            orderRef.id,
        totalAmount:
            totalAmount,
        address:
            addressController.text.trim(),
        city:
            cityController.text.trim(),
        pincode:
            pincodeController.text.trim(),
        items:
            cartItems,
        giftName: isGift
            ? giftNameController.text.trim()
            : null,
        giftMobile: isGift
            ? giftMobileController.text.trim()
            : null,
      );

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
            content: SingleChildScrollView(
              child: Text(
                'Your order has been placed successfully.\n\n'
                'Order ID:\n${orderRef.id}\n\n'
                'Stock has been updated.\n\n'
                'WhatsApp confirmation is ready.',
              ),
            ),
            actions: [
              FilledButton.icon(
                onPressed: () async {
                  final opened =
                      await openWhatsApp(
                    mobile:
                        customerMobile,
                    message:
                        message,
                  );

                  if (!dialogContext.mounted) {
                    return;
                  }

                  if (!opened) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open WhatsApp.',
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.chat,
                ),
                label: const Text(
                  'WhatsApp Customer',
                ),
              ),

              if (isGift)
                FilledButton.icon(
                  onPressed: () async {
                    final opened =
                        await openWhatsApp(
                      mobile:
                          giftMobileController
                              .text
                              .trim(),
                      message:
                          message,
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    if (!opened) {
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not open WhatsApp.',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.card_giftcard,
                  ),
                  label: const Text(
                    'WhatsApp Recipient',
                  ),
                ),

              TextButton(
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

      Navigator.pop(
        context,
        true,
      );
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
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller:
            controller,
        keyboardType:
            keyboardType,
        maxLines:
            maxLines,
        maxLength:
            maxLength,
        validator:
            validator,
        decoration:
            InputDecoration(
          labelText:
              label,
          hintText:
              hint,
          prefixIcon:
              Icon(icon),
          counterText:
              maxLength != null
                  ? ''
                  : null,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE FIELD VALIDATOR
  // ============================================================

  String? mobileValidator(
    String? value,
  ) {
    final mobile =
        value?.trim() ?? '';

    if (mobile.isEmpty) {
      return 'Please enter mobile number';
    }

    if (!isValidMobile(
      mobile,
    )) {
      return 'Mobile number must be exactly 10 digits';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
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
            fontWeight:
                FontWeight.bold,
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

              const SizedBox(
                height: 14,
              ),

              inputField(
                controller:
                    nameController,
                label:
                    'Full Name',
                hint:
                    'Enter your full name',
                icon:
                    Icons.person_outline,
                validator:
                    (value) {
                  if (value ==
                          null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter your name';
                  }

                  if (value
                          .trim()
                          .length <
                      2) {
                    return 'Enter a valid name';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    mobileController,
                label:
                    'Mobile Number',
                hint:
                    '10 digit mobile number',
                icon:
                    Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                maxLength:
                    10,
                validator:
                    mobileValidator,
              ),

              inputField(
                controller:
                    addressController,
                label:
                    'Address',
                hint:
                    'House no., street, area',
                icon:
                    Icons.home_outlined,
                maxLines:
                    3,
                validator:
                    (value) {
                  if (value ==
                          null ||
                      value
                              .trim()
                              .length <
                          5) {
                    return 'Enter a complete address';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    cityController,
                label:
                    'City',
                hint:
                    'Enter your city',
                icon:
                    Icons.location_city_outlined,
                validator:
                    (value) {
                  if (value ==
                          null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Enter city';
                  }

                  return null;
                },
              ),

              inputField(
                controller:
                    pincodeController,
                label:
                    'PIN Code',
                hint:
                    'Enter 6 digit PIN code',
                icon:
                    Icons.pin_drop_outlined,
                keyboardType:
                    TextInputType.number,
                maxLength:
                    6,
                validator:
                    (value) {
                  if (!RegExp(
                    r'^[0-9]{6}$',
                  ).hasMatch(
                    value?.trim() ??
                        '',
                  )) {
                    return 'Enter a valid 6 digit PIN code';
                  }

                  return null;
                },
              ),

              // ==================================================
              // OPTIONAL LOCATION
              // ==================================================

              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                          ),
                          SizedBox(
                            width: 8,
                          ),
                          Text(
                            'Delivery Location',
                            style:
                                TextStyle(
                              fontSize:
                                  17,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Optional: Latitude and Longitude can help with better delivery.',
                        style:
                            TextStyle(
                          color:
                              Colors.grey.shade700,
                          fontSize:
                              13,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child:
                                TextFormField(
                              controller:
                                  latitudeController,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal:
                                    true,
                                signed:
                                    true,
                              ),
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Latitude',
                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    12,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Expanded(
                            child:
                                TextFormField(
                              controller:
                                  longitudeController,
                              keyboardType:
                                  const TextInputType
                                      .numberWithOptions(
                                decimal:
                                    true,
                                signed:
                                    true,
                              ),
                              decoration:
                                  InputDecoration(
                                labelText:
                                    'Longitude',
                                border:
                                    OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(
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

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // SELF / GIFT
              // ==================================================

              const Text(
                'Who is this order for?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value:
                          false,
                      groupValue:
                          isGift,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  setState(() {
                                    isGift =
                                        false;
                                  });
                                },
                      title:
                          const Text(
                        'For Myself',
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
                      value:
                          true,
                      groupValue:
                          isGift,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  setState(() {
                                    isGift =
                                        true;
                                  });
                                },
                      title:
                          const Text(
                        'Gift for Someone',
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
                const SizedBox(
                  height: 14,
                ),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(
                      14,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gift Recipient Details',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 12,
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
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Enter recipient name';
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
                          maxLength:
                              10,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            return mobileValidator(
                              value,
                            );
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
                          maxLines:
                              3,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value
                                        .trim()
                                        .length <
                                    5) {
                              return 'Enter recipient address';
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
                              Icons.location_city_outlined,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Enter recipient city';
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
                          maxLength:
                              6,
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
                              return 'Enter a valid 6 digit PIN code';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              // ==================================================
              // PAYMENT
              // ==================================================

              Card(
                child: ListTile(
                  leading:
                      const Icon(
                    Icons.payments_outlined,
                  ),
                  title:
                      const Text(
                    'Cash on Delivery',
                    style:
                        TextStyle(
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
                    color:
                        Colors.green,
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

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

              const SizedBox(
                height: 12,
              ),

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
                                const EdgeInsets.only(
                              bottom: 12,
                            ),
                            child:
                                Row(
                              children: [
                                Expanded(
                                  child:
                                      Text(
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
                            style:
                                TextStyle(
                              fontSize:
                                  19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(
                              total,
                            ),
                            style:
                                const TextStyle(
                              fontSize:
                                  22,
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

              const SizedBox(
                height: 22,
              ),

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
                  icon:
                      placingOrder
                          ? const SizedBox(
                              width:
                                  22,
                              height:
                                  22,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth:
                                    2,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .shopping_bag_outlined,
                            ),
                  label:
                      Text(
                    placingOrder
                        ? 'Placing Order...'
                        : 'Place Order',
                    style:
                        const TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              const Text(
                'Stock is reduced only after the order is successfully created.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  fontSize:
                      12,
                ),
              ),

              const SizedBox(
                height: 5,
              ),

              const Text(
                'WhatsApp confirmation can be opened for the customer and gift recipient.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.grey,
                  fontSize:
                      12,
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
