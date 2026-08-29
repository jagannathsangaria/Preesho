import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'main.dart';
import 'login_page.dart';

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
  final emailController = TextEditingController();

  // ============================================================
  // GIFT DETAILS
  // ============================================================

  final giftNameController = TextEditingController();
  final giftMobileController = TextEditingController();
  final giftAddressController = TextEditingController();
  final giftCityController = TextEditingController();
  final giftPincodeController = TextEditingController();

  bool placingOrder = false;
  bool isGift = false;

  // ============================================================
  // LOCATION
  // ============================================================

  bool gettingLocation = false;
  double? latitude;
  double? longitude;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    loadCurrentUser();
  }

  // ============================================================
  // LOAD CURRENT USER
  // ============================================================

  Future<void> loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      if (user.displayName != null &&
          user.displayName!.trim().isNotEmpty) {
        nameController.text = user.displayName!;
      }

      if (user.email != null &&
          user.email!.trim().isNotEmpty) {
        emailController.text = user.email!;
      }

      // Phone login user
      if (user.phoneNumber != null &&
          user.phoneNumber!.isNotEmpty) {
        mobileController.text =
            cleanPhoneNumber(user.phoneNumber!);
      }

      await loadUserDetails(user.uid);

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ============================================================
  // CLEAN PHONE NUMBER
  // ============================================================

  String cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll('+91', '');
    cleaned = cleaned.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleaned.length > 10) {
      cleaned = cleaned.substring(
        cleaned.length - 10,
      );
    }

    return cleaned;
  }

  // ============================================================
  // LOAD SAVED USER DETAILS
  // ============================================================

  Future<void> loadUserDetails(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data();

      if (data == null) return;

      if (nameController.text.trim().isEmpty) {
        nameController.text =
            data['name']?.toString() ?? '';
      }

      if (mobileController.text.trim().isEmpty) {
        mobileController.text =
            data['mobile']?.toString() ?? '';
      }

      if (emailController.text.trim().isEmpty) {
        emailController.text =
            data['email']?.toString() ?? '';
      }
    } catch (_) {}
  }

  // ============================================================
  // LOGIN BUTTON
  // ============================================================

  Future<void> goToLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );

    await loadCurrentUser();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // LOCATION
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
          'Location permission denied. You can continue without location.',
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });

      showMessage('Location captured successfully.');
    } catch (_) {
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
  // PLACE ORDER
  // ============================================================

  Future<void> placeOrder() async {
    // ==========================================================
    // LOGIN CHECK FIRST
    // ==========================================================

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showLoginRequiredDialog();
      return;
    }

    // ==========================================================
    // FORM VALIDATION
    // ==========================================================

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (CartController.items.isEmpty) {
      showMessage('Your cart is empty.');
      return;
    }

    if (isGift) {
      if (!_validateGiftDetails()) {
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

      await firestore.runTransaction(
        (transaction) async {
          // ======================================================
          // READ PRODUCTS
          // ======================================================

          final productSnapshots =
              <String,
                  DocumentSnapshot<
                      Map<String, dynamic>>>{};

          for (final cartItem in cartItems) {
            final productRef = firestore
                .collection('products')
                .doc(cartItem.product.id);

            final snapshot =
                await transaction.get(productRef);

            productSnapshots[
                cartItem.product.id] = snapshot;
          }

          // ======================================================
          // STOCK CHECK
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
          // CREATE ORDER
          // ======================================================

          final orderData =
              <String, dynamic>{
            'userId': user.uid,

            'customerName':
                nameController.text.trim(),

            'customerMobile':
                mobileController.text.trim(),

            'customerEmail':
                emailController.text.trim(),

            'customerAddress':
                addressController.text.trim(),

            'customerCity':
                cityController.text.trim(),

            'customerPincode':
                pincodeController.text.trim(),

            // SELF / GIFT

            'orderFor':
                isGift ? 'Gift' : 'Self',

            'isGift': isGift,

            // GIFT DETAILS

            'giftReceiverName':
                isGift
                    ? giftNameController.text.trim()
                    : null,

            'giftReceiverMobile':
                isGift
                    ? giftMobileController.text.trim()
                    : null,

            'giftReceiverAddress':
                isGift
                    ? giftAddressController.text.trim()
                    : null,

            'giftReceiverCity':
                isGift
                    ? giftCityController.text.trim()
                    : null,

            'giftReceiverPincode':
                isGift
                    ? giftPincodeController.text.trim()
                    : null,

            // LOCATION

            'latitude': latitude,

            'longitude': longitude,

            'locationAvailable':
                latitude != null &&
                    longitude != null,

            // ITEMS

            'items': orderItems,

            'totalAmount': totalAmount,

            'status': 'Placed',

            'paymentMethod':
                'Cash on Delivery',

            // WHATSAPP

            'whatsappCustomerMobile':
                mobileController.text.trim(),

            'whatsappGiftReceiverMobile':
                isGift
                    ? giftMobileController.text.trim()
                    : null,

            'whatsappNotificationRequired':
                true,

            'createdAt':
                FieldValue.serverTimestamp(),
          };

          transaction.set(
            orderRef,
            orderData,
          );
        },
      );

      if (!mounted) return;

      // ========================================================
      // SAVE CUSTOMER DETAILS
      // ========================================================

      try {
        await firestore
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,

            'name':
                nameController.text.trim(),

            'mobile':
                mobileController.text.trim(),

            'email':
                emailController.text.trim(),

            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {}

      // ========================================================
      // CLEAR CART
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
              'Stock has been updated.'
              '${latitude != null && longitude != null ? '\n\nDelivery location saved.' : ''}'
              '${isGift ? '\n\nGift receiver details saved.' : ''}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child:
                    const Text('Continue Shopping'),
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
  // LOGIN REQUIRED DIALOG
  // ============================================================

  void showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.phone_android,
            size: 42,
          ),
          title: const Text(
            'Login Required',
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Please login with your mobile number before placing an order.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                goToLogin();
              },
              icon: const Icon(Icons.phone),
              label: const Text(
                'Login with Mobile',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // GIFT VALIDATION
  // ============================================================

  bool _validateGiftDetails() {
    final name =
        giftNameController.text.trim();

    final mobile =
        giftMobileController.text.trim();

    final address =
        giftAddressController.text.trim();

    final city =
        giftCityController.text.trim();

    final pincode =
        giftPincodeController.text.trim();

    if (name.length < 2) {
      showMessage(
        'Please enter gift receiver name.',
      );
      return false;
    }

    if (!RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(mobile)) {
      showMessage(
        'Gift receiver mobile must be exactly 10 digits.',
      );
      return false;
    }

    if (address.length < 5) {
      showMessage(
        'Please enter complete gift receiver address.',
      );
      return false;
    }

    if (city.isEmpty) {
      showMessage(
        'Please enter gift receiver city.',
      );
      return false;
    }

    if (!RegExp(
      r'^[0-9]{6}$',
    ).hasMatch(pincode)) {
      showMessage(
        'Gift receiver PIN code must be exactly 6 digits.',
      );
      return false;
    }

    return true;
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    final total =
        items.fold<double>(
      0,
      (sum, item) =>
          sum + item.totalPrice,
    );

    final user =
        FirebaseAuth.instance.currentUser;

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
              // LOGIN STATUS CARD
              // ==================================================

              if (user == null)
                Card(
                  color: Colors.deepPurple
                      .withValues(alpha: 0.08),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          size: 38,
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Login to Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        const Text(
                          'Login with your mobile number to place your order',
                          textAlign:
                              TextAlign.center,
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child:
                              FilledButton.icon(
                            onPressed:
                                goToLogin,
                            icon: const Icon(
                              Icons.phone,
                            ),
                            label: const Text(
                              'Login with Mobile',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: Colors.green
                      .withValues(alpha: 0.08),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor:
                          Colors.green,
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                      ),
                    ),
                    title: const Text(
                      'Logged In',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      user.phoneNumber ??
                          user.email ??
                          'Customer Account',
                    ),
                    trailing: const Icon(
                      Icons.verified_user,
                      color: Colors.green,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

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
                    'Enter exactly 10 digits',
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
                    return 'Mobile number must be exactly 10 digits';
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

                  if (email.isEmpty) return null;

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
                    return 'Enter a complete address';
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
                    'Enter exactly 6 digits',
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
                    return 'PIN code must be exactly 6 digits';
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
                            Icons.location_on_outlined,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Delivery Location',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        latitude != null &&
                                longitude != null
                            ? 'Location captured successfully'
                            : 'Optional — helps with better delivery',
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
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
                                    strokeWidth: 2,
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
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

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
                                        value ?? false;
                                  });
                                },
                      title: const Text(
                        'For Myself',
                      ),
                      subtitle: const Text(
                        'I am ordering for myself',
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
                                        value ?? false;
                                  });
                                },
                      title: const Text(
                        'Gift Someone',
                      ),
                      subtitle: const Text(
                        'I am ordering for another person',
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
                        const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gift Receiver Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        inputField(
                          controller:
                              giftNameController,
                          label:
                              'Receiver Name',
                          hint:
                              'Enter receiver name',
                          icon:
                              Icons.person_outline,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
                                value.trim().length <
                                    2) {
                              return
                                  'Enter receiver name';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftMobileController,
                          label:
                              'Receiver Mobile Number',
                          hint:
                              'Enter exactly 10 digits',
                          icon:
                              Icons.phone_outlined,
                          keyboardType:
                              TextInputType.phone,
                          maxLength: 10,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (!RegExp(
                              r'^[0-9]{10}$',
                            ).hasMatch(
                              value?.trim() ?? '',
                            )) {
                              return
                                  'Receiver mobile must be exactly 10 digits';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftAddressController,
                          label:
                              'Receiver Address',
                          hint:
                              'Complete address',
                          icon:
                              Icons.home_outlined,
                          maxLines: 3,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
                                value.trim().length <
                                    5) {
                              return
                                  'Enter complete receiver address';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftCityController,
                          label:
                              'Receiver City',
                          hint:
                              'Enter city',
                          icon:
                              Icons.location_city_outlined,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (value == null ||
                                value.trim().isEmpty) {
                              return
                                  'Enter receiver city';
                            }

                            return null;
                          },
                        ),

                        inputField(
                          controller:
                              giftPincodeController,
                          label:
                              'Receiver PIN Code',
                          hint:
                              'Enter 6 digit PIN',
                          icon:
                              Icons.pin_drop_outlined,
                          keyboardType:
                              TextInputType.number,
                          maxLength: 6,
                          validator:
                              (value) {
                            if (!isGift) {
                              return null;
                            }

                            if (!RegExp(
                              r'^[0-9]{6}$',
                            ).hasMatch(
                              value?.trim() ?? '',
                            )) {
                              return
                                  'Receiver PIN must be exactly 6 digits';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

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
                  fontWeight:
                      FontWeight.bold,
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
                        (item) => Padding(
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
                        ),
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
                      : Icon(
                          user == null
                              ? Icons.login
                              : Icons
                                  .shopping_bag_outlined,
                        ),
                  label: Text(
                    placingOrder
                        ? 'Placing Order...'
                        : user == null
                            ? 'Login to Place Order'
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

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
