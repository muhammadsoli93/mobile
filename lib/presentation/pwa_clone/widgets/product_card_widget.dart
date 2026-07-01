import 'package:flutter/material.dart';
import 'package:kumarket/app_core/models.dart';

class ProductCardWidget extends StatelessWidget {
  const ProductCardWidget({
    super.key,
    required this.product,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggleFavorite,
    required this.onAddToCart,
  });

  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final stars = product.rating.round().clamp(0, 5);
    final catalogImage = product.catalogImage;

    Widget buildImagePlaceholder() {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: const Icon(
          Icons.shopping_bag_outlined,
          color: Color(0xFF8C94AD),
          size: 34,
        ),
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1F3C3C43)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        child: catalogImage.isEmpty
                            ? buildImagePlaceholder()
                            : Image.network(
                                catalogImage,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                cacheWidth: 320,
                                cacheHeight: 320,
                                gaplessPlayback: true,
                                frameBuilder:
                                    (context, child, frame, wasSyncLoaded) {
                                  if (wasSyncLoaded || frame != null) {
                                    return child;
                                  }
                                  return buildImagePlaceholder();
                                },
                                errorBuilder: (_, __, ___) =>
                                    buildImagePlaceholder(),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0x1F3C3C43)),
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 18,
                            color: isFavorite
                                ? const Color(0xFFFF3B30)
                                : const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Column(
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: index < stars
                              ? const Color(0xFFFFC107)
                              : const Color(0xFFD1D1D6),
                        );
                      }),
                    ),
                    if (product.reviewsCount > 0)
                      Text(
                        '${product.reviewsCount}',
                        style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      '${product.price.toStringAsFixed(0)} сом',
                      style: const TextStyle(
                        color: Color(0xFF7B2CF5),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.oldPrice != null &&
                        product.oldPrice! > product.price)
                      Text(
                        '${product.oldPrice!.toStringAsFixed(0)} сом',
                        style: const TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onAddToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2CF5),
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('В корзину'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
