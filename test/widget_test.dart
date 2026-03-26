import 'package:flutter_test/flutter_test.dart';
import 'package:kumarket/data/services/cart_service.dart';
import 'package:kumarket/data/services/products_service.dart';

void main() {
  group('CartService', () {
    late ProductsService productsService;
    late CartService cartService;

    setUp(() {
      productsService = ProductsService();
      cartService = CartService(productsService);
    });

    test('adds and removes product quantities', () {
      final product = productsService.products.first;

      cartService.add(product);
      cartService.add(product);
      expect(cartService.quantityOf(product.id), 2);
      expect(cartService.totalItems, 2);

      cartService.removeOne(product);
      expect(cartService.quantityOf(product.id), 1);
      expect(cartService.totalItems, 1);

      cartService.removeOne(product);
      expect(cartService.quantityOf(product.id), 0);
      expect(cartService.totalItems, 0);
    });

    test('calculates total with delivery', () {
      final product = productsService.products.first;
      cartService.add(product);

      expect(cartService.subtotal, product.price);
      expect(cartService.delivery, 1490);
      expect(cartService.total, product.price + 1490);
    });
  });
}
