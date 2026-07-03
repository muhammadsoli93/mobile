import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';
import 'package:kumarket/presentation/pwa_clone/pwa_shell.dart';
import 'package:kumarket/presentation/pwa_clone/widgets/product_card_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductsFeedScreen(
      showHero: true,
      showFavorites: true,
      initialCategoryId: null,
      redirectPath: '/',
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.initialCategoryId,
  });

  final String? initialCategoryId;

  @override
  Widget build(BuildContext context) {
    return ProductsFeedScreen(
      showHero: false,
      showFavorites: false,
      initialCategoryId: initialCategoryId,
      redirectPath: initialCategoryId == null
          ? '/catalog'
          : '/catalog?category=${Uri.encodeComponent(initialCategoryId!)}',
    );
  }
}

class ProductsFeedScreen extends StatefulWidget {
  const ProductsFeedScreen({
    super.key,
    required this.showHero,
    required this.showFavorites,
    required this.initialCategoryId,
    required this.redirectPath,
  });

  final bool showHero;
  final bool showFavorites;
  final String? initialCategoryId;
  final String redirectPath;

  @override
  State<ProductsFeedScreen> createState() => _ProductsFeedScreenState();
}

class _ProductsFeedCache {
  const _ProductsFeedCache({
    required this.products,
    required this.categories,
    required this.selectedCategoryId,
    required this.hasMore,
    required this.nextPage,
    required this.visibleProductsLimit,
    required this.allModeNextPagesByCategory,
    required this.allModeHasMoreByCategory,
    required this.allModeGeneralNextPage,
    required this.allModeGeneralHasMore,
    required this.heroIndex,
  });

  final List<ProductModel> products;
  final List<CategoryModel> categories;
  final String selectedCategoryId;
  final bool hasMore;
  final int? nextPage;
  final int visibleProductsLimit;
  final Map<String, int?> allModeNextPagesByCategory;
  final Map<String, bool> allModeHasMoreByCategory;
  final int? allModeGeneralNextPage;
  final bool allModeGeneralHasMore;
  final int heroIndex;
}

class _ProductsFeedScreenState extends State<ProductsFeedScreen> {
  static const int _allCategoryPerCategoryBatch = 3;
  static const int _productsChunkSize = 10;
  static const int _categoryIconPrefetchCount = 14;
  static const int _backgroundPrefetchMaxPages = 300;
  static const int _backgroundPrefetchFlushSize = 40;
  static final Map<String, _ProductsFeedCache> _cache =
      <String, _ProductsFeedCache>{};

  final AppStore _app = AppStore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _heroController = PageController();
  int _catalogRequestVersion = 0;

  List<ProductModel> _products = <ProductModel>[];
  List<CategoryModel> _categories = <CategoryModel>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int? _nextPage = 2;
  String _selectedCategoryId = '';
  int _visibleProductsLimit = _productsChunkSize;
  String _lastSearchValue = '';
  final Map<String, int?> _allModeNextPagesByCategory = <String, int?>{};
  final Map<String, bool> _allModeHasMoreByCategory = <String, bool>{};
  int? _allModeGeneralNextPage;
  bool _allModeGeneralHasMore = false;
  bool _backgroundPrefetching = false;
  int _backgroundPrefetchSession = 0;
  int _heroIndex = 0;
  int _lastReselectToken = 0;
  Timer? _heroTimer;

  List<ProductModel>? _orderedGridCacheProductsRef;
  List<CategoryModel>? _orderedGridCacheCategoriesRef;
  String _orderedGridCacheQuery = '';
  String _orderedGridCacheSelectedCategoryId = '';
  bool _orderedGridCacheShowHero = false;
  List<ProductModel> _orderedGridCache = const <ProductModel>[];

  String get _cacheKey => widget.redirectPath;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId ?? '';
    _lastSearchValue = _searchController.text.trim();
    final restored = _restoreFromCache();
    _loadInitial(preserveExisting: restored);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _app.favorites.addListener(_rebuild);
    _app.cart.addListener(_rebuild);
    pwaTabReselectNotifier.addListener(_handleTabReselect);
    _startHeroRotation();
  }

  @override
  void dispose() {
    _backgroundPrefetchSession += 1;
    _backgroundPrefetching = false;
    _heroTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _heroController.dispose();
    _app.favorites.removeListener(_rebuild);
    _app.cart.removeListener(_rebuild);
    pwaTabReselectNotifier.removeListener(_handleTabReselect);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTabReselect() {
    final event = pwaTabReselectNotifier.value;
    if (event == null || event.token == _lastReselectToken) {
      return;
    }
    final tabIndex = widget.showHero ? 0 : 1;
    if (event.index != tabIndex) {
      return;
    }
    _lastReselectToken = event.token;
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }
    final minOffset = _scrollController.position.minScrollExtent;
    if (_scrollController.offset <= minOffset + 1) {
      return;
    }
    _scrollController.animateTo(
      minOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query == _lastSearchValue) {
      _rebuild();
      return;
    }
    _lastSearchValue = query;
    setState(() {
      _visibleProductsLimit = _productsChunkSize;
    });
  }

  bool get _isAllCategoryMode {
    return _selectedCategoryId.isEmpty && _searchController.text.trim().isEmpty;
  }

  String _productStableKey(ProductModel product) {
    final id = product.id.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final routeId = product.routeId.trim();
    if (routeId.isNotEmpty) {
      return routeId;
    }
    return '${product.title.trim()}::${product.catalogImage.trim()}';
  }

  int _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x3fffffff;
    }
    return hash;
  }

  List<ProductModel> _stableFeedOrder(Iterable<ProductModel> source) {
    final products = source.toList(growable: false);
    products.sort((a, b) {
      final aKey = _productStableKey(a);
      final bKey = _productStableKey(b);
      final hashCompare = _stableHash(aKey).compareTo(_stableHash(bKey));
      if (hashCompare != 0) {
        return hashCompare;
      }
      return aKey.compareTo(bKey);
    });
    return products;
  }

  List<ProductModel> _mergeProductsKeepingCurrentOrder(
    List<ProductModel> current,
    List<ProductModel> incoming,
  ) {
    final incomingByKey = <String, ProductModel>{
      for (final product in incoming) _productStableKey(product): product,
    };
    final merged = <ProductModel>[];
    final seen = <String>{};

    for (final product in current) {
      final key = _productStableKey(product);
      final updated = incomingByKey.remove(key);
      if (updated != null) {
        merged.add(updated);
        seen.add(key);
      } else if (seen.add(key)) {
        merged.add(product);
      }
    }

    for (final product in incoming) {
      final key = _productStableKey(product);
      final added = incomingByKey.remove(key);
      if (added != null && seen.add(key)) {
        merged.add(added);
      }
    }

    return merged;
  }

  void _startHeroRotation() {
    if (!widget.showHero) {
      return;
    }
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) {
        return;
      }
      if (!_heroController.hasClients) {
        return;
      }
      final heroItems = _heroProducts;
      if (heroItems.length <= 1) {
        return;
      }
      final next = (_heroIndex + 1) % heroItems.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      setState(() {
        _heroIndex = next;
      });
    });
  }

  Future<PaginatedProducts> _fetchProductsWithRetry({
    required int page,
    String? categoryId,
    int attempts = 3,
  }) async {
    Object? lastError;
    for (int attempt = 0; attempt < attempts; attempt += 1) {
      try {
        return await _app.api.fetchProducts(page: page, categoryId: categoryId);
      } catch (error) {
        lastError = error;
        if (attempt < attempts - 1) {
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        }
      }
    }
    throw lastError ?? Exception('Failed to fetch products');
  }

  void _scheduleBackgroundPrefetch({
    required int requestVersion,
    required String categoryIdSnapshot,
  }) {
    if (_backgroundPrefetching || !_hasMore || _nextPage == null) {
      return;
    }
    final session = ++_backgroundPrefetchSession;
    _backgroundPrefetching = true;
    unawaited(
      _runBackgroundPrefetch(
        session: session,
        requestVersion: requestVersion,
        categoryIdSnapshot: categoryIdSnapshot,
      ),
    );
  }

  Future<void> _runBackgroundPrefetch({
    required int session,
    required int requestVersion,
    required String categoryIdSnapshot,
  }) async {
    int fetchedPages = 0;
    int? nextPage = _nextPage;
    bool hasMore = _hasMore;
    final seenIds = _products.map((item) => item.id).toSet();
    final pending = <ProductModel>[];
    final categoryId = categoryIdSnapshot.isEmpty ? null : categoryIdSnapshot;

    bool isStale() {
      return !mounted ||
          session != _backgroundPrefetchSession ||
          requestVersion != _catalogRequestVersion ||
          categoryIdSnapshot != _selectedCategoryId;
    }

    Future<void> flush() async {
      if (pending.isEmpty || isStale()) {
        return;
      }
      setState(() {
        _products = <ProductModel>[
          ..._products,
          ...pending,
        ];
        _nextPage = nextPage;
        _hasMore = hasMore;
        if (_isAllCategoryMode) {
          _allModeGeneralNextPage = nextPage;
          _allModeGeneralHasMore = hasMore;
        }
      });
      pending.clear();
      _saveToCache();
    }

    try {
      while (!isStale() &&
          hasMore &&
          nextPage != null &&
          fetchedPages < _backgroundPrefetchMaxPages) {
        final page = await _fetchProductsWithRetry(
          page: nextPage,
          categoryId: categoryId,
          attempts: 2,
        );
        fetchedPages += 1;

        for (final item in page.results) {
          if (seenIds.add(item.id)) {
            pending.add(item);
          }
        }

        nextPage = page.nextPage;
        hasMore = page.hasMore;

        if (pending.length >= _backgroundPrefetchFlushSize ||
            !hasMore ||
            nextPage == null) {
          await flush();
        }

        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      await flush();
    } catch (_) {
      await flush();
    } finally {
      if (session == _backgroundPrefetchSession) {
        _backgroundPrefetching = false;
      }
    }
  }

  void _precacheCategoryIcons(List<CategoryModel> categories) {
    if (!mounted || categories.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final urls = categories
          .map((item) => item.image.trim())
          .where((item) => item.isNotEmpty)
          .take(_categoryIconPrefetchCount)
          .toList(growable: false);
      for (final url in urls) {
        unawaited(
          precacheImage(NetworkImage(url), context).catchError((_) => false),
        );
      }
    });
  }

  bool _restoreFromCache() {
    final cache = _cache[_cacheKey];
    if (cache == null) {
      return false;
    }
    _products = cache.products;
    _categories = cache.categories;
    _selectedCategoryId = cache.selectedCategoryId;
    _hasMore = cache.hasMore;
    _nextPage = cache.nextPage;
    _visibleProductsLimit = cache.visibleProductsLimit;
    _allModeNextPagesByCategory
      ..clear()
      ..addAll(cache.allModeNextPagesByCategory);
    _allModeHasMoreByCategory
      ..clear()
      ..addAll(cache.allModeHasMoreByCategory);
    _allModeGeneralNextPage = cache.allModeGeneralNextPage;
    _allModeGeneralHasMore = cache.allModeGeneralHasMore;
    _heroIndex = cache.heroIndex;
    _loading = false;
    _loadingMore = false;
    _precacheCategoryIcons(cache.categories);
    return true;
  }

  void _saveToCache() {
    _cache[_cacheKey] = _ProductsFeedCache(
      products: _products,
      categories: _categories,
      selectedCategoryId: _selectedCategoryId,
      hasMore: _hasMore,
      nextPage: _nextPage,
      visibleProductsLimit: _visibleProductsLimit,
      allModeNextPagesByCategory: Map<String, int?>.from(
        _allModeNextPagesByCategory,
      ),
      allModeHasMoreByCategory: Map<String, bool>.from(
        _allModeHasMoreByCategory,
      ),
      allModeGeneralNextPage: _allModeGeneralNextPage,
      allModeGeneralHasMore: _allModeGeneralHasMore,
      heroIndex: _heroIndex,
    );
  }

  Future<void> _loadInitial({bool preserveExisting = false}) async {
    final requestVersion = ++_catalogRequestVersion;
    final categoryIdSnapshot = _selectedCategoryId;
    final allModeSnapshot = _isAllCategoryMode;
    _backgroundPrefetchSession += 1;
    _backgroundPrefetching = false;

    setState(() {
      _loading = true;
      _loadingMore = false;
      if (!preserveExisting) {
        _hasMore = true;
        _nextPage = 2;
        _visibleProductsLimit = _productsChunkSize;
        _products = <ProductModel>[];
        _allModeNextPagesByCategory.clear();
        _allModeHasMoreByCategory.clear();
        _allModeGeneralNextPage = null;
        _allModeGeneralHasMore = false;
      }
    });

    try {
      final categories = await _app.api.fetchCategories();

      if (!mounted) {
        return;
      }
      if (requestVersion != _catalogRequestVersion ||
          categoryIdSnapshot != _selectedCategoryId) {
        return;
      }
      setState(() {
        _categories = categories;
      });
      _precacheCategoryIcons(categories);
      if (allModeSnapshot) {
        // Keep "Все" in sync with PWA: only global products feed + pagination.
        final firstPage = await _fetchProductsWithRetry(page: 1);

        if (!mounted) {
          return;
        }
        if (requestVersion != _catalogRequestVersion ||
            categoryIdSnapshot != _selectedCategoryId) {
          return;
        }

        final products = _stableFeedOrder(firstPage.results);
        final nextProducts = preserveExisting
            ? _mergeProductsKeepingCurrentOrder(_products, products)
            : products;

        setState(() {
          _products = nextProducts;
          _nextPage = firstPage.nextPage;
          _hasMore = firstPage.hasMore;
          _allModeNextPagesByCategory.clear();
          _allModeHasMoreByCategory.clear();
          _allModeGeneralNextPage = firstPage.nextPage;
          _allModeGeneralHasMore = firstPage.hasMore;
        });
        _saveToCache();
        _scheduleBackgroundPrefetch(
          requestVersion: requestVersion,
          categoryIdSnapshot: categoryIdSnapshot,
        );
      } else {
        final firstPage = await _fetchProductsWithRetry(
          page: 1,
          categoryId: categoryIdSnapshot.isEmpty ? null : categoryIdSnapshot,
        );

        if (!mounted) {
          return;
        }
        if (requestVersion != _catalogRequestVersion ||
            categoryIdSnapshot != _selectedCategoryId) {
          return;
        }

        final products = _stableFeedOrder(firstPage.results);
        final nextProducts = preserveExisting
            ? _mergeProductsKeepingCurrentOrder(_products, products)
            : products;

        setState(() {
          _products = nextProducts;
          _nextPage = firstPage.nextPage;
          _hasMore = firstPage.hasMore;
        });
        _saveToCache();
        _scheduleBackgroundPrefetch(
          requestVersion: requestVersion,
          categoryIdSnapshot: categoryIdSnapshot,
        );
      }
      _startHeroRotation();
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (requestVersion != _catalogRequestVersion ||
          categoryIdSnapshot != _selectedCategoryId) {
        return;
      }
      setState(() {
        if (!preserveExisting) {
          _categories = <CategoryModel>[];
          _products = <ProductModel>[];
          _nextPage = null;
          _hasMore = false;
          _allModeNextPagesByCategory.clear();
          _allModeHasMoreByCategory.clear();
          _allModeGeneralNextPage = null;
          _allModeGeneralHasMore = false;
        }
      });
    } finally {
      if (mounted &&
          requestVersion == _catalogRequestVersion &&
          categoryIdSnapshot == _selectedCategoryId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _backgroundPrefetching || !_hasMore) {
      return;
    }
    if (_nextPage == null) {
      return;
    }

    final requestVersion = _catalogRequestVersion;
    final categoryIdSnapshot = _selectedCategoryId;

    setState(() {
      _loadingMore = true;
    });
    try {
      final page = await _fetchProductsWithRetry(
        page: _nextPage!,
        categoryId: categoryIdSnapshot.isEmpty ? null : categoryIdSnapshot,
      );
      final merged = <String, ProductModel>{};
      for (final item in _products) {
        merged[item.id] = item;
      }
      for (final item in page.results) {
        merged[item.id] = item;
      }
      if (!mounted) {
        return;
      }
      if (requestVersion != _catalogRequestVersion ||
          categoryIdSnapshot != _selectedCategoryId) {
        return;
      }
      setState(() {
        _products = merged.values.toList(growable: false);
        _nextPage = page.nextPage;
        _hasMore = page.hasMore;
        if (_isAllCategoryMode) {
          _allModeGeneralNextPage = page.nextPage;
          _allModeGeneralHasMore = page.hasMore;
        }
      });
      _saveToCache();
      _scheduleBackgroundPrefetch(
        requestVersion: requestVersion,
        categoryIdSnapshot: categoryIdSnapshot,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (requestVersion != _catalogRequestVersion ||
          categoryIdSnapshot != _selectedCategoryId) {
        return;
      }
      setState(() {
        _hasMore = _nextPage != null;
      });
    } finally {
      if (mounted &&
          requestVersion == _catalogRequestVersion &&
          categoryIdSnapshot == _selectedCategoryId) {
        setState(() {
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 450) {
      final ordered = _orderedProductsForGrid;
      if (_visibleProductsLimit < ordered.length) {
        setState(() {
          _visibleProductsLimit = min(
            _visibleProductsLimit + _productsChunkSize,
            ordered.length,
          );
        });
        return;
      }
      _loadMore();
    }
  }

  List<ProductModel> get _heroProducts {
    return _products.take(5).toList(growable: false);
  }

  List<ProductModel> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _products;
    }
    return _products.where((product) {
      return product.title.toLowerCase().contains(query) ||
          product.categoryName.toLowerCase().contains(query);
    }).toList(growable: false);
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

  List<ProductModel> _mixAllCategoryProducts(List<ProductModel> source) {
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
    for (final category in _categories) {
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
    while (added) {
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
        final end = min(start + _allCategoryPerCategoryBatch, items.length);
        mixed.addAll(items.sublist(start, end));
        offsets[key] = end;
        added = true;
      }
    }

    return mixed;
  }

  List<ProductModel> _keepVisibleGridOrder(List<ProductModel> ordered) {
    if (_orderedGridCache.isEmpty) {
      return ordered;
    }

    final remaining = <String, ProductModel>{
      for (final product in ordered) _productStableKey(product): product,
    };
    final stable = <ProductModel>[];
    final seen = <String>{};

    for (final previous in _orderedGridCache) {
      final key = _productStableKey(previous);
      final current = remaining.remove(key);
      if (current != null && seen.add(key)) {
        stable.add(current);
      }
    }

    for (final product in ordered) {
      final key = _productStableKey(product);
      final current = remaining.remove(key);
      if (current != null && seen.add(key)) {
        stable.add(current);
      }
    }

    return stable;
  }

  List<ProductModel> get _orderedProductsForGrid {
    final query = _searchController.text.trim().toLowerCase();
    final cacheHit = identical(_orderedGridCacheProductsRef, _products) &&
        identical(_orderedGridCacheCategoriesRef, _categories) &&
        _orderedGridCacheQuery == query &&
        _orderedGridCacheSelectedCategoryId == _selectedCategoryId &&
        _orderedGridCacheShowHero == widget.showHero;
    if (cacheHit) {
      return _orderedGridCache;
    }

    final filtered = query.isEmpty
        ? _products
        : _products.where((product) {
            return product.title.toLowerCase().contains(query) ||
                product.categoryName.toLowerCase().contains(query);
          }).toList(growable: false);

    final isSearchActive = query.isNotEmpty;
    final base = (isSearchActive || !widget.showHero)
        ? filtered
        : () {
            final heroIds = _heroProducts.map((item) => item.id).toSet();
            return filtered
                .where((item) => !heroIds.contains(item.id))
                .toList(growable: false);
          }();

    final nextOrder = _isAllCategoryMode ? _mixAllCategoryProducts(base) : base;
    final canKeepVisibleOrder = _orderedGridCacheQuery == query &&
        _orderedGridCacheSelectedCategoryId == _selectedCategoryId &&
        _orderedGridCacheShowHero == widget.showHero;
    final ordered =
        canKeepVisibleOrder ? _keepVisibleGridOrder(nextOrder) : nextOrder;
    _orderedGridCacheProductsRef = _products;
    _orderedGridCacheCategoriesRef = _categories;
    _orderedGridCacheQuery = query;
    _orderedGridCacheSelectedCategoryId = _selectedCategoryId;
    _orderedGridCacheShowHero = widget.showHero;
    _orderedGridCache = ordered;
    return ordered;
  }

  List<ProductModel> get _visibleProductsForGrid {
    final ordered = _orderedProductsForGrid;
    if (ordered.isEmpty) {
      return ordered;
    }
    final safeLimit = max(
      _productsChunkSize,
      min(_visibleProductsLimit, ordered.length),
    );
    return ordered.take(safeLimit).toList(growable: false);
  }

  ProductModel _favoriteToProduct(FavoriteItem item) {
    final favoriteImage = normalizeImageUrl(item.image);
    return ProductModel(
      id: item.productId,
      slug: item.slug,
      title: item.title,
      price: item.price,
      oldPrice: null,
      description: '',
      rating: item.rating ?? 0,
      reviewsCount: item.reviewsCount ?? 0,
      images: <ProductImageModel>[
        ProductImageModel(
          url: favoriteImage,
          isMain: true,
          thumbUrl: favoriteImage,
          mediumUrl: favoriteImage,
          largeUrl: favoriteImage,
        ),
      ],
      imageThumb: favoriteImage,
      imageMedium: favoriteImage,
      imageLarge: favoriteImage,
      categoryId: '',
      categoryName: '',
      stock: null,
      variants: const <ProductVariantModel>[],
    );
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
    context.push('/auth?redirect=${Uri.encodeComponent(widget.redirectPath)}');
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _app.favorites.items;
    final isSearchActive = _searchController.text.trim().isNotEmpty;
    final orderedGridProducts = _orderedProductsForGrid;
    final visibleGridProducts = _visibleProductsForGrid;
    final showInitialSkeleton = _loading && _products.isEmpty;
    final hasLocalMore =
        visibleGridProducts.length < orderedGridProducts.length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFF8FAFF),
            Color(0xFFF2F2F7),
            Color(0xFFF2F2F7),
          ],
        ),
      ),
      child: RefreshIndicator(
        color: const Color(0xFF7B2CF5),
        onRefresh: () => _loadInitial(preserveExisting: true),
        child: ListView(
          controller: _scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
          children: [
            _SearchHeader(
              controller: _searchController,
              resultCount: _filteredProducts.length,
            ),
            if (widget.showHero) ...[
              const SizedBox(height: 12),
              _HeroSlider(
                products: _heroProducts,
                currentIndex: _heroIndex,
                controller: _heroController,
                onPageChanged: (value) => setState(() => _heroIndex = value),
              ),
            ],
            const SizedBox(height: 16),
            const _SectionTitle(
              title: 'Категории',
              icon: Icons.grid_view_rounded,
            ),
            const SizedBox(height: 8),
            _CategoriesStrip(
              loading: _loading && _categories.isEmpty,
              selectedCategoryId: _selectedCategoryId,
              categories: _categories,
              onSelect: (categoryId) {
                setState(() {
                  _selectedCategoryId = categoryId;
                  _visibleProductsLimit = _productsChunkSize;
                });
                _loadInitial();
              },
            ),
            if (widget.showFavorites && !isSearchActive) ...[
              const SizedBox(height: 18),
              const _SectionTitle(
                title: 'Избранное',
                icon: Icons.favorite_rounded,
              ),
              const SizedBox(height: 8),
              if (favorites.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1F3C3C43)),
                  ),
                  child: const Text(
                    'Нажмите на сердечко товара, чтобы добавить его в избранное.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (favorites.isNotEmpty)
                GridView.builder(
                  itemCount: favorites.length.clamp(0, 4),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.58,
                  ),
                  itemBuilder: (context, index) {
                    final item = favorites[index];
                    final product = _favoriteToProduct(item);
                    return ProductCardWidget(
                      key: ValueKey<String>(
                        'favorite-${_productStableKey(product)}',
                      ),
                      product: product,
                      isFavorite: true,
                      onOpen: () => context.push('/product/${product.routeId}'),
                      onToggleFavorite: () => _app.favorites.toggleStored(item),
                      onAddToCart: () => _onAddToCart(product),
                    );
                  },
                ),
            ],
            const SizedBox(height: 18),
            _SectionTitle(
              title: isSearchActive ? 'Результаты поиска' : 'Товары для вас',
              icon: Icons.local_fire_department_rounded,
            ),
            const SizedBox(height: 8),
            if (showInitialSkeleton)
              const _ProductsSkeleton()
            else if (orderedGridProducts.isEmpty)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 42, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x1F3C3C43)),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: Color(0xFF9CA3AF),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSearchActive
                          ? 'По запросу ничего не найдено'
                          : 'В этой категории пока нет товаров',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                itemCount: visibleGridProducts.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) {
                  final product = visibleGridProducts[index];
                  return ProductCardWidget(
                    key: ValueKey<String>(
                      'home-${_productStableKey(product)}',
                    ),
                    product: product,
                    isFavorite: _app.favorites.isFavorite(product.id),
                    onOpen: () => context.push('/product/${product.routeId}'),
                    onToggleFavorite: () =>
                        _app.favorites.toggleProduct(product),
                    onAddToCart: () => _onAddToCart(product),
                  );
                },
              ),
            const SizedBox(height: 10),
            if (_loadingMore)
              const Text(
                'Загружаем еще товары...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8B92A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else if (!hasLocalMore && !_hasMore)
              const Text(
                'Вы просмотрели все товары',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF8B92A8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.resultCount,
  });

  final TextEditingController controller;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final isSearchActive = controller.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x1F3C3C43)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Что вы ищете?',
              hintStyle: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 17,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF8E8E93),
              ),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0x337B2CF5)),
              ),
            ),
          ),
          if (isSearchActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Найдено: $resultCount',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroSlider extends StatelessWidget {
  const _HeroSlider({
    required this.products,
    required this.currentIndex,
    required this.controller,
    required this.onPageChanged,
  });

  final List<ProductModel> products;
  final int currentIndex;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF8F56F7), Color(0xFFB88DFB)],
          ),
        ),
        child: const Center(
          child: Text(
            'Добро пожаловать в KuMarket',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: controller,
            itemCount: products.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final product = products[index];
              return GestureDetector(
                key: ValueKey<String>('hero-${product.id}'),
                onTap: () => context.push('/product/${product.routeId}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (product.detailImage.isNotEmpty)
                        Image.network(
                          product.detailImage,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.low,
                          cacheWidth: 960,
                          cacheHeight: 540,
                          frameBuilder: (context, child, frame, wasSyncLoaded) {
                            if (wasSyncLoaded || frame != null) {
                              return child;
                            }
                            return Container(color: const Color(0xFF8F56F7));
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF8F56F7),
                          ),
                        )
                      else
                        Container(color: const Color(0xFF8F56F7)),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0xAA000000),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'НОВИНКА',
                            style: TextStyle(
                              color: Color(0xFF7B2CF5),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.price.toStringAsFixed(0)} сом',
                              style: const TextStyle(
                                color: Color(0xFFF3E8FF),
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(products.length, (index) {
            final active = index == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFF7B2CF5) : const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CategoriesStrip extends StatelessWidget {
  const _CategoriesStrip({
    required this.loading,
    required this.selectedCategoryId,
    required this.categories,
    required this.onSelect,
  });

  final bool loading;
  final String selectedCategoryId;
  final List<CategoryModel> categories;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 128,
        child: ListView.separated(
          physics: const ClampingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          itemBuilder: (context, index) {
            return Container(
              width: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1F3C3C43)),
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemCount: 8,
        ),
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryCard(
              title: 'Все',
              imageUrl: '',
              active: selectedCategoryId.isEmpty,
              isAllCategory: true,
              onTap: () => onSelect(''),
            );
          }
          final category = categories[index - 1];
          return _CategoryCard(
            title: category.name,
            imageUrl: category.image,
            active: selectedCategoryId == category.id,
            isAllCategory: false,
            onTap: () => onSelect(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.title,
    required this.imageUrl,
    required this.active,
    required this.isAllCategory,
    required this.onTap,
  });

  final String title;
  final String imageUrl;
  final bool active;
  final bool isAllCategory;
  final VoidCallback onTap;

  Widget _buildFallbackIcon() {
    if (!isAllCategory) {
      return const Center(
        child: Icon(
          Icons.inventory_2_rounded,
          color: Color(0xFF8C94AD),
        ),
      );
    }

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7B2CF5), Color(0xFFA970FF)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x337B2CF5),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          Positioned(
            top: -3,
            right: -3,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 9,
                color: Color(0xFF6A3DE8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 98,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 98,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active
                      ? const Color(0xFF7B2CF5)
                      : const Color(0x1F3C3C43),
                  width: active ? 1.5 : 1,
                ),
                color: active
                    ? const Color(0xFFF3E8FF).withValues(alpha: 0.6)
                    : Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  color: active
                      ? const Color(0xFFF3E8FF).withValues(alpha: 0.45)
                      : const Color(0xFFF8F8FC),
                  child: imageUrl.isEmpty
                      ? _buildFallbackIcon()
                      : Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            filterQuality: FilterQuality.low,
                            cacheWidth: 128,
                            cacheHeight: 96,
                            gaplessPlayback: true,
                            frameBuilder:
                                (context, child, frame, wasSyncLoaded) {
                              if (wasSyncLoaded || frame != null) {
                                return child;
                              }
                              return _buildFallbackIcon();
                            },
                            errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF7B2CF5)
                      : const Color(0xFF111827),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ProductsSkeleton extends StatelessWidget {
  const _ProductsSkeleton();

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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1F3C3C43)),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
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
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
