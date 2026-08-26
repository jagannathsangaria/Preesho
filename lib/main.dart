import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;

  try {
    await Firebase.initializeApp();
  } catch (e) {
    firebaseError = e.toString();
  }

  runApp(
    PreeshoApp(
      firebaseError: firebaseError,
    ),
  );
}

class PreeshoApp extends StatelessWidget {
  final String? firebaseError;

  const PreeshoApp({
    super.key,
    this.firebaseError,
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
      home: firebaseError != null
          ? FirebaseErrorPage(error: firebaseError!)
          : const HomePage(),
    );
  }
}

// ============================================================
// FIREBASE ERROR PAGE
// ============================================================

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
        title: const Text(
          'Preesho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                'Firebase initialization failed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Preesho could not connect to Firebase.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffEEEEF2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  error,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CART ITEM MODEL
// ============================================================

class CartItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final int stock;
  int quantity;

  CartItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    required this.stock,
    this.quantity = 1,
  });

  double get total => price * quantity;
}

// ============================================================
// CART CONTROLLER
// ============================================================

class CartController extends ChangeNotifier {
  static final CartController instance = CartController._();

  CartController._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems {
    int total = 0;

    for (final item in _items) {
      total += item.quantity;
    }

    return total;
  }

  double get totalAmount {
    double total = 0;

    for (final item in _items) {
      total += item.total;
    }

    return total;
  }

  void addItem({
    required String id,
    required String name,
    required String category,
    required double price,
    required String imageUrl,
    required int stock,
  }) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index >= 0) {
      final existing = _items[index];

      if (existing.quantity < existing.stock) {
        existing.quantity++;
      }
    } else {
      _items.add(
        CartItem(
          id: id,
          name: name,
          category: category,
          price: price,
          imageUrl: imageUrl,
          stock: stock <= 0 ? 999 : stock,
        ),
      );
    }

    notifyListeners();
  }

  void increaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index == -1) return;

    final item = _items[index];

    if (item.quantity < item.stock) {
      item.quantity++;
      notifyListeners();
    }
  }

  void decreaseQuantity(String id) {
    final index = _items.indexWhere((item) => item.id == id);

    if (index == -1) return;

    final item = _items[index];

    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.removeAt(index);
    }

    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String readField(
    Map<String, dynamic> data,
    String wantedField,
  ) {
    if (data.containsKey(wantedField)) {
      final value = data[wantedField];

      if (value != null) {
        final text = value.toString().trim();

        if (text.isNotEmpty) {
          return text;
        }
      }
    }

    String normalize(String value) {
      return value
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s_\-]'), '');
    }

    final wanted = normalize(wantedField);

    for (final entry in data.entries) {
      if (normalize(entry.key.toString()) == wanted) {
        if (entry.value != null) {
          final text = entry.value.toString().trim();

          if (text.isNotEmpty) {
            return text;
          }
        }
      }
    }

    return '';
  }

  double parsePrice(String value) {
    final cleaned = value
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(cleaned) ?? 0;
  }

  int parseStock(String value) {
    return int.tryParse(
          value.replaceAll(',', '').trim(),
        ) ??
        999;
  }

  @override
  Widget build(BuildContext context) {
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
          // CART BUTTON
          ListenableBuilder(
            listenable: CartController.instance,
            builder: (context, _) {
              final count = CartController.instance.totalItems;

              return Stack(
                children: [
                  IconButton(
                    tooltip: 'Cart',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CartPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      size: 28,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 5,
                      top: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          // ADMIN
          IconButton(
            tooltip: 'Admin Login',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLogin(),
                ),
              );
            },
            icon: const Icon(
              Icons.admin_panel_settings_outlined,
            ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Firestore Error',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No products available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final products = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // WELCOME BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
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

              ...products.map((doc) {
                final data = doc.data();

                final name = readField(data, 'Name');
                final category =
                    readField(data, 'Category');
                final price =
                    readField(data, 'Price');
                final stock =
                    readField(data, 'Stock');
                final imageUrl =
                    readField(data, 'Imageurl');

                return ProductCard(
                  id: doc.id,
                  name: name,
                  category: category,
                  price: price,
                  stock: stock,
                  imageUrl: imageUrl,
                  priceValue: parsePrice(price),
                  stockValue: parseStock(stock),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
// ============================================================

class ProductCard extends StatelessWidget {
  final String id;
  final String name;
  final String category;
  final String price;
  final String stock;
  final String imageUrl;
  final double priceValue;
  final int stockValue;

  const ProductCard({
    super.key,
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.priceValue,
    required this.stockValue,
  });

  String formatPrice(String value) {
    final cleaned = value.trim();

    if (cleaned.isEmpty) {
      return 'Price unavailable';
    }

    if (cleaned.startsWith('₹')) {
      return cleaned;
    }

    return '₹$cleaned';
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
          // IMAGE
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

                const SizedBox(height: 8),

                Text(
                  category.isEmpty
                      ? 'Category unavailable'
                      : category,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatPrice(price),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      stock.isEmpty
                          ? 'Stock unavailable'
                          : 'Stock: $stock',
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ADD TO CART
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: stockValue <= 0
                        ? null
                        : () {
                            CartController.instance
                                .addItem(
                              id: id,
                              name: name.isEmpty
                                  ? 'Unnamed Product'
                                  : name,
                              category: category,
                              price: priceValue,
                              imageUrl: imageUrl,
                              stock: stockValue,
                            );

                            ScaffoldMessenger.of(
                              context,
                            ).hideCurrentSnackBar();

                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
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
                    label: Text(
                      stockValue <= 0
                          ? 'Out of Stock'
                          : 'Add to Cart',
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

// ============================================================
// CART PAGE
// ============================================================

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  String formatMoney(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: CartController.instance,
        builder: (context, _) {
          final cart = CartController.instance;

          if (cart.items.isEmpty) {
            return const EmptyCartView();
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  itemBuilder: (context, index) {
                    final item = cart.items[index];

                    return CartItemCard(
                      item: item,
                    );
                  },
                ),
              ),

              // BOTTOM TOTAL
              Container(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      color: Colors.black.withValues(
                        alpha: 0.08,
                      ),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Items',
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${cart.totalItems}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            formatMoney(cart.totalAmount),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Checkout will be available soon.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.shopping_bag_outlined,
                          ),
                          label: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CART ITEM CARD
// ============================================================

class CartItemCard extends StatelessWidget {
  final CartItem item;

  const CartItemCard({
    super.key,
    required this.item,
  });

  String formatMoney(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 90,
                height: 90,
                child: item.imageUrl.isNotEmpty &&
                        item.imageUrl.startsWith('http')
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) {
                          return const ProductImagePlaceholder();
                        },
                      )
                    : const ProductImagePlaceholder(),
              ),
            ),

            const SizedBox(width: 12),

            // DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (item.category.isNotEmpty)
                    Text(
                      item.category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(height: 8),

                  Text(
                    formatMoney(item.price),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      // MINUS
                      IconButton(
                        visualDensity:
                            VisualDensity.compact,
                        onPressed: () {
                          CartController.instance
                              .decreaseQuantity(
                            item.id,
                          );
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                      ),

                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // PLUS
                      IconButton(
                        visualDensity:
                            VisualDensity.compact,
                        onPressed: item.quantity <
                                item.stock
                            ? () {
                                CartController.instance
                                    .increaseQuantity(
                                  item.id,
                                );
                              }
                            : null,
                        icon: const Icon(
                          Icons.add_circle_outline,
                        ),
                      ),

                      const Spacer(),

                      // DELETE
                      IconButton(
                        visualDensity:
                            VisualDensity.compact,
                        onPressed: () {
                          CartController.instance
                              .removeItem(item.id);
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

// ============================================================
// EMPTY CART
// ============================================================

class EmptyCartView extends StatelessWidget {
  const EmptyCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Color(0xffEEEEF2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 70,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Add some products to your cart and they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.shopping_bag_outlined,
              ),
              label: const Text(
                'Continue Shopping',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// IMAGE PLACEHOLDER
// ============================================================

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
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }
}
