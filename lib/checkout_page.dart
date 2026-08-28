import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

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

  double? latitude;
  double? longitude;

  bool gettingLocation = false;
  bool placingOrder = false;

  // false = Self
  // true = Gift
  bool isGift = false;

  @override
  void initState() {
    super.initState();
    loadCustomerDetails();
  }

  // ============================================================
  // LOAD CUSTOMER DATA
  // ============================================================

  Future<void> loadCustomerDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    // Firebase Auth mobile number
    final authMobile = user.phoneNumber ?? '';

    if (authMobile.isNotEmpty) {
      final cleanMobile = authMobile.replaceAll(
        RegExp(r'^\+91'),
        '',
      );

      mobileController.text = cleanMobile;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data() ?? {};

      nameController.text =
          data['name']?.toString() ??
          user.displayName ??
          '';

      emailController.text =
          data['email']?.toString() ??
          user.email ??
          '';

      final savedMobile =
          data['mobile']?.toString() ?? '';

      if (savedMobile.isNotEmpty) {
        mobileController.text = savedMobile;
      }
    } catch (_) {
      nameController.text = user.displayName ?? '';
      emailController.text = user.email ?? '';
    }

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // GET CURRENT LOCATION
  // LOCATION IS OPTIONAL
  // ============================================================

  Future<void> getLocation() async {
    if (gettingLocation) return;

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

      if (permission == LocationPermission.denied) {
        showMessage(
          'Location permission denied. Location is optional.',
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        showMessage(
          'Location permission permanently denied. You can continue without location.',
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
        'Location captured successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Unable to get location. You can continue without it.',
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
  // PLACE ORDER
  // ============================================================

  Future<void> placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (CartController.items.isEmpty) {
      showMessage('Your cart is empty.');
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Please login with your mobile number before placing an order.',
      );
      return;
    }

    // ==========================================================
    // GIFT VALIDATION
    // ==========================================================

    if (isGift) {
      final giftMobile =
          giftMobileController.text.trim();

      if (!RegExp(
        r'^[0-9]{10}$',
      ).hasMatch(giftMobile)) {
        showMessage(
          'Gift recipient mobile number must be exactly 10 digits.',
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
      // WHATSAPP NUMBERS
      // ==========================================================

      final customerMobile =
          mobileController.text.trim();

      final giftMobile =
          isGift
              ? giftMobileController.text.trim()
              : '';

      // Customer WhatsApp number
      final customerWhatsApp =
          '+91$customerMobile';

      // Gift recipient WhatsApp number
      final giftWhatsApp =
          isGift && giftMobile.isNotEmpty
              ? '+91$giftMobile'
              : '';

      // ==========================================================
      // TRANSACTION
      // ==========================================================

      await firestore.runTransaction(
        (transaction) async {
          final productSnapshots =
              <String,
                  DocumentSnapshot<
                      Map<String, dynamic>>>{};

          // ------------------------------------------------------
          // READ ALL PRODUCTS FIRST
          // ------------------------------------------------------

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

          // ------------------------------------------------------
          // CHECK STOCK
          // ------------------------------------------------------

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
          // CREATE ORDER
          // ======================================================

          transaction.set(
            orderRef,
            {
              // --------------------------------------------------
              // BASIC ORDER
              // --------------------------------------------------

              'userId': user.uid,

              'customerName':
                  nameController.text.trim(),

              'customerMobile':
                  customerMobile,

              'customerWhatsApp':
                  customerWhatsApp,

              'customerEmail':
                  emailController.text.trim(),

              'customerAddress':
                  addressController.text.trim(),

              'customerCity':
                  cityController.text.trim(),

              'customerPincode':
                  pincodeController.text.trim(),

              // --------------------------------------------------
              // SELF / GIFT
              // --------------------------------------------------

              'orderFor':
                  isGift ? 'Gift' : 'Self',

              'isGift':
                  isGift,

              // --------------------------------------------------
              // GIFT RECIPIENT
              // --------------------------------------------------

              'giftRecipient':
                  isGift
                      ? {
                          'name':
                              giftNameController.text.trim(),
                          'mobile':
                              giftMobile,
                          'whatsApp':
                              giftWhatsApp,
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

              // --------------------------------------------------
              // LOCATION
              // OPTIONAL
              // --------------------------------------------------

              'deliveryLocation':
                  latitude != null &&
                          longitude != null
                      ? {
                          'latitude':
                              latitude,
                          'longitude':
                              longitude,
                        }
                      : null,

              'latitude':
                  latitude,

              'longitude':
                  longitude,

              // --------------------------------------------------
              // ITEMS
              // --------------------------------------------------

              'items':
                  orderItems,

              'totalAmount':
                  totalAmount,

              // --------------------------------------------------
              // PAYMENT
              // --------------------------------------------------

              'status':
                  'Placed',

              'paymentMethod':
                  'Cash on Delivery',

              // --------------------------------------------------
              // WHATSAPP READY DATA
              // --------------------------------------------------

              'whatsappNotifications':
                  {
                'customer':
                    customerWhatsApp,
                'giftRecipient':
                    giftWhatsApp,
                'sendToCustomer':
                    true,
                'sendToGiftRecipient':
                    isGift,
                'apiStatus':
                    'Pending',
              },

              // --------------------------------------------------
              // TIMESTAMP
              // --------------------------------------------------

              'createdAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) return;

      // ==========================================================
      // CLEAR CART ONLY AFTER SUCCESS
      // ==========================================================

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
                  child: Text(
                    'Order Placed',
                  ),
                ),
              ],
            ),
            content: Text(
              isGift
                  ? 'Your gift order has been placed successfully.\n\n'
                    'Order ID:\n${orderRef.id}\n\n'
                    'Customer WhatsApp:\n$customerWhatsApp\n\n'
                    'Gift Recipient WhatsApp:\n$giftWhatsApp\n\n'
                    'Stock has been updated.'
                  : 'Your order has been placed successfully.\n\n'
                    'Order ID:\n${orderRef.id}\n\n'
                    'WhatsApp:\n$customerWhatsApp\n\n'
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
      padding:
          const EdgeInsets.only(bottom: 14),
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
  // MESSAGE
  // ============================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration:
            const Duration(seconds: 4),
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
    emailController.dispose();
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
                  final mobile =
                      value?.trim() ?? '';

                  if (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(mobile)) {
                    return
                        'Mobile number must be 10 digits';
                  }

                  return null;
                },
              ),

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
                        'Enter a valid 6 digit PIN code';
                  }

                  return null;
                },
              ),

              // ==================================================
              // LOCATION
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
                            Icons.location_on,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delivery Location',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 6),

                      const Text(
                        'GPS location is optional but can help with better delivery.',
                        style:
                            TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(
                          height: 10),

                      if (latitude != null &&
                          longitude != null)
                        Text(
                          'Latitude: ${latitude!.toStringAsFixed(6)}\n'
                          'Longitude: ${longitude!.toStringAsFixed(6)}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),

                      const SizedBox(
                          height: 8),

                      OutlinedButton.icon(
                        onPressed:
                            gettingLocation
                                ? null
                                : getLocation,
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
                              : latitude != null
                                  ? 'Update Location'
                                  : 'Add Current Location',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // SELF / GIFT
              // ==================================================

              const Text(
                'Order For',
                style: TextStyle(
                  fontSize: 21,
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
                      onChanged: (value) {
                        setState(() {
                          isGift = false;
                        });
                      },
                      title: const Text(
                        'For Myself',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Deliver the order to me',
                      ),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: isGift,
                      onChanged: (value) {
                        setState(() {
                          isGift = true;
                        });
                      },
                      title: const Text(
                        'Gift Someone',
                        style:
                            TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: const Text(
                        'Send this order to someone else',
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // GIFT DETAILS
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
                          'Gift Recipient Details',
                          style:
                              TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                            height: 14),

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
                              'Recipient Mobile Number',
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

                            final mobile =
                                value?.trim() ??
                                    '';

                            if (!RegExp(
                              r'^[0-9]{10}$',
                            ).hasMatch(
                                mobile)) {
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
                                  'Enter a valid 6 digit PIN code';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(
                            height: 4),

                        const Text(
                          'Gift recipient will also receive the order information on WhatsApp once the WhatsApp API is connected.',
                          style:
                              TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
                    Icons.payments_outlined,
                  ),
                  title: const Text(
                    'Cash on Delivery',
                    style:
                        TextStyle(
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

              const SizedBox(height: 22),

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
                                  '₹${item.totalPrice.toStringAsFixed(0)}',
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
                              fontSize: 19,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
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
                        : isGift
                            ? 'Place Gift Order'
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
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'WhatsApp numbers are saved with the order for notification.',
                textAlign:
                    TextAlign.center,
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
