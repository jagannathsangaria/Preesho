import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_page.dart';
import 'login_page.dart';
import 'admin_login.dart';
import 'orders_page.dart';

import 'courier_documents_page.dart';
import 'courier_panel.dart';

import 'models/preesho_models.dart';
import 'cart/cart_controller.dart';
import 'cart/cart_page.dart';

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
// CART ICON
// ============================================================

class CartIconButton extends StatelessWidget {
  final VoidCallback onCartChanged;

  const CartIconButton({
    super.key,
    required this.onCartChanged,
  });

  void openCart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CartPage(
          onCartChanged: onCartChanged,
        ),
      ),
    ).then((_) {
      onCartChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    final count = CartController.itemCount;

    return IconButton(
      tooltip: 'Cart',
      onPressed: () {
        openCart(context);
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.shopping_cart_outlined,
            size: 27,
          ),
          if (count > 0)
            Positioned(
              right: -7,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 19,
                  minHeight: 19,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
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
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xffF7F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AppEntry(),
    );
  }
}

// ============================================================
// APP ENTRY / USER ROUTING
// ============================================================

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      final user = auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _loading = false;
        });

        return;
      }

      final uid = user.uid;

      final results = await Future.wait([
        firestore
            .collection('users')
            .doc(uid)
            .get(),
        firestore
            .collection('couriers')
            .doc(uid)
            .get(),
      ]);

      final userSnapshot =
          results[0] as DocumentSnapshot<Map<String, dynamic>>;

      final courierSnapshot =
          results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final userData =
          userSnapshot.data() ?? <String, dynamic>{};

      final courierData =
          courierSnapshot.data() ?? <String, dynamic>{};

      final userRole =
          userData['role']?.toString().trim().toLowerCase() ?? '';

      final courierRole =
          courierData['role']?.toString().trim().toLowerCase() ?? '';

      final isCourier =
          userRole == 'courier' ||
          courierRole == 'courier' ||
          courierSnapshot.exists;

      if (isCourier) {
        String firstNonEmpty(
          dynamic first,
          dynamic second,
        ) {
          final firstValue =
              first?.toString().trim() ?? '';

          if (firstValue.isNotEmpty) {
            return firstValue.toLowerCase();
          }

          return second
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';
        }

        final status = firstNonEmpty(
          courierData['status'],
          userData['status'],
        );

        final active =
            courierData['active'] == true ||
                userData['active'] == true;

        final approvedByAdmin =
            courierData['approvedByAdmin'] == true ||
                userData['approvedByAdmin'] == true;

        final approved =
            status == 'approved' ||
            status == 'active';

        if (approved &&
            active &&
            approvedByAdmin) {
          if (!mounted) return;

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const CourierPanel(),
            ),
            (route) => false,
          );

          return;
        }

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => CourierDocumentsPage(
              courierUid: uid,
            ),
          ),
          (route) => false,
        );

        return;
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'AppEntry session check error: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error =
            'Unable to check your account.\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 55,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _checkUserSession,
                  child: const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainShell();
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
      ProfilePage(
        onProfileChanged: refresh,
        onCartChanged: refresh,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() {
            index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
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

    final rawMrp =
        double.tryParse(
              data['MRP']?.toString() ??
                  data['Mrp']?.toString() ??
                  '0',
            ) ??
            0;

    final rawDiscount =
        double.tryParse(
              data['DiscountPercent']?.toString() ??
                  data['Discount']?.toString() ??
                  '0',
            ) ??
            0;

    return Product(
      id: doc.id,
      name: data['Name']?.toString() ?? '',
      category: data['Category']?.toString() ?? '',
      price: data['Price']?.toString() ?? '0',
      stock:
          int.tryParse(
                data['Stock']?.toString() ?? '0',
              ) ??
              0,
      imageUrl:
          data['Imageurl']?.toString() ??
              data['ImageUrl']?.toString() ??
              '',
      description:
          data['Description']?.toString() ?? '',
      active: data['Active'] == true,
      mrp: rawMrp,
      discountPercent: rawDiscount,
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
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  final VoidCallback onCartChanged;

  const HomePage({
    super.key,
    required this.onCartChanged,
  });

  void openOrders(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrdersPage(),
      ),
    );
  }

  void openCategory(
    BuildContext context,
    String category,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsPage(
          category: category,
          onCartChanged: onCartChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F7FA),
      appBar: AppBar(
        titleSpacing: 16,
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'My Orders',
            onPressed: () => openOrders(context),
            icon: const Icon(
              Icons.receipt_long_outlined,
              size: 25,
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .hideCurrentSnackBar();

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Notifications coming soon',
                  ),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(
              Icons.notifications_none_rounded,
              size: 27,
            ),
          ),
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          return RefreshIndicator(
            onRefresh: () async {
              onCartChanged();

              await Future.delayed(
                const Duration(milliseconds: 500),
              );
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                30,
              ),
              children: [
                InkWell(
                  borderRadius:
                      BorderRadius.circular(18),
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: ProductSearch(
                        onCartChanged,
                      ),
                    ).then((_) {
                      onCartChanged();
                    });
                  },
                  child: Container(
                    height: 54,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                          color:
                              Colors.black.withValues(
                            alpha: 0.06,
                          ),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Search products...',
                          style: TextStyle(
                            color:
                                Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // HERO BANNER
                // ------------------------------------------------

                Container(
                  height: 175,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xff4527A0),
                        Color(0xff7B1FA2),
                        Color(0xffAD1457),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                        color:
                            Colors.deepPurple.withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        bottom: -35,
                        child: Icon(
                          Icons.shopping_bag_rounded,
                          size: 150,
                          color:
                              Colors.white.withValues(
                            alpha: 0.10,
                          ),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to Preesho 👋',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight:
                                  FontWeight.w800,
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
                          SizedBox(height: 18),
                          Text(
                            '✨ Great products • Great prices',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // CATEGORY HEADER
                // ------------------------------------------------

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shop by Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CategoriesPage(
                              onCartChanged:
                                  onCartChanged,
                            ),
                          ),
                        );
                      },
                      child:
                          const Text('View All'),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ------------------------------------------------
                // CLICKABLE CATEGORIES
                // ------------------------------------------------

                SizedBox(
                  height: 112,
                  child: ListView(
                    scrollDirection:
                        Axis.horizontal,
                    children: [
                      CategoryCard(
                        icon:
                            Icons.phone_android_rounded,
                        text: 'Electronics',
                        onTap: () {
                          openCategory(
                            context,
                            'Electronics',
                          );
                        },
                      ),
                      CategoryCard(
                        icon:
                            Icons.checkroom_rounded,
                        text: 'Fashion',
                        onTap: () {
                          openCategory(
                            context,
                            'Fashion',
                          );
                        },
                      ),
                      CategoryCard(
                        icon:
                            Icons.home_rounded,
                        text: 'Home',
                        onTap: () {
                          openCategory(
                            context,
                            'Home',
                          );
                        },
                      ),
                      CategoryCard(
                        icon:
                            Icons.watch_rounded,
                        text: 'Accessories',
                        onTap: () {
                          openCategory(
                            context,
                            'Accessories',
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ------------------------------------------------
                // LATEST PRODUCTS
                // ------------------------------------------------

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Latest Products',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${products.length} items',
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                if (products.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons
                                .inventory_2_outlined,
                            size: 50,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No products available',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.68,
                    ),
                    itemBuilder:
                        (context, index) {
                      return ProductTile(
                        product:
                            products[index],
                        onCartChanged:
                            onCartChanged,
                      );
                    },
                  ),
              ],
            ),
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
  final VoidCallback? onTap;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(
        right: 12,
      ),
      child: Material(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        elevation: 1.5,
        shadowColor:
            Colors.black.withValues(
          alpha: 0.08,
        ),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        primary.withValues(
                      alpha: 0.10,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 27,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
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

// ============================================================
// CATEGORY PRODUCTS PAGE
// ============================================================

class CategoryProductsPage
    extends StatelessWidget {
  final String category;
  final VoidCallback onCartChanged;

  const CategoryProductsPage({
    super.key,
    required this.category,
    required this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF7F7FA),
      appBar: AppBar(
        title: Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged:
                onCartChanged,
          ),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          final selectedCategory =
              category.trim().toLowerCase();

          final categoryProducts =
              products.where((product) {
            final productCategory =
                product.category
                    .trim()
                    .toLowerCase();

            return productCategory ==
                selectedCategory;
          }).toList();

          if (categoryProducts.isEmpty) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration:
                          BoxDecoration(
                        color: Colors.white,
                        shape:
                            BoxShape.circle,
                      ),
                      child: Icon(
                        Icons
                            .inventory_2_outlined,
                        size: 52,
                        color: Colors
                            .grey
                            .shade400,
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    const Text(
                      'No products found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      'There are no products in $category yet.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(
                          context,
                        );
                      },
                      icon: const Icon(
                        Icons
                            .arrow_back_rounded,
                      ),
                      label: const Text(
                        'Back to Home',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  4,
                ),
                child: Row(
                  children: [
                    Text(
                      '${categoryProducts.length} products',
                      style: TextStyle(
                        color:
                            Colors.grey.shade700,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding:
                      const EdgeInsets.all(16),
                  itemCount:
                      categoryProducts.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                  itemBuilder:
                      (context, index) {
                    return ProductTile(
                      product:
                          categoryProducts[
                              index],
                      onCartChanged:
                          onCartChanged,
                    );
                  },
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
// CATEGORIES PAGE
// ============================================================

class CategoriesPage
    extends StatelessWidget {
  final VoidCallback onCartChanged;

  const CategoriesPage({
    super.key,
    required this.onCartChanged,
  });

  IconData categoryIcon(
    String category,
  ) {
    final value =
        category.toLowerCase();

    if (value.contains('electronic')) {
      return Icons.phone_android_rounded;
    }

    if (value.contains('fashion') ||
        value.contains('cloth')) {
      return Icons.checkroom_rounded;
    }

    if (value.contains('home')) {
      return Icons.home_rounded;
    }

    if (value.contains('accessor')) {
      return Icons.watch_rounded;
    }

    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF7F7FA),
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged:
                onCartChanged,
          ),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          final categories = products
              .map(
                (p) => p.category.trim(),
              )
              .where(
                (c) => c.isNotEmpty,
              )
              .toSet()
              .toList();

          if (categories.isEmpty) {
            return const Center(
              child: Text(
                'No categories available',
              ),
            );
          }

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),
            itemCount:
                categories.length,
            itemBuilder:
                (context, index) {
              final category =
                  categories[index];

              final categoryCount =
                  products.where(
                (product) =>
                    product.category
                        .trim()
                        .toLowerCase() ==
                    category
                        .trim()
                        .toLowerCase(),
              ).length;

              return Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset:
                          const Offset(0, 5),
                      color: Colors.black
                          .withValues(
                        alpha: 0.06,
                      ),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CategoryProductsPage(
                            category:
                                category,
                            onCartChanged:
                                onCartChanged,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration:
                                BoxDecoration(
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .primary
                                  .withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                            ),
                            child: Icon(
                              categoryIcon(
                                category,
                              ),
                              color: Theme.of(
                                context,
                              )
                                  .colorScheme
                                  .primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(
                            width: 15,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  category,
                                  style:
                                      const TextStyle(
                                    fontSize:
                                        17,
                                    fontWeight:
                                        FontWeight
                                            .w800,
                                  ),
                                ),
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  '$categoryCount products',
                                  style:
                                      TextStyle(
                                    color: Colors
                                        .grey
                                        .shade600,
                                    fontSize:
                                        13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons
                                .arrow_forward_ios_rounded,
                            size: 17,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCT CARD
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
  Widget build(BuildContext context) {
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
          BorderRadius.circular(20),
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
      child: Container(
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset:
                  const Offset(0, 5),
              color:
                  Colors.black.withValues(
                alpha: 0.07,
              ),
            ),
          ],
        ),
        clipBehavior:
            Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    color:
                        Colors.grey.shade100,
                    child: product
                            .imageUrl
                            .isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            fit:
                                BoxFit.cover,
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
                                      .image_not_supported_outlined,
                                  size: 50,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child:
                                Icon(
                              Icons
                                  .shopping_bag_outlined,
                              size: 55,
                            ),
                          ),
                  ),
                ),

                if (product.hasDiscount)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors.red,
                        borderRadius:
                            BorderRadius
                                .circular(
                          8,
                        ),
                      ),
                      child: Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 11,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                if (outOfStock)
                  Positioned.fill(
                    child: Container(
                      color:
                          Colors.white.withValues(
                        alpha: 0.72,
                      ),
                      child:
                          const Center(
                        child: Text(
                          'OUT OF STOCK',
                          style:
                              TextStyle(
                            color:
                                Colors.red,
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                11,
                10,
                11,
                11,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (product
                      .category
                      .isNotEmpty)
                    Text(
                      product.category,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    product.name.isEmpty
                        ? 'Unnamed Product'
                        : product.name,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .end,
                    children: [
                      Text(
                        '₹${product.sellingPrice.toStringAsFixed(0)}',
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      if (product
                          .hasDiscount) ...[
                        const SizedBox(
                          width: 6,
                        ),
                        Flexible(
                          child: Text(
                            '₹${product.originalPrice.toStringAsFixed(0)}',
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              fontSize:
                                  11,
                              color: Colors
                                  .grey
                                  .shade600,
                              decoration:
                                  TextDecoration
                                      .lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(
                    height: 6,
                  ),

                  Text(
                    outOfStock
                        ? 'Out of Stock'
                        : product.stock <= 5
                            ? 'Only ${product.stock} left'
                            : 'In Stock',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w600,
                      color: outOfStock
                          ? Colors.red
                          : product.stock <= 5
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),

                  const SizedBox(
                    height: 9,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 38,
                    child: outOfStock
                        ? OutlinedButton(
                            onPressed: null,
                            child:
                                const Text(
                              'Out of Stock',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                              ),
                            ),
                          )
                        : cartQuantity == 0
                            ? FilledButton.icon(
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
                                                context)
                                        .hideCurrentSnackBar();

                                    ScaffoldMessenger
                                            .of(
                                                context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text(
                                          'Added to cart 🛒',
                                        ),
                                        duration:
                                            Duration(
                                          seconds:
                                              1,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon:
                                    const Icon(
                                  Icons
                                      .add_shopping_cart,
                                  size: 17,
                                ),
                                label:
                                    const Text(
                                  'Add to Cart',
                                  style:
                                      TextStyle(
                                    fontSize:
                                        12,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              )
                            : Container(
                                decoration:
                                    BoxDecoration(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    10,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        Theme.of(
                                      context,
                                    )
                                            .colorScheme
                                            .primary
                                            .withValues(
                                      alpha:
                                          0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .spaceBetween,
                                  children: [
                                    IconButton(
                                      padding:
                                          EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(
                                        minWidth:
                                            38,
                                      ),
                                      onPressed:
                                          () async {
                                        await CartController
                                            .decreaseQuantity(
                                          product.id,
                                        );

                                        onCartChanged();
                                      },
                                      icon:
                                          const Icon(
                                        Icons
                                            .remove,
                                        size: 18,
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
                                      padding:
                                          EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(
                                        minWidth:
                                            38,
                                      ),
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
                                      icon:
                                          const Icon(
                                        Icons.add,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    if (!mounted) return;

    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

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
        title:
            const Text('Product Details'),
        actions: [
          CartIconButton(
            onCartChanged:
                refreshCart,
          ),
        ],
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
                        BorderRadius
                            .circular(
                      20,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                    child: product
                            .imageUrl
                            .isNotEmpty
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

                const SizedBox(
                  height: 20,
                ),

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

                const SizedBox(
                  height: 8,
                ),

                if (product
                    .category
                    .isNotEmpty)
                  Chip(
                    label: Text(
                      product.category,
                    ),
                  ),

                const SizedBox(
                  height: 10,
                ),

                if (product.hasDiscount)
                  Row(
                    children: [
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
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
                          color:
                              Colors.green,
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
                        FontWeight.bold,
                    color:
                        Colors.deepPurple,
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

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  'Description',
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  product.description
                          .isEmpty
                      ? 'No description available for this product.'
                      : product
                          .description,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color:
                        Colors.grey.shade700,
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
                const EdgeInsets.all(16),
            decoration:
                BoxDecoration(
              color: Theme.of(context)
                  .scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color:
                      Colors.grey.shade300,
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
                        onPressed: null,
                        child:
                            const Text(
                          'Out of Stock',
                        ),
                      )
                    : quantity == 0
                        ? FilledButton.icon(
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
                                            context)
                                    .showSnackBar(
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
                                    OutlinedButton
                                        .icon(
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
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatefulWidget {
  final VoidCallback onProfileChanged;
  final VoidCallback onCartChanged;

  const ProfilePage({
    super.key,
    required this.onProfileChanged,
    required this.onCartChanged,
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

      if (!mounted) return;

      widget.onProfileChanged();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Logged out successfully'),
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
    final result =
        await Navigator.push(
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
        FirebaseAuth.instance
            .currentUser;

    final isLoggedIn =
        user != null;

    final displayName =
        user?.displayName?.trim();

    final userName =
        (displayName != null &&
                displayName.isNotEmpty)
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
        actions: [
          CartIconButton(
            onCartChanged:
                widget.onCartChanged,
          ),
        ],
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
                  : Icons
                      .person_outline,
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
                  color:
                      Colors.grey.shade700,
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
                  color:
                      Colors.grey.shade700,
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 20,
          ),

          if (!isLoggedIn)
            ListTile(
              leading:
                  const Icon(Icons.login),
              title: const Text(
                'Login / Sign Up',
              ),
              subtitle: const Text(
                'Login with OTP or password',
              ),
              onTap: openLogin,
            )
          else
            ListTile(
              leading:
                  const Icon(Icons.logout),
              title:
                  const Text('Logout'),
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
            title:
                Text('Saved Addresses'),
          ),

          ListTile(
            leading:
                const Icon(
              Icons.receipt_long,
            ),
            title:
                const Text('My Orders'),
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
            leading: Icon(
              Icons.help_outline,
            ),
            title:
                Text('Help & Support'),
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
      icon:
          const Icon(Icons.arrow_back),
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

        final results =
            products.where(
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
            query.trim().toLowerCase();

        final results =
            products.where(
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
        child:
            Text('No products found'),
      );
    }

    return ListView(
      padding:
          const EdgeInsets.all(12),
      children: products
          .map(
            (product) => ProductTile(
              product: product,
              onCartChanged:
                  onCartChanged,
            ),
          )
          .toList(),
    );
  }
}
