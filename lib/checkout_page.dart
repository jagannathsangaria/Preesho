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

  // ============================================================
  // GIFT DETAILS
  // ============================================================

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  bool placingOrder = false;
  bool gettingLocation = false;

  // true = self
  // false = gift
  bool isSelfOrder = true;

  // ============================================================
  // OPTIONAL LOCATION
  // ============================================================

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      nameController.text = user.displayName ?? '';

      // If Firebase phone authentication is being used,
      // Firebase may already contain the customer's phone.
      final phone = user.phoneNumber ?? '';

      if (phone.isNotEmpty) {
        String cleanPhone = phone.replaceAll('+91', '');

        if (cleanPhone.length == 10) {
          mobileController.text = cleanPhone;
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

    super.dispose();
  }

  // ============================================================
  // MONEY
  // ============================================================

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // GET OPTIONAL LOCATION
  // ============================================================

  Future<void> getCurrentLocation() async {
    if (gettingLocation) return;

    setState(() {
      gettingLocation = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location service is disabled. You can continue without location.',
            ),
          ),
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
          permission ==
              LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission not available. Location is optional.',
            ),
          ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location added successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not get location. You can continue without it.',
          ),
        ),
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
  // WHATSAPP NUMBER
  // ============================================================

  String whatsappNumber(String mobile) {
    String number =
        mobile.replaceAll(RegExp(r'[^0-9]'), '');

    if (number.startsWith('91') &&
        number.length == 12) {
      return number;
    }

    if (number.length == 10) {
      return '91$number';
    }

    return number;
  }

  // ============================================================
  // OPEN WHATSAPP
  // ============================================================

  Future<void> openWhatsApp({
    required String mobile,
    required String message,
  }) async {
    final number = whatsappNumber(mobile);

    if (number.isEmpty) return;

    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'WhatsApp could not be opened.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open WhatsApp.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // WHATSAPP MESSAGE
  // ============================================================

  String createWhatsAppMessage({
    required String orderId,
    required bool gift,
    required String receiverName,
    required String receiverMobile,
    required String receiverAddress,
    required String receiverCity,
    required String receiverPincode,
    required double totalAmount,
  }) {
    final items = CartController.items;

    final itemText = items.map((item) {
      return '• ${item.name} x${item.quantity} - ${money(item.totalPrice)}';
    }).join('\n');

    return '''
Preesho Order Confirmation 🛍️

Order ID:
$orderId

Customer:
${nameController.text.trim()}

Customer Mobile:
${mobileController.text.trim()}

Order Type:
${gift ? 'Gift Order 🎁' : 'Self Order'}

${gift ? '''
Gift Recipient:
$receiverName

Recipient Mobile:
$receiverMobile

Delivery Address:
$receiverAddress
$receiverCity - $receiverPincode
''' : '''
Delivery Address:
${addressController.text.trim()}
${cityController.text.trim()} - ${pincodeController.text.trim()}
'''}

Items:
$itemText

Total Amount:
${money(totalAmount)}

Payment:
Cash on Delivery

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your cart is empty.',
          ),
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

      await firestore.runTransaction(
        (transaction) async {
          // ======================================================
          // READ ALL PRODUCTS FIRST
          // ======================================================

          final productSnapshots =
              <String,
                  DocumentSnapshot<Map<String, dynamic>>>{};

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

          // ======================================================
          // CHECK STOCK + CREATE ORDER ITEMS
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

            final productRef = firestore
                .collection('products')
                .doc(cartItem.product.id);

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
          // GIFT DATA
          // ======================================================

          final giftData =
              isSelfOrder
                  ? null
                  : <String, dynamic>{
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

          // ======================================================
          // CREATE ORDER
          // ======================================================

          transaction.set(
            orderRef,
            {
              'userId':
                  user.uid,

              'customerName':
                  nameController.text.trim(),

              'mobile':
                  mobileController.text.trim(),

              'address':
                  addressController.text.trim(),

              'city':
                  cityController.text.trim(),

              'pincode':
                  pincodeController.text.trim(),

              'customer':
                  customerData,

              'orderType':
                  isSelfOrder
                      ? 'Self'
                      : 'Gift',

              'isGift':
                  !isSelfOrder,

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

              // ==================================================
              // OPTIONAL LOCATION
              // ==================================================

              'latitude':
                  latitude,

              'longitude':
                  longitude,

              'locationAdded':
                  latitude != null &&
                      longitude != null,

              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // CLEAR CART AFTER SUCCESS
      // ========================================================

      CartController.clear();

      final recipientName =
          isSelfOrder
              ? nameController.text.trim()
              : giftNameController.text.trim();

      final recipientMobile =
          isSelfOrder
              ? mobileController.text.trim()
              : giftMobileController.text.trim();

      final recipientAddress =
          isSelfOrder
              ? addressController.text.trim()
              : giftAddressController.text.trim();

      final recipientCity =
          isSelfOrder
              ? cityController.text.trim()
              : giftCityController.text.trim();

      final recipientPincode =
          isSelfOrder
              ? pincodeController.text.trim()
              : giftPincodeController.text.trim();

      final message =
          createWhatsAppMessage(
        orderId: orderRef.id,
        gift: !isSelfOrder,
        receiverName: recipientName,
        receiverMobile: recipientMobile,
        receiverAddress: recipientAddress,
        receiverCity: recipientCity,
        receiverPincode: recipientPincode,
        totalAmount: totalAmount,
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
                'WhatsApp confirmation is ready for sharing.',
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Continue',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // WHATSAPP OPTIONS
      // ========================================================

      await showModalBottomSheet(
        context: context,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Share Order on WhatsApp',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    'Choose which number should receive the order information.',
                    textAlign:
                        TextAlign.center,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(
                        sheetContext,
                      );

                      await openWhatsApp(
                        mobile:
                            mobileController
                                .text
                                .trim(),
                        message:
                            message,
                      );
                    },
                    icon: const Icon(
                      Icons.person,
                    ),
                    label: Text(
                      'Customer WhatsApp\n${mobileController.text.trim()}',
                      textAlign:
                          TextAlign.center,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  if (!isSelfOrder)
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(
                          sheetContext,
                        );

                        await openWhatsApp(
                          mobile:
                              giftMobileController
                                  .text
                                  .trim(),
                          message:
                              message,
                        );
                      },
                      icon: const Icon(
                        Icons.card_giftcard,
                      ),
                      label: Text(
                        'Gift Recipient WhatsApp\n${giftMobileController.text.trim()}',
                        textAlign:
                            TextAlign.center,
                      ),
                    ),

                  const SizedBox(
                    height: 12,
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                      );
                    },
                    child:
                        const Text(
                      'Skip WhatsApp',
                    ),
                  ),
                ],
              ),
            ),
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
          prefixIcon:
              Icon(icon),
          counterText:
              maxLength != null
                  ? ''
                  : null,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE VALIDATOR
  // ============================================================

  String? validateMobile(
    String? value,
  ) {
    final mobile =
        value?.trim() ?? '';

    if (mobile.isEmpty) {
      return 'Mobile number is required';
    }

    if (!RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(mobile)) {
      return 'Enter exactly 10 digit mobile number';
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
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return
                        'Enter your name';
                  }

                  if (value
                          .trim()
                          .length <
                      2) {
                    return
                        'Enter a valid name';
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
                    'Enter 10 digit mobile number',
                icon:
                    Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                maxLength: 10,
                validator:
                    validateMobile,
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
                maxLines: 3,
                validator:
                    (value) {
                  if (value == null ||
                      value
                              .trim()
                              .length <
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
                label:
                    'City',
                hint:
                    'Enter your city',
                icon:
                    Icons.location_city_outlined,
                validator:
                    (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return
                        'Enter city';
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
                maxLength: 6,
                validator:
                    (value) {
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
                          Expanded(
                            child: Text(
                              'Delivery Location',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize:
                                    16,
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

                      const SizedBox(
                        height: 8,
                      ),

                      if (latitude != null &&
                          longitude != null)
                        Text(
                          'Latitude: ${latitude!.toStringAsFixed(6)}\n'
                          'Longitude: ${longitude!.toStringAsFixed(6)}',
                          style:
                              const TextStyle(
                            fontSize: 13,
                          ),
                        )
                      else
                        const Text(
                          'Adding your location can help with better delivery.',
                          style:
                              TextStyle(
                            color:
                                Colors.grey,
                          ),
                        ),

                      const SizedBox(
                        height: 10,
                      ),

                      OutlinedButton.icon(
                        onPressed:
                            gettingLocation
                                ? null
                                : getCurrentLocation,
                        icon:
                            gettingLocation
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
                                    Icons
                                        .my_location,
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
                  fontSize: 21,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      value: true,
                      groupValue:
                          isSelfOrder,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setState(() {
                                    isSelfOrder =
                                        value;
                                  });
                                },
                      title:
                          const Text(
                        'For myself',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle:
                          const Text(
                        'I am ordering for myself',
                      ),
                    ),

                    RadioListTile<bool>(
                      value: false,
                      groupValue:
                          isSelfOrder,
                      onChanged:
                          placingOrder
                              ? null
                              : (value) {
                                  if (value ==
                                      null) {
                                    return;
                                  }

                                  setState(() {
                                    isSelfOrder =
                                        value;
                                  });
                                },
                      title:
                          const Text(
                        'Gift for someone 🎁',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle:
                          const Text(
                        'I am ordering for another person',
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GIFT DETAILS
              // ==================================================

              if (!isSelfOrder) ...[
                const SizedBox(
                  height: 16,
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
                        const Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                            ),
                            SizedBox(
                              width: 8,
                            ),
                            Text(
                              'Gift Recipient Details',
                              style:
                                  TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
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
                            if (!isSelfOrder) {
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
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftMobileController,
                          label:
                              'Recipient Mobile Number',
                          hint:
                              'Enter 10 digit recipient number',
                          icon:
                              Icons.phone_outlined,
                          keyboardType:
                              TextInputType.phone,
                          maxLength: 10,
                          validator:
                              (value) {
                            if (!isSelfOrder) {
                              return
                                  validateMobile(
                                value,
                              );
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
                            if (!isSelfOrder) {
                              if (value ==
                                      null ||
                                  value
                                          .trim()
                                          .length <
                                      5) {
                                return
                                    'Enter complete recipient address';
                              }
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
                            if (!isSelfOrder) {
                              if (value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty) {
                                return
                                    'Enter recipient city';
                              }
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
                              'Enter 6 digit PIN code',
                          icon:
                              Icons.pin_drop_outlined,
                          keyboardType:
                              TextInputType.number,
                          maxLength: 6,
                          validator:
                              (value) {
                            if (!isSelfOrder) {
                              if (!RegExp(
                                r'^[0-9]{6}$',
                              ).hasMatch(
                                value?.trim() ??
                                    '',
                              )) {
                                return
                                    'Enter a valid 6 digit PIN code';
                              }
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
                            style:
                                TextStyle(
                              fontSize:
                                  19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(total),
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
                              width: 22,
                              height: 22,
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
                  label: Text(
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
                'Your location is optional and is used only to help with delivery.',
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
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
