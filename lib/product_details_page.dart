import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'checkout_page.dart';
import 'models/preesho_models.dart';
import 'cart/cart_controller.dart';

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
  int quantity = 1;
  bool addingToCart = false;
  bool buyingNow = false;

  Product get product => widget.product;

  double get sellingPrice => product.numericPrice;

  double get originalPrice => product.originalPrice;

  double get savings =>
      originalPrice > sellingPrice
          ? originalPrice - sellingPrice
          : 0;

  int get discountPercent {
    if (originalPrice <= sellingPrice ||
        originalPrice <= 0) {
      return 0;
    }

    return (((originalPrice - sellingPrice) /
                originalPrice) *
            100)
        .round();
  }

  bool get hasStock => product.stock > 0;

  Future<void> addToCart() async {
    if (!hasStock || addingToCart) return;

    setState(() {
      addingToCart = true;
    });

    try {
      final success =
          await CartController.addProduct(
        product,
        quantity: quantity,
      );

      if (!mounted) return;

      if (success) {
        widget.onCartChanged();

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$quantity × ${product.name} added to cart',
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Product is no longer available.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          addingToCart = false;
        });
      }
    }
  }

  Future<void> buyNow() async {
    if (!hasStock || buyingNow) return;

    setState(() {
      buyingNow = true;
    });

    try {
      final success =
          await CartController.addProduct(
        product,
        quantity: quantity,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Product is no longer available.',
            ),
          ),
        );
        return;
      }

      widget.onCartChanged();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutPage(
            onOrderPlaced: () {
              widget.onCartChanged();
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          buyingNow = false;
        });
      }
    }
  }

  void increaseQuantity() {
    if (quantity < product.stock) {
      setState(() {
        quantity++;
      });
    }
  }

  void decreaseQuantity() {
    if (quantity > 1) {
      setState(() {
        quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          const Color(0xffF7F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const _CartFallbackPage(),
                ),
              );
            },
            icon: const Icon(
              Icons.shopping_bag_outlined,
            ),
          ),
        ],
      ),

      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _ProductImageSection(
              product: product,
              discountPercent:
                  discountPercent,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                120,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // CATEGORY
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color:
                          primary.withValues(alpha: .10),
                      borderRadius:
                          BorderRadius.circular(30),
                    ),
                    child: Text(
                      product.category,
                      style: TextStyle(
                        color: primary,
                        fontWeight:
                            FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // NAME
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 25,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // PRICE
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₹${sellingPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 29,
                          fontWeight:
                              FontWeight.w900,
                          color: primary,
                        ),
                      ),
                      if (originalPrice >
                          sellingPrice) ...[
                        const SizedBox(width: 10),
                        Text(
                          '₹${originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Colors.grey.shade500,
                            decoration:
                                TextDecoration
                                    .lineThrough,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Colors.green
                                    .withValues(
                              alpha: .10,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(8),
                          ),
                          child: Text(
                            '$discountPercent% OFF',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (savings > 0) ...[
                    const SizedBox(height: 7),
                    Text(
                      'You save ₹${savings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // STOCK
                  _StockCard(
                    stock: product.stock,
                  ),

                  const SizedBox(height: 18),

                  // TRUST STRIP
                  _TrustStrip(),

                  const SizedBox(height: 24),

                  // QUANTITY
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Quantity',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      _QuantitySelector(
                        quantity: quantity,
                        onMinus:
                            decreaseQuantity,
                        onPlus:
                            increaseQuantity,
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // DESCRIPTION
                  const Text(
                    'Product Description',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      product.description
                              .trim()
                              .isEmpty
                          ? 'No description available for this product.'
                          : product.description,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.55,
                        color:
                            Colors.grey.shade700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // VENDOR
                  if (product.safeVendorName
                      .isNotEmpty)
                    _VendorCard(
                      vendorName:
                          product.safeVendorName,
                    ),

                  const SizedBox(height: 20),

                  // COD INFO
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey
                            .withValues(alpha: .12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: primary
                                .withValues(
                              alpha: .10,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons
                                .payments_outlined,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Pay safely when your order is delivered.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.verified_rounded,
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      // BOTTOM ACTION BAR
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            14,
            10,
            14,
            12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                blurRadius: 18,
                offset: const Offset(0, -5),
                color:
                    Colors.black.withValues(
                  alpha: .08,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      hasStock && !addingToCart
                          ? addToCart
                          : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(54),
                    side: BorderSide(
                      color: primary,
                      width: 1.5,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: addingToCart
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons
                                  .shopping_bag_outlined,
                              color: primary,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Add to Cart',
                              style: TextStyle(
                                color: primary,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton(
                  onPressed:
                      hasStock && !buyingNow
                          ? buyNow
                          : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(54),
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                  ),
                  child: buyingNow
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons
                                  .flash_on_rounded,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Buy Now',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ],
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

// ============================================================
// PRODUCT IMAGE
// ============================================================

class _ProductImageSection
    extends StatelessWidget {
  final Product product;
  final int discountPercent;

  const _ProductImageSection({
    required this.product,
    required this.discountPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 370,
      color: Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: product.imageUrl.trim().isEmpty
                ? _imagePlaceholder()
                : Image.network(
                    product.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) =>
                            _imagePlaceholder(),
                    loadingBuilder:
                        (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }

                      return Center(
                        child:
                            CircularProgressIndicator(
                          value: progress
                                      .expectedTotalBytes !=
                                  null
                              ? progress
                                      .cumulativeBytesLoaded /
                                  progress
                                      .expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
          ),

          if (discountPercent > 0)
            Positioned(
              top: 18,
              left: 18,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Text(
                  '$discountPercent% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),

          Positioned(
            top: 18,
            right: 18,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    color:
                        Colors.black.withValues(
                      alpha: .08,
                    ),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 16,
                    color: Colors.green,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Verified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Center(
      child: Icon(
        Icons.image_outlined,
        size: 90,
        color: Colors.grey.shade300,
      ),
    );
  }
}

// ============================================================
// STOCK CARD
// ============================================================

class _StockCard extends StatelessWidget {
  final int stock;

  const _StockCard({
    required this.stock,
  });

  @override
  Widget build(BuildContext context) {
    final bool lowStock =
        stock > 0 && stock <= 5;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: lowStock
            ? Colors.orange.withValues(
                alpha: .08,
              )
            : Colors.green.withValues(
                alpha: .08,
              ),
        borderRadius:
            BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            stock <= 0
                ? Icons
                    .remove_shopping_cart_outlined
                : Icons.inventory_2_outlined,
            color: stock <= 0
                ? Colors.red
                : lowStock
                    ? Colors.orange
                    : Colors.green,
          ),
          const SizedBox(width: 10),
          Text(
            stock <= 0
                ? 'Out of stock'
                : lowStock
                    ? 'Only $stock left in stock'
                    : '$stock items available',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: stock <= 0
                  ? Colors.red
                  : lowStock
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// QUANTITY
// ============================================================

class _QuantitySelector
    extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QuantitySelector({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey
              .withValues(alpha: .15),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(
              Icons.remove_rounded,
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(
              Icons.add_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TRUST STRIP
// ============================================================

class _TrustStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _TrustItem(
              icon: Icons.local_shipping_outlined,
              text: 'Fast Delivery',
            ),
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.verified_outlined,
              text: 'Quality',
            ),
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.lock_outline_rounded,
              text: 'Secure',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 22,
          color:
              Theme.of(context)
                  .colorScheme
                  .primary,
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// VENDOR
// ============================================================

class _VendorCard extends StatelessWidget {
  final String vendorName;

  const _VendorCard({
    required this.vendorName,
  });

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color:
                  primary.withValues(alpha: .10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: primary,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sold by',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vendorName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

// Temporary cart navigation placeholder.
// Main.dart will be connected to CartPage in the next step.
class _CartFallbackPage extends StatelessWidget {
  const _CartFallbackPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
      ),
      body: const Center(
        child: Text(
          'Cart',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
