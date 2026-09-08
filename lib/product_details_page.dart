import 'package:flutter/material.dart';

import 'models/preesho_models.dart';
import 'cart/cart_controller.dart';
import 'checkout_page.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  final VoidCallback? onCartChanged;

  const ProductDetailsPage({
    super.key,
    required this.product,
    this.onCartChanged,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int quantity = 1;
  bool addingToCart = false;

  Product get product => widget.product;

  double get price => product.numericPrice;

  double get mrp {
    final value = product.originalPrice;
    return value > price ? value : price;
  }

  double get savings {
    final value = mrp - price;
    return value > 0 ? value : 0;
  }

  int get discountPercent {
    if (mrp <= 0 || price >= mrp) return 0;
    return (((mrp - price) / mrp) * 100).round();
  }

  bool get hasDiscount => mrp > price;

  bool get inStock => product.active && product.stock > 0;

  bool get isLowStock => product.stock > 0 && product.stock <= 5;

  CartItem? get cartItem => CartController.findItem(product.id);

  int get cartQuantity => cartItem?.quantity ?? 0;

  @override
  void initState() {
    super.initState();

    final existing = CartController.findItem(product.id);
    if (existing != null && existing.quantity > 0) {
      quantity = existing.quantity.clamp(1, product.stock);
    }
  }

  Future<void> _addToCart() async {
    if (!inStock || addingToCart) return;

    setState(() {
      addingToCart = true;
    });

    final success = await CartController.addProduct(
      product,
      quantity: quantity,
    );

    if (!mounted) return;

    setState(() {
      addingToCart = false;
    });

    widget.onCartChanged?.call();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: const [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Product cart mein add ho gaya',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Product add nahi ho saka. Stock check karein.',
          ),
        ),
      );
    }
  }

  Future<void> _buyNow() async {
    if (!inStock) return;

    final success = await CartController.addProduct(
      product,
      quantity: quantity,
    );

    if (!mounted) return;

    widget.onCartChanged?.call();

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Product available stock mein nahi hai.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CheckoutPage(),
      ),
    );
  }

  Future<void> _increaseQuantity() async {
    if (!inStock) return;

    final maxStock = product.stock;

    if (quantity >= maxStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Maximum available stock: $maxStock',
          ),
        ),
      );
      return;
    }

    setState(() {
      quantity++;
    });
  }

  void _decreaseQuantity() {
    if (quantity <= 1) return;

    setState(() {
      quantity--;
    });
  }

  Widget _buildProductImage() {
    final image = product.imageUrl.trim();

    return Container(
      height: 360,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: image.isEmpty
                ? Icon(
                    Icons.image_not_supported_outlined,
                    size: 90,
                    color: Colors.grey.shade400,
                  )
                : Padding(
                    padding: const EdgeInsets.all(28),
                    child: Image.network(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          Icons.image_not_supported_outlined,
                          size: 90,
                          color: Colors.grey.shade400,
                        );
                      },
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                    ),
                  ),
          ),

          if (hasDiscount)
            Positioned(
              left: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$discountPercent% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          if (!inStock)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.45),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'OUT OF STOCK',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${price.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(width: 10),
              if (hasDiscount)
                Text(
                  '₹${mrp.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade500,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 7),

          if (hasDiscount)
            Text(
              'You save ₹${savings.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),

          const SizedBox(height: 14),

          Row(
            children: [
              Icon(
                inStock
                    ? Icons.inventory_2_outlined
                    : Icons.remove_shopping_cart_outlined,
                size: 18,
                color: inStock
                    ? Colors.green.shade700
                    : Colors.red.shade600,
              ),
              const SizedBox(width: 7),
              Text(
                !inStock
                    ? 'Currently unavailable'
                    : isLowStock
                        ? 'Only ${product.stock} left'
                        : '${product.stock} items available',
                style: TextStyle(
                  color: !inStock
                      ? Colors.red.shade600
                      : isLowStock
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Quantity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: quantity > 1 ? _decreaseQuantity : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 35,
                  child: Center(
                    child: Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: inStock &&
                          quantity < product.stock
                      ? _increaseQuantity
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    final description = product.description.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description.isEmpty
                ? 'No description available for this product.'
                : description,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.55,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSection() {
    final vendorName = product.safeVendorName;

    if (vendorName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Color(0xFF5B35D5),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sold by',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  vendorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_rounded,
            color: Colors.green,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TrustItem(
              icon: Icons.payments_outlined,
              title: 'COD',
              subtitle: 'Available',
            ),
          ),
          Container(
            height: 45,
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.verified_user_outlined,
              title: 'Secure',
              subtitle: 'Shopping',
            ),
          ),
          Container(
            height: 45,
            width: 1,
            color: Colors.grey.shade300,
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.local_shipping_outlined,
              title: 'Fast',
              subtitle: 'Delivery',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final existingQuantity = cartQuantity;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.10),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFF1EEFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: Color(0xFF5B35D5),
                    ),
                  ),
                  if (existingQuantity > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFF5B35D5),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$existingQuantity',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: inStock ? _addToCart : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B35D5),
                    side: const BorderSide(
                      color: Color(0xFF5B35D5),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: addingToCart
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Add to Cart',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: inStock ? _buyNow : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B35D5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Buy Now',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Product Details',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Share',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(
                    'Sharing option coming soon.',
                  ),
                ),
              );
            },
            icon: const Icon(
              Icons.share_outlined,
            ),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomBar(),

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductImage(),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          product.category,
                          style: const TextStyle(
                            color: Color(0xFF5B35D5),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (inStock)
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 9,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'In Stock',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.3,
                    ),
                  ),

                  const SizedBox(height: 18),

                  _buildPriceSection(),

                  const SizedBox(height: 14),

                  _buildQuantitySection(),

                  const SizedBox(height: 14),

                  _buildDescription(),

                  const SizedBox(height: 14),

                  _buildVendorSection(),

                  const SizedBox(height: 14),

                  _buildTrustSection(),

                  const SizedBox(height: 20),

                  if (inStock)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.green.shade100,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_shipping_rounded,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Cash on Delivery available on this product.',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 25,
          color: const Color(0xFF5B35D5),
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
