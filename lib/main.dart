import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'checkout_page.dart';
import 'login_page.dart';
import 'admin_login.dart';
import 'orders_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await CartController.initialize();

    runApp(const PreeshoApp());
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Firebase initialization failed:\n\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT MODEL
// ============================================================

class Product {
  final String id;
  final String name;
  final String category;

  // Final selling price.
  final String price;

  // Original/MRP price.
  final String mrp;

  // Discount percentage.
  final double discountPercent;

  final int stock;
  final String imageUrl;
  final String description;
  final bool active;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.mrp,
    required this.discountPercent,
    required this.stock,
    required this.imageUrl,
    required this.description,
    required this.active,
  });

  double get numericPrice {
    return double.tryParse(
          price.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
  }

  double get numericMrp {
    final value = double.tryParse(
          mrp.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;

    if (value > 0) {
      return value;
    }

    return numericPrice;
  }

  double get calculatedDiscount {
    if (discountPercent > 0) {
      return discountPercent;
    }

    final original = numericMrp;
    final selling = numericPrice;

    if (original > selling && original > 0) {
      return ((original - selling) / original) * 100;
    }

    return 0;
  }

  Map<String, dynamic> toCartMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'mrp': mrp,
      'discountPercent': discountPercent,
      'stock': stock,
      'imageUrl': imageUrl,
      'description': description,
      'active': active,
    };
  }

  factory Product.fromCartMap(Map<String, dynamic> data) {
    return Product(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      price: data['price']?.toString() ?? '0',
      mrp: data['mrp']?.toString() ?? '0',
      discountPercent:
          double.tryParse(
                data['discountPercent']?.toString() ?? '0',
              ) ??
              0,
      stock:
          int.tryParse(
                data['stock']?.toString() ?? '0',
              ) ??
              0,
      imageUrl: data['imageUrl']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      active: data['active'] == true,
    );
  }
}

// ============================================================
// CART ITEM
// ============================================================

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });

  String get id => product.id;

  String get name => product.name;

  String get category => product.category;

  String get imageUrl => product.imageUrl;

  double get numericPrice => product.numericPrice;

  double get numericMrp => product.numericMrp;

  double get discountPercent => product.calculatedDiscount;

  double get totalPrice => numericPrice * quantity;

  double get totalMrp => numericMrp * quantity;

  double get totalSavings => totalMrp - totalPrice;

  int get availableStock => product.stock;

  Map<String, dynamic> toMap() {
    return {
      'product': product.toCartMap(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      product: Product.fromCartMap(
        Map<String, dynamic>.from(
          data['product'] as Map? ?? {},
        ),
      ),
      quantity:
          int.tryParse(
                data['quantity']?.toString() ?? '1',
              ) ??
              1,
    );
  }
}

// ============================================================
// CART CONTROLLER
// ============================================================

class CartController {
  static const String _storageKey = 'preesho_cart';

  static final List<CartItem> items = [];

  static bool initialized = false;

  static Future<void> initialize() async {
    if (initialized) return;

    final prefs = await SharedPreferences.getInstance();

    final savedCart = prefs.getString(_storageKey);

    if (savedCart != null && savedCart.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedCart);

        if (decoded is List) {
          items.clear();

          for (final item in decoded) {
            if (item is Map) {
              final cartItem = CartItem.fromMap(
                Map<String, dynamic>.from(item),
              );

              if (cartItem.product.id.isNotEmpty &&
                  cartItem.quantity > 0) {
                items.add(cartItem);
              }
            }
          }
        }
      } catch (_) {
        items.clear();
      }
    }

    initialized = true;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    final data = items
        .map((item) => item.toMap())
        .toList();

    await prefs.setString(
      _storageKey,
      jsonEncode(data),
    );
  }

  static double get total {
    return items.fold(
      0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  static double get totalMrp {
    return items.fold(
      0,
      (sum, item) => sum + item.totalMrp,
    );
  }

  static double get totalSavings {
    return totalMrp - total;
  }

  static int get itemCount {
    return items.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  }

  static CartItem? findItem(String productId) {
    try {
      return items.firstWhere(
        (item) => item.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> addProduct(Product product) async {
    if (product.stock <= 0) {
      return false;
    }

    final existing = findItem(product.id);

    if (existing != null) {
      if (existing.quantity >= product.stock) {
        return false;
      }

      existing.quantity++;
      await _save();
      return true;
    }

    items.add(
      CartItem(
        product: product,
        quantity: 1,
      ),
    );

    await _save();
    return true;
  }

  static Future<bool> increaseQuantity(
    String productId,
  ) async {
    final item = findItem(productId);

    if (item == null) return false;

    if (item.quantity >= item.availableStock) {
      return false;
    }

    item.quantity++;

    await _save();
    return true;
  }

  static Future<bool> decreaseQuantity(
    String productId,
  ) async {
    final item = findItem(productId);

    if (item == null) return false;

    if (item.quantity > 1) {
      item.quantity--;
    } else {
      items.remove(item);
    }

    await _save();
    return true;
  }

  static Future<void> removeProduct(
    String productId,
  ) async {
    items.removeWhere(
      (item) => item.id == productId,
    );

    await _save();
  }

  static Future<void> clear() async {
    items.clear();
    await _save();
  }
}

// ============================================================
// APP
// ============================================================

class PreeshoApp extends StatelessWidget {
  const PreeshoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Preesho',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const MainShell(),
    );
  }
}

// ============================================================
// MAIN SHELL
// ============================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  void refresh() {
    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onCartChanged: refresh,
      ),
      CategoriesPage(
        onCartChanged: refresh,
      ),
      CartPage(
        onCartChanged: refresh,
      ),
      ProfilePage(
        onProfileChanged: refresh,
      ),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() {
            index = i;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  CartController.itemCount > 0,
              label: Text(
                '${CartController.itemCount}',
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
              ),
            ),
            selectedIcon: Badge(
              isLabelVisible:
                  CartController.itemCount > 0,
              label: Text(
                '${CartController.itemCount}',
              ),
              child: const Icon(
                Icons.shopping_cart,
              ),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FIRESTORE PRODUCT STREAM
// ============================================================

class ProductStream extends StatelessWidget {
  final Widget Function(List<Product> products) builder;

  const ProductStream({
    super.key,
    required this.builder,
  });

  Product productFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final sellingPrice =
        data['Price']?.toString() ?? '0';

    final mrp =
        data['MRP']?.toString() ??
        data['Mrp']?.toString() ??
        data['mrp']?.toString() ??
        sellingPrice;

    final discount =
        double.tryParse(
              data['DiscountPercent']?.toString() ??
                  data['Discount']?.toString() ??
                  data['discountPercent']?.toString() ??
                  '0',
            ) ??
            0;

    return Product(
      id: doc.id,
      name: data['Name']?.toString() ?? '',
      category: data['Category']?.toString() ?? '',
      price: sellingPrice,
      mrp: mrp,
      discountPercent: discount,
      stock:
          int.tryParse(
                data['Stock']?.toString() ?? '0',
              ) ??
              0,
      imageUrl:
          data['Imageurl']?.toString() ??
          data['ImageUrl']?.toString() ??
          data['imageUrl']?.toString() ??
          '',
      description:
          data['Description']?.toString() ?? '',
      active: data['Active'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
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
                'Unable to load products.\n\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final products = docs
            .map(productFromDocument)
            .where(
              (product) =>
                  product.active &&
                  product.stock > 0,
            )
            .toList();

        return builder(products);
      },
    );
  }
}

// ============================================================
// PRICE WIDGET
// ============================================================

class ProductPrice extends StatelessWidget {
  final Product product;
  final bool large;

  const ProductPrice({
    super.key,
    required this.product,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final discount = product.calculatedDiscount;
    final mrp = product.numericMrp;
    final price = product.numericPrice;

    final showMrp = mrp > price;
    final showDiscount = discount > 0;

    return Wrap(
      crossAxisAlignment:
          WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          '₹${price.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: large ? 28 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),

        if (showMrp)
          Text(
            '₹${mrp.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: large ? 16 : 13,
              color: Colors.grey,
              decoration:
                  TextDecoration.lineThrough,
            ),
          ),

        if (showDiscount)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.green.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(6),
            ),
            child: Text(
              '${discount.toStringAsFixed(0)}% OFF',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  final VoidCallback onCartChanged;

  const HomePage({
    super.key,
    required this.onCartChanged,
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
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearch(
                  onCartChanged,
                ),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_none,
            ),
          ),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Shop smarter. Shop faster.',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection:
                      Axis.horizontal,
                  children: const [
                    CategoryCard(
                      icon:
                          Icons.phone_android,
                      text: 'Electronics',
                    ),
                    CategoryCard(
                      icon: Icons.checkroom,
                      text: 'Fashion',
                    ),
                    CategoryCard(
                      icon: Icons.home,
                      text: 'Home',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'No products available',
                    ),
                  ),
                ),

              ...products.map(
                (product) => ProductTile(
                  product: product,
                  onCartChanged:
                      onCartChanged,
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
// CATEGORY CARD
// ============================================================

class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 115,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CATEGORIES PAGE
// ============================================================

class CategoriesPage extends StatelessWidget {
  final VoidCallback onCartChanged;

  const CategoriesPage({
    super.key,
    required this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: ProductStream(
        builder: (products) {
          final categories = products
              .map((p) => p.category)
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();

          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories available',
              ),
            );
          }

          return ListView(
            children: categories.map((category) {
              final categoryProducts =
                  products
                      .where(
                        (p) =>
                            p.category ==
                            category,
                      )
                      .toList();

              return ExpansionTile(
                title: Text(category),
                leading:
                    const Icon(Icons.category),
                children: categoryProducts
                    .map(
                      (product) =>
                          ProductTile(
                        product: product,
                        onCartChanged:
                            onCartChanged,
                      ),
                    )
                    .toList(),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCT TILE
// ============================================================

class ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onCartChanged;

  const ProductTile({
    super.key,
    required this.product,
    required this.onCartChanged,
  });

  Future<void> addToCart(
    BuildContext context,
  ) async {
    final added =
        await CartController.addProduct(
      product,
    );

    if (added) {
      onCartChanged();

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text('Added to cart'),
          duration:
              Duration(seconds: 1),
        ),
      );
    } else {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Maximum available stock reached'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItem =
        CartController.findItem(product.id);

    final cartQuantity =
        cartItem?.quantity ?? 0;

    final outOfStock =
        product.stock <= 0;

    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailsPage(
              product: product,
              onCartChanged:
                  onCartChanged,
            ),
          ),
        );

        onCartChanged();
      },
      child: Card(
        margin: const EdgeInsets.only(
          bottom: 12,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 75,
                height: 75,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child:
                      product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stack,
                              ) {
                                return const ColoredBox(
                                  color:
                                      Colors.black12,
                                  child: Icon(
                                    Icons
                                        .image_not_supported,
                                  ),
                                );
                              },
                            )
                          : const ColoredBox(
                              color:
                                  Colors.black12,
                              child: Icon(
                                Icons
                                    .shopping_bag_outlined,
                              ),
                            ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name.isEmpty
                          ? 'Unnamed Product'
                          : product.name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      product.category,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    ProductPrice(
                      product: product,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : 'Stock: ${product.stock}',
                      style: TextStyle(
                        color: outOfStock
                            ? Colors.red
                            : Colors.green,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              if (outOfStock)
                const SizedBox(
                  width: 95,
                  child: Text(
                    'Out of Stock',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                )
              else if (cartQuantity == 0)
                IconButton.filled(
                  onPressed: () =>
                      addToCart(context),
                  icon: const Icon(
                    Icons.add_shopping_cart,
                  ),
                )
              else
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        await CartController
                            .decreaseQuantity(
                          product.id,
                        );

                        onCartChanged();
                      },
                      icon: const Icon(
                        Icons
                            .remove_circle_outline,
                      ),
                    ),

                    Text(
                      '$cartQuantity',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    IconButton(
                      onPressed:
                          cartQuantity >=
                                  product.stock
                              ? null
                              : () async {
                                  await CartController
                                      .increaseQuantity(
                                    product.id,
                                  );

                                  onCartChanged();
                                },
                      icon: const Icon(
                        Icons
                            .add_circle_outline,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PRODUCT DETAILS PAGE
// ============================================================

class ProductDetailsPage
    extends StatefulWidget {
  final Product product;
  final VoidCallback onCartChanged;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.onCartChanged,
  });

  @override
  State<ProductDetailsPage> createState() =>
      _ProductDetailsPageState();
}

class _ProductDetailsPageState
    extends State<ProductDetailsPage> {
  void refreshCart() {
    setState(() {});
    widget.onCartChanged();
  }

  Future<void> addProduct() async {
    final added =
        await CartController.addProduct(
      widget.product,
    );

    if (!mounted) return;

    if (added) {
      refreshCart();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text('Added to cart'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Maximum available stock reached'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    final cartItem =
        CartController.findItem(product.id);

    final quantity =
        cartItem?.quantity ?? 0;

    final outOfStock =
        product.stock <= 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Product Details',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.all(16),
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    child:
                        product.imageUrl.isNotEmpty
                            ? Image.network(
                                product.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (
                                  context,
                                  error,
                                  stack,
                                ) {
                                  return const Center(
                                    child: Icon(
                                      Icons
                                          .image_not_supported,
                                      size: 70,
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(
                                  Icons
                                      .shopping_bag_outlined,
                                  size: 80,
                                ),
                              ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  product.name.isEmpty
                      ? 'Unnamed Product'
                      : product.name,
                  style:
                      const TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                if (product.category
                    .isNotEmpty)
                  Chip(
                    label: Text(
                      product.category,
                    ),
                  ),

                const SizedBox(height: 10),

                ProductPrice(
                  product: product,
                  large: true,
                ),

                const SizedBox(height: 12),

                if (product.calculatedDiscount >
                    0)
                  Container(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                      color:
                          Colors.green.withValues(
                        alpha: 0.10,
                      ),
                    ),
                    child: Text(
                      'You save ₹${(product.numericMrp - product.numericPrice).toStringAsFixed(0)} on this product',
                      style:
                          const TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(
                      outOfStock
                          ? Icons
                              .cancel_outlined
                          : Icons
                              .check_circle_outline,
                      color: outOfStock
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : '${product.stock} items available',
                      style: TextStyle(
                        color: outOfStock
                            ? Colors.red
                            : Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Description',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  product.description.isEmpty
                      ? 'No description available for this product.'
                      : product.description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color:
                        Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.all(16),
            decoration:
                BoxDecoration(
              color: Theme.of(context)
                  .scaffoldBackgroundColor,
              border:
                  Border(
                top: BorderSide(
                  color:
                      Colors.grey.shade300,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: outOfStock
                    ? FilledButton(
                        onPressed: null,
                        child:
                            const Text(
                          'Out of Stock',
                        ),
                      )
                    : quantity == 0
                        ? FilledButton.icon(
                            onPressed:
                                addProduct,
                            icon:
                                const Icon(
                              Icons
                                  .add_shopping_cart,
                            ),
                            label:
                                const Text(
                              'Add to Cart',
                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child:
                                    OutlinedButton
                                        .icon(
                                  onPressed:
                                      () async {
                                    await CartController
                                        .decreaseQuantity(
                                      product.id,
                                    );

                                    refreshCart();
                                  },
                                  icon:
                                      const Icon(
                                    Icons
                                        .remove,
                                  ),
                                  label:
                                      const Text(
                                    'Remove',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Text(
                                '$quantity',
                                style:
                                    const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    FilledButton
                                        .icon(
                                  onPressed:
                                      quantity >=
                                              product
                                                  .stock
                                          ? null
                                          : () async {
                                              await CartController
                                                  .increaseQuantity(
                                                product
                                                    .id,
                                              );

                                              refreshCart();
                                            },
                                  icon:
                                      const Icon(
                                    Icons.add,
                                  ),
                                  label:
                                      const Text(
                                    'Add',
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
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

class CartPage extends StatefulWidget {
  final VoidCallback onCartChanged;

  const CartPage({
    super.key,
    required this.onCartChanged,
  });

  @override
  State<CartPage> createState() =>
      _CartPageState();
}

class _CartPageState
    extends State<CartPage> {
  Future<void> decrease(
    String productId,
  ) async {
    await CartController.decreaseQuantity(
      productId,
    );

    setState(() {});
    widget.onCartChanged();
  }

  Future<void> increase(
    String productId,
  ) async {
    await CartController.increaseQuantity(
      productId,
    );

    setState(() {});
    widget.onCartChanged();
  }

  Future<void> remove(
    String productId,
  ) async {
    await CartController.removeProduct(
      productId,
    );

    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          CartController.itemCount > 0
              ? 'My Cart (${CartController.itemCount})'
              : 'My Cart',
        ),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
              ),
            )
          : Column(
              children: [
                Expanded(
                  child:
                      ListView.builder(
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    itemCount: items.length,
                    itemBuilder:
                        (context, index) {
                      final item =
                          items[index];

                      return Card(
                        margin:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            10,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                height: 70,
                                child:
                                    ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                  child: item
                                          .imageUrl
                                          .isNotEmpty
                                      ? Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (
                                            context,
                                            error,
                                            stack,
                                          ) {
                                            return const Icon(
                                              Icons
                                                  .shopping_bag_outlined,
                                            );
                                          },
                                        )
                                      : const Icon(
                                          Icons
                                              .shopping_bag_outlined,
                                        ),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      item.name,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 5,
                                    ),

                                    ProductPrice(
                                      product:
                                          item.product,
                                    ),

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed:
                                              () =>
                                                  decrease(
                                            item.id,
                                          ),
                                          icon:
                                              const Icon(
                                            Icons
                                                .remove_circle_outline,
                                          ),
                                        ),

                                        Text(
                                          '${item.quantity}',
                                          style:
                                              const TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .bold,
                                          ),
                                        ),

                                        IconButton(
                                          onPressed: item.quantity >=
                                                  item.availableStock
                                              ? null
                                              : () =>
                                                  increase(
                                                    item.id,
                                                  ),
                                          icon:
                                              const Icon(
                                            Icons
                                                .add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                onPressed:
                                    () => remove(
                                  item.id,
                                ),
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Container(
                  padding:
                      const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    border:
                        Border(
                      top: BorderSide(
                        color: Colors
                            .grey
                            .shade300,
                      ),
                    ),
                  ),
                  child:
                      Column(
                    children: [
                      if (CartController
                              .totalSavings >
                          0)
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'You save',
                              style:
                                  TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            Text(
                              '₹${CartController.totalSavings.toStringAsFixed(0)}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ],
                        ),

                      if (CartController
                              .totalSavings >
                          0)
                        const SizedBox(
                          height: 6,
                        ),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style:
                                TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          Text(
                            '₹${CartController.total.toStringAsFixed(0)}',
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

                      const SizedBox(
                        height: 12,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        height: 52,
                        child:
                            FilledButton(
                          onPressed:
                              () async {
                            final user =
                                FirebaseAuth
                                    .instance
                                    .currentUser;

                            if (user ==
                                null) {
                              final loginResult =
                                  await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          const LoginPage(),
                                ),
                              );

                              if (loginResult !=
                                      true ||
                                  FirebaseAuth
                                          .instance
                                          .currentUser ==
                                      null) {
                                return;
                              }
                            }

                            final result =
                                await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const CheckoutPage(),
                              ),
                            );

                            if (result ==
                                    true &&
                                mounted) {
                              setState(
                                () {},
                              );
                              widget
                                  .onCartChanged();
                            }
                          },
                          child:
                              const Text(
                            'Proceed to Checkout',
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
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
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  final VoidCallback onProfileChanged;

  const ProfilePage({
    super.key,
    required this.onProfileChanged,
  });

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState
    extends State<ProfilePage> {
  Future<void> logout() async {
    try {
      await FirebaseAuth.instance
          .signOut();

      // Important:
      // Cart is NOT cleared during logout.
      // It remains stored locally.

      if (!mounted) return;

      widget.onProfileChanged();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Logged out successfully',
          ),
        ),
      );

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not logout. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> openLogin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
    );

    if (result == true && mounted) {
      widget.onProfileChanged();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    final isLoggedIn = user != null;

    final displayName =
        user?.displayName?.trim();

    final userName =
        (displayName != null &&
                displayName.isNotEmpty)
            ? displayName
            : 'Preesho Customer';

    final email = user?.email ?? '';
    final mobile =
        user?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
        ),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          CircleAvatar(
            radius: 42,
            child: Icon(
              isLoggedIn
                  ? Icons.person
                  : Icons.person_outline,
              size: 45,
            ),
          ),

          const SizedBox(height: 10),

          Center(
            child: Text(
              userName,
              style:
                  const TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          if (isLoggedIn &&
              email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                email,
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                ),
              ),
            ),
          ],

          if (isLoggedIn &&
              mobile.isNotEmpty) ...[
            const SizedBox(height: 4),
            Center(
              child: Text(
                mobile,
                style: TextStyle(
                  color:
                      Colors.grey.shade700,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          if (!isLoggedIn)
            ListTile(
              leading:
                  const Icon(Icons.login),
              title: const Text(
                'Login / Sign Up',
              ),
              subtitle:
                  const Text(
                'Login with OTP or password',
              ),
              onTap: openLogin,
            )
          else
            ListTile(
              leading:
                  const Icon(Icons.logout),
              title: const Text(
                'Logout',
              ),
              subtitle:
                  const Text(
                'Sign out from your account',
              ),
              onTap: logout,
            ),

          const ListTile(
            leading: Icon(
              Icons.location_on_outlined,
            ),
            title: Text(
              'Saved Addresses',
            ),
          ),

          ListTile(
            leading:
                const Icon(
              Icons.receipt_long,
            ),
            title: const Text(
              'My Orders',
            ),
            subtitle:
                const Text(
              'View your placed orders',
            ),
            onTap: () async {
              if (FirebaseAuth
                      .instance
                      .currentUser ==
                  null) {
                final result =
                    await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginPage(),
                  ),
                );

                if (result != true) {
                  return;
                }
              }

              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const OrdersPage(),
                ),
              );
            },
          ),

          ListTile(
            leading:
                const Icon(
              Icons.admin_panel_settings_outlined,
            ),
            title: const Text(
              'Admin Login',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const AdminLogin(),
                ),
              );
            },
          ),

          const ListTile(
            leading:
                Icon(Icons.help_outline),
            title: Text(
              'Help & Support',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEARCH
// ============================================================

class ProductSearch
    extends SearchDelegate<Product?> {
  final VoidCallback onCartChanged;

  ProductSearch(this.onCartChanged);

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon:
            const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(
        Icons.arrow_back,
      ),
    );
  }

  @override
  Widget buildResults(
    BuildContext context,
  ) {
    return ProductStream(
      builder: (products) {
        final searchQuery =
            query.trim().toLowerCase();

        final results = products
            .where(
              (product) {
                if (searchQuery.isEmpty) {
                  return true;
                }

                return product.name
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        ) ||
                    product.category
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        ) ||
                    product.description
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        );
              },
            )
            .toList();

        return _searchList(
          context,
          results,
        );
      },
    );
  }

  @override
  Widget buildSuggestions(
    BuildContext context,
  ) {
    return ProductStream(
      builder: (products) {
        final searchQuery =
            query.trim().toLowerCase();

        final results = products
            .where(
              (product) {
                if (searchQuery.isEmpty) {
                  return true;
                }

                return product.name
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        ) ||
                    product.category
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        ) ||
                    product.description
                        .toLowerCase()
                        .contains(
                          searchQuery,
                        );
              },
            )
            .toList();

        return _searchList(
          context,
          results,
        );
      },
    );
  }

  Widget _searchList(
    BuildContext context,
    List<Product> products,
  ) {
    if (products.isEmpty) {
      return const Center(
        child: Text(
          'No products found',
        ),
      );
    }

    return ListView(
      padding:
          const EdgeInsets.all(12),
      children: products
          .map(
            (product) =>
                ProductTile(
              product: product,
              onCartChanged:
                  onCartChanged,
            ),
          )
          .toList(),
    );
  }
}
