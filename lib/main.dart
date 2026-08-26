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
          ? FirebaseErrorPage(
              error: firebaseError!,
            )
          : const HomePage(),
    );
  }
}

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
                style: TextStyle(
                  fontSize: 16,
                ),
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
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  mainAxisAlignment: MainAxisAlignment.center,
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

                return ProductCard(
                  name: readField(data, 'Name'),
                  category:
                      readField(data, 'Category'),
                  price: readField(data, 'Price'),
                  stock: readField(data, 'Stock'),
                  imageUrl:
                      readField(data, 'Imageurl'),
                );
              }),
            ],
          );
        },
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
        child: Icon(
          Icons.image_outlined,
          size: 60,
          color: Colors.grey,
        ),
      ),
    );
  }
}
