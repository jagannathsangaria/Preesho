import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../checkout_page.dart';
import '../login_page.dart';
import '../orders_page.dart';
import 'cart_controller.dart';

const List<String> activeOrderStatuses = [
  'Placed',
  'Confirmed',
  'Processing',
  'Packed',
  'Shipped',
  'Picked by Courier',
  'Out for Delivery',
];

const List<String> fullOrderStatuses = [
  'Placed',
  'Confirmed',
  'Processing',
  'Packed',
  'Shipped',
  'Picked by Courier',
  'Out for Delivery',
  'Delivered',
];

class CartPage extends StatefulWidget {
  final VoidCallback onCartChanged;

  const CartPage({
    super.key,
    required this.onCartChanged,
  });

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _loading = false;

  String _money(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  double _discountPercent(CartItem item) {
    if (item.originalPrice <= item.numericPrice ||
        item.originalPrice <= 0) {
      return 0;
    }

    return ((item.originalPrice - item.numericPrice) /
            item.originalPrice) *
        100;
  }

  Future<void> _increase(CartItem item) async {
    setState(() => _loading = true);

    await CartController.increaseQuantity(item.id);

    if (!mounted) return;

    setState(() => _loading = false);
    widget.onCartChanged();
  }

  Future<void> _decrease(CartItem item) async {
    setState(() => _loading = true);

    await CartController.decreaseQuantity(item.id);

    if (!mounted) return;

    setState(() => _loading = false);
    widget.onCartChanged();
  }

  Future<void> _remove(CartItem item) async {
    await CartController.removeProduct(item.id);

    if (!mounted) return;

    widget.onCartChanged();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${item.name} removed from cart'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );

    setState(() {});
  }

  Future<void> _clearCart() async {
    if (CartController.items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Clear Cart?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'All products will be removed from your cart.',
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
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await CartController.clear();

    if (!mounted) return;

    widget.onCartChanged();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cart cleared'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _checkout() async {
    if (CartController.items.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
      );

      if (!mounted) return;

      if (result == null &&
          FirebaseAuth.instance.currentUser == null) {
        return;
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CheckoutPage(),
      ),
    );

    if (!mounted) return;

    setState(() {});
    widget.onCartChanged();
  }

  @override
  Widget build(BuildContext context) {
    final items = CartController.items;

    final total = CartController.total;
    final originalTotal = CartController.originalTotal;
    final savings = CartController.productSavings;

    final hasDiscount = originalTotal > total;

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xff171717),
        centerTitle: false,
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: _clearCart,
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: items.isEmpty
          ? _EmptyCart(
              onContinueShopping: () {
                Navigator.pop(context);
              },
            )
          : RefreshIndicator(
              onRefresh: () async {
                await CartController.initialize();

                if (!mounted) return;

                setState(() {});
                widget.onCartChanged();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  180,
                ),
                children: [
                  _CartHeader(
                    itemCount: CartController.itemCount,
                    savings: savings,
                  ),
                  const SizedBox(height: 12),

                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: _CartProductCard(
                        item: item,
                        discountPercent:
                            _discountPercent(item),
                        onIncrease: _loading
                            ? null
                            : () => _increase(item),
                        onDecrease: _loading
                            ? null
                            : () => _decrease(item),
                        onRemove: () => _remove(item),
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  const _DeliveryInfoCard(),

                  const SizedBox(height: 12),

                  _PriceDetailsCard(
                    originalTotal: originalTotal,
                    total: total,
                    savings: savings,
                    hasDiscount: hasDiscount,
                  ),

                  const SizedBox(height: 12),

                  const _CodInfoCard(),
                ],
              ),
            ),
      bottomNavigationBar: items.isEmpty
          ? null
          : _CheckoutBottomBar(
              total: total,
              itemCount: CartController.itemCount,
              onCheckout: _checkout,
            ),
    );
  }
}

class _CartHeader extends StatelessWidget {
  final int itemCount;
  final double savings;

  const _CartHeader({
    required this.itemCount,
    required this.savings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xff4F46E5),
            Color(0xff7C3AED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withValues(
              alpha: 0.18,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.18,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '$itemCount ${itemCount == 1 ? 'Item' : 'Items'} in your cart',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  savings > 0
                      ? 'You are saving ₹${savings.toStringAsFixed(0)}'
                      : 'Review your items before checkout',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: 0.88,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _CartProductCard extends StatelessWidget {
  final CartItem item;
  final double discountPercent;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;
  final VoidCallback onRemove;

  const _CartProductCard({
    required this.item,
    required this.discountPercent,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        item.originalPrice > item.numericPrice;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffECECF2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.045,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _ProductImage(
                  imageUrl: item.imageUrl,
                  size: 94,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.category,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹${item.numericPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (hasDiscount) ...[
                            const SizedBox(width: 7),
                            Text(
                              '₹${item.originalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                decoration:
                                    TextDecoration
                                        .lineThrough,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green
                                    .withValues(
                                  alpha: 0.10,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(6),
                              ),
                              child: Text(
                                '${discountPercent.round()}% OFF',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight:
                                      FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove',
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.availableStock > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 15,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${item.availableStock} available',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xffF5F5FA),
                    borderRadius:
                        BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xffE5E5EC),
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onDecrease,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(
                          Icons.remove_rounded,
                          size: 18,
                        ),
                      ),
                      Container(
                        width: 34,
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onIncrease,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _ProductImage({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xffF4F5F8),
        borderRadius: BorderRadius.circular(17),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return const _ImagePlaceholder();
              },
              loadingBuilder:
                  (context, child, progress) {
                if (progress == null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
            )
          : const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey,
        size: 32,
      ),
    );
  }
}

class _DeliveryInfoCard extends StatelessWidget {
  const _DeliveryInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffE8E8EF),
        ),
      ),
      child: const Column(
        children: [
          _InfoRow(
            icon: Icons.local_shipping_outlined,
            title: 'Fast & Safe Delivery',
            subtitle:
                'Your order will be delivered to your selected address.',
          ),
          SizedBox(height: 13),
          _InfoRow(
            icon: Icons.verified_user_outlined,
            title: 'Secure Shopping',
            subtitle:
                'Your order information is securely processed.',
          ),
          SizedBox(height: 13),
          _InfoRow(
            icon: Icons.assignment_return_outlined,
            title: 'Easy Order Support',
            subtitle:
                'Track your order from the Orders section.',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xffF1F0FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple,
            size: 21,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceDetailsCard extends StatelessWidget {
  final double originalTotal;
  final double total;
  final double savings;
  final bool hasDiscount;

  const _PriceDetailsCard({
    required this.originalTotal,
    required this.total,
    required this.savings,
    required this.hasDiscount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xffE8E8EF),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Details',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _PriceRow(
            title: 'MRP / Product Price',
            value: '₹${originalTotal.toStringAsFixed(0)}',
            muted: hasDiscount,
          ),
          const SizedBox(height: 10),
          _PriceRow(
            title: 'Discounted Price',
            value: '₹${total.toStringAsFixed(0)}',
            bold: true,
          ),
          const SizedBox(height: 10),
          _PriceRow(
            title: 'Delivery',
            value: 'FREE',
            valueColor: Colors.green,
            bold: true,
          ),
          if (savings > 0) ...[
            const SizedBox(height: 13),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.green.withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                'You save ₹${savings.toStringAsFixed(0)} on this order',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Divider(
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 8),
          _PriceRow(
            title: 'Total Amount',
            value: '₹${total.toStringAsFixed(0)}',
            bold: true,
            large: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String title;
  final String value;
  final bool bold;
  final bool large;
  final bool muted;
  final Color? valueColor;

  const _PriceRow({
    required this.title,
    required this.value,
    this.bold = false,
    this.large = false,
    this.muted = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: muted
                  ? Colors.grey.shade500
                  : Colors.grey.shade700,
              fontSize: large ? 14 : 13,
              fontWeight: bold
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ??
                (large
                    ? const Color(0xff111827)
                    : Colors.grey.shade800),
            fontSize: large ? 18 : 13,
            fontWeight: bold
                ? FontWeight.w900
                : FontWeight.w600,
            decoration: muted
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
      ],
    );
  }
}

class _CodInfoCard extends StatelessWidget {
  const _CodInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffFFFBEB),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xffFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xffB45309),
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash on Delivery Available',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'COD option will be available during checkout.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xff78716C),
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

class _CheckoutBottomBar extends StatelessWidget {
  final double total;
  final int itemCount;
  final VoidCallback onCheckout;

  const _CheckoutBottomBar({
    required this.total,
    required this.itemCount,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          14,
          12,
          14,
          12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.10,
              ),
              blurRadius: 18,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xff4F46E5),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 19,
                ),
                label: const Text(
                  'Proceed to Checkout',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onContinueShopping;

  const _EmptyCart({
    required this.onContinueShopping,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xffEEECFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 55,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your cart is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products you love and they will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: onContinueShopping,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xff4F46E5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                ),
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                ),
                label: const Text(
                  'Continue Shopping',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* =========================================================
   ACTIVE ORDER TRACKING
   ========================================================= */

class ActiveOrderTracking extends StatelessWidget {
  const ActiveOrderTracking({super.key});

  String normalizeStatus(
    Map<String, dynamic> data,
  ) {
    final value =
        data['orderStatus'] ??
        data['status'] ??
        'Placed';

    final text = value.toString().trim();

    if (text.isEmpty) {
      return 'Placed';
    }

    for (final status in fullOrderStatuses) {
      if (status.toLowerCase() ==
          text.toLowerCase()) {
        return status;
      }
    }

    return text;
  }

  DateTime timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime orderDate(
    Map<String, dynamic> data,
  ) {
    return timestampToDate(
      data['createdAt'] ??
          data['placedAt'] ??
          data['updatedAt'],
    );
  }

  bool isActive(String status) {
    return activeOrderStatuses.any(
      (value) =>
          value.toLowerCase() ==
          status.toLowerCase(),
    );
  }

  int statusIndex(String status) {
    final index =
        fullOrderStatuses.indexWhere(
      (value) =>
          value.toLowerCase() ==
          status.toLowerCase(),
    );

    return index < 0 ? 0 : index;
  }

  Color statusColor(String status) {
    switch (status) {
      case 'Placed':
        return Colors.blue;
      case 'Confirmed':
        return Colors.indigo;
      case 'Processing':
        return Colors.orange;
      case 'Packed':
        return Colors.deepOrange;
      case 'Shipped':
        return Colors.purple;
      case 'Picked by Courier':
        return Colors.teal;
      case 'Out for Delivery':
        return Colors.green;
      case 'Delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'Placed':
        return Icons.receipt_long;
      case 'Confirmed':
        return Icons.verified_outlined;
      case 'Processing':
        return Icons.settings_outlined;
      case 'Packed':
        return Icons.inventory_2_outlined;
      case 'Shipped':
        return Icons.local_shipping_outlined;
      case 'Picked by Courier':
        return Icons.delivery_dining;
      case 'Out for Delivery':
        return Icons.directions_bike_outlined;
      case 'Delivered':
        return Icons.check_circle;
      default:
        return Icons.circle_outlined;
    }
  }

  String shortOrderId(String id) {
    if (id.length <= 10) {
      return id;
    }

    return id.substring(0, 10);
  }

  double number(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(
                ',',
                '',
              ) ??
              '',
        ) ??
        0;
  }

  Future<void> copyText(
    BuildContext context,
    String text,
    String message,
  ) async {
    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where(
            'userId',
            isEqualTo: user.uid,
          )
          .snapshots(),
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Checking active orders...',
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final docs =
            snapshot.data?.docs ?? [];

        final activeOrders = docs
            .map(
              (doc) => MapEntry(
                doc.id,
                doc.data(),
              ),
            )
            .where(
              (entry) => isActive(
                normalizeStatus(entry.value),
              ),
            )
            .toList();

        activeOrders.sort(
          (a, b) => orderDate(
            b.value,
          ).compareTo(
            orderDate(a.value),
          ),
        );

        if (activeOrders.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            12,
            12,
            12,
            4,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  bottom: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .local_shipping_outlined,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Active Order Tracking',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ...activeOrders.map(
                (entry) => _buildOrderCard(
                  context,
                  entry.key,
                  entry.value,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final currentStatus =
        normalizeStatus(data);

    final currentIndex =
        statusIndex(currentStatus);

    final total = number(
      data['total'] ??
          data['grandTotal'] ??
          data['amount'] ??
          data['totalAmount'] ??
          0,
    );

    final courierName =
        data['courierPersonName']
                ?.toString() ??
            data['courierName']
                ?.toString() ??
            '';

    final courierMobile =
        data['courierPhone']
                ?.toString() ??
            data['courierMobile']
                ?.toString() ??
            '';

    final courierPartner =
        data['courierPartner']
                ?.toString() ??
            '';

    final trackingNumber =
        data['trackingNumber']
                ?.toString() ??
            '';

    final color =
        statusColor(currentStatus);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: color.withValues(alpha: 0.08),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color,
                  child: Icon(
                    statusIcon(currentStatus),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Status',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentStatus,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${shortOrderId(orderId)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Order Progress',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _TrackingTimeline(
                  currentIndex: currentIndex,
                ),
                if (courierName.isNotEmpty ||
                    courierMobile.isNotEmpty ||
                    courierPartner.isNotEmpty ||
                    trackingNumber.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal
                          .withValues(alpha: 0.07),
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons
                                  .delivery_dining,
                              color: Colors.teal,
                            ),
                            SizedBox(width: 9),
                            Text(
                              'Courier Details',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (courierPartner
                            .isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            'Partner: $courierPartner',
                          ),
                        ],
                        if (courierName.isNotEmpty)
                          Text(
                            'Name: $courierName',
                          ),
                        if (courierMobile
                            .isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Phone: $courierMobile',
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  copyText(
                                    context,
                                    courierMobile,
                                    'Courier number copied.',
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons.copy_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        if (trackingNumber
                            .isNotEmpty)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Tracking: $trackingNumber',
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  copyText(
                                    context,
                                    trackingNumber,
                                    'Tracking number copied.',
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons.copy_outlined,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const OrdersPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.receipt_long,
                    ),
                    label: const Text(
                      'View Full Order Details',
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

class _TrackingTimeline
    extends StatelessWidget {
  final int currentIndex;

  const _TrackingTimeline({
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        fullOrderStatuses.length,
        (index) {
          final status =
              fullOrderStatuses[index];

          final completed =
              index <= currentIndex;

          final last =
              index ==
                  fullOrderStatuses.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,
                          color: completed
                              ? Colors.deepPurple
                              : Colors.grey.shade300,
                        ),
                        child: Icon(
                          completed
                              ? Icons.check
                              : Icons
                                  .circle_outlined,
                          size: 14,
                          color: completed
                              ? Colors.white
                              : Colors.grey
                                  .shade600,
                        ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 2,
                            ),
                            color: index <
                                    currentIndex
                                ? Colors.deepPurple
                                : Colors
                                    .grey
                                    .shade300,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 1,
                      bottom: 12,
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            completed
                                ? FontWeight.w800
                                : FontWeight.w500,
                        color: completed
                            ? Colors.black87
                            : Colors.grey
                                .shade500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
