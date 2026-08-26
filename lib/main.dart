import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const PreeshoApp());
}

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
        scaffoldBackgroundColor: const Color(0xffF7F7F9),
      ),
      home: const HomePage(),
    );
  }
}

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
      final actualKey = normalize(entry.key.toString());

      if (actualKey == wanted) {
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
          IconButton(
            tooltip: 'Admin Panel',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPanel(),
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
            .where('Active', isEqualTo: true)
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
                  'Firebase Error:\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
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
              // HOME BANNER
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
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
                    SizedBox(height: 18),
                    Text(
                      '✨ Best products at great prices',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // CATEGORY
              const Text(
                'Shop by Category',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    CategoryCard(
                      icon: Icons.checkroom,
                      title: 'Fashion',
                    ),
                    CategoryCard(
                      icon: Icons.phone_android,
                      title: 'Electronics',
                    ),
                    CategoryCard(
                      icon: Icons.home_outlined,
                      title: 'Home',
                    ),
                    CategoryCard(
                      icon: Icons.watch_outlined,
                      title: 'Accessories',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // PRODUCTS TITLE
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Latest Products',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All'),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // PRODUCTS
              ...products.map((doc) {
                final data = doc.data();

                final name =
                    readField(data, 'Name');

                final category =
                    readField(data, 'Category');

                final price =
                    readField(data, 'Price');

                final stock =
                    readField(data, 'Stock');

                final imageUrl =
                    readField(data, 'Imageurl');

                return ProductCard(
                  name: name,
                  category: category,
                  price: price,
                  stock: stock,
                  imageUrl: imageUrl,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const CategoryCard({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String name;
  final String category;
  final String price;
  final String stock;
  final String imageUrl;

  const ProductCard({
    super.key,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.imageUrl,
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
                    loadingBuilder:
                        (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return const Center(
                        child:
                            CircularProgressIndicator(),
                      );
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
                // NAME
                Text(
                  name.isEmpty
                      ? 'Unnamed Product'
                      : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // CATEGORY
                Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      size: 19,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        category.isEmpty
                            ? 'Category unavailable'
                            : category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // PRICE + STOCK
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
                    Row(
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 17,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          stock.isEmpty
                              ? 'Stock unavailable'
                              : 'Stock: $stock',
                          style: const TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ADD TO CART
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            '${name.isEmpty ? 'Product' : name} added to cart',
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

class ProductImagePlaceholder
    extends StatelessWidget {
  const ProductImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xffEEEEF2),
      child: const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Product Image',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
