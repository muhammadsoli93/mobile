import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';
import 'package:kumarket/presentation/pwa_clone/widgets/product_card_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const int _recommendationsPerCategoryBatch = 3;
  static const int _recommendationsChunkSize = 10;
  static const int _recommendationsMaxItems = 100;

  final AppStore _app = AppStore.instance;
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  int _recommendationsRequestVersion = 0;

  List<CategoryModel> _recommendationCategories = <CategoryModel>[];
  List<ProductModel> _recommendationProducts = <ProductModel>[];
  final Map<String, int?> _nextPagesByCategory = <String, int?>{};
  final Map<String, bool> _hasMoreByCategory = <String, bool>{};

  bool _recommendationsLoading = true;
  bool _recommendationsLoadingMore = false;
  bool _recommendationsHasMore = true;
  int _visibleRecommendationsLimit = _recommendationsChunkSize;

  @override
  void initState() {
    super.initState();
    _app.cart.addListener(_rebuild);
    _app.favorites.addListener(_rebuild);
    _scrollController.addListener(_onScroll);
    unawaited(_loadRecommendationsInitial());
  }

  @override
  void dispose() {
    _app.cart.removeListener(_rebuild);
    _app.favorites.removeListener(_rebuild);
    _scrollController.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _isRecommendationsRequestStale(int requestVersion) {
    return !mounted || requestVersion != _recommendationsRequestVersion;
  }

  Future<void> _loadRecommendationsInitial() async {
    final requestVersion = ++_recommendationsRequestVersion;
    setState(() {
      _recommendationsLoading = true;
      _recommendationsLoadingMore = false;
      _recommendationsHasMore = true;
      _visibleRecommendationsLimit = _recommendationsChunkSize;
      _recommendationProducts = <ProductModel>[];
      _recommendationCategories = <CategoryModel>[];
      _nextPagesByCategory.clear();
      _hasMoreByCategory.clear();
    });

    try {
      final categories = await _app.api.fetchCategories();
      if (_isRecommendationsRequestStale(requestVersion)) {
        return;
      }

      final sourceCategories = categories
          .where((category) => category.id.trim().isNotEmpty)
          .toList(growable: false);

      if (sourceCategories.isEmpty) {
        setState(() {
          _recommendationCategories = categories;
          _recommendationProducts = <ProductModel>[];
          _recommendationsHasMore = false;
        });
        return;
      }

      final firstPages = await Future.wait<PaginatedProducts>(
        sourceCategories
            .map(
              (category) => _app.api
                  .fetchProducts(page: 1, categoryId: category.id)
                  .catchError(
                    (_) => const PaginatedProducts(
                      results: <ProductModel>[],
                      nextPage: null,
                      hasMore: false,
                    ),
                  ),
            )
            .toList(growable: false),
      );

      if (_isRecommendationsRequestStale(requestVersion)) {
        return;
      }

      final seenIds = <String>{};
      final products = <ProductModel>[];
      final nextPages = <String, int?>{};
      final hasMore = <String, bool>{};

      for (int index = 0; index < sourceCategories.length; index += 1) {
        final category = sourceCategories[index];
        final page = firstPages[index];
        nextPages[category.id] = page.nextPage;
        hasMore[category.id] = page.hasMore;

        final shuffled = <ProductModel>[...page.results]..shuffle(_random);
        int addedForCategory = 0;
        for (final product in shuffled) {
          if (addedForCategory >= _recommendationsPerCategoryBatch) {
            break;
          }
          if (product.id.trim().isEmpty) {
            continue;
          }
          if (!seenIds.add(product.id)) {
            continue;
          }
          products.add(product);
          addedForCategory += 1;
        }
      }

      final limitedProducts =
          products.take(_recommendationsMaxItems).toList(growable: false);

      setState(() {
        _recommendationCategories = categories;
        _recommendationProducts = limitedProducts;
        _nextPagesByCategory
          ..clear()
          ..addAll(nextPages);
        _hasMoreByCategory
          ..clear()
          ..addAll(hasMore);
        _recommendationsHasMore = hasMore.values.any((value) => value) &&
            limitedProducts.length < _recommendationsMaxItems;
      });
    } catch (_) {
      if (_isRecommendationsRequestStale(requestVersion)) {
        return;
      }
      setState(() {
        _recommendationCategories = <CategoryModel>[];
        _recommendationProducts = <ProductModel>[];
        _recommendationsHasMore = false;
      });
    } finally {
      if (!_isRecommendationsRequestStale(requestVersion)) {
        setState(() {
          _recommendationsLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreRecommendations() async {
    if (_recommendationsLoading ||
        _recommendationsLoadingMore ||
        !_recommendationsHasMore) {
      return;
    }
    if (_recommendationProducts.length >= _recommendationsMaxItems) {
      setState(() {
        _recommendationsHasMore = false;
      });
      return;
    }

    final requestVersion = _recommendationsRequestVersion;
    final categoriesToFetch = _recommendationCategories.where((category) {
      final key = category.id.trim();
      if (key.isEmpty) {
        return false;
      }
      final page = _nextPagesByCategory[key];
      final hasMore = _hasMoreByCategory[key] ?? false;
      return hasMore && page != null && page > 0;
    }).toList(growable: false);

    if (categoriesToFetch.isEmpty) {
      setState(() {
        _recommendationsHasMore = false;
      });
      return;
    }

    setState(() {
      _recommendationsLoadingMore = true;
    });

    try {
      final fetchedPages = await Future.wait<PaginatedProducts>(
        categoriesToFetch.map((category) {
          final page = _nextPagesByCategory[category.id];
          if (page == null || page <= 0) {
            return Future<PaginatedProducts>.value(
              const PaginatedProducts(
                results: <ProductModel>[],
                nextPage: null,
                hasMore: false,
              ),
            );
          }
          return _app.api
              .fetchProducts(page: page, categoryId: category.id)
              .catchError(
                (_) => const PaginatedProducts(
                  results: <ProductModel>[],
                  nextPage: null,
                  hasMore: false,
                ),
              );
        }).toList(growable: false),
      );

      if (_isRecommendationsRequestStale(requestVersion)) {
        return;
      }

      final seenIds = _recommendationProducts.map((item) => item.id).toSet();
      final appended = <ProductModel>[];
      final nextPages = <String, int?>{};
      final hasMore = <String, bool>{};

      for (int index = 0; index < categoriesToFetch.length; index += 1) {
        final category = categoriesToFetch[index];
        final page = fetchedPages[index];
        nextPages[category.id] = page.nextPage;
        hasMore[category.id] = page.hasMore;

        final shuffled = <ProductModel>[...page.results]..shuffle(_random);
        int addedForCategory = 0;
        for (final product in shuffled) {
          if (addedForCategory >= _recommendationsPerCategoryBatch) {
            break;
          }
          if (product.id.trim().isEmpty) {
            continue;
          }
          if (!seenIds.add(product.id)) {
            continue;
          }
          appended.add(product);
          addedForCategory += 1;
        }
      }

      final merged = <ProductModel>[
        ..._recommendationProducts,
        ...appended,
      ];
      final limited =
          merged.take(_recommendationsMaxItems).toList(growable: false);

      _nextPagesByCategory.addAll(nextPages);
      _hasMoreByCategory.addAll(hasMore);
      final hasMoreAny = _hasMoreByCategory.values.any((value) => value) &&
          limited.length < _recommendationsMaxItems;

      setState(() {
        _recommendationProducts = limited;
        _recommendationsHasMore = hasMoreAny;
      });
    } catch (_) {
      if (_isRecommendationsRequestStale(requestVersion)) {
        return;
      }
      setState(() {
        _recommendationsHasMore = false;
      });
    } finally {
      if (!_isRecommendationsRequestStale(requestVersion)) {
        setState(() {
          _recommendationsLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 450) {
      return;
    }

    final ordered = _orderedRecommendationProducts;
    if (_visibleRecommendationsLimit < ordered.length) {
      setState(() {
        _visibleRecommendationsLimit = min(
          _visibleRecommendationsLimit + _recommendationsChunkSize,
          ordered.length,
        );
      });
      return;
    }

    unawaited(_loadMoreRecommendations());
  }

  String _normalizeCategoryKey(String value) {
    return value.trim().toLowerCase();
  }

  String _categoryKeyFromProduct(ProductModel product) {
    final byName = _normalizeCategoryKey(product.categoryName);
    if (byName.isNotEmpty) {
      return byName;
    }
    final byId = _normalizeCategoryKey(product.categoryId);
    if (byId.isNotEmpty) {
      return byId;
    }
    return 'unknown';
  }

  String _categoryKeyFromCategory(CategoryModel category) {
    final byName = _normalizeCategoryKey(category.name);
    if (byName.isNotEmpty) {
      return byName;
    }
    final byId = _normalizeCategoryKey(category.id);
    if (byId.isNotEmpty) {
      return byId;
    }
    return '';
  }

  List<ProductModel> _mixByCategoryCycle(List<ProductModel> source) {
    if (source.length <= 1) {
      return source;
    }

    final grouped = <String, List<ProductModel>>{};
    for (final product in source) {
      final key = _categoryKeyFromProduct(product);
      grouped.putIfAbsent(key, () => <ProductModel>[]).add(product);
    }
    if (grouped.length <= 1) {
      return source;
    }

    final orderedKeys = <String>[];
    for (final category in _recommendationCategories) {
      final key = _categoryKeyFromCategory(category);
      if (key.isNotEmpty &&
          grouped.containsKey(key) &&
          !orderedKeys.contains(key)) {
        orderedKeys.add(key);
      }
    }
    for (final product in source) {
      final key = _categoryKeyFromProduct(product);
      if (!orderedKeys.contains(key)) {
        orderedKeys.add(key);
      }
    }

    final offsets = <String, int>{
      for (final key in orderedKeys) key: 0,
    };
    final mixed = <ProductModel>[];

    bool added = true;
    while (added && mixed.length < _recommendationsMaxItems) {
      added = false;
      for (final key in orderedKeys) {
        final items = grouped[key];
        if (items == null || items.isEmpty) {
          continue;
        }
        final start = offsets[key] ?? 0;
        if (start >= items.length) {
          continue;
        }
        final end = min(
          start + _recommendationsPerCategoryBatch,
          items.length,
        );
        mixed.addAll(items.sublist(start, end));
        offsets[key] = end;
        added = true;
        if (mixed.length >= _recommendationsMaxItems) {
          break;
        }
      }
    }

    return mixed.take(_recommendationsMaxItems).toList(growable: false);
  }

  List<ProductModel> get _orderedRecommendationProducts {
    return _mixByCategoryCycle(_recommendationProducts);
  }

  List<ProductModel> get _visibleRecommendationProducts {
    final ordered = _orderedRecommendationProducts;
    if (ordered.isEmpty) {
      return ordered;
    }
    final safeLimit = max(
      _recommendationsChunkSize,
      min(_visibleRecommendationsLimit, ordered.length),
    );
    return ordered.take(safeLimit).toList(growable: false);
  }

  Future<void> _onAddToCart(ProductModel product) async {
    ProductVariantModel? variant;
    for (final candidate in product.variants) {
      if (candidate.id.trim().isNotEmpty && candidate.inStock) {
        variant = candidate;
        break;
      }
    }
    variant ??= product.variants.isNotEmpty ? product.variants.first : null;

    if (variant == null || variant.id.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Откройте карточку товара и выберите вариант.'),
        ),
      );
      return;
    }

    final ok = _app.cart.addProduct(
      product,
      maxQuantity: variant.quantity ?? product.stock,
      variantId: variant.id,
      color: variant.color.trim().isEmpty ? null : variant.color,
      size: variant.size.trim().isEmpty ? null : variant.size,
    );
    if (ok || !mounted) {
      return;
    }
    context.push('/auth?redirect=${Uri.encodeComponent('/cart')}');
  }

  @override
  Widget build(BuildContext context) {
    final items = _app.cart.items;
    if (items.isEmpty) {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 54,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Корзина пуста',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Добавьте товары из каталога.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () => context.go('/catalog'),
                  child: const Text('Перейти в каталог'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF2F2F7),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Корзина',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _app.cart.clear,
                child: const Text('Очистить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _CartLineTile(item: item)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x1F3C3C43)),
            ),
            child: Column(
              children: [
                _SummaryRow(
                  title: 'Товары',
                  value: '${_app.cart.count} шт',
                ),
                const SizedBox(height: 6),
                _SummaryRow(
                  title: 'Сумма',
                  value: '${_app.cart.total.toStringAsFixed(0)} сом',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => context.push('/checkout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CF5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: const Text('Оформить заказ'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _CartSectionTitle(
            title: 'Товары для вас',
            icon: Icons.local_fire_department_rounded,
          ),
          const SizedBox(height: 8),
          if (_recommendationsLoading)
            const _RecommendationsSkeleton()
          else if (_orderedRecommendationProducts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F3C3C43)),
              ),
              child: const Text(
                'Пока нет рекомендаций',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            GridView.builder(
              itemCount: _visibleRecommendationProducts.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, index) {
                final product = _visibleRecommendationProducts[index];
                return ProductCardWidget(
                  product: product,
                  isFavorite: _app.favorites.isFavorite(product.id),
                  onOpen: () => context.push('/product/${product.routeId}'),
                  onToggleFavorite: () => _app.favorites.toggleProduct(product),
                  onAddToCart: () => _onAddToCart(product),
                );
              },
            ),
            const SizedBox(height: 8),
            if (_recommendationsLoadingMore)
              const Text(
                'Загружаем еще товары...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8B92A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (_visibleRecommendationProducts.length >=
                    _orderedRecommendationProducts.length &&
                !_recommendationsHasMore)
              const Text(
                'Показаны все рекомендации',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8B92A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.item,
  });

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = AppStore.instance.cart;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1F3C3C43)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 74,
              height: 74,
              child: item.image.isEmpty
                  ? Container(color: const Color(0xFFF2F2F7))
                  : Image.network(
                      normalizeImageUrl(item.image),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 128,
                      cacheHeight: 128,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFFF2F2F7)),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toStringAsFixed(0)} сом',
                  style: const TextStyle(
                    color: Color(0xFF7B2CF5),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _QtyButton(
                      icon: Icons.remove_rounded,
                      onTap: () =>
                          cart.setItemQuantity(item.itemId, item.quantity - 1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _QtyButton(
                      icon: Icons.add_rounded,
                      onTap: () =>
                          cart.setItemQuantity(item.itemId, item.quantity + 1),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => cart.removeItem(item.itemId),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFFF3B30),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CartSectionTitle extends StatelessWidget {
  const _CartSectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF7B2CF5), size: 20),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _RecommendationsSkeleton extends StatelessWidget {
  const _RecommendationsSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.58,
      ),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x1F3C3C43)),
          ),
        );
      },
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.logoAssetPath,
    this.icon = Icons.account_balance_wallet_rounded,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? logoAssetPath;
  final IconData icon;
  final bool enabled;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const List<_PaymentMethodOption> _paymentMethods =
      <_PaymentMethodOption>[
    _PaymentMethodOption(
      id: 'mbank',
      title: 'MBank',
      subtitle: 'Оплата через приложение MBank',
      logoAssetPath: 'assets/images/payment_mbank.png',
      icon: Icons.account_balance_wallet_rounded,
      enabled: true,
    ),
  ];

  static const String _mbankDeeplinkBase = String.fromEnvironment(
    'MBANK_DEEPLINK_BASE',
    defaultValue: 'https://app.mbank.kg/deeplink',
  );
  static const String _mbankServiceId = String.fromEnvironment(
    'MBANK_SERVICE_ID',
    defaultValue: '90bad204-49b7-45fd-8e2f-74d981230673',
  );
  static const bool _mbankTestMode = bool.fromEnvironment(
    'MBANK_TEST_MODE',
    defaultValue: false,
  );
  // Legacy parameter name kept for backward compatibility.
  static const String _mbankDeeplinkService = String.fromEnvironment(
    'MBANK_DEEPLINK_SERVICE',
  );

  final AppStore _app = AppStore.instance;
  late String _selectedPaymentMethod;
  String _error = '';
  bool _submitting = false;

  List<_PaymentMethodOption> get _enabledPaymentMethods {
    return _paymentMethods
        .where((method) => method.enabled)
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    final enabledMethods = _enabledPaymentMethods;
    _selectedPaymentMethod = enabledMethods.isNotEmpty
        ? enabledMethods.first.id
        : _paymentMethods.first.id;
    _app.auth.addListener(_rebuild);
    _app.cart.addListener(_rebuild);
  }

  @override
  void dispose() {
    _app.auth.removeListener(_rebuild);
    _app.cart.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  String _resolveAccount(CustomerOrder? order) {
    if (order == null) {
      return '';
    }
    final id = order.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    return order.number.trim();
  }

  Uri? _buildMbankDeeplink(CustomerOrder? order) {
    final service = _mbankServiceId.trim().isNotEmpty
        ? _mbankServiceId.trim()
        : _mbankDeeplinkService.trim();
    if (service.isEmpty) {
      return null;
    }

    final base = Uri.tryParse(_mbankDeeplinkBase);
    if (base == null || !base.hasScheme) {
      return null;
    }

    final query = <String, String>{
      ...base.queryParameters,
      'service': service,
    };

    final account = _resolveAccount(order);
    if (account.isNotEmpty) {
      query['PARAM1'] = account;
      // Legacy compatibility for providers that still read `account`.
      query['account'] = account;
    }

    final amount = order?.totalPrice ?? _app.cart.total;
    if (amount > 0) {
      query['amount'] = amount.toStringAsFixed(2);
    }
    if (_mbankTestMode) {
      query['test_mode'] = '1';
    }

    return base.replace(queryParameters: query);
  }

  Future<bool> _openMbankDeeplink(CustomerOrder? order) async {
    final deeplink = _buildMbankDeeplink(order);
    if (deeplink == null) {
      return false;
    }
    try {
      return await launchUrl(
        deeplink,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openSelectedPaymentMethod(CustomerOrder? order) {
    switch (_selectedPaymentMethod) {
      case 'mbank':
        return _openMbankDeeplink(order);
      default:
        return Future<bool>.value(false);
    }
  }

  void _createOrder() {
    if (_submitting) {
      return;
    }
    unawaited(_createOrderAsync());
  }

  Future<void> _createOrderAsync() async {
    final user = _app.auth.user;
    if (user == null) {
      context.push('/auth?redirect=${Uri.encodeComponent('/checkout')}');
      return;
    }
    if (_selectedPaymentMethod.trim().isEmpty) {
      setState(() {
        _error = 'Выберите способ оплаты.';
      });
      return;
    }
    setState(() {
      _error = '';
      _submitting = true;
    });
    final result = await _app.orders.createOrder(_selectedPaymentMethod);
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      setState(() {
        _error = result.message;
        _submitting = false;
      });
      return;
    }
    final launched = await _openSelectedPaymentMethod(result.order);
    if (!mounted) {
      return;
    }
    if (!launched) {
      final bool hasService = _mbankServiceId.trim().isNotEmpty ||
          _mbankDeeplinkService.trim().isNotEmpty;
      final String fallbackMessage = _selectedPaymentMethod == 'mbank'
          ? hasService
              ? 'Заказ создан, но MBank не открылся автоматически. Проверьте установку приложения MBank.'
              : 'Заказ создан. Для автозапуска оплаты задайте MBANK_SERVICE_ID (или MBANK_DEEPLINK_SERVICE).'
          : 'Заказ создан. Перенаправление в выбранный способ оплаты временно недоступно.';
      final snackBar = SnackBar(content: Text(fallbackMessage));
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
    setState(() => _submitting = false);
    context.go('/orders?created=1');
  }

  @override
  Widget build(BuildContext context) {
    final items = _app.cart.items;
    final paymentMethods = _enabledPaymentMethods;
    if (items.isEmpty) {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'В корзине нет товаров',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => context.go('/catalog'),
                  child: const Text('Вернуться в каталог'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF2F2F7),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          const Text(
            'Оформление заказа',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7B2CF5)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF7B2CF5),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'После оформления заказа откроется MBANK Payments Deeplink с параметрами service, PARAM1 (номер заказа) и amount.',
                    style: TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x1F3C3C43)),
            ),
            child: Column(
              children: [
                _SummaryRow(title: 'Товары', value: '${_app.cart.count} шт'),
                const SizedBox(height: 6),
                _SummaryRow(
                  title: 'Итого',
                  value: '${_app.cart.total.toStringAsFixed(0)} сом',
                ),
              ],
            ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFBE123C),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Тип оплаты',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (paymentMethods.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x1F3C3C43)),
              ),
              child: const Text(
                'Нет доступных способов оплаты.',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            GridView.builder(
              itemCount: paymentMethods.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.08,
              ),
              itemBuilder: (context, index) {
                final method = paymentMethods[index];
                final isSelected = method.id == _selectedPaymentMethod;
                return _PaymentMethodTile(
                  method: method,
                  selected: isSelected,
                  disabled: _submitting,
                  onTap: () {
                    if (_submitting) {
                      return;
                    }
                    setState(() {
                      _selectedPaymentMethod = method.id;
                    });
                  },
                );
              },
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _submitting || paymentMethods.isEmpty ? null : _createOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CF5),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Продолжить оформление',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final _PaymentMethodOption method;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFF7B2CF5) : const Color(0x1F3C3C43),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x1A7B2CF5),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: method.logoAssetPath == null
                    ? Icon(
                        method.icon,
                        color: const Color(0xFF059669),
                        size: 30,
                      )
                    : Padding(
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          method.logoAssetPath!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              method.icon,
                              color: const Color(0xFF059669),
                              size: 30,
                            );
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                method.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
