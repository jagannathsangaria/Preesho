import 'package:flutter/material.dart';

void main() => runApp(const PreeshoApp());

class Product {
  final String name, category, price;
  final IconData icon;
  const Product(this.name, this.category, this.price, this.icon);
}

const products = [
  Product('Smart Watch', 'Electronics', '₹1,999', Icons.watch),
  Product('Wireless Earbuds', 'Electronics', '₹1,499', Icons.headphones),
  Product('Backpack', 'Fashion', '₹899', Icons.backpack),
  Product('Running Shoes', 'Fashion', '₹2,299', Icons.directions_run),
  Product('Coffee Maker', 'Home', '₹3,499', Icons.coffee),
  Product('Desk Lamp', 'Home', '₹799', Icons.light),
];

class PreeshoApp extends StatelessWidget {
  const PreeshoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Preesho',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
    home: const MainShell(),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final cart = <Product>[];

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(onAdd: (p) => setState(() => cart.add(p))),
      CategoriesPage(onAdd: (p) => setState(() => cart.add(p))),
      CartPage(cart: cart, onRemove: (p) => setState(() => cart.remove(p))),
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.category_outlined), selectedIcon: Icon(Icons.category), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final void Function(Product) onAdd;
  const HomePage({super.key, required this.onAdd});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Preesho'), actions: [
      IconButton(onPressed: () => showSearch(context: context, delegate: ProductSearch(onAdd)), icon: const Icon(Icons.search)),
      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
    ]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(colors: [Color(0xff5E35B1), Color(0xff8E24AA)]),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Welcome to Preesho', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold)),
          SizedBox(height: 7), Text('Shop smarter. Shop faster.', style: TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 22),
      const Text('Categories', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [
        _cat(Icons.phone_android, 'Electronics'), _cat(Icons.checkroom, 'Fashion'), _cat(Icons.home, 'Home'),
      ])),
      const SizedBox(height: 14),
      const Text('Popular Products', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ...products.map((p) => ProductTile(product: p, onAdd: onAdd)),
    ]),
  );
  Widget _cat(IconData icon, String text) => Card(
    child: SizedBox(width: 115, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon), const SizedBox(height: 5), Text(text, style: const TextStyle(fontSize: 12))
    ])),
  );
}

class CategoriesPage extends StatelessWidget {
  final void Function(Product) onAdd;
  const CategoriesPage({super.key, required this.onAdd});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Categories')),
    body: ListView(children: ['Electronics', 'Fashion', 'Home'].map((c) =>
      ExpansionTile(title: Text(c), leading: const Icon(Icons.category),
        children: products.where((p) => p.category == c).map((p) => ProductTile(product: p, onAdd: onAdd)).toList())
    ).toList()),
  );
}

class CartPage extends StatelessWidget {
  final List<Product> cart;
  final void Function(Product) onRemove;
  const CartPage({super.key, required this.cart, required this.onRemove});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Cart')),
    body: cart.isEmpty
      ? const Center(child: Text('Your cart is empty'))
      : Column(children: [
          Expanded(child: ListView(children: cart.map((p) => ListTile(
            leading: CircleAvatar(child: Icon(p.icon)), title: Text(p.name), subtitle: Text(p.price),
            trailing: IconButton(onPressed: () => onRemove(p), icon: const Icon(Icons.delete_outline)),
          )).toList())),
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressPage())),
              child: const Text('Proceed to Address')))),
        ]),
  );
}

class AddressPage extends StatelessWidget {
  const AddressPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery Address')),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      const TextField(decoration: InputDecoration(labelText: 'Full Name')),
      const TextField(decoration: InputDecoration(labelText: 'Mobile Number'), keyboardType: TextInputType.phone),
      const TextField(decoration: InputDecoration(labelText: 'Address')),
      const TextField(decoration: InputDecoration(labelText: 'City')),
      const TextField(decoration: InputDecoration(labelText: 'PIN Code'), keyboardType: TextInputType.number),
      const Spacer(),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => showDialog(
        context: context, builder: (_) => AlertDialog(title: const Text('Order Ready'), content: const Text('Payment gateway will be connected in the next release.'), actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ])), child: const Text('Continue to Payment')))
    ])),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Profile')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 45)),
      const SizedBox(height: 10),
      const Center(child: Text('Guest User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.login), title: const Text('Login / Sign Up'), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()))),
      const ListTile(leading: Icon(Icons.location_on_outlined), title: Text('Saved Addresses')),
      const ListTile(leading: Icon(Icons.receipt_long), title: Text('My Orders')),
      const ListTile(leading: Icon(Icons.help_outline), title: Text('Help & Support')),
    ]),
  );
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Login / Sign Up')),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const TextField(decoration: InputDecoration(labelText: 'Mobile Number', prefixText: '+91 '), keyboardType: TextInputType.phone),
      const SizedBox(height: 12),
      const TextField(decoration: InputDecoration(labelText: 'Password'), obscureText: true),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Continue'))),
    ])),
  );
}

class ProductTile extends StatelessWidget {
  final Product product; final void Function(Product) onAdd;
  const ProductTile({super.key, required this.product, required this.onAdd});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    leading: CircleAvatar(child: Icon(product.icon)),
    title: Text(product.name), subtitle: Text(product.price),
    trailing: IconButton(onPressed: () { onAdd(product); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'))); }, icon: const Icon(Icons.add_shopping_cart)),
  ));
}

class ProductSearch extends SearchDelegate<Product?> {
  final void Function(Product) onAdd;
  ProductSearch(this.onAdd);
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext context) => _results();
  @override Widget buildSuggestions(BuildContext context) => _results();
  Widget _results() => ListView(children: products.where((p) => p.name.toLowerCase().contains(query.toLowerCase())).map((p) => ProductTile(product: p, onAdd: onAdd)).toList());
}
