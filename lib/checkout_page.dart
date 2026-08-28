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

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final pincodeController = TextEditingController();

  bool placingOrder = false;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      nameController.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    cityController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  // ============================================================
  // CHECK CURRENT STOCK
  // ============================================================

  Future<bool> checkStockBeforeOrder() async {
    for (final cartItem in CartController.items) {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(cartItem.id)
          .get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data();

      if (data == null) {
        return false;
      }

      final active = data['Active'] == true;

      final stock =
          int.tryParse(data['Stock']?.toString() ?? '0') ?? 0;

      if (!active || stock <= 0) {
        return false;
      }

      if (cartItem.quantity > stock) {
        return false;
      }
    }

    return true;
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
            'Please login before placing an order',
          ),
        ),
      );
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      // --------------------------------------------------------
      // FIRST CHECK
      // --------------------------------------------------------

      final stockAvailable =
          await checkStockBeforeOrder();

      if (!stockAvailable) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Some items are out of stock or have insufficient stock.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // CREATE ORDER + REDUCE STOCK IN ONE TRANSACTION
      // --------------------------------------------------------

      final firestore =
          FirebaseFirestore.instance;

      final orderItems = CartController.items.map((item) {
        return {
          'productId': item.id,
          'name': item.name,
          'category': item.category,
          'price': item.numericPrice,
          'quantity': item.quantity,
          'total': item.totalPrice,
          'imageUrl': item.imageUrl,
        };
      }).toList();

      final orderRef =
          firestore.collection('orders').doc();

      await firestore.runTransaction(
        (transaction) async {
          // ----------------------------------------------------
          // READ ALL PRODUCTS FIRST
          // ----------------------------------------------------

          final productSnapshots =
              <String, DocumentSnapshot<Map<String, dynamic>>>{};

          for (final cartItem
              in CartController.items) {
            final productRef = firestore
                .collection('products')
                .doc(cartItem.id);

            final productSnapshot =
                await transaction.get(productRef);

            productSnapshots[cartItem.id] =
                productSnapshot;
          }

          // ----------------------------------------------------
          // VERIFY STOCK
          // ----------------------------------------------------

          for (final cartItem
              in CartController.items) {
            final snapshot =
                productSnapshots[cartItem.id];

            if (snapshot == null ||
                !snapshot.exists) {
              throw Exception(
                'Product "${cartItem.name}" is no longer available.',
              );
            }

            final data = snapshot.data();

            if (data == null) {
              throw Exception(
                'Product "${cartItem.name}" is unavailable.',
              );
            }

            final active =
                data['Active'] == true;

            if (!active) {
              throw Exception(
                '"${cartItem.name}" is currently unavailable.',
              );
            }

            final currentStock =
                int.tryParse(
                      data['Stock']?.toString() ?? '0',
                    ) ??
                    0;

            // NEVER ALLOW NEGATIVE STOCK
            if (currentStock <= 0) {
              throw Exception(
                '"${cartItem.name}" is out of stock.',
              );
            }

            if (cartItem.quantity >
                currentStock) {
              throw Exception(
                'Only $currentStock "${cartItem.name}" available.',
              );
            }
          }

          // ----------------------------------------------------
          // REDUCE STOCK
          // ----------------------------------------------------

          for (final cartItem
              in CartController.items) {
            final snapshot =
                productSnapshots[cartItem.id]!;

            final data =
                snapshot.data()!;

            final currentStock =
                int.tryParse(
                      data['Stock']?.toString() ?? '0',
                    ) ??
                    0;

            final newStock =
                currentStock - cartItem.quantity;

            // EXTRA SAFETY: NEVER BELOW ZERO
            if (newStock < 0) {
              throw Exception(
                'Insufficient stock for "${cartItem.name}".',
              );
            }

            final productRef =
                firestore
                    .collection('products')
                    .doc(cartItem.id);

            transaction.update(
              productRef,
              {
                'Stock': newStock.toString(),
              },
            );
          }

          // ----------------------------------------------------
          // CREATE ORDER
          // ----------------------------------------------------

          final orderData = {
            'userId': user.uid,
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
            'items': orderItems,
            'totalAmount':
                CartController.total,
            'status': 'Placed',
            'paymentMethod':
                'Cash on Delivery',
            'createdAt':
                FieldValue.serverTimestamp(),
          };

          transaction.set(
            orderRef,
            orderData,
          );
        },
      );

      // --------------------------------------------------------
      // ORDER SUCCESS
      // --------------------------------------------------------

      if (!mounted) return;

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
              'Stock has been updated.\n\n'
              'Order ID:\n${orderRef.id}',
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
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message =
          e.toString().replaceFirst(
                'Exception: ',
                '',
              );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
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
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
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

    final hasItems = items.isNotEmpty;

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
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Delivery Details',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              inputField(
                controller: nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline,
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

              inputField(
                controller: mobileController,
                label: 'Mobile Number',
                hint: 'Enter 10 digit mobile number',
                icon: Icons.phone_outlined,
                keyboardType:
                    TextInputType.phone,
                validator: (value) {
                  final mobile =
                      value?.trim() ?? '';

                  if (mobile.isEmpty) {
                    return 'Enter mobile number';
                  }

                  if (!RegExp(
                    r'^[0-9]{10}$',
                  ).hasMatch(mobile)) {
                    return 'Enter a valid 10 digit number';
                  }

                  return null;
                },
              ),

              inputField(
                controller: addressController,
                label: 'Address',
                hint: 'House no., street, area',
                icon: Icons.home_outlined,
                maxLines: 3,
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Enter delivery address';
                  }

                  if (value.trim().length < 5) {
                    return 'Enter a complete address';
                  }

                  return null;
                },
              ),

              inputField(
                controller: cityController,
                label: 'City',
                hint: 'Enter your city',
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
                controller: pincodeController,
                label: 'PIN Code',
                hint: 'Enter 6 digit PIN code',
                icon: Icons.pin_drop_outlined,
                keyboardType:
                    TextInputType.number,
                validator: (value) {
                  final pincode =
                      value?.trim() ?? '';

                  if (!RegExp(
                    r'^[0-9]{6}$',
                  ).hasMatch(pincode)) {
                    return 'Enter a valid 6 digit PIN code';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 10),

              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.payments_outlined,
                  ),
                  title: const Text(
                    'Cash on Delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Pay when your order is delivered',
                  ),
                  trailing: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w500,
                                    ),
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

                      const SizedBox(height: 6),

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
                              CartController.total,
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

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed:
                      !hasItems || placingOrder
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
                          Icons.shopping_bag_outlined,
                        ),
                  label: Text(
                    placingOrder
                        ? 'Confirming Order...'
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
                'Stock is reduced only after the order is successfully confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'By placing this order, you agree to receive your order at the address provided above.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
