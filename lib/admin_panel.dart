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

  final productsRef =
      FirebaseFirestore.instance.collection('products');

  final ordersRef =
      FirebaseFirestore.instance.collection('orders');

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

  // =====================================================
  // SAVE PRODUCT
  // =====================================================

  Future<void> saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await productsRef.add({
        'Name': nameController.text.trim(),
        'Category': categoryController.text.trim(),
        'Price': priceController.text.trim(),
        'Stock': stockController.text.trim(),
        'Imageurl': imageUrlController.text.trim(),
        'Description': descriptionController.text.trim(),
        'Active': active,
        'CreatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product saved successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error saving product:\n$e',
          ),
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

  // =====================================================
  // DELETE PRODUCT
  // =====================================================

  Future<void> deleteProduct(String id) async {
    try {
      await productsRef.doc(id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Product deleted',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete error:\n$e',
          ),
        ),
      );
    }
  }

  // =====================================================
  // UPDATE ORDER STATUS
  // =====================================================

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
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Status update failed:\n$e',
          ),
        ),
      );
    }
  }

  // =====================================================
  // INPUT FIELD
  // =====================================================

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

  String imagePreviewUrl() {
    return imageUrlController.text.trim();
  }

  // =====================================================
  // MONEY
  // =====================================================

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

  // =====================================================
  // DATE
  // =====================================================

  String formatDate(dynamic value) {
    if (value is! Timestamp) {
      return 'Date unavailable';
    }

    final date = value.toDate();

    final day =
        date.day.toString().padLeft(2, '0');
    final month =
        date.month.toString().padLeft(2, '0');
    final year =
        date.year.toString();

    return '$day/$month/$year';
  }

  // =====================================================
  // STATUS COLOR
  // =====================================================

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

  // =====================================================
  // BUILD
  // =====================================================

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
          // =================================================
          // ADD PRODUCT HEADER
          // =================================================

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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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

          // =================================================
          // PRODUCT FORM
          // =================================================

          Form(
            key: _formKey,
            child: Column(
              children: [
                inputField(
                  controller: nameController,
                  label: 'Product Name',
                  icon: Icons.shopping_bag_outlined,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
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
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter category';
                    }
                    return null;
                  },
                ),

                inputField(
                  controller: priceController,
                  label: 'Price',
                  icon: Icons.currency_rupee,
                  keyboardType:
                      TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter price';
                    }

                    if (double.tryParse(
                            value.trim()) ==
                        null) {
                      return 'Enter a valid price';
                    }

                    return null;
                  },
                ),

                inputField(
                  controller: stockController,
                  label: 'Stock',
                  icon: Icons.inventory_2_outlined,
                  keyboardType:
                      TextInputType.number,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter stock';
                    }

                    if (int.tryParse(
                            value.trim()) ==
                        null) {
                      return 'Enter valid stock';
                    }

                    return null;
                  },
                ),

                inputField(
                  controller: imageUrlController,
                  label: 'Image URL',
                  icon: Icons.image_outlined,
                  keyboardType:
                      TextInputType.url,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter image URL';
                    }

                    if (!value
                        .trim()
                        .startsWith('http')) {
                      return 'Enter a valid image URL';
                    }

                    return null;
                  },
                ),

                // IMAGE PREVIEW
                ValueListenableBuilder<
                    TextEditingValue>(
                  valueListenable:
                      imageUrlController,
                  builder:
                      (context, value, child) {
                    final url =
                        imagePreviewUrl();

                    if (url.isEmpty ||
                        !url.startsWith('http')) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      height: 200,
                      margin:
                          const EdgeInsets.only(
                        bottom: 14,
                      ),
                      clipBehavior:
                          Clip.antiAlias,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),
                        color:
                            Colors.grey.shade200,
                      ),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error,
                                stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 45,
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'Image could not be loaded',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                inputField(
                  controller:
                      descriptionController,
                  label: 'Description',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                ),

                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Product Active',
                    ),
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
                    onPressed:
                        saving ? null : saveProduct,
                    icon: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),
                    label: Text(
                      saving
                          ? 'Saving...'
                          : 'Save Product',
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed:
                        saving ? null : clearForm,
                    icon: const Icon(
                      Icons.clear_all,
                    ),
                    label: const Text(
                      'Clear Form',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // =================================================
          // PRODUCTS
          // =================================================

          const Text(
            'Products in Firestore',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: productsRef
                .orderBy(
                  'CreatedAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: Text(
                    'Products error:\n${snapshot.error}',
                  ),
                );
              }

              final docs =
                  snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Padding(
                  padding:
                      EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No products found',
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();

                  final name =
                      data['Name']
                              ?.toString() ??
                          '';

                  final category =
                      data['Category']
                              ?.toString() ??
                          '';

                  final price =
                      data['Price']
                              ?.toString() ??
                          '';

                  final stock =
                      data['Stock']
                              ?.toString() ??
                          '';

                  final imageUrl =
                      data['Imageurl']
                              ?.toString() ??
                          '';

                  final isActive =
                      data['Active'] == true;

                  return Card(
                    margin:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.all(10),
                      leading: SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          child: imageUrl
                                      .isNotEmpty &&
                                  imageUrl
                                      .startsWith(
                                          'http')
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context,
                                          error,
                                          stackTrace) {
                                    return const Icon(
                                      Icons
                                          .image_not_supported_outlined,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons
                                      .image_outlined,
                                ),
                        ),
                      ),
                      title: Text(
                        name.isEmpty
                            ? 'Unnamed Product'
                            : name,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '$category\n₹$price • Stock: $stock',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (dialogContext) {
                              return AlertDialog(
                                title:
                                    const Text(
                                  'Delete Product?',
                                ),
                                content:
                                    Text(
                                  'Delete "$name"?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                    },
                                    child:
                                        const Text(
                                      'Cancel',
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(
                                        dialogContext,
                                      );
                                      deleteProduct(
                                        doc.id,
                                      );
                                    },
                                    child:
                                        const Text(
                                      'Delete',
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(
                          Icons
                              .delete_outline,
                        ),
                      ),
                      onTap: () {
                        ScaffoldMessenger.of(
                                context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              isActive
                                  ? 'Product is Active'
                                  : 'Product is Inactive',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 35),

          // =================================================
          // ORDERS HEADER
          // =================================================

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
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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

          // =================================================
          // ORDERS
          // =================================================

          StreamBuilder<
              QuerySnapshot<
                  Map<String, dynamic>>>(
            stream: ordersRef
                .orderBy(
                  'createdAt',
                  descending: true,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(16),
                    child: Text(
                      'Orders error:\n${snapshot.error}',
                    ),
                  ),
                );
              }

              final orders =
                  snapshot.data?.docs ?? [];

              if (orders.isEmpty) {
                return const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No customer orders yet.',
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: orders.map((doc) {
                  final data = doc.data();

                  final status =
                      data['status']
                              ?.toString() ??
                          'Placed';

                  final email =
                      data['email']
                              ?.toString() ??
                          data['userEmail']
                              ?.toString() ??
                          'Email unavailable';

                  final name =
                      data['name']
                              ?.toString() ??
                          data['customerName']
                              ?.toString() ??
                          'Customer';

                  final mobile =
                      data['mobile']
                              ?.toString() ??
                          data['phone']
                              ?.toString() ??
                          '';

                  final address =
                      data['address']
                              ?.toString() ??
                          '';

                  final city =
                      data['city']
                              ?.toString() ??
                          '';

                  final pincode =
                      data['pincode']
                              ?.toString() ??
                          '';

                  final total =
                      data['totalAmount'];

                  final createdAt =
                      data['createdAt'];

                  final items =
                      data['items'] is List
                          ? List<dynamic>.from(
                              data['items'],
                            )
                          : <dynamic>[];

                  return Card(
                    margin:
                        const EdgeInsets.only(
                      bottom: 16,
                    ),
                    color: Colors.white,
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ORDER TOP
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      'Order #${doc.id}',
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Text(
                                      formatDate(
                                        createdAt,
                                      ),
                                      style: TextStyle(
                                        color: Colors
                                            .grey
                                            .shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      statusColor(
                                    status,
                                  ).withOpacity(
                                      0.12),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color:
                                        statusColor(
                                      status,
                                    ),
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const Divider(
                            height: 25,
                          ),

                          // CUSTOMER
                          const Text(
                            'Customer',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Text(
                            name,
                            style:
                                const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(email),

                          if (mobile.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .only(
                                top: 3,
                              ),
                              child: Text(
                                mobile,
                              ),
                            ),

                          const SizedBox(
                            height: 15,
                          ),

                          // ADDRESS
                          const Text(
                            'Delivery Address',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            '$address, $city - $pincode',
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          // ITEMS
                          if (items.isNotEmpty) ...[
                            const Text(
                              'Items',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(
                              height: 7,
                            ),
                            ...items.map(
                              (item) {
                                if (item
                                    is! Map) {
                                  return const SizedBox
                                      .shrink();
                                }

                                final itemName =
                                    item['name']
                                            ?.toString() ??
                                        'Product';

                                final quantity =
                                    item['quantity']
                                            ?.toString() ??
                                        '1';

                                final itemTotal =
                                    item['total'];

                                return Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    bottom: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child:
                                            Text(
                                          '$itemName × $quantity',
                                          maxLines:
                                              2,
                                          overflow:
                                              TextOverflow
                                                  .ellipsis,
                                        ),
                                      ),
                                      Text(
                                        money(
                                          itemTotal,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],

                          const Divider(
                            height: 25,
                          ),

                          // TOTAL
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                            children: [
                              const Text(
                                'Order Total',
                                style:
                                    TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                              Text(
                                money(total),
                                style:
                                    const TextStyle(
                                  fontSize: 21,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 15,
                          ),

                          // STATUS DROPDOWN
                          DropdownButtonFormField<
                              String>(
                            initialValue:
                                status,
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Order Status',
                              border:
                                  OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Placed',
                                child: Text(
                                  'Placed',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Confirmed',
                                child: Text(
                                  'Confirmed',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Shipped',
                                child: Text(
                                  'Shipped',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Delivered',
                                child: Text(
                                  'Delivered',
                                ),
                              ),
                              DropdownMenuItem(
                                value:
                                    'Cancelled',
                                child: Text(
                                  'Cancelled',
                                ),
                              ),
                            ],
                            onChanged:
                                (value) {
                              if (value == null ||
                                  value ==
                                      status) {
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
