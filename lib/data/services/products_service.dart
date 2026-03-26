import 'package:kumarket/data/models/product.dart';

final class ProductsService {
  final List<Product> _products = const [
    Product(
      id: 'p1',
      name: 'Беспроводные наушники X8',
      description: 'Шумоподавление, до 30 часов работы',
      price: 18990,
      oldPrice: 21990,
      rating: 4.8,
      category: ProductCategory.electronics,
      isPopular: true,
    ),
    Product(
      id: 'p2',
      name: 'Увлажнитель воздуха Mini',
      description: 'Тихий режим и ночная подсветка',
      price: 12990,
      rating: 4.6,
      category: ProductCategory.home,
      isPopular: true,
    ),
    Product(
      id: 'p3',
      name: 'Худи Oversize',
      description: 'Плотный хлопок, унисекс',
      price: 15990,
      oldPrice: 17990,
      rating: 4.7,
      category: ProductCategory.clothes,
      isPopular: true,
    ),
    Product(
      id: 'p4',
      name: 'Сыворотка Vitamin C',
      description: 'Осветляет тон и выравнивает рельеф',
      price: 8990,
      rating: 4.9,
      category: ProductCategory.beauty,
      isPopular: true,
    ),
    Product(
      id: 'p5',
      name: 'Конструктор Space Lab',
      description: '146 деталей, 8+',
      price: 10490,
      rating: 4.8,
      category: ProductCategory.kids,
      isPopular: false,
    ),
    Product(
      id: 'p6',
      name: 'Смарт-часы Fit Pro',
      description: 'Пульс, сон, GPS, водозащита',
      price: 24990,
      oldPrice: 27990,
      rating: 4.7,
      category: ProductCategory.electronics,
    ),
    Product(
      id: 'p7',
      name: 'Набор контейнеров 12 шт',
      description: 'Герметичные крышки, BPA free',
      price: 7990,
      rating: 4.5,
      category: ProductCategory.home,
    ),
    Product(
      id: 'p8',
      name: 'Кроссовки Urban Run',
      description: 'Легкая подошва и дышащий верх',
      price: 28990,
      rating: 4.6,
      category: ProductCategory.clothes,
    ),
    Product(
      id: 'p9',
      name: 'Фен Ionic Air',
      description: '3 режима, концентратор в комплекте',
      price: 20990,
      rating: 4.7,
      category: ProductCategory.beauty,
    ),
    Product(
      id: 'p10',
      name: 'Детский рюкзак Dino',
      description: 'Легкий и водоотталкивающий',
      price: 6990,
      rating: 4.8,
      category: ProductCategory.kids,
    ),
  ];

  List<Product> get products => List.unmodifiable(_products);

  List<Product> get popularProducts =>
      _products.where((product) => product.isPopular).toList(growable: false);

  List<Product> byCategory(ProductCategory? category) {
    if (category == null) {
      return products;
    }
    return _products
        .where((product) => product.category == category)
        .toList(growable: false);
  }

  List<Product> search({
    String query = '',
    ProductCategory? category,
  }) {
    final lowerQuery = query.trim().toLowerCase();
    return _products.where((product) {
      final categoryMatched = category == null || product.category == category;
      if (!categoryMatched) {
        return false;
      }
      if (lowerQuery.isEmpty) {
        return true;
      }
      return product.name.toLowerCase().contains(lowerQuery) ||
          product.description.toLowerCase().contains(lowerQuery);
    }).toList(growable: false);
  }

  Product? byId(String id) {
    for (final product in _products) {
      if (product.id == id) {
        return product;
      }
    }
    return null;
  }

  Map<ProductCategory, int> categoryCount() {
    final counts = <ProductCategory, int>{};
    for (final category in ProductCategory.values) {
      counts[category] = _products.where((p) => p.category == category).length;
    }
    return counts;
  }
}
