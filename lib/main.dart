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

import 'product_details_page.dart';
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
              padding: const EdgeInsets.all(24),
              child: Text(
                'Firebase initialization failed:\n$e',
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B35D5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FA),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const AppEntry(),
    );
  }
}

// ============================================================
// APP ENTRY
// ============================================================

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  Future<Widget> _getStartPage() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const MainShell();
    }

    try {
      final firestore = FirebaseFirestore.instance;

      final userSnap = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final courierSnap = await firestore
          .collection('couriers')
          .doc(user.uid)
          .get();

      final userData = userSnap.data() ?? {};
      final courierData = courierSnap.data() ?? {};

      final userRole =
          (userData['role'] ?? '').toString().trim().toLowerCase();

      final courierRole =
          (courierData['role'] ?? '').toString().trim().toLowerCase();

      final isCourier =
          userRole == 'courier' ||
          courierRole == 'courier' ||
          courierSnap.exists;

      if (isCourier) {
        final status = (
          courierData['status'] ??
          userData['status'] ??
          ''
        ).toString().trim().toLowerCase();

        final active =
            courierData['active'] == true ||
            userData['active'] == true;

        final approvedByAdmin =
            courierData['approvedByAdmin'] == true ||
            userData['approvedByAdmin'] == true;

        final approved =
            status == 'approved' ||
            status == 'active';

        if (approved && active && approvedByAdmin) {
          return const CourierPanel();
        }

        return CourierDocumentsPage(
          courierUid: user.uid,
        );
      }

      return const MainShell();
    } catch (_) {
      return const MainShell();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartPage(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return snapshot.data ?? const MainShell();
      },
    );
  }
}

// ============================================================
// CART ICON
// ============================================================

class CartIconButton extends StatefulWidget {
  final VoidCallback? onCartChanged;

  const CartIconButton({
    super.key,
    this.onCartChanged,
  });

  @override
  State<CartIconButton> createState() => _CartIconButtonState();
}

class _CartIconButtonState extends State<CartIconButton> {
  @override
  Widget build(BuildContext context) {
    final count = CartController.itemCount;

    return IconButton(
      tooltip: 'Cart',
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CartPage(
              onCartChanged: () {
                widget.onCartChanged?.call();

                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        );

        if (mounted) {
          setState(() {});
        }
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_bag_outlined, size: 26),
          if (count > 0)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
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
// MAIN SHELL
// ============================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;
  int refreshKey = 0;

  void refreshAll() {
    setState(() {
      refreshKey++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        key: ValueKey('home_$refreshKey'),
        onCartChanged: refreshAll,
      ),
      CategoriesPage(
        key: ValueKey('categories_$refreshKey'),
        onCartChanged: refreshAll,
      ),
      ProfilePage(
        key: ValueKey('profile_$refreshKey'),
        onCartChanged: refreshAll,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        height: 72,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
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
// PRODUCT STREAM
// ============================================================

class ProductStream extends StatelessWidget {
  final Widget Function(List<Product> products) builder;

  const ProductStream({
    super.key,
    required this.builder,
  });

  Product _fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return Product(
      id: id,
      name: (data['Name'] ?? data['name'] ?? '').toString(),
      category:
          (data['Category'] ?? data['category'] ?? '').toString(),
      price: data['Price'] ?? data['price'] ?? 0,
      stock: int.tryParse(
            (data['Stock'] ?? data['stock'] ?? 0).toString(),
          ) ??
          0,
      imageUrl:
          (data['Imageurl'] ??
                  data['ImageUrl'] ??
                  data['imageUrl'] ??
                  data['image'] ??
                  '')
              .toString(),
      description:
          (data['Description'] ??
                  data['description'] ??
                  '')
              .toString(),
      active: data['Active'] == null
          ? (data['active'] ?? true) == true
          : data['Active'] == true,
      mrp: data['MRP'] ?? data['Mrp'] ?? data['mrp'],
      discountPercent:
          data['DiscountPercent'] ??
          data['Discount'] ??
          data['discountPercent'],
      vendorUid:
          (data['vendorUid'] ?? data['vendorUID'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (data['vendorUid'] ?? data['vendorUID']).toString(),
      vendorName:
          (data['vendorName'] ?? '').toString().trim().isEmpty
          ? null
          : data['vendorName'].toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Products load nahi ho pa rahe.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final products = <Product>[];

        for (final doc in snapshot.data?.docs ?? []) {
          try {
            final product = _fromFirestore(
              doc.id,
              doc.data(),
            );

            if (product.active && product.stock > 0) {
              products.add(product);
            }
          } catch (_) {}
        }

        return builder(products);
      },
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatelessWidget {
  final VoidCallback? onCartChanged;

  const HomePage({
    super.key,
    this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Preesho',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Orders',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrdersPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications coming soon'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          return RefreshIndicator(
            onRefresh: () async {
              onCartChanged?.call();
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      4,
                      20,
                      18,
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductSearch(
                              products: products,
                              onCartChanged: onCartChanged,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            SizedBox(width: 17),
                            Icon(
                              Icons.search_rounded,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Search products...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: Container(
                      height: 175,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF6C45E8),
                            Color(0xFF3E1FA8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5B35D5)
                                .withOpacity(0.25),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -30,
                            top: -35,
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Shop Smart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Best products. Great prices.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 14),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Fast & reliable delivery',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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
                  ),
                ),

                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      14,
                    ),
                    child: Text(
                      'Shop by Category',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 112,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      scrollDirection: Axis.horizontal,
                      children: [
                        CategoryCard(
                          title: 'Electronics',
                          icon: Icons.devices_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryProductsPage(
                                  category: 'Electronics',
                                  onCartChanged: onCartChanged,
                                ),
                              ),
                            );
                          },
                        ),
                        CategoryCard(
                          title: 'Fashion',
                          icon: Icons.checkroom_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryProductsPage(
                                  category: 'Fashion',
                                  onCartChanged: onCartChanged,
                                ),
                              ),
                            );
                          },
                        ),
                        CategoryCard(
                          title: 'Home',
                          icon: Icons.home_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryProductsPage(
                                  category: 'Home',
                                  onCartChanged: onCartChanged,
                                ),
                              ),
                            );
                          },
                        ),
                        CategoryCard(
                          title: 'Accessories',
                          icon: Icons.watch_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryProductsPage(
                                  category: 'Accessories',
                                  onCartChanged: onCartChanged,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      14,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Products',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${products.length} items',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (products.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No products available right now.',
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      30,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return ProductTile(
                            product: products[index],
                            onCartChanged: onCartChanged,
                          );
                        },
                        childCount: products.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.68,
                      ),
                    ),
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
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EBFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.category_outlined,
                color: Color(0xFF5B35D5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
  final VoidCallback? onCartChanged;

  const CategoriesPage({
    super.key,
    this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          final categoryMap = <String, int>{};

          for (final product in products) {
            final category = product.category.trim();

            if (category.isNotEmpty) {
              categoryMap[category] =
                  (categoryMap[category] ?? 0) + 1;
            }
          }

          final categories = categoryMap.keys.toList()..sort();

          if (categories.isEmpty) {
            return const Center(
              child: Text('No categories available.'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];

              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoryProductsPage(
                        category: category,
                        onCartChanged: onCartChanged,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0EBFF),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          size: 30,
                          color: Color(0xFF5B35D5),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        category,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${categoryMap[category]} products',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
// CATEGORY PRODUCTS PAGE
// ============================================================

class CategoryProductsPage extends StatelessWidget {
  final String category;
  final VoidCallback? onCartChanged;

  const CategoryProductsPage({
    super.key,
    required this.category,
    this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          category,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ProductStream(
        builder: (products) {
          final filtered = products.where((product) {
            return product.category.trim().toLowerCase() ==
                category.trim().toLowerCase();
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'No products found in $category.',
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              30,
            ),
            itemCount: filtered.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: 0.68,
            ),
            itemBuilder: (context, index) {
              return ProductTile(
                product: filtered[index],
                onCartChanged: onCartChanged,
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// PRODUCT TILE
// ============================================================

class ProductTile extends StatefulWidget {
  final Product product;
  final VoidCallback? onCartChanged;

  const ProductTile({
    super.key,
    required this.product,
    this.onCartChanged,
  });

  @override
  State<ProductTile> createState() => _ProductTileState();
}

class _ProductTileState extends State<ProductTile> {
  Product get product => widget.product;

  int get cartQuantity {
    return CartController.findItem(product.id)?.quantity ?? 0;
  }

  double get discount {
    if (product.hasDiscount &&
        product.originalPrice > 0) {
      return ((product.originalPrice - product.numericPrice) /
              product.originalPrice) *
          100;
    }

    final raw = product.discountPercent;

    if (raw is num) {
      return raw.toDouble();
    }

    return double.tryParse(
          raw.toString().replaceAll('%', '').trim(),
        ) ??
        0;
  }

  Future<void> addOne() async {
    final success = await CartController.addProduct(product);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock available nahi hai.'),
        ),
      );
      return;
    }

    setState(() {});
    widget.onCartChanged?.call();
  }

  Future<void> increase() async {
    final success =
        await CartController.increaseQuantity(product.id);

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum available stock reached.'),
        ),
      );
      return;
    }

    setState(() {});
    widget.onCartChanged?.call();
  }

  Future<void> decrease() async {
    await CartController.decreaseQuantity(product.id);

    if (!mounted) return;

    setState(() {});
    widget.onCartChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final quantity = cartQuantity;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: product,
              onCartChanged: widget.onCartChanged,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFFF5F5F8),
                      child: product.imageUrl.trim().isEmpty
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                size: 48,
                                color: Colors.grey,
                              ),
                            )
                          : Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 44,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${discount.round()}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                12,
                11,
                12,
                12,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        '₹${product.numericPrice.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(
                          '₹${product.originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            decoration:
                                TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (quantity == 0)
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: addOne,
                        icon: const Icon(
                          Icons.add_shopping_cart,
                          size: 17,
                        ),
                        label: const Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EBFF),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: decrease,
                            icon: const Icon(
                              Icons.remove,
                              size: 17,
                            ),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 38,
                            ),
                          ),
                          Text(
                            '$quantity',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            onPressed: increase,
                            icon: const Icon(
                              Icons.add,
                              size: 17,
                            ),
                            padding: EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 38,
                            ),
                          ),
                        ],
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
// PROFILE PAGE
// ============================================================

class ProfilePage extends StatelessWidget {
  final VoidCallback? onCartChanged;

  const ProfilePage({
    super.key,
    this.onCartChanged,
  });

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const MainShell(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          20,
          10,
          20,
          30,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6C45E8),
                  Color(0xFF4324B5),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5B35D5)
                      .withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      Colors.white.withOpacity(0.18),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        user == null
                            ? 'Welcome to Preesho'
                            : 'Welcome back!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        user?.email ??
                            'Login to manage your account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (user == null)
            _ProfileMenuTile(
              icon: Icons.login_rounded,
              title: 'Login / Sign Up',
              subtitle: 'Access your Preesho account',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                );
              },
            )
          else
            _ProfileMenuTile(
              icon: Icons.logout_rounded,
              title: 'Logout',
              subtitle: 'Sign out from your account',
              onTap: () => logout(context),
            ),

          _ProfileMenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'My Orders',
            subtitle: 'View your orders and delivery status',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrdersPage(),
                ),
              );
            },
          ),

          _ProfileMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Saved Addresses',
            subtitle: 'Manage your delivery addresses',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Address management coming soon',
                  ),
                ),
              );
            },
          ),

          _ProfileMenuTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Admin Login',
            subtitle: 'Open admin management panel',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminLoginPage(),
                ),
              );
            },
          ),

          _ProfileMenuTile(
            icon: Icons.support_agent_outlined,
            title: 'Help & Support',
            subtitle: 'Get help with your Preesho order',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Support section coming soon',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE MENU TILE
// ============================================================

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF0EBFF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF5B35D5),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
        ),
        onTap: onTap,
      ),
    );
  }
}

// ============================================================
// PRODUCT SEARCH
// ============================================================

class ProductSearch extends StatefulWidget {
  final List<Product> products;
  final VoidCallback? onCartChanged;

  const ProductSearch({
    super.key,
    required this.products,
    this.onCartChanged,
  });

  @override
  State<ProductSearch> createState() => _ProductSearchState();
}

class _ProductSearchState extends State<ProductSearch> {
  final TextEditingController controller =
      TextEditingController();

  String query = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((product) {
      final text =
          '${product.name} ${product.category}'
              .toLowerCase();

      return text.contains(query.toLowerCase().trim());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: controller,
          autofocus: true,
          onChanged: (value) {
            setState(() {
              query = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search products...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
            ),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      controller.clear();
                      setState(() {
                        query = '';
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        actions: [
          CartIconButton(
            onCartChanged: widget.onCartChanged,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: filtered.isEmpty
          ? const Center(
              child: Text(
                'No products found.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final product = filtered[index];

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _SearchProductTile(
                    product: product,
                    onCartChanged:
                        widget.onCartChanged,
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// SEARCH PRODUCT TILE
// ============================================================

class _SearchProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onCartChanged;

  const _SearchProductTile({
    required this.product,
    this.onCartChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: product,
              onCartChanged: onCartChanged,
            ),
          ),
        );
      },
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 92,
                height: 92,
                child: product.imageUrl.trim().isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFF5F5F8),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                        ),
                      )
                    : Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) {
                          return const ColoredBox(
                            color: Color(0xFFF5F5F8),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹${product.numericPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
