import 'package:flutter/material.dart';
import 'package:kumarket/data/models/product.dart';
import 'package:kumarket/data/services/products_service.dart';

final class CartLine {
  const CartLine({
    required this.product,
    required this.quantity,
  });

  final Product product;
  final int quantity;

  double get total => product.price * quantity;
}

final class CartService extends ChangeNotifier {
  CartService(this._productsService);

  final ProductsService _productsService;
  final Map<String, int> _items = <String, int>{};

  int quantityOf(String productId) => _items[productId] ?? 0;

  int get totalItems => _items.values.fold<int>(0, (sum, item) => sum + item);

  bool get isEmpty => _items.isEmpty;

  List<CartLine> get lines {
    final result = <CartLine>[];
    _items.forEach((productId, quantity) {
      final product = _productsService.byId(productId);
      if (product != null) {
        result.add(CartLine(product: product, quantity: quantity));
      }
    });
    return result;
  }

  double get subtotal => lines.fold<double>(0, (sum, line) => sum + line.total);

  double get delivery => isEmpty ? 0 : 1490;

  double get total => subtotal + delivery;

  void add(Product product) {
    _items.update(product.id, (value) => value + 1, ifAbsent: () => 1);
    notifyListeners();
  }

  void removeOne(Product product) {
    final currentQuantity = _items[product.id];
    if (currentQuantity == null) {
      return;
    }
    if (currentQuantity <= 1) {
      _items.remove(product.id);
    } else {
      _items[product.id] = currentQuantity - 1;
    }
    notifyListeners();
  }

  void removeAll(String productId) {
    if (_items.remove(productId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    if (_items.isEmpty) {
      return;
    }
    _items.clear();
    notifyListeners();
  }
}
