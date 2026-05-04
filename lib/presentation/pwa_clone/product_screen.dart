import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';
import 'package:kumarket/presentation/pwa_clone/widgets/product_card_widget.dart';

class ProductScreen extends StatefulWidget {
  const ProductScreen({
    super.key,
    required this.routeId,
  });

  final String routeId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  static const int _relatedChunkSize = 10;

  final AppStore _app = AppStore.instance;
  final ScrollController _scrollController = ScrollController();
  ProductModel? _product;
  List<ProductModel> _related = <ProductModel>[];
  bool _loading = true;
  String _error = '';
  int _imageIndex = 0;
  String _selectedColor = '';
  String _selectedSize = '';
  int _visibleRelatedLimit = _relatedChunkSize;

  Color? _tryParseVariantColor(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return null;
    }

    final lower = value.toLowerCase();
    const named = <String, int>{
      'красный': 0xFFFF0000,
      'синий': 0xFF0000FF,
      'зеленый': 0xFF008000,
      'зелёный': 0xFF008000,
      'черный': 0xFF000000,
      'чёрный': 0xFF000000,
      'белый': 0xFFFFFFFF,
      'желтый': 0xFFFFFF00,
      'жёлтый': 0xFFFFFF00,
      'оранжевый': 0xFFFFA500,
      'фиолетовый': 0xFF800080,
      'розовый': 0xFFFFC0CB,
      'серый': 0xFF808080,
      'коричневый': 0xFFA52A2A,
      'голубой': 0xFF00FFFF,
      'бордовый': 0xFFB22222,
      'бежевый': 0xFFF5F5DC,
      'шоколадный': 0xFFD2691E,
      'серебристый': 0xFFC0C0C0,
      'золотой': 0xFFFFD700,
      'лавандовый': 0xFFE6E6FA,
      'салатовый': 0xFF90EE90,
      'red': 0xFFFF0000,
      'blue': 0xFF0000FF,
      'green': 0xFF008000,
      'black': 0xFF000000,
      'white': 0xFFFFFFFF,
      'yellow': 0xFFFFFF00,
      'orange': 0xFFFFA500,
      'purple': 0xFF800080,
      'pink': 0xFFFFC0CB,
      'gray': 0xFF808080,
      'grey': 0xFF808080,
      'brown': 0xFFA52A2A,
    };

    final namedValue = named[lower];
    if (namedValue != null) {
      return Color(namedValue);
    }

    String hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length == 3) {
      hex = '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length != 8) {
      return null;
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return null;
    }
    return Color(parsed);
  }

  bool _looksLikeHexColor(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty) {
      return false;
    }
    if (value.startsWith('#')) {
      final length = value.length;
      return length == 4 || length == 7 || length == 9;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    _app.cart.addListener(_rebuild);
    _app.favorites.addListener(_rebuild);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _app.cart.removeListener(_rebuild);
    _app.favorites.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 350) {
      return;
    }
    if (_visibleRelatedLimit >= _related.length) {
      return;
    }
    setState(() {
      _visibleRelatedLimit = min(
        _visibleRelatedLimit + _relatedChunkSize,
        _related.length,
      );
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
      _product = null;
      _related = <ProductModel>[];
      _selectedColor = '';
      _selectedSize = '';
      _visibleRelatedLimit = _relatedChunkSize;
    });

    try {
      final product = await _app.api.fetchProductByRouteId(widget.routeId);
      if (product == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Товар не найден';
        });
        return;
      }

      final related = await _app.api.fetchRelatedProducts(product: product);
      if (!mounted) {
        return;
      }

      final colorOptions = product.variants
          .map((variant) => variant.color.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final sizeOptions = product.variants
          .map((variant) => variant.size.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);

      setState(() {
        _product = product;
        _related = related;
        _selectedColor = colorOptions.isNotEmpty ? colorOptions.first : '';
        _selectedSize = sizeOptions.isNotEmpty ? sizeOptions.first : '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось загрузить товар';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  ProductVariantModel? get _selectedVariant {
    final product = _product;
    if (product == null || product.variants.isEmpty) {
      return null;
    }
    for (final variant in product.variants) {
      final colorMatches =
          _selectedColor.isEmpty || variant.color == _selectedColor;
      final sizeMatches =
          _selectedSize.isEmpty || variant.size == _selectedSize;
      if (colorMatches && sizeMatches) {
        return variant;
      }
    }
    return product.variants.first;
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null) {
      return;
    }
    final variant = _selectedVariant;
    final maxQty = variant?.quantity ?? product.stock;
    final ok = _app.cart.addProduct(
      product,
      color: _selectedColor.isEmpty ? null : _selectedColor,
      size: _selectedSize.isEmpty ? null : _selectedSize,
      variantId: variant?.id,
      maxQuantity: maxQty,
    );
    if (ok || !mounted) {
      return;
    }
    context.push(
        '/auth?redirect=${Uri.encodeComponent('/product/${product.routeId}')}');
  }

  List<ProductModel> get _visibleRelatedProducts {
    if (_related.isEmpty) {
      return _related;
    }
    final safeLimit = min(_visibleRelatedLimit, _related.length);
    return _related.take(safeLimit).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B2CF5)));
    }
    if (_error.isNotEmpty || _product == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error.isEmpty ? 'Товар не найден' : _error,
                style: const TextStyle(
                  color: Color(0xFF374151),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;
    final images = product.detailImages;
    final colors = product.variants
        .map((item) => item.color.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final sizes = product.variants
        .map((item) => item.size.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final isFavorite = _app.favorites.isFavorite(product.id);
    final selectedVariant = _selectedVariant;
    final inStock = selectedVariant?.inStock ?? true;
    final visibleRelated = _visibleRelatedProducts;

    return Container(
      color: const Color(0xFFF2F2F7),
      child: RefreshIndicator(
        color: const Color(0xFF7B2CF5),
        onRefresh: _load,
        child: ListView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x1F3C3C43)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF7B2CF5),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _app.favorites.toggleProduct(product),
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFavorite
                        ? const Color(0xFFFF3B30)
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: PageView.builder(
                itemCount: images.isEmpty ? 1 : images.length,
                onPageChanged: (value) => setState(() => _imageIndex = value),
                itemBuilder: (context, index) {
                  if (images.isEmpty || images[index].isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        size: 50,
                        color: Color(0xFF8C94AD),
                      ),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      images[index],
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 1024,
                      cacheHeight: 900,
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        if (wasSyncLoaded || frame != null) {
                          return child;
                        }
                        return Container(color: const Color(0xFFF2F2F7));
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF2F2F7),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (images.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (index) {
                    final active = _imageIndex == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: active ? 18 : 6,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF7B2CF5)
                            : const Color(0xFFD1D1D6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '${product.price.toStringAsFixed(0)} сом',
              style: const TextStyle(
                color: Color(0xFF7B2CF5),
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (product.oldPrice != null)
              Text(
                '${product.oldPrice!.toStringAsFixed(0)} сом',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            const SizedBox(height: 8),
            _RatingLine(
                rating: product.rating, reviewsCount: product.reviewsCount),
            const SizedBox(height: 12),
            if (sizes.isNotEmpty) ...[
              const Text(
                'Размер',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sizes.map((size) {
                  final active = _selectedSize == size;
                  return _ChoiceChip(
                    label: size,
                    active: active,
                    onTap: () => setState(() => _selectedSize = size),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
            ],
            if (colors.isNotEmpty) ...[
              const Text(
                'Цвет',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: colors.map((color) {
                  final active = _selectedColor == color;
                  return _ColorChoiceChip(
                    rawValue: color,
                    swatchColor: _tryParseVariantColor(color),
                    hideCodeLabel: _looksLikeHexColor(color),
                    active: active,
                    onTap: () => setState(() => _selectedColor = color),
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 12),
            ],
            if (product.description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1F3C3C43)),
                ),
                child: Text(
                  product.description,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: inStock ? _addToCart : null,
                icon:
                    const Icon(Icons.shopping_cart_checkout_rounded, size: 22),
                label: Text(
                  inStock ? 'Добавить в корзину' : 'Нет в наличии',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2CF5),
                  disabledBackgroundColor: const Color(0xFF9CA3AF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            if (_related.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Товары из этой категории',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                itemCount: visibleRelated.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) {
                  final related = visibleRelated[index];
                  return ProductCardWidget(
                    product: related,
                    isFavorite: _app.favorites.isFavorite(related.id),
                    onOpen: () => context.push('/product/${related.routeId}'),
                    onToggleFavorite: () =>
                        _app.favorites.toggleProduct(related),
                    onAddToCart: () async {
                      final added = _app.cart
                          .addProduct(related, maxQuantity: related.stock);
                      if (!added && mounted) {
                        context.push(
                            '/auth?redirect=${Uri.encodeComponent('/product/${related.routeId}')}');
                      }
                    },
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF3E8FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF7B2CF5) : const Color(0x1F3C3C43),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF7B2CF5) : const Color(0xFF374151),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ColorChoiceChip extends StatelessWidget {
  const _ColorChoiceChip({
    required this.rawValue,
    required this.swatchColor,
    required this.hideCodeLabel,
    required this.active,
    required this.onTap,
  });

  final String rawValue;
  final Color? swatchColor;
  final bool hideCodeLabel;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showLabel = !hideCodeLabel;
    final effectiveColor = swatchColor ?? const Color(0xFFE5E7EB);
    final swatchNeedsBorder = effectiveColor.computeLuminance() > 0.86;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: showLabel ? 12 : 8,
          vertical: showLabel ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFF3E8FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF7B2CF5) : const Color(0x1F3C3C43),
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: showLabel ? 18 : 24,
              height: showLabel ? 18 : 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveColor,
                border: Border.all(
                  color: swatchNeedsBorder
                      ? const Color(0x4D111827)
                      : Colors.transparent,
                ),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Text(
                rawValue,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF7B2CF5)
                      : const Color(0xFF374151),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({
    required this.rating,
    required this.reviewsCount,
  });

  final double rating;
  final int reviewsCount;

  @override
  Widget build(BuildContext context) {
    final stars = rating.round().clamp(0, 5);
    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            Icons.star_rounded,
            size: 18,
            color: index < stars
                ? const Color(0xFFFFC107)
                : const Color(0xFFD1D1D6),
          );
        }),
        const SizedBox(width: 8),
        Text(
          '$reviewsCount отзывов',
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
