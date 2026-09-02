import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_page.dart';
import 'login_page.dart';
import 'admin_login.dart';
import 'orders_page.dart';

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
// CART ICON - TOP APP BAR
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
      ProfilePage(
        onProfileChanged: refresh,
        onCartChanged: refresh,
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
              ).then((_) {
                onCartChanged();
              });
            },
            icon: const Icon(Icons.search),
          ),
          CartIconButton(
            onCartChanged: onCartChanged,
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
                  scrollDirection: Axis.horizontal,
                  children: const [
                    CategoryCard(
                      icon: Icons.phone_android,
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
                  onCartChanged: onCartChanged,
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
        actions: [
          CartIconButton(
            onCartChanged: onCartChanged,
          ),
        ],
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
            children: categories.map(
              (category) {
                final categoryProducts =
                    products
                        .where(
                          (p) => p.category == category,
                        )
                        .toList();

                return ExpansionTile(
                  title: Text(category),
                  leading: const Icon(
                    Icons.category,
                  ),
                  children:
                      categoryProducts
                          .map(
                            (product) => ProductTile(
                              product: product,
                              onCartChanged:
                                  onCartChanged,
                            ),
                          )
                          .toList(),
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

class ProductTile extends StatelessWidget {
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
        CartController.findItem(product.id);

    final cartQuantity =
        cartItem?.quantity ?? 0;

    final outOfStock =
        product.stock <= 0;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsPage(
              product: product,
              onCartChanged: onCartChanged,
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
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 75,
                height: 75,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12),
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stack) {
                            return const ColoredBox(
                              color: Colors.black12,
                              child: Icon(
                                Icons.image_not_supported,
                              ),
                            );
                          },
                        )
                      : const ColoredBox(
                          color: Colors.black12,
                          child: Icon(
                            Icons.shopping_bag_outlined,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (product.hasDiscount)
                      Row(
                        children: [
                          Text(
                            '₹${product.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              decoration:
                                  TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            '${product.discountPercent.toStringAsFixed(0)}% OFF',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${product.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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
                        fontWeight: FontWeight.w600,
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
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (cartQuantity == 0)
                IconButton.filled(
                  onPressed: () async {
                    final added =
                        await CartController.addProduct(
                      product,
                    );

                    if (added) {
                      onCartChanged();

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Added to cart'),
                          duration:
                              Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.add_shopping_cart,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
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
                        Icons.remove_circle_outline,
                      ),
                    ),
                    Text(
                      '$cartQuantity',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed:
                          cartQuantity >= product.stock
                              ? null
                              : () async {
                                  await CartController
                                      .increaseQuantity(
                                    product.id,
                                  );

                                  onCartChanged();
                                },
                      icon: const Icon(
                        Icons.add_circle_outline,
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

class ProductDetailsPage extends StatefulWidget {
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
        actions: [
          CartIconButton(
            onCartChanged: refreshCart,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(20),
                    child: product.imageUrl.isNotEmpty
                        ? Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stack) {
                              return const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 70,
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Icon(
                              Icons.shopping_bag_outlined,
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
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (product.category.isNotEmpty)
                  Chip(
                    label: Text(product.category),
                  ),
                const SizedBox(height: 10),
                if (product.hasDiscount)
                  Row(
                    children: [
                      Text(
                        '₹${product.originalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                          decoration:
                              TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(
                          fontSize: 17,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  '₹${product.sellingPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      outOfStock
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      color: outOfStock
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      outOfStock
                          ? 'Out of Stock'
                          : '${product.stock} items available',
                      style: TextStyle(
                        color: outOfStock
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.shade300,
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
                        child: const Text(
                          'Out of Stock',
                        ),
                      )
                    : quantity == 0
                        ? FilledButton.icon(
                            onPressed: () async {
                              final added =
                                  await CartController
                                      .addProduct(
                                product,
                              );

                              if (added) {
                                refreshCart();

                                if (!context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Added to cart'),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.add_shopping_cart,
                            ),
                            label: const Text(
                              'Add to Cart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await CartController
                                        .decreaseQuantity(
                                      product.id,
                                    );

                                    refreshCart();
                                  },
                                  icon: const Icon(
                                    Icons.remove,
                                  ),
                                  label: const Text(
                                    'Remove',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$quantity',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed:
                                      quantity >=
                                              product.stock
                                          ? null
                                          : () async {
                                              await CartController
                                                  .increaseQuantity(
                                                product.id,
                                              );

                                              refreshCart();
                                            },
                                  icon: const Icon(
                                    Icons.add,
                                  ),
                                  label: const Text(
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
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      widget.onProfileChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Logged out successfully'),
        ),
      );

      setState(() {});
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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
        builder: (_) => const LoginPage(),
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
        title: const Text('My Profile'),
        actions: [
          CartIconButton(
            onCartChanged:
                widget.onCartChanged,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                  color: Colors.grey.shade700,
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
                  color: Colors.grey.shade700,
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
              subtitle: const Text(
                'Login with OTP or password',
              ),
              onTap: openLogin,
            )
          else
            ListTile(
              leading:
                  const Icon(Icons.logout),
              title: const Text('Logout'),
              subtitle: const Text(
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
                const Icon(Icons.receipt_long),
            title:
                const Text('My Orders'),
            subtitle: const Text(
              'View your placed orders',
            ),
            onTap: () async {
              if (FirebaseAuth.instance.currentUser ==
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
            leading: const Icon(
              Icons.admin_panel_settings_outlined,
            ),
            title:
                const Text('Admin Login'),
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
        icon: const Icon(Icons.clear),
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
                    .contains(searchQuery) ||
                product.category
                    .toLowerCase()
                    .contains(searchQuery) ||
                product.description
                    .toLowerCase()
                    .contains(searchQuery);
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
                    .contains(searchQuery) ||
                product.category
                    .toLowerCase()
                    .contains(searchQuery) ||
                product.description
                    .toLowerCase()
                    .contains(searchQuery);
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
        child: Text('No products found'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
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
