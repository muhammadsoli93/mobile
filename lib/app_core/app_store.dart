import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:kumarket/app_core/models.dart';

const String _apiBase = 'https://kumarket.shop/api';
const String _authStorageKey = 'kumarket_auth_user_v1';
const String _authTokenStorageKey = 'kumarket_auth_tokens_v1';
const String _cartStorageKey = 'kumarket_cart_v1';
const String _favoritesStorageKey = 'kumarket_favorites_v1';
const String _ordersStoragePrefix = 'kumarket_orders_';
const String _deepSeekApiKeyPrimary =
    String.fromEnvironment('DEEPSEEK_API_KEY');
const String _deepSeekApiKeySecondary = String.fromEnvironment(
  'DEEPSEEK_KEY',
  defaultValue: 'sk-9ff24eac053245838382b94e269484a4',
);
const String _deepSeekApiBase = String.fromEnvironment(
  'DEEPSEEK_API_BASE',
  defaultValue: 'https://api.deepseek.com',
);
const String _deepSeekModel = String.fromEnvironment(
  'DEEPSEEK_MODEL',
  defaultValue: 'deepseek-reasoner',
);

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(status=$statusCode, message=$message)';

  static ApiException fromResponse(http.Response response) {
    final fallback = 'HTTP ${response.statusCode}';
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final message = _extractMessage(decoded);
      return ApiException(
        message: message.isEmpty ? fallback : message,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException(message: fallback, statusCode: response.statusCode);
    }
  }

  static String _extractMessage(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      for (final item in value) {
        final nested = _extractMessage(item);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      return '';
    }
    if (value is Map) {
      final map = value.cast<Object?, Object?>();
      for (final key in const <String>[
        'detail',
        'message',
        'error',
        'errors',
        'non_field_errors',
      ]) {
        final nested = _extractMessage(map[key]);
        if (nested.isNotEmpty) {
          return nested;
        }
      }

      for (final entry in map.entries) {
        final nested = _extractMessage(entry.value);
        if (nested.isNotEmpty) {
          final key = toSafeString(entry.key);
          if (key.isEmpty) {
            return nested;
          }
          return '$key: $nested';
        }
      }
    }
    return '';
  }
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, String> _ruDescriptionCache = <String, String>{};

  Future<List<CategoryModel>> fetchCategories() async {
    final decoded = await _requestObject(
      method: 'GET',
      paths: const <String>['/catalog/categories/', '/catalog/category/'],
    );

    final rawResults = _extractResults(decoded);
    final categories = <CategoryModel>[];
    for (final item in rawResults) {
      if (item is Map<String, dynamic>) {
        categories.add(CategoryModel.fromJson(item));
      }
    }
    return categories;
  }

  Future<PaginatedProducts> fetchProducts({
    required int page,
    String? categoryId,
  }) async {
    final params = <String, String>{'page': '$page'};
    if ((categoryId ?? '').trim().isNotEmpty) {
      params['category'] = categoryId!.trim();
    }

    final decoded = await _requestObject(
      method: 'GET',
      paths: const <String>['/catalog/products/'],
      query: params,
    );

    final rawResults = _extractResults(decoded);
    final results = <ProductModel>[];
    for (final item in rawResults) {
      if (item is Map<String, dynamic>) {
        results.add(ProductModel.fromJson(item));
      }
    }

    final nextPage = _extractNextPage(toSafeString(decoded['next']));
    return PaginatedProducts(
      results: results,
      nextPage: nextPage,
      hasMore: nextPage != null,
    );
  }

  Future<ProductModel?> fetchProductByRouteId(String routeId) async {
    final value = routeId.trim();
    if (value.isEmpty) {
      return null;
    }

    final direct = await _fetchProductByPath(value);
    if (direct != null) {
      return _ensureRussianDescription(direct);
    }

    final firstPage = await fetchProducts(page: 1);
    for (final product in firstPage.results) {
      if (product.id == value || product.slug == value) {
        return _ensureRussianDescription(product);
      }
    }
    return null;
  }

  Future<List<ProductModel>> fetchRelatedProducts({
    required ProductModel product,
    int limit = 16,
  }) async {
    if (product.categoryId.isEmpty && product.categoryName.isEmpty) {
      return const <ProductModel>[];
    }

    String normalizeCategory(String value) {
      return value.trim().toLowerCase();
    }

    final sourceCategoryId = product.categoryId.trim();
    final sourceCategoryName = normalizeCategory(product.categoryName);

    bool isSameCategory(ProductModel item) {
      final itemCategoryId = item.categoryId.trim();
      final itemCategoryName = normalizeCategory(item.categoryName);

      if (sourceCategoryId.isNotEmpty && itemCategoryId.isNotEmpty) {
        return sourceCategoryId == itemCategoryId;
      }
      if (sourceCategoryName.isNotEmpty && itemCategoryName.isNotEmpty) {
        return sourceCategoryName == itemCategoryName;
      }
      if (sourceCategoryId.isNotEmpty || sourceCategoryName.isNotEmpty) {
        return false;
      }
      return false;
    }

    final related = <ProductModel>[];
    final seenIds = <String>{};
    int page = 1;
    int scanned = 0;
    while (scanned < 8) {
      final pack = await fetchProducts(
        page: page,
        categoryId: sourceCategoryId.isNotEmpty ? sourceCategoryId : null,
      );
      scanned += 1;

      for (final item in pack.results) {
        if (item.id == product.id) {
          continue;
        }
        if (!isSameCategory(item)) {
          continue;
        }
        if (!seenIds.add(item.id)) {
          continue;
        }
        related.add(item);
        if (related.length >= limit) {
          return related;
        }
      }

      if (pack.nextPage == null) {
        break;
      }
      page = pack.nextPage!;
    }

    return related;
  }

  Future<Map<String, dynamic>> requestAuthCode({required String phone}) {
    return _requestObject(
      method: 'POST',
      paths: const <String>['/auth/mobile/send-code/', '/auth/request-code/'],
      body: <String, dynamic>{
        'phone': phone,
        'phone_number': phone,
      },
    );
  }

  Future<Map<String, dynamic>> verifyAuthCode({
    required String phone,
    required String code,
    String fullName = '',
    String city = '',
  }) {
    final normalizedName = fullName.trim();
    final normalizedCity = city.trim();
    final body = <String, dynamic>{
      'phone': phone,
      'phone_number': phone,
      'code': code,
      'sms_code': code,
    };
    if (normalizedName.isNotEmpty) {
      body['full_name'] = normalizedName;
      body['fullName'] = normalizedName;
    }
    if (normalizedCity.isNotEmpty) {
      body['city'] = normalizedCity;
    }

    return _requestObject(
      method: 'POST',
      paths: const <String>['/auth/mobile/sign-in/', '/auth/verify-code/'],
      body: body,
    );
  }

  Future<Map<String, dynamic>> fetchMe({required String accessToken}) {
    return _requestObject(
      method: 'GET',
      paths: const <String>['/auth/me/', '/profile/my/'],
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    required String fullName,
    required String city,
    String? photo,
    String? phone,
  }) async {
    final photoValue = (photo ?? '').trim();
    final phoneValue = (phone ?? '').trim();

    final payloads = <Map<String, dynamic>>[
      <String, dynamic>{
        'name': fullName,
      },
      <String, dynamic>{
        'name': fullName,
        if (phoneValue.isNotEmpty) 'phone': phoneValue,
      },
      <String, dynamic>{
        'name': fullName,
        if (photoValue.isNotEmpty) 'avatar': photoValue,
      },
      <String, dynamic>{
        'name': fullName,
        if (phoneValue.isNotEmpty) 'phone': phoneValue,
        if (photoValue.isNotEmpty) 'avatar': photoValue,
      },
      <String, dynamic>{
        'name': fullName,
        'city': city,
      },
      <String, dynamic>{
        'full_name': fullName,
        if (phoneValue.isNotEmpty) 'phone': phoneValue,
        if (photoValue.isNotEmpty) 'avatar': photoValue,
      },
      <String, dynamic>{
        'fullName': fullName,
        'city': city,
      },
      <String, dynamic>{
        'full_name': fullName,
        'city': city,
        if (photoValue.isNotEmpty) 'photo': photoValue,
        if (phoneValue.isNotEmpty) 'phone': phoneValue,
      },
      <String, dynamic>{
        'full_name': fullName,
        'city': city,
        if (photoValue.isNotEmpty) 'photo': photoValue,
      },
      <String, dynamic>{
        'fullName': fullName,
        if (photoValue.isNotEmpty) 'photo': photoValue,
        if (phoneValue.isNotEmpty) 'phone': phoneValue,
      },
    ];

    const methods = <String>['PUT', 'PATCH', 'POST'];
    const paths = <String>['/profile/my/', '/profile/'];

    ApiException? lastApiError;
    Object? lastUnknownError;

    for (final payload in payloads) {
      for (final method in methods) {
        for (final path in paths) {
          try {
            return await _requestObject(
              method: method,
              paths: <String>[path],
              accessToken: accessToken,
              body: payload,
            );
          } on ApiException catch (e) {
            lastApiError = e;
            if (e.statusCode == 401 || e.statusCode == 403) {
              rethrow;
            }
            if (e.statusCode == 400 ||
                e.statusCode == 404 ||
                e.statusCode == 405 ||
                e.statusCode == 409 ||
                e.statusCode == 415 ||
                e.statusCode == 422) {
              continue;
            }
            continue;
          } catch (e) {
            lastUnknownError = e;
          }
        }
      }
    }

    if (lastApiError != null) {
      throw lastApiError;
    }
    if (lastUnknownError != null) {
      throw ApiException(message: lastUnknownError.toString());
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> saveDeliveryAddress({
    required String accessToken,
    required DeliveryAddress address,
  }) async {
    final payload = <String, dynamic>{
      'country': address.country,
      'city': address.city,
      'address': address.address,
      'pickup_point_label': address.pickupPointLabel,
      'pickupPointLabel': address.pickupPointLabel,
    };

    try {
      return await _requestObject(
        method: 'POST',
        paths: const <String>['/profile/delivery-addresses/'],
        accessToken: accessToken,
        body: payload,
      );
    } on ApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) {
        rethrow;
      }
      return _requestObject(
        method: 'PATCH',
        paths: const <String>['/profile/', '/profile/my/'],
        accessToken: accessToken,
        body: <String, dynamic>{
          'delivery_address': payload,
          'deliveryAddress': payload,
        },
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchOrders({
    required String accessToken,
  }) async {
    final decoded = await _requestObject(
      method: 'GET',
      paths: const <String>['/order/orders/'],
      accessToken: accessToken,
    );

    final list = _extractResults(decoded);
    if (list.isNotEmpty) {
      return list.whereType<Map<String, dynamic>>().toList(growable: false);
    }

    if (decoded.isNotEmpty &&
        (decoded.containsKey('id') || decoded.containsKey('number'))) {
      return <Map<String, dynamic>>[decoded];
    }

    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> createOrder({
    required String accessToken,
    required Map<String, dynamic> payload,
  }) {
    return _requestObject(
      method: 'POST',
      paths: const <String>['/order/orders/'],
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<void> syncCartItems({
    required String accessToken,
    required List<CartItem> items,
  }) async {
    final payloadItems = items
        .map(
          (item) => <String, dynamic>{
            'product_id': item.productId,
            'product_variant_id': item.variantId,
            'quantity': item.quantity,
          },
        )
        .toList(growable: false);

    final payload = <String, dynamic>{
      'items': payloadItems,
    };

    try {
      await _requestObject(
        method: 'PUT',
        paths: const <String>['/cart/items/'],
        accessToken: accessToken,
        body: payload,
      );
      return;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        rethrow;
      }
    }

    try {
      await _requestObject(
        method: 'POST',
        paths: const <String>['/cart/items/', '/cart/'],
        accessToken: accessToken,
        body: payload,
      );
    } catch (_) {
      // non-blocking sync
    }
  }

  Future<ProductModel?> _fetchProductByPath(String pathValue) async {
    try {
      final decoded = await _requestObject(
        method: 'GET',
        paths: <String>[
          '/catalog/products/${Uri.encodeComponent(pathValue)}/',
        ],
      );
      return ProductModel.fromJson(decoded);
    } on ApiException {
      return null;
    }
  }

  Future<ProductModel> _ensureRussianDescription(ProductModel product) async {
    final source = product.description.trim();
    if (source.isEmpty || _hasCyrillic(source)) {
      return product;
    }

    final cacheKey = product.id.isNotEmpty ? product.id : product.slug;
    final cached = _ruDescriptionCache[cacheKey];
    if ((cached ?? '').trim().isNotEmpty) {
      return product.copyWith(description: cached!.trim());
    }

    final translated = await _translateDescriptionToRussian(source);
    if (translated.isEmpty) {
      return product;
    }

    if (cacheKey.isNotEmpty) {
      _ruDescriptionCache[cacheKey] = translated;
    }
    return product.copyWith(description: translated);
  }

  bool _hasCyrillic(String value) {
    for (final rune in value.runes) {
      if (rune >= 0x0400 && rune <= 0x04FF) {
        return true;
      }
    }
    return false;
  }

  Future<String> _translateDescriptionToRussian(String value) async {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return '';
    }
    final apiKey = _effectiveDeepSeekApiKey;
    if (apiKey.isEmpty) {
      return '';
    }

    final clipped = compact.length > 380 ? compact.substring(0, 380) : compact;
    final uri = _deepSeekCompletionsUri();
    final payload = <String, dynamic>{
      'model': _deepSeekModel,
      'temperature': 0.0,
      'messages': <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content': 'You are a translation API. Translate input text to Russian. '
              'Return only translated Russian text without explanations, markdown, or extra words.',
        },
        <String, String>{
          'role': 'user',
          'content': clipped,
        },
      ],
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return '';
      }

      final rawChoices = decoded['choices'];
      if (rawChoices is! List || rawChoices.isEmpty) {
        return '';
      }

      String rawText = '';
      final firstChoice = rawChoices.first;
      if (firstChoice is Map<String, dynamic>) {
        final message = firstChoice['message'];
        if (message is Map<String, dynamic>) {
          rawText = toSafeString(message['content']);
        }
        if (rawText.isEmpty) {
          rawText = toSafeString(firstChoice['text']);
        }
      }
      final cleanedText = _stripTranslationArtifacts(rawText);
      final translated = normalizeProductDescription(cleanedText);

      if (translated.isEmpty || !_hasCyrillic(translated)) {
        return '';
      }
      return translated;
    } catch (_) {
      return '';
    }
  }

  String get _effectiveDeepSeekApiKey {
    final primary = _deepSeekApiKeyPrimary.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    return _deepSeekApiKeySecondary.trim();
  }

  Uri _deepSeekCompletionsUri() {
    final normalizedBase = _deepSeekApiBase.trim().replaceFirst(
          RegExp(r'\/$'),
          '',
        );
    return Uri.parse('$normalizedBase/chat/completions');
  }

  String _stripTranslationArtifacts(String value) {
    var text = value.trim();
    text = text.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
    text = text.replaceAll(RegExp(r'\s*```$'), '');
    text = text.replaceFirst(
      RegExp(
          r'^(Р В Р’В Р РЋРІР‚вЂќР В Р’В Р вЂ™Р’ВµР В Р Р‹Р В РІР‚С™Р В Р’В Р вЂ™Р’ВµР В Р’В Р В РІР‚В Р В Р’В Р РЋРІР‚СћР В Р’В Р СћРІР‚В|translation)\s*:\s*',
          caseSensitive: false),
      '',
    );
    return text.trim();
  }

  Future<Map<String, dynamic>> _requestObject({
    required String method,
    required List<String> paths,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final response = await _requestRaw(
      method: method,
      paths: paths,
      query: query,
      body: body,
      accessToken: accessToken,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException.fromResponse(response);
    }

    if (response.bodyBytes.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is List) {
      return <String, dynamic>{'results': decoded};
    }
    return <String, dynamic>{};
  }

  Future<http.Response> _requestRaw({
    required String method,
    required List<String> paths,
    Map<String, String>? query,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    if (paths.isEmpty) {
      throw const ApiException(message: 'No API path configured');
    }

    ApiException? lastError;
    http.Response? lastResponse;

    for (int i = 0; i < paths.length; i += 1) {
      final path = _normalizePath(paths[i]);
      final uri = Uri.parse('$_apiBase$path').replace(queryParameters: query);
      try {
        final headers = <String, String>{
          'Accept': 'application/json',
        };
        if ((accessToken ?? '').trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer ${accessToken!.trim()}';
        }
        if (body != null) {
          headers['Content-Type'] = 'application/json';
        }

        late final http.Response response;
        switch (method.toUpperCase()) {
          case 'GET':
            response = await _client.get(uri, headers: headers);
            break;
          case 'POST':
            response = await _client.post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'PUT':
            response = await _client.put(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'PATCH':
            response = await _client.patch(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
            break;
          case 'DELETE':
            response = await _client.delete(uri, headers: headers);
            break;
          default:
            throw ApiException(message: 'Unsupported method: $method');
        }

        lastResponse = response;
        if (response.statusCode == 404 && i < paths.length - 1) {
          continue;
        }

        return response;
      } catch (e) {
        if (e is ApiException) {
          lastError = e;
        } else {
          lastError = ApiException(message: e.toString());
        }
      }
    }

    if (lastResponse != null) {
      throw ApiException.fromResponse(lastResponse);
    }
    if (lastError != null) {
      throw lastError;
    }
    throw const ApiException(message: 'Request failed');
  }

  String _normalizePath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '/';
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  List<dynamic> _extractResults(Map<String, dynamic> decoded) {
    final direct = decoded['results'];
    if (direct is List) {
      return direct;
    }
    final data = decoded['data'];
    if (data is List) {
      return data;
    }
    final items = decoded['items'];
    if (items is List) {
      return items;
    }
    return const <dynamic>[];
  }

  int? _extractNextPage(String nextUrl) {
    if (nextUrl.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(nextUrl);
    if (parsed == null) {
      return null;
    }
    final next = int.tryParse(parsed.queryParameters['page'] ?? '');
    if (next == null || next <= 0) {
      return null;
    }
    return next;
  }
}

class ActionResult {
  const ActionResult({
    required this.ok,
    required this.message,
  });

  final bool ok;
  final String message;
}

class OrderCreateResult extends ActionResult {
  const OrderCreateResult({
    required super.ok,
    required super.message,
    this.order,
  });

  final CustomerOrder? order;
}

class AuthCodeResult extends ActionResult {
  const AuthCodeResult({
    required super.ok,
    required super.message,
    required this.normalizedPhone,
  });

  final String normalizedPhone;
}

class AuthLoginResult extends ActionResult {
  const AuthLoginResult({
    required super.ok,
    required super.message,
    required this.user,
  });

  final AuthUser? user;
}

class AuthStore extends ChangeNotifier {
  AuthStore(this._storage, this._api) {
    _restore();
  }

  final GetStorage _storage;
  final ApiService _api;

  AuthUser? _user;
  String? _accessToken;
  String? _refreshToken;

  AuthUser? get user => _user;
  String? get accessToken =>
      (_accessToken ?? '').trim().isEmpty ? null : _accessToken!.trim();
  String? get refreshToken =>
      (_refreshToken ?? '').trim().isEmpty ? null : _refreshToken!.trim();
  bool get isLoggedIn => _user != null && accessToken != null;

  void _restore() {
    final rawUser = _storage.read(_authStorageKey);
    if (rawUser is Map<String, dynamic>) {
      _user = AuthUser.fromJson(rawUser);
    } else if (rawUser is String && rawUser.isNotEmpty) {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        _user = AuthUser.fromJson(decoded);
      }
    }

    final rawTokens = _storage.read(_authTokenStorageKey);
    if (rawTokens is Map<String, dynamic>) {
      _accessToken = toSafeString(rawTokens['access']);
      _refreshToken = toSafeString(rawTokens['refresh']);
    } else if (rawTokens is String && rawTokens.isNotEmpty) {
      final decoded = jsonDecode(rawTokens);
      if (decoded is Map<String, dynamic>) {
        _accessToken = toSafeString(decoded['access']);
        _refreshToken = toSafeString(decoded['refresh']);
      }
    }
  }

  Future<AuthCodeResult> requestCode(String phoneInput) async {
    final normalized = normalizePhone(phoneInput);
    if (!isKyrgyzPhone(normalized)) {
      return AuthCodeResult(
        ok: false,
        normalizedPhone: normalized,
        message: 'Введите номер в формате +996XXXXXXXXX.',
      );
    }

    try {
      final decoded = await _api.requestAuthCode(phone: normalized);
      final message = _extractMessage(
        decoded,
        fallback: 'Код отправлен на $normalized',
      );
      return AuthCodeResult(
        ok: true,
        normalizedPhone: normalized,
        message: message,
      );
    } on ApiException catch (e) {
      return AuthCodeResult(
        ok: false,
        normalizedPhone: normalized,
        message: e.message,
      );
    } catch (_) {
      return AuthCodeResult(
        ok: false,
        normalizedPhone: normalized,
        message: 'Не удалось отправить код. Попробуйте снова.',
      );
    }
  }

  Future<AuthLoginResult> login({
    required String phone,
    required String code,
    String fullName = '',
    String city = '',
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final normalizedCode = code.trim();
    final normalizedName = fullName.trim();
    final normalizedCity = city.trim();

    if (!isKyrgyzPhone(normalizedPhone)) {
      return const AuthLoginResult(
        ok: false,
        message: 'Invalid phone number.',
        user: null,
      );
    }
    if (normalizedCode.isEmpty) {
      return const AuthLoginResult(
        ok: false,
        message: 'Enter the SMS code.',
        user: null,
      );
    }

    try {
      final decoded = await _api.verifyAuthCode(
        phone: normalizedPhone,
        code: normalizedCode,
        fullName: normalizedName,
        city: normalizedCity,
      );

      final access = _extractToken(decoded, const <String>[
        'access',
        'access_token',
        'token',
        'auth_token',
      ]);
      final refresh = _extractToken(decoded, const <String>[
        'refresh',
        'refresh_token',
      ]);

      if (access.isEmpty) {
        return const AuthLoginResult(
          ok: false,
          message: 'Server did not return auth token.',
          user: null,
        );
      }

      Map<String, dynamic>? userMap = _extractFirstMap(decoded, const <String>[
        'user',
        'profile',
        'data',
      ]);

      if ((userMap == null || userMap.isEmpty) && _looksLikeUserMap(decoded)) {
        userMap = decoded;
      }

      if (normalizedName.isNotEmpty || normalizedCity.isNotEmpty) {
        try {
          final syncedProfile = await _api.updateProfile(
            accessToken: access,
            fullName: normalizedName,
            city: normalizedCity,
            phone: normalizedPhone,
          );
          final syncedMap = _extractFirstMap(
                  syncedProfile, const <String>['user', 'profile', 'data']) ??
              syncedProfile;
          if (syncedMap.isNotEmpty) {
            userMap = syncedMap;
          }
        } catch (_) {}
      }

      try {
        final me = await _api.fetchMe(accessToken: access);
        final meMap =
            _extractFirstMap(me, const <String>['user', 'profile', 'data']) ??
                me;
        if (meMap.isNotEmpty) {
          userMap = meMap;
        }
      } catch (_) {}

      final previousName = (_user?.fullName ?? '').trim();
      final previousCity = (_user?.city ?? '').trim();
      final fallbackName = normalizedName.isNotEmpty
          ? normalizedName
          : (previousName.isNotEmpty ? previousName : 'User');
      final fallbackCity = normalizedCity.isNotEmpty
          ? normalizedCity
          : (previousCity.isNotEmpty ? previousCity : 'Nookat');

      final next = _mapAuthUser(
        raw: userMap,
        fallbackPhone: normalizedPhone,
        fallbackFullName: fallbackName,
        fallbackCity: fallbackCity,
      );

      _user = next;
      _accessToken = access;
      _refreshToken = refresh;
      _storage.write(_authStorageKey, next.toJson());
      _storage.write(_authTokenStorageKey, <String, String>{
        'access': access,
        'refresh': refresh,
      });
      notifyListeners();

      return AuthLoginResult(
        ok: true,
        message: 'OK',
        user: next,
      );
    } on ApiException catch (e) {
      return AuthLoginResult(ok: false, message: e.message, user: null);
    } catch (_) {
      return const AuthLoginResult(
        ok: false,
        message: 'Failed to sign in.',
        user: null,
      );
    }
  }

  Future<ActionResult> updateProfile({
    required String fullName,
    String city = '',
    String? photo,
  }) async {
    final current = _user;
    final token = accessToken;
    if (current == null || token == null) {
      return const ActionResult(
        ok: false,
        message: 'Authorization required.',
      );
    }

    final normalizedName = fullName.trim();
    final normalizedCity = city.trim();
    if (normalizedName.isEmpty) {
      return const ActionResult(ok: false, message: 'Enter your name.');
    }

    try {
      final decoded = await _api.updateProfile(
        accessToken: token,
        fullName: normalizedName,
        city: normalizedCity,
        photo: photo,
        phone: current.phone,
      );
      final next = _mapAuthUser(
        raw: _extractFirstMap(
                decoded, const <String>['user', 'profile', 'data']) ??
            decoded,
        fallbackPhone: current.phone,
        fallbackFullName: normalizedName,
        fallbackCity: normalizedCity.isEmpty ? current.city : normalizedCity,
        fallbackPhoto: (photo ?? '').trim().isEmpty ? current.photo : photo,
        fallbackDeliveryAddress: current.deliveryAddress,
      );
      _user = next;
      _storage.write(_authStorageKey, next.toJson());
      notifyListeners();
      return const ActionResult(ok: true, message: 'Profile updated.');
    } on ApiException catch (e) {
      return ActionResult(ok: false, message: e.message);
    } catch (_) {
      return const ActionResult(
        ok: false,
        message: 'Failed to update profile.',
      );
    }
  }

  Future<ActionResult> updateDeliveryAddress(DeliveryAddress address) async {
    final current = _user;
    final token = accessToken;
    if (current == null || token == null) {
      return const ActionResult(
        ok: false,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРІР‚С”Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ.',
      );
    }

    try {
      final decoded = await _api.saveDeliveryAddress(
        accessToken: token,
        address: address,
      );

      final next = _mapAuthUser(
        raw: _extractFirstMap(
                decoded, const <String>['user', 'profile', 'data']) ??
            decoded,
        fallbackPhone: current.phone,
        fallbackFullName: current.fullName,
        fallbackCity: address.city,
        fallbackPhoto: current.photo,
        fallbackDeliveryAddress: address,
      );

      _user = next;
      _storage.write(_authStorageKey, next.toJson());
      notifyListeners();
      return const ActionResult(
          ok: true,
          message:
              'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІвЂћСћР В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚Сљ Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В¦Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦.');
    } on ApiException catch (e) {
      return ActionResult(ok: false, message: e.message);
    } catch (_) {
      return const ActionResult(
        ok: false,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’Вµ Р В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В¦Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚Сљ.',
      );
    }
  }

  void logout() {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _storage.remove(_authStorageKey);
    _storage.remove(_authTokenStorageKey);
    notifyListeners();
  }

  String normalizePhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('996') && digits.length == 12) {
      return '+$digits';
    }
    if (digits.startsWith('0') && digits.length == 10) {
      return '+996${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '+996$digits';
    }
    return value.trim();
  }

  bool isKyrgyzPhone(String value) {
    return RegExp(r'^\+996\d{9}$').hasMatch(value);
  }

  String _extractMessage(Map<String, dynamic> decoded,
      {required String fallback}) {
    final candidates = <Object?>[
      decoded['message'],
      decoded['detail'],
      decoded['error'],
      decoded['errors'],
      decoded['non_field_errors'],
    ];
    for (final item in candidates) {
      final text = _messageFromAny(item);
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  String _messageFromAny(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      for (final item in value) {
        final nested = _messageFromAny(item);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      return '';
    }
    if (value is Map) {
      for (final entry in value.entries) {
        final nested = _messageFromAny(entry.value);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return '';
  }

  String _extractToken(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final direct = toSafeString(data[key]);
      if (direct.isNotEmpty) {
        return direct;
      }
    }
    final nested =
        _extractFirstMap(data, const <String>['tokens', 'token', 'data']);
    if (nested != null) {
      for (final key in keys) {
        final value = toSafeString(nested[key]);
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return '';
  }

  Map<String, dynamic>? _extractFirstMap(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
    return null;
  }

  bool _looksLikeUserMap(Map<String, dynamic>? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final id = toSafeString(value['id']);
    final userId = toSafeString(value['user_id']);
    final phone = toSafeString(value['phone']);
    final phoneNumber = toSafeString(value['phone_number']);
    final fullName = toSafeString(value['full_name']);
    final name = toSafeString(value['name']);
    final city = toSafeString(value['city']);
    if (id.isNotEmpty || userId.isNotEmpty) {
      return true;
    }
    if (phone.isNotEmpty || phoneNumber.isNotEmpty) {
      return true;
    }
    if (fullName.isNotEmpty || name.isNotEmpty || city.isNotEmpty) {
      return true;
    }
    return false;
  }

  AuthUser _mapAuthUser({
    required Map<String, dynamic>? raw,
    required String fallbackPhone,
    required String fallbackFullName,
    required String fallbackCity,
    String? fallbackPhoto,
    DeliveryAddress? fallbackDeliveryAddress,
  }) {
    final now = DateTime.now().toIso8601String();
    final map = raw ?? const <String, dynamic>{};

    final id = _firstNonEmpty(<String?>[
      toSafeString(map['id']),
      toSafeString(map['user_id']),
      toSafeString(map['uuid']),
      _user?.id,
      'user-${DateTime.now().millisecondsSinceEpoch}',
    ]);

    final phone = normalizePhone(
      _firstNonEmpty(<String?>[
        toSafeString(map['phone']),
        toSafeString(map['phone_number']),
        fallbackPhone,
      ]),
    );

    final fullName = _firstNonEmpty(<String?>[
      toSafeString(map['full_name']),
      toSafeString(map['fullName']),
      toSafeString(map['name']),
      fallbackFullName,
    ]);

    final city = _firstNonEmpty(<String?>[
      toSafeString(map['city']),
      toSafeString(map['city_name']),
      fallbackCity,
    ]);

    final photo = _firstNonEmpty(<String?>[
      toSafeString(map['photo']),
      toSafeString(map['avatar']),
      fallbackPhoto,
      _user?.photo,
    ]);

    final rawDelivery = map['delivery_address'] ?? map['deliveryAddress'];
    DeliveryAddress? deliveryAddress =
        fallbackDeliveryAddress ?? _user?.deliveryAddress;
    if (rawDelivery is Map<String, dynamic>) {
      deliveryAddress = DeliveryAddress.fromJson(<String, dynamic>{
        'country': toSafeString(rawDelivery['country']),
        'city': toSafeString(rawDelivery['city']),
        'address': toSafeString(rawDelivery['address']),
        'pickupPointLabel': _firstNonEmpty(<String?>[
          toSafeString(rawDelivery['pickupPointLabel']),
          toSafeString(rawDelivery['pickup_point_label']),
        ]),
      });
    }

    return AuthUser(
      id: id,
      phone: phone,
      fullName: fullName,
      city: city,
      photo: photo.isEmpty ? null : photo,
      createdAtIso: _firstNonEmpty(<String?>[
        toSafeString(map['created_at']),
        toSafeString(map['createdAt']),
        _user?.createdAtIso,
        now,
      ]),
      updatedAtIso: _firstNonEmpty(<String?>[
        toSafeString(map['updated_at']),
        toSafeString(map['updatedAt']),
        now,
      ]),
      deliveryAddress: deliveryAddress,
    );
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }
}

class FavoritesStore extends ChangeNotifier {
  FavoritesStore(this._storage) {
    _restore();
  }

  final GetStorage _storage;
  List<FavoriteItem> _items = <FavoriteItem>[];

  List<FavoriteItem> get items => List<FavoriteItem>.unmodifiable(_items);

  bool isFavorite(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  void toggleProduct(ProductModel product) {
    final currentIndex =
        _items.indexWhere((item) => item.productId == product.id);
    if (currentIndex >= 0) {
      _items = _items
          .where((item) => item.productId != product.id)
          .toList(growable: false);
      _persist();
      notifyListeners();
      return;
    }

    final next = FavoriteItem(
      productId: product.id,
      slug: product.slug,
      title: product.title,
      price: product.price,
      image:
          product.catalogImage.isEmpty ? '/icon-192.png' : product.catalogImage,
      rating: product.rating,
      reviewsCount: product.reviewsCount,
    );

    _items = <FavoriteItem>[next, ..._items];
    _persist();
    notifyListeners();
  }

  void toggleStored(FavoriteItem item) {
    final currentIndex = _items.indexWhere(
      (entry) => entry.productId == item.productId,
    );
    if (currentIndex >= 0) {
      _items = _items
          .where((entry) => entry.productId != item.productId)
          .toList(growable: false);
    } else {
      _items = <FavoriteItem>[item, ..._items];
    }
    _persist();
    notifyListeners();
  }

  void _restore() {
    final raw = _storage.read(_favoritesStorageKey);
    if (raw is List) {
      final parsed = <FavoriteItem>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          parsed.add(FavoriteItem.fromJson(item));
        }
      }
      _items = parsed;
      return;
    }

    if (raw is String) {
      final parsedList = decodeJsonList(raw);
      _items = parsedList.map(FavoriteItem.fromJson).toList(growable: false);
    }
  }

  void _persist() {
    _storage.write(
      _favoritesStorageKey,
      _items.map((item) => item.toJson()).toList(growable: false),
    );
  }
}

class CartStore extends ChangeNotifier {
  CartStore(this._storage, this._auth, this._api) {
    _restore();
    _auth.addListener(_syncCartIfNeeded);
  }

  final GetStorage _storage;
  final AuthStore _auth;
  final ApiService _api;

  List<CartItem> _items = <CartItem>[];

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.fold<int>(0, (sum, item) => sum + item.quantity);
  double get total =>
      _items.fold<double>(0, (sum, item) => sum + item.totalPrice);

  int quantityForProduct(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index < 0) {
      return 0;
    }
    return _items[index].quantity;
  }

  bool addProduct(
    ProductModel product, {
    int quantity = 1,
    String? size,
    String? color,
    String? variantId,
    int? maxQuantity,
  }) {
    if (!_auth.isLoggedIn) {
      return false;
    }

    final itemId = _buildItemId(
      productId: product.id,
      variantId: variantId,
      size: size,
      color: color,
    );
    final index = _items.indexWhere((item) => item.itemId == itemId);
    final safeAdd = quantity <= 0 ? 1 : quantity;
    final cartImage = product.thumbnailImage.isEmpty
        ? product.catalogImage
        : product.thumbnailImage;

    if (index >= 0) {
      final current = _items[index];
      final cap = current.maxQuantity ?? maxQuantity;
      final nextQuantity = _clampQuantity(current.quantity + safeAdd, cap);
      _items[index] = current.copyWith(
        title: product.title,
        slug: product.slug,
        image: cartImage.isEmpty ? '/icon-192.png' : cartImage,
        price: product.price,
        quantity: nextQuantity,
        size: size ?? current.size,
        color: color ?? current.color,
        variantId: variantId ?? current.variantId,
        maxQuantity: cap,
      );
    } else {
      _items = <CartItem>[
        ..._items,
        CartItem(
          itemId: itemId,
          productId: product.id,
          slug: product.slug,
          title: product.title,
          price: product.price,
          image: cartImage.isEmpty ? '/icon-192.png' : cartImage,
          quantity: _clampQuantity(safeAdd, maxQuantity),
          size: size,
          color: color,
          variantId: variantId,
          maxQuantity: maxQuantity,
        ),
      ];
    }

    _persist();
    notifyListeners();
    _syncCartIfNeeded();
    return true;
  }

  void setItemQuantity(String itemId, int quantity) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index < 0) {
      return;
    }
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }

    final current = _items[index];
    _items[index] = current.copyWith(
      quantity: _clampQuantity(quantity, current.maxQuantity),
    );
    _persist();
    notifyListeners();
    _syncCartIfNeeded();
  }

  void removeItem(String itemId) {
    _items =
        _items.where((item) => item.itemId != itemId).toList(growable: false);
    _persist();
    notifyListeners();
    _syncCartIfNeeded();
  }

  void clear() {
    if (_items.isEmpty) {
      return;
    }
    _items = <CartItem>[];
    _persist();
    notifyListeners();
    _syncCartIfNeeded();
  }

  int _clampQuantity(int quantity, int? maxQuantity) {
    final safe = quantity <= 0 ? 1 : quantity;
    if (maxQuantity == null || maxQuantity <= 0) {
      return safe;
    }
    if (safe > maxQuantity) {
      return maxQuantity;
    }
    return safe;
  }

  String _buildItemId({
    required String productId,
    String? variantId,
    String? size,
    String? color,
  }) {
    return <String>[
      productId,
      (variantId ?? '').trim().toLowerCase(),
      (size ?? '').trim().toLowerCase(),
      (color ?? '').trim().toLowerCase(),
    ].join('::');
  }

  void _restore() {
    final raw = _storage.read(_cartStorageKey);
    if (raw is List) {
      final parsed = <CartItem>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          parsed.add(CartItem.fromJson(item));
        }
      }
      _items = parsed;
      return;
    }
    if (raw is String) {
      final parsedList = decodeJsonList(raw);
      _items = parsedList.map(CartItem.fromJson).toList(growable: false);
    }
  }

  void _persist() {
    _storage.write(
      _cartStorageKey,
      _items.map((item) => item.toJson()).toList(growable: false),
    );
  }

  void _syncCartIfNeeded() {
    final token = _auth.accessToken;
    if (token == null) {
      return;
    }
    unawaited(
      _api.syncCartItems(accessToken: token, items: _items).catchError((_) {}),
    );
  }
}

class OrdersStore extends ChangeNotifier {
  OrdersStore(this._storage, this._auth, this._cart, this._api) {
    _auth.addListener(_onAuthChanged);
    _restoreForCurrentUser();
    unawaited(refresh());
  }

  final GetStorage _storage;
  final AuthStore _auth;
  final CartStore _cart;
  final ApiService _api;

  List<CustomerOrder> _orders = <CustomerOrder>[];
  bool _isLoading = false;
  String _syncError = '';

  List<CustomerOrder> get orders => List<CustomerOrder>.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String get syncError => _syncError;

  Future<OrderCreateResult> createOrder(String paymentMethod) async {
    final user = _auth.user;
    final token = _auth.accessToken;

    if (user == null || token == null) {
      return const OrderCreateResult(
        ok: false,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРІР‚С”Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ.',
      );
    }
    if (_cart.items.isEmpty) {
      return const OrderCreateResult(
        ok: false,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В° Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СњР В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°.',
      );
    }

    for (final item in _cart.items) {
      if ((item.variantId ?? '').trim().isEmpty) {
        return OrderCreateResult(
          ok: false,
          message:
              'Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРЎС™Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В° "${item.title}" Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’Вµ Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦ Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ (Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ/Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В Р Р‹Р вЂ™Р’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ў).',
        );
      }
    }

    final address = user.deliveryAddress ??
        const DeliveryAddress(
          country:
              'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦',
          city:
              'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ',
          address:
              'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎСџР В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р В Р вЂ№Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’В',
          pickupPointLabel:
              'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎвЂќР В Р’В Р В Р вЂ№Р В Р вЂ Р Р†Р вЂљРЎв„ўР вЂ™Р’В¬Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В°, Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ',
        );

    final normalizedPaymentMethod =
        paymentMethod.trim().isEmpty ? 'cash' : paymentMethod.trim();

    final strictItemsPayload = _cart.items
        .map(
          (item) => <String, dynamic>{
            'product_variant_id': item.variantId,
            'quantity': item.quantity,
          },
        )
        .toList(growable: false);

    final compatItemsPayload = _cart.items
        .map(
          (item) => <String, dynamic>{
            'product_id': item.productId,
            'product_variant_id': item.variantId,
            'variant_id': item.variantId,
            'quantity': item.quantity,
            'color': item.color,
            'size': item.size,
          },
        )
        .toList(growable: false);

    final safeAddress =
        _sanitizeDeliveryAddress(address, fallbackCity: user.city);

    final deliveryPayload = <String, dynamic>{
      'country': safeAddress.country,
      'city': safeAddress.city,
      'address': safeAddress.address,
      'entrance': 1,
      'apartment': 1,
    };

    final legacyDeliveryPayload = <String, dynamic>{
      ...deliveryPayload,
      'pickup_point_label': safeAddress.pickupPointLabel,
      'pickupPointLabel': safeAddress.pickupPointLabel,
    };

    final payloads = <Map<String, dynamic>>[
      <String, dynamic>{
        'payment_method': normalizedPaymentMethod,
        'payment_status': 'not_paid',
        'items': strictItemsPayload,
        'delivery_address': deliveryPayload,
        'full_name': user.fullName,
        'phone': user.phone,
      },
      <String, dynamic>{
        'payment_method': normalizedPaymentMethod,
        'paymentMethod': normalizedPaymentMethod,
        'payment_status': 'not_paid',
        'paymentStatus': 'not_paid',
        'items': compatItemsPayload,
        'order_items': compatItemsPayload,
        'delivery_address': legacyDeliveryPayload,
        'deliveryAddress': legacyDeliveryPayload,
        'full_name': user.fullName,
        'phone': user.phone,
      },
      <String, dynamic>{
        'items': strictItemsPayload,
        'delivery_address': deliveryPayload,
      },
      <String, dynamic>{'deliveryAddress': legacyDeliveryPayload},
    ];

    try {
      await _api.syncCartItems(
        accessToken: token,
        items: _cart.items,
      );

      ApiException? lastApiError;
      Map<String, dynamic>? decoded;
      for (final payload in payloads) {
        try {
          decoded = await _api.createOrder(
            accessToken: token,
            payload: payload,
          );
          break;
        } on ApiException catch (e) {
          lastApiError = e;
          if (e.statusCode == 401 || e.statusCode == 403) {
            rethrow;
          }
          if (e.statusCode == 400 ||
              e.statusCode == 404 ||
              e.statusCode == 405 ||
              e.statusCode == 409 ||
              e.statusCode == 415 ||
              e.statusCode == 422) {
            continue;
          }
          rethrow;
        }
      }

      if (decoded == null) {
        throw lastApiError ??
            const ApiException(message: 'Order create failed');
      }

      final created = _mapOrder(
        raw: _extractOrderMap(decoded),
        fallbackItems: _cart.items,
        fallbackAddress: safeAddress,
        fallbackPaymentMethod: normalizedPaymentMethod,
        fallbackFullName: user.fullName,
        fallbackPhone: user.phone,
      );

      _orders = <CustomerOrder>[created, ..._orders];
      _persist();
      _cart.clear();
      notifyListeners();
      unawaited(refresh());
      return OrderCreateResult(
        ok: true,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В· Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СњР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’ВµР В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦ Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В  Django.',
        order: created,
      );
    } on ApiException catch (e) {
      return OrderCreateResult(ok: false, message: e.message);
    } catch (_) {
      return const OrderCreateResult(
        ok: false,
        message:
            'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’Вµ Р В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СњР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·.',
      );
    }
  }

  Future<void> refresh() async {
    final token = _auth.accessToken;
    final user = _auth.user;
    if (token == null || user == null) {
      _orders = <CustomerOrder>[];
      _isLoading = false;
      _syncError = '';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _syncError = '';
    notifyListeners();

    try {
      final rawOrders = await _api.fetchOrders(accessToken: token);
      _orders = rawOrders
          .map(
            (raw) => _mapOrder(
              raw: raw,
              fallbackItems: const <CartItem>[],
              fallbackAddress: _sanitizeDeliveryAddress(
                user.deliveryAddress ??
                    const DeliveryAddress(
                      country:
                          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦',
                      city:
                          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ',
                      address:
                          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎСџР В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р Р†РІР‚С›РІР‚вЂњР В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р В Р вЂ№Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’В',
                      pickupPointLabel:
                          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎвЂќР В Р’В Р В Р вЂ№Р В Р вЂ Р Р†Р вЂљРЎв„ўР вЂ™Р’В¬Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р В Р РЏ Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В°, Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћ',
                    ),
                fallbackCity: user.city,
              ),
              fallbackPaymentMethod: 'card',
              fallbackFullName: user.fullName,
              fallbackPhone: user.phone,
            ),
          )
          .toList(growable: false);
      _persist();
    } on ApiException catch (e) {
      _syncError = e.message;
      _restoreForCurrentUser();
    } catch (_) {
      _syncError =
          'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРЎв„ўР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’Вµ Р В Р’В Р В Р вЂ№Р В Р Р‹Р Р†Р вЂљРЎС™Р В Р’В Р вЂ™Р’В Р В РЎС›Р Р†Р вЂљР’ВР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В»Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В±Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В¦Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р’В Р В РІР‚В° Р В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРІР‚СњР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљР’ВР В Р’В Р В Р вЂ№Р В Р’В Р РЋРІР‚СљР В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљ Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎСљР В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В·Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В .';
      _restoreForCurrentUser();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onAuthChanged() {
    _restoreForCurrentUser();
    unawaited(refresh());
  }

  void _restoreForCurrentUser() {
    final phone = _auth.user?.phone;
    if ((phone ?? '').isEmpty) {
      _orders = <CustomerOrder>[];
      notifyListeners();
      return;
    }

    final raw = _storage.read('$_ordersStoragePrefix$phone');
    if (raw is List) {
      final parsed = <CustomerOrder>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          parsed.add(CustomerOrder.fromJson(item));
        }
      }
      _orders = parsed;
      notifyListeners();
      return;
    }

    if (raw is String) {
      final parsedList = decodeJsonList(raw);
      _orders = parsedList.map(CustomerOrder.fromJson).toList(growable: false);
      notifyListeners();
      return;
    }

    _orders = <CustomerOrder>[];
    notifyListeners();
  }

  DeliveryAddress _sanitizeDeliveryAddress(
    DeliveryAddress value, {
    String fallbackCity = '',
  }) {
    final cityFallback = _normalizeAddressValue(
      fallbackCity,
      fallback: '\u041d\u043e\u043e\u043a\u0430\u0442',
    );
    final country = _normalizeAddressValue(
      value.country,
      fallback: '\u041a\u044b\u0440\u0433\u044b\u0437\u0441\u0442\u0430\u043d',
    );
    final city = _normalizeAddressValue(value.city, fallback: cityFallback);
    final address = _normalizeAddressValue(value.address, fallback: city);
    final pickupDefault = '$country, $city';
    final pickup = _normalizeAddressValue(
      value.pickupPointLabel,
      fallback: pickupDefault,
    );
    return DeliveryAddress(
      country: country,
      city: city,
      address: address,
      pickupPointLabel: pickup,
    );
  }

  String _normalizeAddressValue(
    String value, {
    required String fallback,
  }) {
    final normalized = toSafeString(value);
    if (normalized.isEmpty || _isLikelyMojibake(normalized)) {
      return fallback.trim();
    }
    return normalized;
  }

  bool _isLikelyMojibake(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (normalized.contains('\uFFFD')) {
      return true;
    }
    if (normalized.contains('\u00D0') || normalized.contains('\u00D1')) {
      return true;
    }
    if (normalized.contains('\u0420\u00A0') ||
        normalized.contains('\u0420\u2019') ||
        normalized.contains('\u0420\u040b')) {
      return true;
    }
    return false;
  }

  void _persist() {
    final phone = _auth.user?.phone;
    if ((phone ?? '').isEmpty) {
      return;
    }
    _storage.write(
      '$_ordersStoragePrefix$phone',
      _orders.map((order) => order.toJson()).toList(growable: false),
    );
  }

  Map<String, dynamic> _extractOrderMap(Map<String, dynamic> decoded) {
    for (final key in const <String>['order', 'result', 'data']) {
      final value = decoded[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
    return decoded;
  }

  CustomerOrder _mapOrder({
    required Map<String, dynamic> raw,
    required List<CartItem> fallbackItems,
    required DeliveryAddress fallbackAddress,
    required String fallbackPaymentMethod,
    required String fallbackFullName,
    required String fallbackPhone,
  }) {
    final now = DateTime.now().toIso8601String();

    final rawItems = (raw['items'] is List)
        ? raw['items'] as List
        : (raw['order_items'] is List)
            ? raw['order_items'] as List
            : const <dynamic>[];

    final items = <CartItem>[];
    for (final item in rawItems) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final nestedProduct = item['product'];
      final nestedVariant = item['product_variant'];
      final productMap =
          nestedProduct is Map<String, dynamic> ? nestedProduct : null;
      final variantMap =
          nestedVariant is Map<String, dynamic> ? nestedVariant : null;

      final productId = _firstNonEmpty(<String?>[
        toSafeString(item['product_id']),
        toSafeString(item['productId']),
        toSafeString(item['product']),
        toSafeString(productMap?['id']),
      ]);

      final variantId = _firstNonEmpty(<String?>[
        toSafeString(item['product_variant_id']),
        toSafeString(item['variant_id']),
        toSafeString(item['variantId']),
        toSafeString(item['product_variant']),
        toSafeString(variantMap?['id']),
      ]);

      final quantity = _safeInt(
        item['quantity'] ?? item['qty'] ?? item['count'],
        fallback: 1,
      );

      final price = _safeDouble(
        item['price'] ??
            item['unit_price'] ??
            item['amount'] ??
            item['total_price'],
      );

      final title = _firstNonEmpty(<String?>[
        toSafeString(item['title']),
        toSafeString(item['name']),
        toSafeString(productMap?['title']),
        toSafeString(productMap?['name']),
        'Р В Р’В Р вЂ™Р’В Р В Р Р‹Р РЋРІР‚С”Р В Р’В Р вЂ™Р’В Р В Р Р‹Р Р†Р вЂљРЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В°Р В Р’В Р В Р вЂ№Р В Р’В Р Р†Р вЂљРЎв„ў',
      ]);

      final color = _firstNonEmpty(<String?>[
        toSafeString(item['color']),
        toSafeString(variantMap?['color']),
      ]);

      final size = _firstNonEmpty(<String?>[
        toSafeString(item['size']),
        toSafeString(variantMap?['size']),
      ]);

      final image = _firstNonEmpty(<String?>[
        toSafeString(item['image']),
        toSafeString(productMap?['image']),
        '/icon-192.png',
      ]);

      items.add(
        CartItem(
          itemId: [productId, variantId, size, color].join('::'),
          productId: productId,
          slug: _firstNonEmpty(<String?>[
            toSafeString(item['slug']),
            toSafeString(productMap?['slug']),
          ]),
          title: title,
          price: price,
          image: image,
          quantity: quantity,
          size: size.isEmpty ? null : size,
          color: color.isEmpty ? null : color,
          variantId: variantId.isEmpty ? null : variantId,
          maxQuantity: null,
        ),
      );
    }

    final effectiveItems = items.isEmpty ? fallbackItems : items;
    final total = _safeDouble(
      raw['total_amount'] ??
          raw['total_price'] ??
          raw['totalPrice'] ??
          raw['total'] ??
          raw['amount'],
      fallback: effectiveItems.fold<double>(
        0,
        (sum, item) => sum + item.totalPrice,
      ),
    );

    final rawAddress = raw['delivery_address'] ?? raw['deliveryAddress'];
    DeliveryAddress deliveryAddress = fallbackAddress;
    if (rawAddress is Map<String, dynamic>) {
      final pickup = _firstNonEmpty(<String?>[
        toSafeString(rawAddress['pickupPointLabel']),
        toSafeString(rawAddress['pickup_point_label']),
      ]);
      deliveryAddress = DeliveryAddress(
        country: _firstNonEmpty(<String?>[
          toSafeString(rawAddress['country']),
          fallbackAddress.country,
        ]),
        city: _firstNonEmpty(<String?>[
          toSafeString(rawAddress['city']),
          fallbackAddress.city,
        ]),
        address: _firstNonEmpty(<String?>[
          toSafeString(rawAddress['address']),
          fallbackAddress.address,
        ]),
        pickupPointLabel:
            pickup.isEmpty ? fallbackAddress.pickupPointLabel : pickup,
      );
    }

    final normalized = <String, dynamic>{
      'id': _firstNonEmpty(<String?>[
        toSafeString(raw['id']),
        'order-${DateTime.now().microsecondsSinceEpoch}',
      ]),
      'number': _firstNonEmpty(<String?>[
        toSafeString(raw['number']),
        toSafeString(raw['order_number']),
        toSafeString(raw['id']),
      ]),
      'createdAtIso': _firstNonEmpty(<String?>[
        toSafeString(raw['created_at']),
        toSafeString(raw['createdAt']),
        toSafeString(raw['created']),
        now,
      ]),
      'totalPrice': total,
      'paymentMethod': _firstNonEmpty(<String?>[
        toSafeString(raw['payment_method']),
        toSafeString(raw['paymentMethod']),
        fallbackPaymentMethod,
      ]),
      'status': _firstNonEmpty(<String?>[
        toSafeString(raw['status']),
        'created',
      ]),
      'paymentStatus': _firstNonEmpty(<String?>[
        toSafeString(raw['payment_status']),
        toSafeString(raw['paymentStatus']),
        'not_paid',
      ]),
      'items':
          effectiveItems.map((item) => item.toJson()).toList(growable: false),
      'deliveryAddress': deliveryAddress.toJson(),
      'fullName': _firstNonEmpty(<String?>[
        toSafeString(raw['full_name']),
        toSafeString(raw['fullName']),
        fallbackFullName,
      ]),
      'phone': _firstNonEmpty(<String?>[
        toSafeString(raw['phone']),
        fallbackPhone,
      ]),
    };

    return CustomerOrder.fromJson(normalized);
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  int _safeInt(Object? value, {int fallback = 0}) {
    final asInt = toSafeInt(value, fallback: fallback);
    if (asInt <= 0) {
      return fallback <= 0 ? 1 : fallback;
    }
    return asInt;
  }

  double _safeDouble(Object? value, {double fallback = 0}) {
    return toSafeDouble(value, fallback: fallback);
  }
}

class AppStore {
  AppStore._internal();

  static final AppStore instance = AppStore._internal();

  final GetStorage storage = GetStorage();
  late final ApiService api = ApiService();
  late final AuthStore auth = AuthStore(storage, api);
  late final FavoritesStore favorites = FavoritesStore(storage);
  late final CartStore cart = CartStore(storage, auth, api);
  late final OrdersStore orders = OrdersStore(storage, auth, cart, api);
}
