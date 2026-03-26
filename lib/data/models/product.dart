enum ProductCategory {
  electronics,
  home,
  clothes,
  beauty,
  kids,
}

extension ProductCategoryX on ProductCategory {
  String get label {
    switch (this) {
      case ProductCategory.electronics:
        return 'Электроника';
      case ProductCategory.home:
        return 'Дом';
      case ProductCategory.clothes:
        return 'Одежда';
      case ProductCategory.beauty:
        return 'Красота';
      case ProductCategory.kids:
        return 'Детям';
    }
  }
}

final class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.category,
    this.oldPrice,
    this.isPopular = false,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final double rating;
  final ProductCategory category;
  final bool isPopular;
}
