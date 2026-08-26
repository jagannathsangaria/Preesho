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
          // ADMIN HEADER
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

          // FORM
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

                // ACTIVE SWITCH
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

                // SAVE BUTTON
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

                // CLEAR BUTTON
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

          // PRODUCTS SECTION
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
                            builder: (dialogContext) {
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
                                          dialogContext);
                                    },
                                    child:
                                        const Text(
                                      'Cancel',
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(
                                          dialogContext);
                                      deleteProduct(
                                          doc.id);
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
        ],
      ),
    );
  }
}
