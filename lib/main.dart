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

  runApp(PreeshoApp(firebaseError: firebaseError));
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

// =====================================================
// CART MODEL
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
    final cleaned = price
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(cleaned) ?? 0;
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
    final index = items.indexWhere((item) => item.id == id);

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
    final index = items.indexWhere((item) => item.id == id);

    if (index >= 0) {
      items[index].quantity++;
    }
  }

  static void decrease(String id) {
    final index = items.indexWhere((item) => item.id == id);

    if (index >= 0) {
      if (items[index].quantity > 1) {
        items[index].quantity--;
      } else {
        items.removeAt(index);
      }
    }
  }

  static void remove(String id) {
    items.removeWhere((item) => item.id == id);
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
}

// =====================================================
// FIREBASE ERROR
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
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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

                  setState(() {});
                },
              ),
              if (CartController.count > 0)
                Positioned(
                  right: 6,
                  top: 6,
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

          final allProducts = snapshot.data!.docs;

          final products = allProducts.where((doc) {
            if (searchText.trim().isEmpty) {
              return true;
            }

            final data = doc.data();

            final name =
                readField(data, 'Name').toLowerCase();

            final category =
                readField(data, 'Category').toLowerCase();

            final search =
                searchText.trim().toLowerCase();

            return name.contains(search) ||
                category.contains(search);
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // SEARCH
              TextField(
                onChanged: (value) {
                  setState(() {
                    searchText = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
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

              // BANNER
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

              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),

              ...products.map((doc) {
                final data = doc.data();

                return ProductCard(
                  id: doc.id,
                  name: readField(data, 'Name'),
                  category:
                      readField(data, 'Category'),
                  price: readField(data, 'Price'),
                  stock: readField(data, 'Stock'),
                  imageUrl:
                      readField(data, 'Imageurl'),
                  onCartChanged: () {
                    setState(() {});
                  },
                );
              }),
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
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  String money(double value) {
    return '₹${value.toStringAsFixed(0)}';
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
                    padding: const EdgeInsets.all(16),
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

                // TOTAL AREA
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    16,
                    18,
                    18,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black.withOpacity(0.08),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              money(CartController.total),
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Checkout will be added next.',
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              child: Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
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
                    item.name.isEmpty
                        ? 'Unnamed Product'
                        : item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    item.category,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 7),

                  Text(
                    money(item.numericPrice),
                    style: const TextStyle(
                      fontSize: 17,
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
                          CartController.decrease(
                            item.id,
                          );
                          onChanged();
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
                        onPressed: () {
                          CartController.increase(
                            item.id,
                          );
                          onChanged();
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                        ),
                      ),

                      const Spacer(),

                      // REMOVE
                      IconButton(
                        tooltip: 'Remove',
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
            Text(
              'Add some products to your cart.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
              ),
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
  const ProductImagePlaceholder({super.key});

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
