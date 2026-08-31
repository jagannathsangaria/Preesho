import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPanel extends StatefulWidget {
const AdminPanel({super.key});

@override
State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
final _formKey = GlobalKey<FormState>();

final nameController = TextEditingController();
final categoryController = TextEditingController();
final priceController = TextEditingController();
final stockController = TextEditingController();
final imageUrlController = TextEditingController();
final descriptionController = TextEditingController();

bool active = true;
bool saving = false;

final productsRef = FirebaseFirestore.instance.collection('products');
final ordersRef = FirebaseFirestore.instance.collection('orders');

@override
void dispose() {
nameController.dispose();
categoryController.dispose();
priceController.dispose();
stockController.dispose();
imageUrlController.dispose();
descriptionController.dispose();
super.dispose();
}

// ============================================================
// SAVE PRODUCT
// ============================================================

Future<void> saveProduct() async {
if (!_formKey.currentState!.validate()) {
return;
}

setState(() {
  saving = true;
});

try {
  final stock = int.tryParse(stockController.text.trim()) ?? 0;

  await productsRef.add({
    'Name': nameController.text.trim(),
    'Category': categoryController.text.trim(),
    'Price': priceController.text.trim(),
    'Stock': stock,
    'Imageurl': imageUrlController.text.trim(),
    'Description': descriptionController.text.trim(),
    'Active': active,
    'CreatedAt': FieldValue.serverTimestamp(),
  });

  if (!mounted) return;

  clearForm();

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Product added successfully'),
    ),
  );
} on FirebaseException catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Error adding product:\n${e.message ?? e.code}',
      ),
    ),
  );
} catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error adding product:\n$e'),
    ),
  );
} finally {
  if (mounted) {
    setState(() {
      saving = false;
    });
  }
}

}

// ============================================================
// CLEAR FORM
// ============================================================

void clearForm() {
nameController.clear();
categoryController.clear();
priceController.clear();
stockController.clear();
imageUrlController.clear();
descriptionController.clear();

setState(() {
  active = true;
});

}

// ============================================================
// DELETE PRODUCT
// ============================================================

Future<void> deleteProduct(
String id,
String name,
) async {
try {
await productsRef.doc(id).delete();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('"$name" deleted successfully'),
    ),
  );
} on FirebaseException catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Delete failed:\n${e.message ?? e.code}',
      ),
    ),
  );
}

}

// ============================================================
// ORDER STATUS
// ============================================================

Future<void> updateOrderStatus(
String orderId,
String status,
) async {
try {
await ordersRef.doc(orderId).update({
'status': status,
'updatedAt': FieldValue.serverTimestamp(),
});

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Order status updated to $status',
      ),
    ),
  );
} on FirebaseException catch (e) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Status update failed:\n${e.message ?? e.code}',
      ),
    ),
  );
}

}

// ============================================================
// INPUT FIELD
// ============================================================

Widget inputField({
required TextEditingController controller,
required String label,
required IconData icon,
TextInputType? keyboardType,
int maxLines = 1,
String? Function(String?)? validator,
}) {
return Padding(
padding: const EdgeInsets.only(bottom: 14),
child: TextFormField(
controller: controller,
keyboardType: keyboardType,
maxLines: maxLines,
validator: validator,
decoration: InputDecoration(
labelText: label,
prefixIcon: Icon(icon),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
),
),
);
}

// ============================================================
// MONEY
// ============================================================

String money(dynamic value) {
if (value is num) {
return '₹${value.toStringAsFixed(0)}';
}

final number = double.tryParse(
  value?.toString() ?? '',
);

if (number == null) {
  return '₹0';
}

return '₹${number.toStringAsFixed(0)}';

}

// ============================================================
// DATE
// ============================================================

String formatDate(dynamic value) {
if (value is! Timestamp) {
return 'Date unavailable';
}

final date = value.toDate();

final day = date.day.toString().padLeft(2, '0');
final month = date.month.toString().padLeft(2, '0');
final year = date.year.toString();

return '$day/$month/$year';

}

// ============================================================
// STATUS COLOR
// ============================================================

Color statusColor(String status) {
switch (status.toLowerCase()) {
case 'delivered':
return Colors.green;

  case 'cancelled':
    return Colors.red;

  case 'shipped':
    return Colors.blue;

  case 'confirmed':
    return Colors.orange;

  default:
    return Colors.deepPurple;
}

}

// ============================================================
// DELETE CONFIRMATION
// ============================================================

Future<void> confirmDelete(
String id,
String name,
) async {
final result = await showDialog<bool>(
context: context,
builder: (dialogContext) {
return AlertDialog(
title: const Text('Delete Product?'),
content: Text(
'Are you sure you want to delete "$name"?\n\n'
'This product will also disappear from the customer app.',
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(dialogContext, false);
},
child: const Text('Cancel'),
),
FilledButton(
onPressed: () {
Navigator.pop(dialogContext, true);
},
child: const Text('Delete'),
),
],
);
},
);

if (result == true) {
  await deleteProduct(id, name);
}

}

// ============================================================
// CUSTOMER DETAIL ROW
// ============================================================

Widget detailRow(
IconData icon,
String text,
) {
if (text.trim().isEmpty) {
return const SizedBox.shrink();
}

return Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        icon,
        size: 18,
        color: Colors.deepPurple,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    ],
  ),
);

}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text(
'Preesho Admin Panel',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
body: ListView(
padding: const EdgeInsets.all(16),
children: [
// ======================================================
// ADD PRODUCT HEADER
// ======================================================

      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
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
              'Add New Product',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Add products directly to Firestore',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 22),

      // ======================================================
      // PRODUCT FORM
      // ======================================================

      Form(
        key: _formKey,
        child: Column(
          children: [
            inputField(
              controller: nameController,
              label: 'Product Name',
              icon: Icons.shopping_bag_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter product name';
                }
                return null;
              },
            ),
            inputField(
              controller: categoryController,
              label: 'Category',
              icon: Icons.category_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter category';
                }
                return null;
              },
            ),
            inputField(
              controller: priceController,
              label: 'Price',
              icon: Icons.currency_rupee,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter price';
                }

                if (double.tryParse(value.trim()) == null) {
                  return 'Enter a valid price';
                }

                return null;
              },
            ),
            inputField(
              controller: stockController,
              label: 'Stock',
              icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter stock';
                }

                final stock = int.tryParse(value.trim());

                if (stock == null || stock < 0) {
                  return 'Stock cannot be below 0';
                }

                return null;
              },
            ),
            inputField(
              controller: imageUrlController,
              label: 'Image URL',
              icon: Icons.image_outlined,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter image URL';
                }

                if (!value.trim().startsWith('http')) {
                  return 'Enter a valid image URL';
                }

                return null;
              },
            ),
            inputField(
              controller: descriptionController,
              label: 'Description',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            Card(
              child: SwitchListTile(
                title: const Text('Product Active'),
                subtitle: const Text(
                  'Active products will appear in the app',
                ),
                value: active,
                onChanged: (value) {
                  setState(() {
                    active = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: saving ? null : saveProduct,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  saving ? 'Saving...' : 'Save Product',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: saving ? null : clearForm,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Form'),
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 30),

      // ======================================================
      // PRODUCTS HEADER
      // ======================================================

      const Text(
        'Products in Firestore',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
        ),
      ),

      const SizedBox(height: 12),

      // ======================================================
      // PRODUCTS LIST
      // ======================================================

      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: productsRef
            .orderBy(
              'CreatedAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Products error:\n${snapshot.error}',
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No products found'),
                ),
              ),
            );
          }

          return Column(
            children: docs.map((doc) {
              final data = doc.data();

              final name = data['Name']?.toString() ?? '';
              final category = data['Category']?.toString() ?? '';
              final price = data['Price']?.toString() ?? '0';

              final stock = int.tryParse(
                    data['Stock']?.toString() ?? '0',
                  ) ??
                  0;

              final isActive = data['Active'] == true;

              final imageUrl = data['Imageurl']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 65,
                        height: 65,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stack) {
                                    return const Icon(
                                      Icons.image_not_supported,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons.shopping_bag_outlined,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Unnamed Product' : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(category),
                            const SizedBox(height: 4),
                            Text(
                              '₹$price',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Text(
                                  stock <= 0
                                      ? 'OUT OF STOCK'
                                      : 'Stock: $stock',
                                  style: TextStyle(
                                    color: stock <= 0
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green
                                          : Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete Product',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          confirmDelete(doc.id, name);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),

      const SizedBox(height: 35),

      // ======================================================
      // ORDERS HEADER
      // ======================================================

      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [
              Color(0xff1565C0),
              Color(0xff42A5F5),
            ],
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Orders',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'View and manage customer orders',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 15),

      // ======================================================
      // ORDERS LIST
      // ======================================================

      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ordersRef
            .orderBy(
              'createdAt',
              descending: true,
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Orders error:\n${snapshot.error}',
                ),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];

          if (orders.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No customer orders yet.'),
                ),
              ),
            );
          }

          return Column(
            children: orders.map((doc) {
              final data = doc.data();

              final status =
                  data['status']?.toString() ?? 'Placed';

              // ==================================================
              // CUSTOMER DETAILS
              // Supports both OLD and NEW order formats
              // ==================================================

              final customerName =
                  data['customerName']?.toString() ??
                      data['name']?.toString() ??
                      'Customer';

              final customerMobile =
                  data['customerMobile']?.toString() ??
                      data['mobile']?.toString() ??
                      data['phone']?.toString() ??
                      '';

              final customerEmail =
                  data['customerEmail']?.toString() ??
                      data['email']?.toString() ??
                      '';

              final customerAddress =
                  data['customerAddress']?.toString() ??
                      data['address']?.toString() ??
                      '';

              final customerCity =
                  data['customerCity']?.toString() ??
                      data['city']?.toString() ??
                      '';

              final customerPincode =
                  data['customerPincode']?.toString() ??
                      data['pincode']?.toString() ??
                      '';

              // ==================================================
              // GIFT DETAILS
              // ==================================================

              final isGift = data['isGift'] == true ||
                  data['orderFor']?.toString() == 'Gift';

              final giftReceiverName =
                  data['giftReceiverName']?.toString() ?? '';

              final giftReceiverMobile =
                  data['giftReceiverMobile']?.toString() ?? '';

              final giftReceiverAddress =
                  data['giftReceiverAddress']?.toString() ?? '';

              final giftReceiverCity =
                  data['giftReceiverCity']?.toString() ?? '';

              final giftReceiverPincode =
                  data['giftReceiverPincode']?.toString() ?? '';

              // ==================================================
              // ORDER DATA
              // ==================================================

              final total = data['totalAmount'];
              final createdAt = data['createdAt'];

              final items = data['items'] is List
                  ? List<dynamic>.from(data['items'])
                  : <dynamic>[];

              // ==================================================
              // ACTUAL DELIVERY DETAILS
              // For Gift order, delivery goes to receiver
              // ==================================================

              final deliveryName =
                  isGift && giftReceiverName.isNotEmpty
                      ? giftReceiverName
                      : customerName;

              final deliveryMobile =
                  isGift && giftReceiverMobile.isNotEmpty
                      ? giftReceiverMobile
                      : customerMobile;

              final deliveryAddress =
                  isGift && giftReceiverAddress.isNotEmpty
                      ? giftReceiverAddress
                      : customerAddress;

              final deliveryCity =
                  isGift && giftReceiverCity.isNotEmpty
                      ? giftReceiverCity
                      : customerCity;

              final deliveryPincode =
                  isGift && giftReceiverPincode.isNotEmpty
                      ? giftReceiverPincode
                      : customerPincode;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==========================================
                      // ORDER HEADER
                      // ==========================================

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Order #${doc.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  formatDate(createdAt),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(status)
                                  .withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const Divider(height: 25),

                      // ==========================================
                      // ORDER TYPE
                      // ==========================================

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isGift
                              ? Colors.pink.withOpacity(0.10)
                              : Colors.blue.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isGift
                                  ? Icons.card_giftcard
                                  : Icons.person,
                              size: 18,
                              color: isGift
                                  ? Colors.pink
                                  : Colors.blue,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              isGift
                                  ? 'Gift Order'
                                  : 'Self Order',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isGift
                                    ? Colors.pink
                                    : Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // CUSTOMER DETAILS
                      // ==========================================

                      const Text(
                        'Customer Details',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),

                      const SizedBox(height: 10),

                      detailRow(
                        Icons.person_outline,
                        customerName,
                      ),

                      detailRow(
                        Icons.phone_outlined,
                        customerMobile,
                      ),

                      detailRow(
                        Icons.email_outlined,
                        customerEmail,
                      ),

                      const SizedBox(height: 10),

                      // ==========================================
                      // DELIVERY DETAILS
                      // ==========================================

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.local_shipping_outlined,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isGift
                                      ? 'Gift Delivery Details'
                                      : 'Delivery Details',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            detailRow(
                              Icons.person_outline,
                              deliveryName,
                            ),

                            detailRow(
                              Icons.phone_outlined,
                              deliveryMobile,
                            ),

                            detailRow(
                              Icons.home_outlined,
                              deliveryAddress,
                            ),

                            detailRow(
                              Icons.location_city_outlined,
                              deliveryCity,
                            ),

                            detailRow(
                              Icons.pin_drop_outlined,
                              deliveryPincode,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // ITEMS
                      // ==========================================

                      if (items.isNotEmpty) ...[
                        const Text(
                          'Items',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(height: 8),

                        ...items.map(
                          (item) {
                            if (item is! Map) {
                              return const SizedBox.shrink();
                            }

                            final itemName =
                                item['name']?.toString() ??
                                    'Product';

                            final quantity =
                                item['quantity']?.toString() ??
                                    '1';

                            final itemTotal = item['total'];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '$itemName × $quantity',
                                    ),
                                  ),
                                  Text(
                                    money(itemTotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      const Divider(height: 25),

                      // ==========================================
                      // TOTAL
                      // ==========================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Total',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            money(total),
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Payment: Cash on Delivery',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // STATUS
                      // ==========================================

                      DropdownButtonFormField<String>(
                        value: [
                          'Placed',
                          'Confirmed',
                          'Shipped',
                          'Delivered',
                          'Cancelled',
                        ].contains(status)
                            ? status
                            : 'Placed',
                        decoration: const InputDecoration(
                          labelText: 'Order Status',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Placed',
                            child: Text('Placed'),
                          ),
                          DropdownMenuItem(
                            value: 'Confirmed',
                            child: Text('Confirmed'),
                          ),
                          DropdownMenuItem(
                            value: 'Shipped',
                            child: Text('Shipped'),
                          ),
                          DropdownMenuItem(
                            value: 'Delivered',
                            child: Text('Delivered'),
                          ),
                          DropdownMenuItem(
                            value: 'Cancelled',
                            child: Text('Cancelled'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null || value == status) {
                            return;
                          }

                          updateOrderStatus(
                            doc.id,
                            value,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),

      const SizedBox(height: 30),
    ],
  ),
);

}
}
