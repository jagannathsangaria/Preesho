import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PreeshoApp());
}

class Product {
  final String id;
  final String name;
  final String category;
  final String price;
  final String description;
  final String imageUrl;
  final String stock;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.stock,
  });

  factory Product.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    return Product(
      id: doc.id,
      name: (data['Name'] ?? '').toString(),
      category: (data['Category'] ?? '').toString(),
      price: (data['Price'] ?? '').toString(),
      description: (data['Description'] ?? '').toString(),
      imageUrl: (data['Imageurl'] ?? '').toString(),
      stock: (data['Stock'] ?? '').toString(),
    );
  }
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
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final List<Product> cart = [];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onAdd: (product) {
          setState(() {
            cart.add(product);
          });
        },
      ),
      CategoriesPage(
        onAdd: (product) {
          setState(() {
            cart.add(product);
          });
        },
      ),
      CartPage(
        cart: cart,
        onRemove: (product) {
          setState(() {
            cart.remove(product);
          });
        },
      ),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() {
            index = value;
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
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
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

class HomePage extends StatelessWidget {
  final void Function(Product) onAdd;

  const HomePage({
    super.key,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preesho'),
        actions: [
          IconButton(
            onPressed: () {
              showSearch(
                context: context,
                delegate: ProductSearch(onAdd),
              );
            },
            icon: const Icon(Icons.search),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('Active', isEqualTo: true)
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
                  'Firebase error:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final products = snapshot.data?.docs
                  .map(Product.fromFirestore)
                  .toList() ??
              [];

          if (products.isEmpty) {
            return const Center(
              child: Text('No products available'),
            );
          }

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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                'Products from Firebase',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...products.map(
                (product) => ProductTile(
                  product: product,
                  onAdd: onAdd,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 5),
            Text(
              text,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoriesPage extends StatelessWidget {
  final void Function(Product) onAdd;

  const CategoriesPage({
    super.key,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('products')
            .where('Active', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Firebase error: ${snapshot.error}'),
            );
          }

          final products = snapshot.data?.docs
                  .map(Product.fromFirestore)
                  .toList() ??
              [];

          return ListView(
            children: products
                .map(
                  (product) => ProductTile(
                    product: product,
                    onAdd: onAdd,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class CartPage extends StatelessWidget {
  final List<Product> cart;
  final void Function(Product) onRemove;

  const CartPage({
    super.key,
    required this.cart,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cart'),
      ),
      body: cart.isEmpty
          ? const Center(
              child: Text('Your cart is empty'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: cart.map(
                      (product) {
                        return ListTile(
                          leading: CircleAvatar(
                            child: const Icon(Icons.shopping_bag),
                          ),
                          title: Text(product.name),
                          subtitle: Text('₹${product.price}'),
                          trailing: IconButton(
                            onPressed: () => onRemove(product),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressPage(),
                          ),
                        );
                      },
                      child: const Text('Proceed to Address'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AddressPage extends StatelessWidget {
  const AddressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Address'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Full Name',
              ),
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Mobile Number',
              ),
              keyboardType: TextInputType.phone,
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Address',
              ),
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'City',
              ),
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'PIN Code',
              ),
              keyboardType: TextInputType.number,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Order Ready'),
                      content: const Text(
                        'Payment gateway will be connected in the next release.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Continue to Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 42,
            child: Icon(
              Icons.person,
              size: 45,
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              'Guest User',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Login / Sign Up'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LoginPage(),
                ),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.location_on_outlined),
            title: Text('Saved Addresses'),
          ),
          const ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('My Orders'),
          ),
          const ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Help & Support'),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login / Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Mobile Number',
                prefixText: '+91 ',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Password',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  final Product product;
  final void Function(Product) onAdd;

  const ProductTile({
    super.key,
    required this.product,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: const Icon(Icons.shopping_bag),
        ),
        title: Text(product.name),
        subtitle: Text(
          '₹${product.price}\n${product.category}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: () {
            onAdd(product);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Added to cart'),
              ),
            );
          },
          icon: const Icon(Icons.add_shopping_cart),
        ),
      ),
    );
  }
}

class ProductSearch extends SearchDelegate<Product?> {
  final void Function(Product) onAdd;

  ProductSearch(this.onAdd);

  @override
  List<Widget>? buildActions(BuildContext context) {
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
  Widget buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FirebaseProductSearchResults(
      query: query,
      onAdd: onAdd,
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FirebaseProductSearchResults(
      query: query,
      onAdd: onAdd,
    );
  }
}

class FirebaseProductSearchResults extends StatelessWidget {
  final String query;
  final void Function(Product) onAdd;

  const FirebaseProductSearchResults({
    super.key,
    required this.query,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('Active', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Firebase error: ${snapshot.error}'),
          );
        }

        final products = snapshot.data?.docs
                .map(Product.fromFirestore)
                .where(
                  (product) =>
                      product.name.toLowerCase().contains(
                            query.toLowerCase(),
                          ) ||
                      product.category.toLowerCase().contains(
                            query.toLowerCase(),
                          ),
                )
                .toList() ??
            [];

        if (products.isEmpty) {
          return const Center(
            child: Text('No products found'),
          );
        }

        return ListView(
          children: products
              .map(
                (product) => ProductTile(
                  product: product,
                  onAdd: onAdd,
                ),
              )
              .toList(),
        );
      },
    );
  }
}
