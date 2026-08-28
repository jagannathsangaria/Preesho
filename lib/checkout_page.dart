import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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

  // Optional customer email
  final emailController = TextEditingController();

  // ============================================================
  // GIFT DETAILS
  // ============================================================

  bool isGift = false;

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  // ============================================================
  // LOCATION
  // ============================================================

  double? latitude;
  double? longitude;
  bool gettingLocation = false;

  bool placingOrder = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      nameController.text = user.displayName ?? '';
      emailController.text = user.email ?? '';
    }

    loadCustomerData();
  }

  // ============================================================
  // LOAD CUSTOMER DATA
  // ============================================================

  Future<void> loadCustomerData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) return;

      final data = snapshot.data();

      if (data == null) return;

      if (!mounted) return;

      setState(() {
        if (nameController.text.trim().isEmpty) {
          nameController.text =
              data['name']?.toString() ?? '';
        }

        mobileController.text =
            data['mobile']?.toString() ?? '';

        emailController.text =
            data['email']?.toString() ??
                FirebaseAuth.instance.currentUser?.email ??
                '';
      });
    } catch (_) {
      // Customer data loading failure should not block checkout.
    }
  }

  // ============================================================
  // GET LOCATION
  // LOCATION IS OPTIONAL
  // ============================================================

  Future<void> getCurrentLocation() async {
    setState(() {
      gettingLocation = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        showMessage(
          'Location service is turned off. You can continue without location.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showMessage(
          'Location permission not available. Location is optional.',
        );
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      showMessage(
        'Location added successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not get location. You can continue without it.',
      );
    } finally {
      if (mounted) {
        setState(() {
          gettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // WHATSAPP
  //
  // Opens WhatsApp with order information.
  // This is NOT WhatsApp Business API yet.
  // ============================================================

  Future<void> openWhatsApp({
    required String mobile,
    required String message,
  }) async {
    final cleanMobile =
        mobile.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanMobile.length != 10) {
      showMessage(
        'Invalid WhatsApp mobile number.',
      );
      return;
    }

    final whatsappNumber =
        '91$cleanMobile';

    final uri = Uri.parse(
      'https://wa.me/$whatsappNumber?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        showMessage(
          'WhatsApp could not be opened.',
        );
      }
    } catch (_) {
      if (mounted) {
        showMessage(
          'WhatsApp could not be opened.',
        );
      }
    }
  }

  // ============================================================
  // WHATSAPP MESSAGE
  // ============================================================

  String buildWhatsAppMessage({
    required String orderId,
    required String receiverName,
    required String receiverMobile,
    required String receiverAddress,
    required String receiverCity,
    required String receiverPincode,
    required double totalAmount,
    required bool gift,
  }) {
    final items = CartController.items;

    final itemLines = items.map((item) {
      return '• ${item.name} × ${item.quantity} - ${money(item.totalPrice)}';
    }).join('\n');

    return '''
Preesho Order Confirmation

Order ID:
$orderId

Customer:
${nameController.text.trim()}

Customer Mobile:
${mobileController.text.trim()}

Order Type:
${gift ? 'Gift Order' : 'Self Order'}

Delivery To:
$receiverName
$receiverMobile
$receiverAddress
$receiverCity - $receiverPincode

Items:
$itemLines

Total Amount:
${money(totalAmount)}

Payment:
Cash on Delivery

${latitude != null && longitude != null ? 'Delivery Location:\nLatitude: $latitude\nLongitude: $longitude\n' : ''}

Thank you for shopping with Preesho.
''';
  }

  // ============================================================
  // PLACE ORDER
  // ============================================================

  Future<void> placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (CartController.items.isEmpty) {
      showMessage(
        'Your cart is empty.',
      );
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Please login with mobile number and OTP before placing an order.',
      );
      return;
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
      // DELIVERY DETAILS
      // ========================================================

      final deliveryName = isGift
          ? giftNameController.text.trim()
          : nameController.text.trim();

      final deliveryMobile = isGift
          ? giftMobileController.text.trim()
          : mobileController.text.trim();

      final deliveryAddress = isGift
          ? giftAddressController.text.trim()
          : addressController.text.trim();

      final deliveryCity = isGift
          ? giftCityController.text.trim()
          : cityController.text.trim();

      final deliveryPincode = isGift
          ? giftPincodeController.text.trim()
          : pincodeController.text.trim();

      // ========================================================
      // FIRESTORE TRANSACTION
      // STOCK + ORDER CREATED TOGETHER
      // ========================================================

      await firestore.runTransaction(
        (transaction) async {
          final productSnapshots =
              <String,
                  DocumentSnapshot<Map<String, dynamic>>>{};

          // ----------------------------------------------------
          // READ ALL PRODUCTS FIRST
          // ----------------------------------------------------

          for (final cartItem in cartItems) {
            final productRef = firestore
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
            final snapshot =
                productSnapshots[
                    cartItem.product.id];

            if (snapshot == null ||
                !snapshot.exists) {
              throw Exception(
                '${cartItem.name} is no longer available.',
              );
            }

            final data =
                snapshot.data() ?? {};

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
                    .doc(
                      cartItem.product.id,
                    );

            transaction.update(
              productRef,
              {
                'Stock': newStock,
              },
            );

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

          // ----------------------------------------------------
          // CREATE ORDER
          // ----------------------------------------------------

          final orderData =
              <String, dynamic>{
            'userId':
                user.uid,

            'customerName':
                nameController.text.trim(),

            'customerMobile':
                mobileController.text.trim(),

            'customerEmail':
                emailController.text.trim(),

            'orderType':
                isGift ? 'Gift' : 'Self',

            'deliveryName':
                deliveryName,

            'deliveryMobile':
                deliveryMobile,

            'deliveryAddress':
                deliveryAddress,

            'deliveryCity':
                deliveryCity,

            'deliveryPincode':
                deliveryPincode,

            'isGift':
                isGift,

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
          };

          // ----------------------------------------------------
          // OPTIONAL LOCATION
          // ----------------------------------------------------

          if (latitude != null &&
              longitude != null) {
            orderData['latitude'] =
                latitude;

            orderData['longitude'] =
                longitude;
          }

          // ----------------------------------------------------
          // GIFT RECIPIENT DETAILS
          // ----------------------------------------------------

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

      final whatsappMessage =
          buildWhatsAppMessage(
        orderId: orderRef.id,
        receiverName: deliveryName,
        receiverMobile: deliveryMobile,
        receiverAddress:
            deliveryAddress,
        receiverCity:
            deliveryCity,
        receiverPincode:
            deliveryPincode,
        totalAmount: totalAmount,
        gift: isGift,
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
                'Stock has been updated.',
              ),
            ),
            actions: [
              if (!isGift)
                TextButton(
                  onPressed: () async {
                    await openWhatsApp(
                      mobile:
                          mobileController.text
                              .trim(),
                      message:
                          whatsappMessage,
                    );
                  },
                  child: const Text(
                    'WhatsApp',
                  ),
                ),

              if (isGift)
                TextButton(
                  onPressed: () async {
                    await openWhatsApp(
                      mobile:
                          mobileController.text
                              .trim(),
                      message:
                          whatsappMessage,
                    );
                  },
                  child: const Text(
                    'Customer WhatsApp',
                  ),
                ),

              if (isGift)
                TextButton(
                  onPressed: () async {
                    await openWhatsApp(
                      mobile:
                          giftMobileController
                              .text
                              .trim(),
                      message:
                          whatsappMessage,
                    );
                  },
                  child: const Text(
                    'Gift WhatsApp',
                  ),
                ),

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

      Navigator.pop(
        context,
        true,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      showMessage(
        'Order failed:\n${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
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
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          counterText:
              maxLength != null ? '' : null,
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

                  if (value.trim().length <
                      2) {
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
                    '10 digit mobile number',
                icon:
                    Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  final mobile =
                      value?.trim() ?? '';

                  if (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(mobile)) {
                    return
                        'Enter a valid 10 digit mobile number';
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
                label: 'Email (Optional)',
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
                      value.trim().length <
                          5) {
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
                maxLength: 6,
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
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Delivery Location',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            'Optional',
                            style:
                                TextStyle(
                              color:
                                  Colors.grey,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        latitude != null &&
                                longitude !=
                                    null
                            ? 'Location added\nLat: $latitude\nLong: $longitude'
                            : 'Adding location may help with better delivery.',
                        style: TextStyle(
                          color:
                              Colors.grey.shade700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              gettingLocation
                                  ? null
                                  : getCurrentLocation,
                          icon: gettingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                ),
                          label: Text(
                            gettingLocation
                                ? 'Getting Location...'
                                : latitude !=
                                            null &&
                                        longitude !=
                                            null
                                    ? 'Update Location'
                                    : 'Add Current Location',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // SELF OR GIFT
              // ==================================================

              const Text(
                'Who is this order for?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

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
                        'Deliver to my address',
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
                        'Gift for Someone',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Enter recipient details',
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GIFT DETAILS
              // ==================================================

              if (isGift) ...[
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                          validator: (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
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
                          maxLength: 10,
                          validator: (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (!RegExp(
                              r'^[0-9]{10}$',
                            ).hasMatch(
                              value?.trim() ??
                                  '',
                            )) {
                              return
                                  'Enter a valid 10 digit number';
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
                          validator: (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
                                value.trim()
                                        .length <
                                    5) {
                              return
                                  'Enter recipient address';
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
                          validator: (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
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
                          maxLength: 6,
                          validator: (value) {
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
                                  'Enter a valid 6 digit PIN code';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

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

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    emailController.dispose();

    giftNameController.dispose();
    giftMobileController.dispose();
    giftAddressController.dispose();
    giftCityController.dispose();
    giftPincodeController.dispose();

    super.dispose();
  }
}
