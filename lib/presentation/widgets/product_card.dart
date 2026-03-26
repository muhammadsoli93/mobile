import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/core/functions/price_formatter.dart';
import 'package:kumarket/data/models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: _gradientForCategory(product.category),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.hexFFFFFF.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${product.rating} ★',
                          style: AppTextStyles.s12w600h000000,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        product.name.split(' ').first,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.hexFFFFFF,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.s16w600h000000,
            ),
            const SizedBox(height: 4),
            Text(
              product.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.s12w400hB2B2B2,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  formatPrice(product.price),
                  style: AppTextStyles.s16w600h000000,
                ),
                const SizedBox(width: 8),
                if (product.oldPrice != null)
                  Text(
                    formatPrice(product.oldPrice!),
                    style: const TextStyle(
                      color: AppColors.hex99A6B8,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (quantity == 0)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('В корзину'),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: AppColors.hexF3F3F3,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Text(
                      '$quantity',
                      style: AppTextStyles.s16w600h000000,
                    ),
                    IconButton(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  LinearGradient _gradientForCategory(ProductCategory category) {
    switch (category) {
      case ProductCategory.electronics:
        return const LinearGradient(
          colors: [Color(0xFF1459E5), Color(0xFF4D8DFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ProductCategory.home:
        return const LinearGradient(
          colors: [Color(0xFF34A853), Color(0xFF75C977)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ProductCategory.clothes:
        return const LinearGradient(
          colors: [Color(0xFF9C4CCF), Color(0xFFDA78FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ProductCategory.beauty:
        return const LinearGradient(
          colors: [Color(0xFFE96085), Color(0xFFF8A9C3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case ProductCategory.kids:
        return const LinearGradient(
          colors: [Color(0xFFF59F1A), Color(0xFFF9D976)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }
}
