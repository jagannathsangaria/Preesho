import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_login.dart';
import 'account_page.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    runApp(const PreeshoApp());
  } catch (e) {
    runApp(
      PreeshoApp(
        firebaseError: true,
        errorMessage: e.toString(),
      ),
    );
  }
}

class PreeshoApp extends StatelessWidget {
  final bool firebaseError;
  final String errorMessage;

  const PreeshoApp({
    super.key,
    this.firebaseError = false,
    this.errorMessage = '',
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preesho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xffF7F7F9),
      ),
      home: firebaseError
          ? FirebaseErrorPage(error: errorMessage)
          : const HomePage(),
    );
  }
}

// =====================================================
// CART ITEM
// =====================================================

class CartItem {
  final String id;
  final String name;
  final String category;
  final String price;
  final String imageUrl;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.quantity = 1,
  });

  double get numericPrice {
    final value = price
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(value) ?? 0;
  }

  double get totalPrice => numericPrice * quantity;
}

// =====================================================
// CART CONTROLLER
// =====================================================

class CartController {
  static final List<CartItem> items = [];

  static void addProduct({
    required String id,
    required String name,
    required String category,
    required String price,
    required String imageUrl,
  }) {
    final index = items.indexWhere(
      (item) => item.id == id,
    );

    if (index >= 0) {
      items[index].quantity++;
    } else {
      items.add(
        CartItem(
          id: id,
          name: name,
          category: category,
          price: price,
          imageUrl: imageUrl,
        ),
      );
    }
  }

  static void increase(String id) {
    final index = items.indexWhere(
      (item) => item.id == id,
    );

    if (index >= 0) {
      items[index].quantity++;
    }
  }

  static void decrease(String id) {
    final index = items.indexWhere(
      (item) => item.id == id,
    );

    if (index >= 0) {
      if (items[index].quantity > 1) {
        items[index].quantity--;
      } else {
        items.removeAt(index);
      }
    }
  }

  static void remove(String id) {
    items.removeWhere(
      (item) => item.id == id,
    );
  }

  static double get total {
    return items.fold(
      0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  static int get count {
    return items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }

  static void clear() {
    items.clear();
  }
}

// =====================================================
// FIREBASE ERROR PAGE
// =====================================================

class FirebaseErrorPage extends StatelessWidget {
  final String error;

  const FirebaseErrorPage({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preesho'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 70,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Firebase Connection Error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                SelectableText(
                  error,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// HOME PAGE
// =====================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchText = '';

  String field(
    Map<String, dynamic> data,
    String key,
  ) {
    if (data[key] != null) {
      return data[key].toString();
    }

    return '';
  }

  Future<void> openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            tooltip: user == null
                ? 'Login'
                : 'My Account',
            icon: Icon(
              user == null
                  ? Icons.person_outline
                  : Icons.person,
            ),
            onPressed: user == null
                ? openLogin
                : openAccount,
          ),

          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Cart',
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CartPage(),
                    ),
                  );

                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              if (CartController.count > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${CartController.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            tooltip: 'Admin',
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLogin(),
                ),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where(
              'Active',
              isEqualTo: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Products error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          final filtered = docs.where((doc) {
            if (searchText.trim().isEmpty) {
              return true;
            }

            final data = doc.data();

            final name = field(
              data,
              'Name',
            ).toLowerCase();

            final category = field(
              data,
              'Category',
            ).toLowerCase();

            final search =
                searchText.trim().toLowerCase();

            return name.contains(search) ||
                category.contains(search);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(
                    Icons.search,
                  ),
                  suffixIcon: searchText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              searchText = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff5E35B1),
                      Color(0xff8E24AA),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to Preesho',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Shop smarter. Shop faster.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Latest Products',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 14),

              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No products found',
                    ),
                  ),
                ),

              ...filtered.map(
                (doc) {
                  final data = doc.data();

                  return ProductCard(
                    id: doc.id,
                    name: field(data, 'Name'),
                    category:
                        field(data, 'Category'),
                    price: field(data, 'Price'),
                    stock: field(data, 'Stock'),
                    imageUrl:
                        field(data, 'Imageurl'),
                    onCartChanged: () {
                      setState(() {});
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================
// PRODUCT CARD
// =====================================================

class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final String price;
  final String stock;
  final String imageUrl;
  final VoidCallback onCartChanged;

  const ProductCard({
    super.key,
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.onCartChanged,
  });

  String displayPrice() {
    if (price.trim().isEmpty) {
      return 'Price unavailable';
    }

    if (price.trim().startsWith('₹')) {
      return price.trim();
    }

    return '₹${price.trim()}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 210,
            child: imageUrl.isNotEmpty &&
                    imageUrl.startsWith('http')
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) {
                      return const ProductImagePlaceholder();
                    },
                  )
                : const ProductImagePlaceholder(),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'Unnamed Product'
                      : name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  category,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayPrice(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      stock.isEmpty
                          ? ''
                          : 'Stock: $stock',
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      CartController.addProduct(
                        id: id,
                        name: name,
                        category: category,
                        price: price,
                        imageUrl: imageUrl,
                      );

                      onCartChanged();

                      ScaffoldMessenger.of(context)
                          .hideCurrentSnackBar();

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            '${name.isEmpty ? 'Product' : name} added to cart',
                          ),
                          action: SnackBarAction(
                            label: 'VIEW CART',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CartPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                    ),
                    label: const Text(
                      'Add to Cart',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// CART PAGE
// =====================================================

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() =>
      _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  Future<void> checkout() async {
    if (CartController.items.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );

      if (!mounted) return;

      if (result != true &&
          FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CheckoutPage(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: items.isEmpty
          ? const EmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];

                      return CartItemCard(
                        item: item,
                        onChanged: () {
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black
                            .withOpacity(0.08),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Total',
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
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: checkout,
                            icon: const Icon(
                              Icons
                                  .shopping_bag_outlined,
                            ),
                            label: const Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// =====================================================
// CHECKOUT PAGE
// =====================================================

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() =>
      _CheckoutPageState();
}

class _CheckoutPageState
    extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  final addressController = TextEditingController();
  final cityController = TextEditingController();
  final stateController = TextEditingController();
  final pincodeController = TextEditingController();

  bool placingOrder = false;

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  void initState() {
    super.initState();

    final user =
        FirebaseAuth.instance.currentUser;

    if (user != null) {
      nameController.text =
          user.displayName ?? '';
      // Email is intentionally not used as mobile.
    }

    loadExistingProfile();
  }

  Future<void> loadExistingProfile() async {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      final data = doc.data();

      if (data == null) return;

      if (nameController.text.trim().isEmpty) {
        nameController.text =
            data['name']?.toString() ?? '';
      }

      mobileController.text =
          data['mobile']?.toString() ?? '';
    } catch (_) {
      // Profile loading failure should not block checkout.
    }
  }

  Future<void> placeOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Please login before placing your order.',
      );
      return;
    }

    if (CartController.items.isEmpty) {
      showMessage('Your cart is empty.');
      return;
    }

    setState(() {
      placingOrder = true;
    });

    try {
      final orderItems =
          CartController.items.map((item) {
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

      final total = CartController.total;

      final orderData = {
        'userId': user.uid,
        'customerName':
            nameController.text.trim(),
        'mobile':
            mobileController.text.trim(),
        'email': user.email ?? '',
        'address':
            addressController.text.trim(),
        'city': cityController.text.trim(),
        'state': stateController.text.trim(),
        'pincode':
            pincodeController.text.trim(),
        'items': orderItems,
        'totalAmount': total,
        'paymentMethod': 'Cash on Delivery',
        'paymentStatus': 'Pending',
        'orderStatus': 'Placed',
        'createdAt':
            FieldValue.serverTimestamp(),
      };

      final orderRef = await FirebaseFirestore
          .instance
          .collection('orders')
          .add(orderData);

      // Save/update address in customer profile.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,
            'name':
                nameController.text.trim(),
            'mobile':
                mobileController.text.trim(),
            'email': user.email ?? '',
            'address':
                addressController.text.trim(),
            'city': cityController.text.trim(),
            'state': stateController.text.trim(),
            'pincode':
                pincodeController.text.trim(),
          },
          SetOptions(merge: true),
        );
      } catch (_) {
        // Order is already created, so profile
        // update failure should not cancel the order.
      }

      CartController.clear();

      if (!mounted) return;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessPage(
            orderId: orderRef.id,
            amount: total,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not place order.\n${e.message ?? e.code}',
      );
    } catch (e) {
      if (!mounted) return;

      showMessage(
        'Could not place order. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  Widget field({
    required TextEditingController controller,
    required String label,
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
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            field(
              controller: nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter your name';
                }
                return null;
              },
            ),

            field(
              controller: mobileController,
              label: 'Mobile Number',
              icon: Icons.phone_outlined,
              keyboardType:
                  TextInputType.phone,
              validator: (value) {
                final mobile =
                    value?.trim() ?? '';

                if (!RegExp(
                  r'^[0-9]{10}$',
                ).hasMatch(mobile)) {
                  return 'Enter valid 10 digit mobile number';
                }

                return null;
              },
            ),

            field(
              controller: addressController,
              label: 'Full Address',
              icon: Icons.home_outlined,
              maxLines: 3,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter delivery address';
                }
                return null;
              },
            ),

            field(
              controller: cityController,
              label: 'City',
              icon: Icons.location_city_outlined,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter city';
                }
                return null;
              },
            ),

            field(
              controller: stateController,
              label: 'State',
              icon: Icons.map_outlined,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Enter state';
                }
                return null;
              },
            ),

            field(
              controller: pincodeController,
              label: 'PIN Code',
              icon: Icons.pin_drop_outlined,
              keyboardType:
                  TextInputType.number,
              validator: (value) {
                if (!RegExp(
                  r'^[0-9]{6}$',
                ).hasMatch(
                  value?.trim() ?? '',
                )) {
                  return 'Enter valid 6 digit PIN code';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              color: Colors.white,
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
                                        FontWeight.w500,
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
                          style: const TextStyle(
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

            const SizedBox(height: 14),

            Card(
              color: Colors.white,
              child: const ListTile(
                leading: Icon(
                  Icons.local_shipping_outlined,
                ),
                title: Text(
                  'Cash on Delivery',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Pay when your order is delivered',
                ),
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: placingOrder
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
                        Icons.check_circle_outline,
                      ),
                label: Text(
                  placingOrder
                      ? 'Placing Order...'
                      : 'Place Order',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// ORDER SUCCESS PAGE
// =====================================================

class OrderSuccessPage extends StatelessWidget {
  final String orderId;
  final double amount;

  const OrderSuccessPage({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 100,
                  color: Colors.green,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Order Placed Successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Thank you for shopping with Preesho.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 24),

                Card(
                  color: Colors.white,
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        const Text(
                          'Order ID',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          orderId,
                          textAlign:
                              TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Order Amount',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.popUntil(
                        context,
                        (route) => route.isFirst,
                      );
                    },
                    child: const Text(
                      'Continue Shopping',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// CART ITEM CARD
// =====================================================

class CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onChanged;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onChanged,
  });

  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
          const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: item.imageUrl.isNotEmpty &&
                        item.imageUrl
                            .startsWith('http')
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error,
                                stackTrace) {
                          return const ProductImagePlaceholder();
                        },
                      )
                    : const ProductImagePlaceholder(),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name.isEmpty
                        ? 'Unnamed Product'
                        : item.name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(item.category),

                  const SizedBox(height: 5),

                  Text(
                    money(item.numericPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),

                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          CartController.decrease(
                            item.id,
                          );
                          onChanged();
                        },
                        icon: const Icon(
                          Icons
                              .remove_circle_outline,
                        ),
                      ),

                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        onPressed: () {
                          CartController.increase(
                            item.id,
                          );
                          onChanged();
                        },
                        icon: const Icon(
                          Icons
                              .add_circle_outline,
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        onPressed: () {
                          CartController.remove(
                            item.id,
                          );
                          onChanged();
                        },
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// EMPTY CART
// =====================================================

class EmptyCart extends StatelessWidget {
  const EmptyCart({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 90,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add some products to your cart.',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Continue Shopping',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================
// IMAGE PLACEHOLDER
// =====================================================

class ProductImagePlaceholder
    extends StatelessWidget {
  const ProductImagePlaceholder({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffEEEEF2),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 55,
          color: Colors.grey,
        ),
      ),
    );
  }
}
