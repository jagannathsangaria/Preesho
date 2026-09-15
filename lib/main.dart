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
// CUSTOMER ADDRESS MODEL
// ============================================================

class CustomerAddress {
  final String addressId;
  final String fullAddress;
  final String city;
  final String pincode;
  final bool isDefault;

  const CustomerAddress({
    required this.addressId,
    required this.fullAddress,
    required this.city,
    required this.pincode,
    required this.isDefault,
  });

  factory CustomerAddress.fromMap(Map<String, dynamic> map) {
    return CustomerAddress(
      addressId: (map['addressId'] ?? map['id'] ?? '').toString(),
      fullAddress: (map['fullAddress'] ?? map['address'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      pincode: (map['pincode'] ?? map['pinCode'] ?? map['postalCode'] ?? '').toString(),
      isDefault: map['isDefault'] == true || map['default'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'addressId': addressId,
    'fullAddress': fullAddress,
    'city': city,
    'pincode': pincode,
    'isDefault': isDefault,
  };
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
        colorSchemeSeed: const Color(0xff6A1B9A),
        scaffoldBackgroundColor: const Color(0xffF7F7FA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
        ),
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
      HomePage(onCartChanged: refresh),
      PlayPage(onCartChanged: refresh),
      TopDealsPage(onCartChanged: refresh),
      ProfilePage(onProfileChanged: refresh),
      CartPage(onCartChanged: refresh),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        height: 70,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.play_circle_outline_rounded),
            selectedIcon: Icon(Icons.play_circle_rounded),
            label: 'Play',
          ),
          const NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Top Deals',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Account',
          ),
          NavigationDestination(
            icon: _CartNavIcon(count: CartController.items.length),
            selectedIcon: _CartNavIcon(count: CartController.items.length, selected: true),
            label: 'Cart',
          ),
        ],
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  final int count;
  final bool selected;

  const _CartNavIcon({required this.count, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined),
        if (count > 0)
          Positioned(
            right: -9,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xffE53935),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
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
// HOME PAGE - MODERN PREESHO SHOPPING UI
// ============================================================

class HomePage extends StatefulWidget {
  final VoidCallback onCartChanged;

  const HomePage({super.key, required this.onCartChanged});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String selectedCategory = 'For You';
  String addressText = 'Add a delivery address';
  int bannerIndex = 0;
  final PageController _bannerController = PageController(viewportFraction: .93);

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddress() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!snap.exists || !mounted) return;
      final data = snap.data() ?? <String, dynamic>{};
      final addresses = data['addresses'];
      CustomerAddress? chosen;

      if (addresses is List) {
        final parsed = addresses.whereType<Map>().map((item) {
          return CustomerAddress.fromMap(Map<String, dynamic>.from(item));
        }).toList();
        if (parsed.isNotEmpty) {
          final defaultId = (data['defaultAddressId'] ?? '').toString();
          chosen = parsed.firstWhere(
            (a) => a.addressId == defaultId,
            orElse: () => parsed.firstWhere((a) => a.isDefault, orElse: () => parsed.first),
          );
        }
      }

      final legacy = (data['address'] ?? '').toString().trim();
      if (chosen != null) {
        final text = [
          chosen!.fullAddress,
          if (chosen!.city.isNotEmpty) chosen!.city,
          if (chosen!.pincode.isNotEmpty) chosen!.pincode,
        ].where((e) => e.trim().isNotEmpty).join(', ');
        setState(() => addressText = text);
      } else if (legacy.isNotEmpty) {
        setState(() => addressText = legacy);
      }
    } catch (_) {}
  }

  void _openSearch() {
    showSearch(context: context, delegate: ProductSearch(widget.onCartChanged));
  }

  void _selectCategory(String category) {
    setState(() => selectedCategory = category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F8FC),
      body: ProductStream(
        builder: (products) {
          final allCategories = <String>{
            ...products.map((p) => p.category.trim()).where((c) => c.isNotEmpty),
          };
          final categories = <String>[
            'For You',
            'Fashion',
            'Mobiles',
            'Electronics',
            'Beauty',
            'Home',
            ...allCategories.where((c) => !{'Fashion', 'Mobiles', 'Electronics', 'Beauty', 'Home'}.contains(c)),
          ];

          final visible = selectedCategory == 'For You'
              ? products
              : products.where((p) => p.category.toLowerCase() == selectedCategory.toLowerCase()).toList();

          final banners = _buildBanners(products);
          final recommendations = products.take(8).toList();
          final hotPicks = [...products]..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _topArea(context)),
                SliverToBoxAdapter(child: _shortcutCards()),
                SliverToBoxAdapter(child: _locationBar()),
                SliverToBoxAdapter(child: _searchBar()),
                SliverToBoxAdapter(child: _categoryMenu(categories)),
                SliverToBoxAdapter(child: _bannerCarousel(banners)),
                SliverToBoxAdapter(child: _sectionHeader('Jagannath, still looking for these?', 'See all')),
                SliverToBoxAdapter(child: _recommendations(recommendations)),
                SliverToBoxAdapter(child: _sectionHeader("Today's Hot Pick", hotPicks.isEmpty ? '' : 'See all')),
                if (hotPicks.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: Text('No products available yet.')),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.crossAxisExtent >= 700 ? 4 : 2;
                        return SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) => _ModernProductCard(
                              product: hotPicks[i],
                              onCartChanged: widget.onCartChanged,
                            ),
                            childCount: hotPicks.length,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: columns == 2 ? .62 : .68,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _topArea(BuildContext context) {
    return Container(
      color: const Color(0xffDFF3FF),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preesho', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                SizedBox(height: 2),
                Text('Shop smart. Live better.', style: TextStyle(fontSize: 11, color: Color(0xff456273))),
              ],
            ),
          ),
          IconButton(onPressed: _openSearch, icon: const Icon(Icons.search_rounded)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          _CartNavIcon(count: CartController.items.length),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _shortcutCards() {
    const items = [
      ('Preesho', Icons.shopping_bag_rounded),
      ('Value Deals', Icons.local_offer_rounded),
      ('Travel', Icons.flight_takeoff_rounded),
      ('Grocery', Icons.local_grocery_store_rounded),
    ];

    return Container(
      color: const Color(0xffDFF3FF),
      height: 76,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (_, i) {
          final item = items[i];
          return Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 3), color: Color(0x12000000))],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: const Color(0xffE8F7FF), borderRadius: BorderRadius.circular(11)),
                  child: Icon(item.$2, size: 18, color: const Color(0xff1377B9)),
                ),
                const SizedBox(width: 7),
                Expanded(child: Text(item.$1, maxLines: 2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _locationBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 21),
          const SizedBox(width: 7),
          const Text('WORK', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(addressText, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 21),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xffFFF4D8), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [Icon(Icons.stars_rounded, size: 14, color: Color(0xffC88A00)), SizedBox(width: 3), Text('120 pts', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))]),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(17),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(color: const Color(0xffF4F6F8), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xffE3E7EA))),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.black54),
                    SizedBox(width: 9),
                    Expanded(child: Text('Search for products', style: TextStyle(color: Colors.black45, fontSize: 14))),
                    Icon(Icons.camera_alt_outlined, size: 20, color: Colors.black54),
                    SizedBox(width: 12),
                    Icon(Icons.mic_none_rounded, size: 20, color: Colors.black54),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: const Color(0xffF4F6F8), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xffE3E7EA))),
            child: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
    );
  }

  Widget _categoryMenu(List<String> categories) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final category = categories[i];
            final selected = selectedCategory.toLowerCase() == category.toLowerCase();
            return InkWell(
              onTap: () => _selectCategory(category),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xff17212B) : const Color(0xffF4F6F8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(category, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xff303840))),
              ),
            );
          },
        ),
      ),
    );
  }

  List<_PreeshoBanner> _buildBanners(List<Product> products) {
    final first = products.isNotEmpty ? products[0] : null;
    final second = products.length > 1 ? products[1] : first;
    final third = products.length > 2 ? products[2] : first;
    return [
      _PreeshoBanner(title: 'Big deals, better prices', subtitle: 'Fresh picks for your everyday shopping', offer: 'UP TO 50% OFF', product: first),
      _PreeshoBanner(title: 'Value shopping starts here', subtitle: 'Save more on selected Preesho products', offer: 'SPECIAL OFFER', product: second),
      _PreeshoBanner(title: 'Pay smart. Save more.', subtitle: 'Enjoy available payment & bank offers', offer: 'EXTRA SAVINGS', product: third),
    ];
  }

  Widget _bannerCarousel(List<_PreeshoBanner> banners) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 4),
      child: Column(
        children: [
          SizedBox(
            height: 178,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              onPageChanged: (i) => setState(() => bannerIndex = i),
              itemBuilder: (_, i) => _PromoBanner(banner: banners[i]),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == bannerIndex ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(color: i == bannerIndex ? const Color(0xff17212B) : const Color(0xffB8C1C8), borderRadius: BorderRadius.circular(6)),
            )),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String action) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -.2))),
          if (action.isNotEmpty) Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xff1476B5))),
        ],
      ),
    );
  }

  Widget _recommendations(List<Product> products) {
    if (products.isEmpty) {
      return const SizedBox(height: 70, child: Center(child: Text('Start browsing products to see recommendations.')));
    }
    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _RecommendationCard(product: products[i], onCartChanged: widget.onCartChanged),
      ),
    );
  }
}

class _PreeshoBanner {
  final String title;
  final String subtitle;
  final String offer;
  final Product? product;

  const _PreeshoBanner({required this.title, required this.subtitle, required this.offer, required this.product});
}

class _PromoBanner extends StatelessWidget {
  final _PreeshoBanner banner;

  const _PromoBanner({required this.banner});

  @override
  Widget build(BuildContext context) {
    final product = banner.product;
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(18, 15, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff1677B9), Color(0xff65C5E8)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(blurRadius: 13, offset: Offset(0, 6), color: Color(0x18000000))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: Text(banner.offer, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                const SizedBox(height: 10),
                Text(banner.title, maxLines: 2, style: const TextStyle(color: Colors.white, fontSize: 21, height: 1.05, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(banner.subtitle, maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2)),
                const Spacer(),
                const Row(children: [Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 14), SizedBox(width: 5), Text('Payment & bank offers available', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700))]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: Colors.white.withOpacity(.18),
                child: product == null || product.imageUrl.trim().isEmpty
                    ? const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 52))
                    : Image.network(product.imageUrl.trim(), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white, size: 45))),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Product product;
  final VoidCallback onCartChanged;

  const _RecommendationCard({required this.product, required this.onCartChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product, onCartChanged: onCartChanged)));
        onCartChanged();
      },
      child: Container(
        width: 158,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xffE7EAED)), boxShadow: const [BoxShadow(blurRadius: 8, offset: Offset(0, 3), color: Color(0x0D000000))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            ClipRRect(borderRadius: BorderRadius.circular(13), child: Container(width: double.infinity, color: const Color(0xffF4F6F8), child: _ProductImage(product.imageUrl, fit: BoxFit.contain))),
            if (product.hasDiscount) Positioned(left: 5, top: 5, child: _DiscountBadge(percent: product.discountPercent)),
          ])),
          const SizedBox(height: 8),
          Text(product.name.isEmpty ? 'Unnamed Product' : product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(product.hasDiscount ? 'Special offer for you' : 'Explore this product', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ]),
      ),
    );
  }
}

class _ModernProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onCartChanged;

  const _ModernProductCard({required this.product, required this.onCartChanged});

  @override
  Widget build(BuildContext context) {
    final item = CartController.findItem(product.id);
    final quantity = item?.quantity ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsPage(product: product, onCartChanged: onCartChanged)));
        onCartChanged();
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xffE6E9EC)), boxShadow: const [BoxShadow(blurRadius: 9, offset: Offset(0, 3), color: Color(0x0C000000))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Stack(children: [
            ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(18)), child: Container(width: double.infinity, color: const Color(0xffF5F6F7), child: _ProductImage(product.imageUrl, fit: BoxFit.contain))),
            if (product.hasDiscount) Positioned(left: 8, top: 8, child: _DiscountBadge(percent: product.discountPercent)),
            Positioned(right: 8, top: 8, child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(.92), shape: BoxShape.circle), child: const Icon(Icons.favorite_border_rounded, size: 18))),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(10, 9, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name.isEmpty ? 'Unnamed Product' : product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: const Color(0xffE9F7EF), borderRadius: BorderRadius.circular(5)), child: const Row(children: [Icon(Icons.star_rounded, size: 11, color: Color(0xff1B8A4A)), SizedBox(width: 2), Text('4.3', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xff1B8A4A)))])), const SizedBox(width: 5), Expanded(child: Text(product.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.black54)))]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${product.sellingPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              if (product.hasDiscount) ...[const SizedBox(width: 5), Text('₹${product.originalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.black45, decoration: TextDecoration.lineThrough))],
            ]),
            const SizedBox(height: 3),
            Text(product.stock > 0 ? 'Free delivery • In stock' : 'Out of stock', style: TextStyle(fontSize: 9, color: product.stock > 0 ? const Color(0xff1B8A4A) : Colors.red, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, height: 36, child: quantity == 0 ? OutlinedButton.icon(onPressed: product.stock <= 0 ? null : () async { final added = await CartController.addProduct(product); if (added) { onCartChanged(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'), duration: Duration(seconds: 1))); } }, icon: const Icon(Icons.add_shopping_cart_rounded, size: 16), label: const Text('Add to Cart', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))) : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(onPressed: () async { await CartController.decreaseQuantity(product.id); onCartChanged(); }, icon: const Icon(Icons.remove_circle_outline_rounded, size: 20)), Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w900)), IconButton(onPressed: quantity >= product.stock ? null : () async { await CartController.increaseQuantity(product.id); onCartChanged(); }, icon: const Icon(Icons.add_circle_outline_rounded, size: 20))])),
          ]),
        ]),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _ProductImage(this.url, {this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final safeUrl = url.trim();
    if (safeUrl.isEmpty || safeUrl.toLowerCase() == 'undefined' || safeUrl.toLowerCase() == 'null') {
      return const Center(child: Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xff9AA4AC)));
    }
    return Image.network(safeUrl, fit: fit, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined, size: 42, color: Color(0xff9AA4AC))));
  }
}

class _DiscountBadge extends StatelessWidget {
  final double percent;

  const _DiscountBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xff0F9D58), borderRadius: BorderRadius.circular(7)),
      child: Text('${percent.toStringAsFixed(0)}% OFF', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

class PlayPage extends StatelessWidget {
  final VoidCallback onCartChanged;
  const PlayPage({super.key, required this.onCartChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Play', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ProductStream(builder: (products) => ListView(padding: const EdgeInsets.all(14), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: const Color(0xffE7F7FF), borderRadius: BorderRadius.circular(22)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Discover Preesho', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('Explore products, offers and fresh picks.', style: TextStyle(color: Colors.black54))])),
        const SizedBox(height: 18),
        const Text('Trending now', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...products.take(8).map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: ProductTile(product: p, onCartChanged: onCartChanged))),
      ])),
    );
  }
}

class TopDealsPage extends StatelessWidget {
  final VoidCallback onCartChanged;
  const TopDealsPage({super.key, required this.onCartChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top Deals', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ProductStream(builder: (products) {
        final deals = [...products]..sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: deals.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: .64),
          itemBuilder: (_, i) => _ModernProductCard(product: deals[i], onCartChanged: onCartChanged),
        );
      }),
    );
  }
}

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
