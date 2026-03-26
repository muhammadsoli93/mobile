import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/core/functions/price_formatter.dart';
import 'package:kumarket/core/functions/setup_dependencies.dart';
import 'package:kumarket/data/models/product.dart';
import 'package:kumarket/data/services/cart_service.dart';
import 'package:kumarket/data/services/products_service.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final productsService = sl<ProductsService>();
    final cartService = sl<CartService>();

    return SafeArea(
      child: AnimatedBuilder(
        animation: cartService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text(
                'Категории',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 14),
              ...ProductCategory.values.map((category) {
                final products = productsService.byCategory(category);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.hexFFFFFF,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      category.label,
                      style: AppTextStyles.title,
                    ),
                    children: products
                        .map(
                          (product) => _CategoryProductTile(
                            product: product,
                            quantity: cartService.quantityOf(product.id),
                            onAdd: () => cartService.add(product),
                            onRemove: () => cartService.removeOne(product),
                          ),
                        )
                        .toList(growable: false),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryProductTile extends StatelessWidget {
  const _CategoryProductTile({
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.hexFFFFFF,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.s14w400h000000.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatPrice(product.price),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.hex000000,
                  ),
                ),
              ],
            ),
          ),
          if (quantity == 0)
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Добавить'),
            )
          else
            Row(
              children: [
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text(
                  '$quantity',
                  style: AppTextStyles.s14w400h000000.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
