import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/preesho_models.dart';

// ============================================================
// CART ITEM
// ============================================================

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    required this.quantity,
  });

  // ============================================================
  // PRODUCT DETAILS
  // ============================================================

  String get id => product.id;

  String get name => product.name;

  String get category => product.category;

  String get imageUrl => product.imageUrl;

  double get numericPrice => product.numericPrice;

  double get originalPrice => product.originalPrice;

  dynamic get discountPercent => product.discountPercent;

  // ============================================================
  // TOTAL PRICE
  // ============================================================

  double get totalPrice {
    return numericPrice * quantity;
  }

  // ============================================================
  // AVAILABLE STOCK
  // ============================================================

  int get availableStock {
    return product.stock;
  }
}

// ============================================================
// CART CONTROLLER
// ============================================================

class CartController {
  static const String _storageKey = 'preesho_cart_v2';

  static final List<CartItem> items = [];

  static SharedPreferences? _preferences;

  static bool _initialized = false;

  // ============================================================
  // INITIALIZE CART
  // ============================================================

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _preferences = await SharedPreferences.getInstance();

    await _loadCart();

    _initialized = true;
  }

  // ============================================================
  // LOAD CART
  // ============================================================

  static Future<void> _loadCart() async {
    if (_preferences == null) {
      return;
    }

    try {
      final String? savedCart =
          _preferences!.getString(_storageKey);

      if (savedCart == null || savedCart.trim().isEmpty) {
        return;
      }

      final dynamic decoded = jsonDecode(savedCart);

      if (decoded is! List) {
        return;
      }

      items.clear();

      for (final dynamic item in decoded) {
        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> data =
            Map<String, dynamic>.from(item);

        final Map<String, dynamic> productData =
            data['product'] is Map
                ? Map<String, dynamic>.from(
                    data['product'],
                  )
                : data;

        final Product product = Product(
          id: productData['id']?.toString() ?? '',
          name: productData['name']?.toString() ?? '',
          category:
              productData['category']?.toString() ?? '',
          price: productData['price'] ?? 0,
          stock: _toInt(
            productData['stock'],
          ),
          imageUrl:
              productData['imageUrl']?.toString() ?? '',
          description:
              productData['description']?.toString() ?? '',
          active: productData['active'] == true,
          mrp: productData['mrp'] ?? 0,
          discountPercent:
              productData['discountPercent'] ?? 0,
        );

        int quantity = _toInt(
          data['quantity'],
        );

        // --------------------------------------------------------
        // INVALID PRODUCT
        // --------------------------------------------------------

        if (product.id.trim().isEmpty) {
          continue;
        }

        // --------------------------------------------------------
        // INVALID / INACTIVE / OUT OF STOCK
        // --------------------------------------------------------

        if (!product.active) {
          continue;
        }

        if (product.stock <= 0) {
          continue;
        }

        // --------------------------------------------------------
        // QUANTITY VALIDATION
        // --------------------------------------------------------

        if (quantity <= 0) {
          quantity = 1;
        }

        if (quantity > product.stock) {
          quantity = product.stock;
        }

        items.add(
          CartItem(
            product: product,
            quantity: quantity,
          ),
        );
      }

      await _saveCart();
    } catch (_) {
      // Corrupted cart data should never crash the app.
      items.clear();
    }
  }

  // ============================================================
  // SAVE CART
  // ============================================================

  static Future<void> _saveCart() async {
    if (_preferences == null) {
      return;
    }

    try {
      final List<Map<String, dynamic>> data =
          items.map((item) {
        return {
          'product': {
            'id': item.product.id,
            'name': item.product.name,
            'category': item.product.category,
            'price': item.product.price,
            'stock': item.product.stock,
            'imageUrl': item.product.imageUrl,
            'description': item.product.description,
            'active': item.product.active,
            'mrp': item.product.mrp,
            'discountPercent':
                item.product.discountPercent,
          },
          'quantity': item.quantity,
        };
      }).toList();

      await _preferences!.setString(
        _storageKey,
        jsonEncode(data),
      );
    } catch (_) {
      // Ignore storage errors so cart actions don't crash UI.
    }
  }

  // ============================================================
  // ITEM COUNT
  // ============================================================

  static int get itemCount {
    int count = 0;

    for (final CartItem item in items) {
      count += item.quantity;
    }

    return count;
  }

  // ============================================================
  // TOTAL
  // ============================================================

  static double get total {
    double amount = 0;

    for (final CartItem item in items) {
      amount += item.totalPrice;
    }

    return amount;
  }

  // ============================================================
  // ORIGINAL TOTAL
  // ============================================================

  static double get originalTotal {
    double amount = 0;

    for (final CartItem item in items) {
      amount +=
          item.originalPrice * item.quantity;
    }

    return amount;
  }

  // ============================================================
  // PRODUCT SAVINGS
  // ============================================================

  static double get productSavings {
    final double savings =
        originalTotal - total;

    return savings < 0 ? 0 : savings;
  }

  // ============================================================
  // FIND ITEM
  // ============================================================

  static CartItem? findItem(String productId) {
    try {
      return items.firstWhere(
        (item) => item.product.id == productId,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // ADD PRODUCT
  // ============================================================

  static Future<bool> addProduct(
    Product product, {
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      return false;
    }

    if (!product.active) {
      return false;
    }

    if (product.stock <= 0) {
      return false;
    }

    final CartItem? existing =
        findItem(product.id);

    if (existing != null) {
      final int newQuantity =
          existing.quantity + quantity;

      if (newQuantity > product.stock) {
        existing.quantity = product.stock;
      } else {
        existing.quantity = newQuantity;
      }
    } else {
      final int safeQuantity =
          quantity > product.stock
              ? product.stock
              : quantity;

      items.add(
        CartItem(
          product: product,
          quantity: safeQuantity,
        ),
      );
    }

    await _saveCart();

    return true;
  }

  // ============================================================
  // INCREASE QUANTITY
  // ============================================================

  static Future<bool> increaseQuantity(
    String productId,
  ) async {
    final CartItem? item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (item.quantity >= item.availableStock) {
      return false;
    }

    item.quantity++;

    await _saveCart();

    return true;
  }

  // ============================================================
  // DECREASE QUANTITY
  // ============================================================

  static Future<bool> decreaseQuantity(
    String productId,
  ) async {
    final CartItem? item =
        findItem(productId);

    if (item == null) {
      return false;
    }

    if (item.quantity > 1) {
      item.quantity--;

      await _saveCart();

      return true;
    }

    return false;
  }

  // ============================================================
  // REMOVE PRODUCT
  // ============================================================

  static Future<void> removeProduct(
    String productId,
  ) async {
    items.removeWhere(
      (item) => item.product.id == productId,
    );

    await _saveCart();
  }

  // ============================================================
  // CLEAR CART
  // ============================================================

  static Future<void> clear() async {
    items.clear();

    await _saveCart();
  }

  // ============================================================
  // SAFE INT CONVERSION
  // ============================================================

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}
