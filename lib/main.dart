import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Existing price field
  final String price;

  final int stock;
  final String imageUrl;
  final String description;
  final bool active;

  // New discount fields
  final double mrp;
  final double discountPercent;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
    required this.description,
    required this.active,
    this.mrp = 0,
    this.discountPercent = 0,
  });

  double get numericPrice {
    return double.tryParse(
          price.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;
  }

  // Selling price after discount.
  double get sellingPrice {
    if (discountPercent > 0 && mrp > 0) {
      final calculated =
          mrp - (mrp * discountPercent / 100);

      return calculated > 0 ? calculated : 0;
    }

    return numericPrice;
  }

  double get originalPrice {
    if (mrp > 0) {
      return mrp;
    }

    return numericPrice;
  }

  bool get hasDiscount {
    return discountPercent > 0 &&
        originalPrice > sellingPrice;
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

  double get numericPrice => product.sellingPrice;

  double get originalPrice => product.originalPrice;

  double get discountPercent =>
      product.discountPercent;

  double get totalPrice =>
      numericPrice * quantity;

  int get availableStock => product.stock;
}

// ============================================================
// CART CONTROLLER
// ============================================================

class CartController {
  static const String _storageKey =
      'preesho_cart_v2';

  static final List<CartItem> items = [];

  static SharedPreferences? _preferences;

  static bool _initialized = false;

  // ----------------------------------------------------------
  // INITIALIZE CART
  // ----------------------------------------------------------

  static Future<void> initialize() async {
    if (_initialized) return;

    _preferences =
        await SharedPreferences.getInstance();

    await _loadCart();

    _initialized = true;
  }

  // ----------------------------------------------------------
  // LOAD CART
  // ----------------------------------------------------------

  static Future<void> _loadCart() async {
    try {
      final saved =
          _preferences?.getString(_storageKey);

      if (saved == null || saved.isEmpty) {
        return;
      }

      final decoded =
          jsonDecode(saved);

      if (decoded is! List) {
        return;
      }

      for (final item in decoded) {
        if (item is! Map) continue;

        final productData =
            item['product'];

        if (productData is! Map) {
          continue;
        }

        final product = Product(
          id: productData['id']?.toString() ?? '',
          name:
              productData['name']?.toString() ?? '',
          category:
              productData['category']?.toString() ?? '',
          price:
              productData['price']?.toString() ?? '0',
          stock: int.tryParse(
                productData['stock']?.toString() ??
                    '0',
              ) ??
              0,
          imageUrl:
              productData['imageUrl']?.toString() ??
                  '',
          description:
              productData['description']?.toString() ??
                  '',
          active:
              productData['active'] == true,
          mrp:
              double.tryParse(
                    productData['mrp']?.toString() ??
                        '0',
                  ) ??
                  0,
          discountPercent:
              double.tryParse(
                    productData['discountPercent']
                            ?.toString() ??
                        '0',
                  ) ??
                  0,
        );

        final quantity =
            int.tryParse(
                  item['quantity']?.toString() ??
                      '1',
                ) ??
                1;

        if (product.id.isEmpty ||
            quantity <= 0 ||
            product.stock <= 0) {
          continue;
        }

        final safeQuantity =
            quantity > product.stock
                ? product.stock
                : quantity;

        items.add(
          CartItem(
            product: product,
            quantity: safeQuantity,
          ),
        );
      }
    } catch (_) {
      items.clear();
    }
  }

  // ----------------------------------------------------------
  // SAVE CART
  // ----------------------------------------------------------

  static Future<void> _saveCart() async {
    try {
      final data = items.map((item) {
        return {
          'quantity': item.quantity,
          'product': {
            'id': item.product.id,
            'name': item.product.name,
            'category': item.product.category,
            'price': item.product.price,
            'stock': item.product.stock,
            'imageUrl': item.product.imageUrl,
            'description':
                item.product.description,
            'active': item.product.active,
            'mrp': item.product.mrp,
            'discountPercent':
                item.product.discountPercent,
          },
        };
      }).toList();

      await _preferences?.setString(
        _storageKey,
        jsonEncode(data),
      );
    } catch (_) {}
  }

  // ----------------------------------------------------------
  // TOTAL
  // ----------------------------------------------------------

  static double get total {
    return items.fold(
      0,
      (sum, item) => sum + item.totalPrice,
    );
  }

  // ----------------------------------------------------------
  // ORIGINAL TOTAL
  // ----------------------------------------------------------

  static double get originalTotal {
    return items.fold(
      0,
      (sum, item) =>
          sum +
          (item.originalPrice *
              item.quantity),
    );
  }

  // ----------------------------------------------------------
  // PRODUCT DISCOUNT SAVING
  // ----------------------------------------------------------

  static double get productSavings {
    final saving =
        originalTotal - total;

    return saving > 0 ? saving : 0;
  }

  // ----------------------------------------------------------
  // FIND ITEM
  // ----------------------------------------------------------

  static CartItem? findItem(
    String productId,
  ) {
    try {
      return items.firstWhere(
        (item) => item.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // ADD PRODUCT
  // ----------------------------------------------------------

  static Future<bool> addProduct(
    Product product,
  ) async {
    if (product.stock <= 0) {
      return false;
    }

    final existing =
        findItem(product.id);

    if (existing != null) {
      if (existing.quantity >=
          product.stock) {
        return false;
      }

      existing.quantity++;

      await _saveCart();

      return true;
    }

    items.add(
      CartItem(
        product: product,
        quantity: 1,
      ),
    );

    await _saveCart();

    return true;
  }

  // ----------------------------------------------------------
  // INCREASE
  // ----------------------------------------------------------

  static Future<bool> increaseQuantity(
    String productId,
  ) async {
    final item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (item.quantity >=
        item.availableStock) {
      return false;
    }

    item.quantity++;

    await _saveCart();

    return true;
  }

  // ----------------------------------------------------------
  // DECREASE
  // ----------------------------------------------------------

  static Future<bool> decreaseQuantity(
    String productId,
  ) async {
    final item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (item.quantity > 1) {
      item.quantity--;
    } else {
      items.remove(item);
    }

    await _saveCart();

    return true;
  }

  // ----------------------------------------------------------
  // REMOVE
  // ----------------------------------------------------------

  static Future<void> removeProduct(
    String productId,
  ) async {
    items.removeWhere(
      (item) => item.id == productId,
    );

    await _saveCart();
  }

  // ----------------------------------------------------------
  // CLEAR
  // ----------------------------------------------------------

  static Future<void> clear() async {
    items.clear();

    await _preferences?.remove(
      _storageKey,
    );
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
        colorSchemeSeed:
            Colors.deepPurple,
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
  State<MainShell> createState() =>
      _MainShellState();
}

class _MainShellState
    extends State<MainShell> {
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
      bottomNavigationBar:
          NavigationBar(
        selectedIndex: index,
        onDestinationSelected:
            (i) {
          setState(() {
            index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon:
                Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.category_outlined,
            ),
            selectedIcon:
                Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.shopping_cart_outlined,
            ),
            selectedIcon: Icon(
              Icons.shopping_cart,
            ),
            label: 'Cart',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(Icons.person),
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

class ProductStream
    extends StatelessWidget {
  final Widget Function(
    List<Product> products,
  ) builder;

  const ProductStream({
    super.key,
    required this.builder,
  });

  Product productFromDocument(
    QueryDocumentSnapshot<
        Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final rawMrp =
        double.tryParse(
              data['MRP']?.toString() ??
                  data['Mrp']?.toString() ??
                  '0',
            ) ??
            0;

    final rawDiscount =
        double.tryParse(
              data['DiscountPercent']
                      ?.toString() ??
                  data['Discount']
                      ?.toString() ??
                  '0',
            ) ??
            0;

    return Product(
      id: doc.id,
      name:
          data['Name']?.toString() ?? '',
      category:
          data['Category']?.toString() ??
              '',
      price:
          data['Price']?.toString() ??
              '0',
      stock: int.tryParse(
            data['Stock']?.toString() ??
                '0',
          ) ??
          0,
      imageUrl:
          data['Imageurl']?.toString() ??
              data['ImageUrl']
                  ?.toString() ??
              '',
      description:
          data['Description']
                  ?.toString() ??
              '',
      active:
          data['Active'] == true,
      mrp: rawMrp,
      discountPercent:
          rawDiscount,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return StreamBuilder<
        QuerySnapshot<
            Map<String, dynamic>>>(
      stream: FirebaseFirestore
          .instance
          .collection('products')
          .snapshots(),
      builder:
          (context, snapshot) {
        if (snapshot
                .connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
                CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                20,
              ),
              child: Text(
                'Unable to load products.\n\n${snapshot.error}',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        final products = docs
            .map(
              productFromDocument,
            )
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
// HOME PAGE
// ============================================================

class HomePage
    extends StatelessWidget {
  final VoidCallback onCartChanged;

  const HomePage({
    super.key,
    required this.onCartChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate:
                    ProductSearch(
                  onCartChanged,
                ),
              );
            },
            icon: const Icon(
              Icons.search,
            ),
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
            padding:
                const EdgeInsets.all(
              16,
            ),
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  22,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xff5E35B1),
                      Color(0xff8E24AA),
                    ],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Welcome to Preesho',
                      style: TextStyle(
                        color:
                            Colors.white,
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    SizedBox(
                      height: 7,
                    ),
                    Text(
                      'Shop smarter. Shop faster.',
                      style:
                          TextStyle(
                        color: Colors
                            .white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              SizedBox(
                height: 90,
                child: ListView(
                  scrollDirection:
                      Axis.horizontal,
                  children:
                      const [
                    CategoryCard(
                      icon: Icons
                          .phone_android,
                      text:
                          'Electronics',
                    ),
                    CategoryCard(
                      icon: Icons
                          .checkroom,
                      text: 'Fashion',
                    ),
                    CategoryCard(
                      icon:
                          Icons.home,
                      text: 'Home',
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              const Text(
                'Products',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              if (products.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    30,
                  ),
                  child: Center(
                    child: Text(
                      'No products available',
                    ),
                  ),
                ),

              ...products.map(
                (product) =>
                    ProductTile(
                  product:
                      product,
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

class CategoryCard
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: SizedBox(
        width: 115,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment
                  .center,
          children: [
            Icon(icon),
            const SizedBox(
              height: 5,
            ),
            Text(
              text,
              style:
                  const TextStyle(
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

class CategoriesPage
    extends StatelessWidget {
  final VoidCallback onCartChanged;

  const CategoriesPage({
    super.key,
    required this.onCartChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Categories'),
      ),
      body: ProductStream(
        builder: (products) {
          final categories =
              products
                  .map(
                    (p) => p.category,
                  )
                  .where(
                    (c) =>
                        c.isNotEmpty,
                  )
                  .toSet()
                  .toList();

          if (categories
              .isEmpty) {
            return const Center(
              child: Text(
                'No categories available',
              ),
            );
          }

          return ListView(
            children:
                categories.map(
              (category) {
                final categoryProducts =
                    products
                        .where(
                          (p) =>
                              p.category ==
                              category,
                        )
                        .toList();

                return ExpansionTile(
                  title:
                      Text(category),
                  leading:
                      const Icon(
                    Icons.category,
                  ),
                  children:
                      categoryProducts
                          .map(
                    (product) =>
                        ProductTile(
                      product:
                          product,
                      onCartChanged:
                          onCartChanged,
                    ),
                  ).toList(),
                );
              },
            ).toList(),
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCT TILE
// ============================================================

class ProductTile
    extends StatelessWidget {
  final Product product;
  final VoidCallback onCartChanged;

  const ProductTile({
    super.key,
    required this.product,
    required this.onCartChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final cartItem =
        CartController.findItem(
      product.id,
    );

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
                width: 75,
                height: 75,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  child: product
                          .imageUrl
                          .isNotEmpty
                      ? Image.network(
                          product
                              .imageUrl,
                          fit: BoxFit
                              .cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stack,
                          ) {
                            return const ColoredBox(
                              color: Colors
                                  .black12,
                              child:
                                  Icon(
                                Icons
                                    .image_not_supported,
                              ),
                            );
                          },
                        )
                      : const ColoredBox(
                          color:
                              Colors.black12,
                          child:
                              Icon(
                            Icons
                                .shopping_bag_outlined,
                          ),
                        ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      product.name
                              .isEmpty
                          ? 'Unnamed Product'
                          : product.name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      product.category,
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    if (product
                        .hasDiscount)
                      Row(
                        children: [
                          Text(
                            '₹${product.originalPrice.toStringAsFixed(0)}',
                            style:
                                TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              decoration:
                                  TextDecoration
                                      .lineThrough,
                            ),
                          ),
                          const SizedBox(
                            width: 7,
                          ),
                          Text(
                            '${product.discountPercent.toStringAsFixed(0)}% OFF',
                            style:
                                const TextStyle(
                              color: Colors
                                  .green,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      '₹${product.sellingPrice.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight
                                .bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : 'Stock: ${product.stock}',
                      style: TextStyle(
                        color:
                            outOfStock
                                ? Colors
                                    .red
                                : Colors
                                    .green,
                        fontWeight:
                            FontWeight
                                .w600,
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
                    style:
                        TextStyle(
                      color:
                          Colors.red,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                )
              else if (cartQuantity ==
                  0)
                IconButton.filled(
                  onPressed:
                      () async {
                    final added =
                        await CartController
                            .addProduct(
                      product,
                    );

                    if (added) {
                      onCartChanged();

                      if (!context
                          .mounted) {
                        return;
                      }

                      ScaffoldMessenger
                          .of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Added to cart',
                          ),
                          duration:
                              Duration(
                            seconds: 1,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons
                        .add_shopping_cart,
                  ),
                )
              else
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed:
                          () async {
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
                            FontWeight
                                .bold,
                      ),
                    ),

                    IconButton(
                      onPressed:
                          cartQuantity >=
                                  product
                                      .stock
                              ? null
                              : () async {
                                  await CartController
                                      .increaseQuantity(
                                    product
                                        .id,
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
  State<ProductDetailsPage>
      createState() =>
          _ProductDetailsPageState();
}

class _ProductDetailsPageState
    extends State<
        ProductDetailsPage> {
  void refreshCart() {
    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final product =
        widget.product;

    final cartItem =
        CartController.findItem(
      product.id,
    );

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
                  const EdgeInsets.all(
                16,
              ),
              children: [
                Container(
                  height: 300,
                  width:
                      double.infinity,
                  decoration:
                      BoxDecoration(
                    color: Colors
                        .grey
                        .shade100,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child:
                      ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                    child: product
                            .imageUrl
                            .isNotEmpty
                        ? Image.network(
                            product
                                .imageUrl,
                            fit: BoxFit
                                .cover,
                            errorBuilder:
                                (
                              context,
                              error,
                              stack,
                            ) {
                              return const Center(
                                child:
                                    Icon(
                                  Icons
                                      .image_not_supported,
                                  size: 70,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child:
                                Icon(
                              Icons
                                  .shopping_bag_outlined,
                              size: 80,
                            ),
                          ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                Text(
                  product.name
                          .isEmpty
                      ? 'Unnamed Product'
                      : product.name,
                  style:
                      const TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                if (product
                    .category
                    .isNotEmpty)
                  Chip(
                    label: Text(
                      product
                          .category,
                    ),
                  ),

                const SizedBox(
                  height: 10,
                ),

                if (product
                    .hasDiscount)
                  Row(
                    children: [
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style:
                            TextStyle(
                          fontSize: 18,
                          color: Colors
                              .grey
                              .shade600,
                          decoration:
                              TextDecoration
                                  .lineThrough,
                        ),
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style:
                            const TextStyle(
                          fontSize: 17,
                          color: Colors
                              .green,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '₹${product.sellingPrice.toStringAsFixed(0)}',
                  style:
                      const TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight
                            .bold,
                    color: Colors
                        .deepPurple,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Row(
                  children: [
                    Icon(
                      outOfStock
                          ? Icons
                              .cancel_outlined
                          : Icons
                              .check_circle_outline,
                      color:
                          outOfStock
                              ? Colors
                                  .red
                              : Colors
                                  .green,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : '${product.stock} items available',
                      style:
                          TextStyle(
                        color:
                            outOfStock
                                ? Colors
                                    .red
                                : Colors
                                    .green,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  'Description',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  product
                          .description
                          .isEmpty
                      ? 'No description available for this product.'
                      : product
                          .description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors
                        .grey
                        .shade700,
                  ),
                ),

                const SizedBox(
                  height: 30,
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets.all(
              16,
            ),
            decoration:
                BoxDecoration(
              color: Theme.of(
                context,
              )
                  .scaffoldBackgroundColor,
              border:
                  Border(
                top:
                    BorderSide(
                  color: Colors
                      .grey
                      .shade300,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width:
                    double.infinity,
                height: 54,
                child: outOfStock
                    ? FilledButton(
                        onPressed:
                            null,
                        child:
                            const Text(
                          'Out of Stock',
                        ),
                      )
                    : quantity ==
                            0
                        ? FilledButton
                            .icon(
                            onPressed:
                                () async {
                              final added =
                                  await CartController
                                      .addProduct(
                                product,
                              );

                              if (added) {
                                refreshCart();

                                if (!context
                                    .mounted) {
                                  return;
                                }

                                ScaffoldMessenger
                                    .of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text(
                                      'Added to cart',
                                    ),
                                  ),
                                );
                              }
                            },
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
                                    OutlinedButton.icon(
                                  onPressed:
                                      () async {
                                    await CartController
                                        .decreaseQuantity(
                                      product
                                          .id,
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
                                  fontSize:
                                      20,
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
                                    FilledButton.icon(
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

class CartPage
    extends StatefulWidget {
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
  @override
  Widget build(
    BuildContext context,
  ) {
    final items =
        CartController.items;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Cart'),
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
                        const EdgeInsets
                            .all(
                      12,
                    ),
                    itemCount:
                        items.length,
                    itemBuilder:
                        (context,
                            index) {
                      final item =
                          items[index];

                      return Card(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 12,
                        ),
                        child:
                            Padding(
                          padding:
                              const EdgeInsets
                                  .all(
                            10,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width:
                                    70,
                                height:
                                    70,
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
                                      ? Image
                                          .network(
                                          item
                                              .imageUrl,
                                          fit: BoxFit
                                              .cover,
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
                                      item
                                          .name,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height:
                                          5,
                                    ),

                                    if (item
                                            .originalPrice >
                                        item
                                            .numericPrice)
                                      Text(
                                        '₹${item.originalPrice.toStringAsFixed(0)}',
                                        style:
                                            TextStyle(
                                          color: Colors
                                              .grey
                                              .shade600,
                                          decoration:
                                              TextDecoration
                                                  .lineThrough,
                                        ),
                                      ),

                                    Text(
                                      '₹${item.numericPrice.toStringAsFixed(0)}',
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    if (item
                                            .discountPercent >
                                        0)
                                      Text(
                                        '${item.discountPercent.toStringAsFixed(0)}% OFF',
                                        style:
                                            const TextStyle(
                                          color:
                                              Colors.green,
                                          fontWeight:
                                              FontWeight.bold,
                                        ),
                                      ),

                                    const SizedBox(
                                      height:
                                          8,
                                    ),

                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed:
                                              () async {
                                            await CartController
                                                .decreaseQuantity(
                                              item
                                                  .id,
                                            );

                                            if (!mounted) {
                                              return;
                                            }

                                            setState(
                                              () {},
                                            );

                                            widget
                                                .onCartChanged();
                                          },
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
                                          onPressed:
                                              item.quantity >=
                                                      item.availableStock
                                                  ? null
                                                  : () async {
                                                      await CartController
                                                          .increaseQuantity(
                                                        item
                                                            .id,
                                                      );

                                                      if (!mounted) {
                                                        return;
                                                      }

                                                      setState(
                                                        () {},
                                                      );

                                                      widget
                                                          .onCartChanged();
                                                    },
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
                                    () async {
                                  await CartController
                                      .removeProduct(
                                    item.id,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  setState(
                                    () {},
                                  );

                                  widget
                                      .onCartChanged();
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .delete_outline,
                                  color: Colors
                                      .red,
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
                      const EdgeInsets
                          .all(
                    16,
                  ),
                  decoration:
                      BoxDecoration(
                    border:
                        Border(
                      top:
                          BorderSide(
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
                              .productSavings >
                          0)
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            const Text(
                              'Product Savings',
                            ),
                            Text(
                              '- ₹${CartController.productSavings.toStringAsFixed(0)}',
                              style:
                                  const TextStyle(
                                color:
                                    Colors.green,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

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
                              fontSize:
                                  20,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          Text(
                            '₹${CartController.total.toStringAsFixed(0)}',
                            style:
                                const TextStyle(
                              fontSize:
                                  22,
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
                                  await Navigator
                                      .push(
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
                                await Navigator
                                    .push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const CheckoutPage(),
                              ),
                            );

                            if (result ==
                                true) {
                              if (!mounted) {
                                return;
                              }

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
                              fontSize:
                                  16,
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

class ProfilePage
    extends StatefulWidget {
  final VoidCallback
      onProfileChanged;

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
      await FirebaseAuth
          .instance
          .signOut();

      // Important:
      // Cart is NOT cleared on logout.
      //
      // This fixes the issue where customer
      // goes back / logs out and cart disappears.
      //
      // Later we can make cart user-specific.

      if (!mounted) return;

      widget
          .onProfileChanged();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Logged out successfully',
          ),
        ),
      );

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not logout. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> openLogin() async {
    final result =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginPage(),
      ),
    );

    if (result == true &&
        mounted) {
      widget
          .onProfileChanged();

      setState(() {});
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final user =
        FirebaseAuth
            .instance
            .currentUser;

    final isLoggedIn =
        user != null;

    final displayName =
        user?.displayName?.trim();

    final userName =
        (displayName != null &&
                displayName
                    .isNotEmpty)
            ? displayName
            : 'Preesho Customer';

    final email =
        user?.email ?? '';

    final mobile =
        user?.phoneNumber ?? '';

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Profile'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(
          16,
        ),
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

          const SizedBox(
            height: 10,
          ),

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
            const SizedBox(
              height: 4,
            ),
            Center(
              child: Text(
                email,
                style: TextStyle(
                  color: Colors
                      .grey
                      .shade700,
                ),
              ),
            ),
          ],

          if (isLoggedIn &&
              mobile.isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),
            Center(
              child: Text(
                mobile,
                style: TextStyle(
                  color: Colors
                      .grey
                      .shade700,
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 20,
          ),

          if (!isLoggedIn)
            ListTile(
              leading: const Icon(
                Icons.login,
              ),
              title:
                  const Text(
                'Login / Sign Up',
              ),
              subtitle:
                  const Text(
                'Login with OTP or password',
              ),
              onTap:
                  openLogin,
            )
          else
            ListTile(
              leading:
                  const Icon(
                Icons.logout,
              ),
              title:
                  const Text(
                'Logout',
              ),
              subtitle:
                  const Text(
                'Sign out from your account',
              ),
              onTap:
                  logout,
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
            title:
                const Text(
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
                    await Navigator
                        .push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const LoginPage(),
                  ),
                );

                if (result !=
                    true) {
                  return;
                }
              }

              if (!mounted) {
                return;
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const OrdersPage(),
                ),
              );
            },
          ),

          // --------------------------------------------------
          // NOTE:
          // Admin will be moved to separate app.
          // Existing button is kept temporarily so
          // current project doesn't break.
          // --------------------------------------------------

          ListTile(
            leading:
                const Icon(
              Icons
                  .admin_panel_settings_outlined,
            ),
            title:
                const Text(
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
                Icon(
              Icons.help_outline,
            ),
            title:
                Text(
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

  ProductSearch(
    this.onCartChanged,
  );

  @override
  List<Widget>? buildActions(
    BuildContext context,
  ) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(
          Icons.clear,
        ),
      ),
    ];
  }

  @override
  Widget buildLeading(
    BuildContext context,
  ) {
    return IconButton(
      onPressed: () {
        close(
          context,
          null,
        );
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
            query
                .trim()
                .toLowerCase();

        final results =
            products.where(
          (product) {
            if (searchQuery
                .isEmpty) {
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
        ).toList();

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
            query
                .trim()
                .toLowerCase();

        final results =
            products.where(
          (product) {
            if (searchQuery
                .isEmpty) {
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
        ).toList();

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
          const EdgeInsets.all(
        12,
      ),
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
