import 'dart:convert';

double toSafeDouble(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

int toSafeInt(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      return parsed;
    }
  }
  return fallback;
}

bool toSafeBool(Object? value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (const <String>{'1', 'true', 'yes', 'y', 'on'}.contains(normalized)) {
      return true;
    }
    if (const <String>{'0', 'false', 'no', 'n', 'off'}.contains(normalized)) {
      return false;
    }
  }
  return fallback;
}

String toSafeString(Object? value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  final normalized = value.toString().trim();
  if (normalized.isEmpty) {
    return fallback;
  }
  return _normalizePotentialMojibake(normalized);
}

String normalizeVariantSizeLabel(Object? value) {
  final normalized = toSafeString(value);
  if (normalized.isEmpty) {
    return '';
  }

  final compact = normalized.toUpperCase().replaceAll(RegExp(r'[\s_\-]+'), '');

  const hiddenSizeMarkers = <String>{
    'ONESIZE',
    'FREESIZE',
    'STANDARD',
    'СТАНДАРТ',
  };

  for (final marker in hiddenSizeMarkers) {
    if (compact == marker || compact.startsWith(marker)) {
      return '';
    }
  }

  return normalized;
}

String _firstNonEmptyImageUrl(Iterable<String?> candidates) {
  for (final raw in candidates) {
    final normalized = normalizeImageUrl(toSafeString(raw));
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _extractImageUrlByKeys(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final direct = normalizeImageUrl(toSafeString(json[key]));
    if (direct.isNotEmpty) {
      return direct;
    }
  }
  return '';
}

String normalizeProductDescription(Object? rawValue) {
  final extracted = _extractDescriptionText(rawValue).trim();
  if (extracted.isEmpty) {
    return '';
  }

  final fixedEncoding = _normalizePotentialMojibake(extracted);
  final withoutHtml = _stripHtmlTags(fixedEncoding);
  final decodedEntities = _decodeHtmlEntities(withoutHtml);
  final normalized = _normalizeDescriptionWhitespace(decodedEntities);
  final withoutNoise = _removeDescriptionNoise(normalized);

  if (withoutNoise.isEmpty || _looksLikeMachinePayload(withoutNoise)) {
    return '';
  }

  return _truncateDescription(withoutNoise);
}

String _extractDescriptionText(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String || value is num || value is bool) {
    return value.toString();
  }
  if (value is List) {
    final chunks = <String>[];
    for (final item in value) {
      final text = _extractDescriptionText(item).trim();
      if (text.isNotEmpty) {
        chunks.add(text);
      }
    }
    return chunks.join('\n');
  }
  if (value is Map) {
    final map = value.cast<Object?, Object?>();
    for (final key in const <String>[
      'description',
      'full_description',
      'fullDescription',
      'short_description',
      'shortDescription',
      'summary',
      'text',
      'content',
      'body',
      'value',
      'details',
    ]) {
      final nested = _extractDescriptionText(map[key]).trim();
      if (nested.isNotEmpty) {
        return nested;
      }
    }

    final chunks = <String>[];
    for (final entry in map.entries) {
      if (chunks.length >= 4) {
        break;
      }
      final keyName = entry.key?.toString().toLowerCase() ?? '';
      if (keyName.contains('id') ||
          keyName.contains('url') ||
          keyName.contains('image') ||
          keyName.contains('photo') ||
          keyName.contains('price') ||
          keyName.contains('stock')) {
        continue;
      }
      final nested = _extractDescriptionText(entry.value).trim();
      if (nested.isNotEmpty && nested.length > 2) {
        chunks.add(nested);
      }
    }
    return chunks.join('\n');
  }
  return '';
}

final Map<int, int> _cp1251ByteByCodePoint = _buildCp1251ByteByCodePoint();

Map<int, int> _buildCp1251ByteByCodePoint() {
  final map = <int, int>{};
  for (int byte = 0x80; byte <= 0xFF; byte += 1) {
    final codePoint = _cp1251CodePointFromByte(byte);
    if (codePoint != null) {
      map[codePoint] = byte;
    }
  }
  return map;
}

int? _cp1251CodePointFromByte(int byte) {
  if (byte < 0x80 || byte > 0xFF) {
    return null;
  }
  if (byte >= 0xC0) {
    return 0x0410 + (byte - 0xC0);
  }

  switch (byte) {
    case 0x80:
      return 0x0402;
    case 0x81:
      return 0x0403;
    case 0x82:
      return 0x201A;
    case 0x83:
      return 0x0453;
    case 0x84:
      return 0x201E;
    case 0x85:
      return 0x2026;
    case 0x86:
      return 0x2020;
    case 0x87:
      return 0x2021;
    case 0x88:
      return 0x20AC;
    case 0x89:
      return 0x2030;
    case 0x8A:
      return 0x0409;
    case 0x8B:
      return 0x2039;
    case 0x8C:
      return 0x040A;
    case 0x8D:
      return 0x040C;
    case 0x8E:
      return 0x040B;
    case 0x8F:
      return 0x040F;
    case 0x90:
      return 0x0452;
    case 0x91:
      return 0x2018;
    case 0x92:
      return 0x2019;
    case 0x93:
      return 0x201C;
    case 0x94:
      return 0x201D;
    case 0x95:
      return 0x2022;
    case 0x96:
      return 0x2013;
    case 0x97:
      return 0x2014;
    case 0x99:
      return 0x2122;
    case 0x9A:
      return 0x0459;
    case 0x9B:
      return 0x203A;
    case 0x9C:
      return 0x045A;
    case 0x9D:
      return 0x045C;
    case 0x9E:
      return 0x045B;
    case 0x9F:
      return 0x045F;
    case 0xA0:
      return 0x00A0;
    case 0xA1:
      return 0x040E;
    case 0xA2:
      return 0x045E;
    case 0xA3:
      return 0x0408;
    case 0xA4:
      return 0x00A4;
    case 0xA5:
      return 0x0490;
    case 0xA6:
      return 0x00A6;
    case 0xA7:
      return 0x00A7;
    case 0xA8:
      return 0x0401;
    case 0xA9:
      return 0x00A9;
    case 0xAA:
      return 0x0404;
    case 0xAB:
      return 0x00AB;
    case 0xAC:
      return 0x00AC;
    case 0xAD:
      return 0x00AD;
    case 0xAE:
      return 0x00AE;
    case 0xAF:
      return 0x0407;
    case 0xB0:
      return 0x00B0;
    case 0xB1:
      return 0x00B1;
    case 0xB2:
      return 0x0406;
    case 0xB3:
      return 0x0456;
    case 0xB4:
      return 0x0491;
    case 0xB5:
      return 0x00B5;
    case 0xB6:
      return 0x00B6;
    case 0xB7:
      return 0x00B7;
    case 0xB8:
      return 0x0451;
    case 0xB9:
      return 0x2116;
    case 0xBA:
      return 0x0454;
    case 0xBB:
      return 0x00BB;
    case 0xBC:
      return 0x0458;
    case 0xBD:
      return 0x0405;
    case 0xBE:
      return 0x0455;
    case 0xBF:
      return 0x0457;
    default:
      return null;
  }
}

bool _isCp1251UpperHalfSpecial(int rune) {
  final byte = _cp1251ByteByCodePoint[rune];
  if (byte == null) {
    return false;
  }
  return byte >= 0x80 && byte < 0xC0;
}

String _normalizePotentialMojibake(String value) {
  var best = value;
  var bestScore = _textQualityScore(value);

  final candidates = <String>{
    _tryDecodeUtf8Mojibake(value),
    _tryDecodeUtf8FromCp1251Mojibake(value),
  };
  for (final candidate in candidates) {
    if (candidate.isEmpty) {
      continue;
    }
    final score = _textQualityScore(candidate);
    if (score > bestScore + 0.5) {
      best = candidate;
      bestScore = score;
    }
  }

  return best;
}

String _tryDecodeUtf8Mojibake(String value) {
  if (value.isEmpty || !_looksLikeUtf8Mojibake(value)) {
    return value;
  }
  try {
    final decoded = utf8.decode(latin1.encode(value)).trim();
    if (decoded.isEmpty) {
      return value;
    }
    return _textQualityScore(decoded) >= _textQualityScore(value)
        ? decoded
        : value;
  } catch (_) {
    return value;
  }
}

String _tryDecodeUtf8FromCp1251Mojibake(String value) {
  if (value.isEmpty || !_looksLikeCp1251Mojibake(value)) {
    return value;
  }

  final bytes = <int>[];
  for (final rune in value.runes) {
    if (rune <= 0x7F) {
      bytes.add(rune);
      continue;
    }
    final byte = _cp1251ByteByCodePoint[rune];
    if (byte == null) {
      return value;
    }
    bytes.add(byte);
  }

  try {
    final decoded = utf8.decode(bytes).trim();
    if (decoded.isEmpty) {
      return value;
    }
    return _textQualityScore(decoded) >= _textQualityScore(value)
        ? decoded
        : value;
  } catch (_) {
    return value;
  }
}

bool _looksLikeUtf8Mojibake(String value) {
  int markerCount = 0;
  for (final unit in value.codeUnits) {
    if (unit == 0x00D0 || unit == 0x00D1 || unit == 0x00C2 || unit == 0x00C3) {
      markerCount += 1;
    }
  }
  return markerCount >= 2;
}

bool _looksLikeCp1251Mojibake(String value) {
  int specialCount = 0;
  for (final rune in value.runes) {
    if (_isCp1251UpperHalfSpecial(rune)) {
      specialCount += 1;
    }
  }
  if (specialCount < 2) {
    return false;
  }

  final pairCount = RegExp(r'[РС][\u0400-\u045F]').allMatches(value).length;
  return pairCount >= 2;
}

double _textQualityScore(String value) {
  if (value.isEmpty) {
    return 0;
  }
  int letters = 0;
  int markers = 0;
  int cp1251Special = 0;
  for (final rune in value.runes) {
    final isAsciiLetter =
        (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
    final isCyrillic = rune >= 0x0400 && rune <= 0x04FF;
    if (isAsciiLetter || isCyrillic) {
      letters += 1;
    }
    if (rune == 0x00D0 || rune == 0x00D1 || rune == 0x00C2 || rune == 0x00C3) {
      markers += 1;
    }
    if (_isCp1251UpperHalfSpecial(rune)) {
      cp1251Special += 1;
    }
  }
  final cp1251PairCount =
      RegExp(r'[РС][\u0400-\u045F]').allMatches(value).length;
  return letters -
      (markers * 2.5) -
      (cp1251Special * 1.8) -
      (cp1251PairCount * 1.4);
}

String _stripHtmlTags(String value) {
  var text = value;
  text = text.replaceAll(
    RegExp(
      r'<(script|style)[^>]*>.*?</\1>',
      caseSensitive: false,
      dotAll: true,
    ),
    ' ',
  );
  text = text.replaceAll(
    RegExp(r'<\s*br\s*/?>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(
    RegExp(r'</\s*(p|div|li|tr|h[1-6])\s*>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(
    RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true),
    ' ',
  );
  return text;
}

String _decodeHtmlEntities(String value) {
  var text = value;
  final namedEntities = <String, String>{
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&#39;': "'",
    '&lt;': '<',
    '&gt;': '>',
  };
  for (final entry in namedEntities.entries) {
    text = text.replaceAll(
      RegExp(entry.key, caseSensitive: false),
      entry.value,
    );
  }

  text = text.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (match) {
      final codePoint = int.tryParse(match.group(1) ?? '');
      if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
        return match.group(0) ?? '';
      }
      return String.fromCharCode(codePoint);
    },
  );
  text = text.replaceAllMapped(
    RegExp(r'&#x([0-9a-fA-F]+);'),
    (match) {
      final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
      if (codePoint == null || codePoint < 0 || codePoint > 0x10FFFF) {
        return match.group(0) ?? '';
      }
      return String.fromCharCode(codePoint);
    },
  );
  return text;
}

String _normalizeDescriptionWhitespace(String value) {
  final lines = value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return lines.join('\n').trim();
}

String _removeDescriptionNoise(String value) {
  if (value.isEmpty) {
    return '';
  }

  final lines = value.split('\n');
  final filtered = <String>[];
  final seen = <String>{};

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final lower = line.toLowerCase();
    if (_isPromotionalLine(lower) || _isPriceNoiseLine(line, lower)) {
      continue;
    }
    if (lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('www.')) {
      continue;
    }

    if (!seen.add(lower)) {
      continue;
    }
    filtered.add(line);
  }

  if (filtered.isEmpty) {
    return '';
  }
  return filtered.join('\n');
}

bool _isPromotionalLine(String lower) {
  for (final marker in const <String>[
    'shopkeeper',
    'hot recommendation',
    'hot sale',
    'recommended',
    'recommendation',
    'flash sale',
    'best seller',
    'new arrivals',
  ]) {
    if (lower.contains(marker)) {
      return true;
    }
  }
  return false;
}

bool _isPriceNoiseLine(String line, String lower) {
  final hasDigits = RegExp(r'\d').hasMatch(line);
  final hasCurrency = line.contains('\$') ||
      line.contains('\u00A5') ||
      line.contains('\u20AC') ||
      line.contains('\u20BD');
  final hasPriceWord =
      lower.contains('price') || lower.contains('carnival price');
  if (hasDigits && hasCurrency && hasPriceWord) {
    return true;
  }

  final digitCount = RegExp(r'\d').allMatches(line).length;
  int letterCount = 0;
  for (final rune in line.runes) {
    final isLatin =
        (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
    final isCyrillic = rune >= 0x0400 && rune <= 0x04FF;
    if (isLatin || isCyrillic) {
      letterCount += 1;
    }
  }
  if (digitCount >= 6 && letterCount <= 4) {
    return true;
  }

  if (RegExp(r'^(price|carnival price)\b', caseSensitive: false)
          .hasMatch(line) &&
      hasDigits) {
    return true;
  }
  return false;
}

bool _looksLikeMachinePayload(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  if ((compact.startsWith('{') && compact.endsWith('}')) ||
      (compact.startsWith('[') && compact.endsWith(']'))) {
    return true;
  }
  return false;
}

String _truncateDescription(String value) {
  const maxLines = 10;
  const maxLength = 400;

  final lines = value.split('\n');
  var normalized = lines.take(maxLines).join('\n').trim();
  if (normalized.length <= maxLength) {
    return normalized;
  }

  normalized = normalized.substring(0, maxLength).trimRight();
  final safeCut = normalized.lastIndexOf(' ');
  if (safeCut > maxLength - 40) {
    normalized = normalized.substring(0, safeCut);
  }
  return '$normalized...';
}

class ProductImageModel {
  const ProductImageModel({
    required this.url,
    required this.isMain,
    this.thumbUrl = '',
    this.mediumUrl = '',
    this.largeUrl = '',
  });

  final String url;
  final bool isMain;
  final String thumbUrl;
  final String mediumUrl;
  final String largeUrl;

  String get listImage =>
      _firstNonEmptyImageUrl(<String>[mediumUrl, thumbUrl, largeUrl, url]);
  String get detailImage =>
      _firstNonEmptyImageUrl(<String>[largeUrl, url, mediumUrl, thumbUrl]);

  factory ProductImageModel.fromJson(Map<String, dynamic> json) {
    final original = _extractImageUrlByKeys(
      json,
      const <String>[
        'image',
        'url',
        'src',
        'main_image',
        'mainImage',
      ],
    );
    final thumb = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_thumb',
        'thumb',
        'thumbnail',
        'preview',
        'small',
        'small_image',
        'smallImage',
      ],
    );
    final medium = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_medium',
        'medium',
        'medium_image',
        'mediumImage',
      ],
    );
    final large = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_large',
        'large',
        'large_image',
        'largeImage',
        'original',
        'full',
      ],
    );
    return ProductImageModel(
      url: _firstNonEmptyImageUrl(<String>[original, large, medium, thumb]),
      isMain: json['is_main'] == true,
      thumbUrl: _firstNonEmptyImageUrl(<String>[thumb, medium, original]),
      mediumUrl: _firstNonEmptyImageUrl(<String>[medium, large, original]),
      largeUrl: _firstNonEmptyImageUrl(<String>[large, original, medium]),
    );
  }
}

class ProductVariantModel {
  const ProductVariantModel({
    required this.id,
    required this.color,
    required this.size,
    required this.price,
    required this.quantity,
  });

  final String id;
  final String color;
  final String size;
  final double? price;
  final int? quantity;

  bool get inStock {
    if (quantity == null) {
      return true;
    }
    return quantity! > 0;
  }

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    final rawQuantity = json['quantity'];
    final hasQuantity = rawQuantity != null;
    return ProductVariantModel(
      id: toSafeString(
        json['id'] ?? json['product_variant_id'] ?? json['variant_id'],
      ),
      color: toSafeString(json['color']),
      size: normalizeVariantSizeLabel(json['size']),
      price: json['price'] == null ? null : toSafeDouble(json['price']),
      quantity: hasQuantity ? toSafeInt(rawQuantity) : null,
    );
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.price,
    required this.oldPrice,
    required this.description,
    required this.rating,
    required this.reviewsCount,
    required this.images,
    required this.imageThumb,
    required this.imageMedium,
    required this.imageLarge,
    required this.categoryId,
    required this.categoryName,
    required this.stock,
    required this.variants,
    required this.isAdult,
    required this.ageRestricted,
  });

  final String id;
  final String slug;
  final String title;
  final double price;
  final double? oldPrice;
  final String description;
  final double rating;
  final int reviewsCount;
  final List<ProductImageModel> images;
  final String imageThumb;
  final String imageMedium;
  final String imageLarge;
  final String categoryId;
  final String categoryName;
  final int? stock;
  final List<ProductVariantModel> variants;
  final bool isAdult;
  final bool ageRestricted;

  bool get isAdultRestricted => isAdult || ageRestricted;

  ProductModel copyWith({
    String? description,
    bool? isAdult,
    bool? ageRestricted,
  }) {
    return ProductModel(
      id: id,
      slug: slug,
      title: title,
      price: price,
      oldPrice: oldPrice,
      description: description ?? this.description,
      rating: rating,
      reviewsCount: reviewsCount,
      images: images,
      imageThumb: imageThumb,
      imageMedium: imageMedium,
      imageLarge: imageLarge,
      categoryId: categoryId,
      categoryName: categoryName,
      stock: stock,
      variants: variants,
      isAdult: isAdult ?? this.isAdult,
      ageRestricted: ageRestricted ?? this.ageRestricted,
    );
  }

  String get routeId => slug.isNotEmpty ? slug : id;

  String get mainImage {
    final preferredMain = _firstNonEmptyImageUrl(
      <String>[imageLarge, imageMedium, imageThumb],
    );
    for (final image in images) {
      if (image.isMain && image.url.isNotEmpty) {
        return image.url;
      }
    }
    for (final image in images) {
      if (image.url.isNotEmpty) {
        return image.url;
      }
    }
    return preferredMain;
  }

  String get thumbnailImage =>
      _firstNonEmptyImageUrl(<String>[imageThumb, imageMedium, mainImage]);

  String get catalogImage =>
      _firstNonEmptyImageUrl(<String>[imageMedium, imageThumb, mainImage]);

  String get detailImage =>
      _firstNonEmptyImageUrl(<String>[imageLarge, mainImage, imageMedium]);

  List<String> get detailImages {
    final urls = <String>[];
    final seen = <String>{};

    void addUrl(String value) {
      final normalized = normalizeImageUrl(value);
      if (normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      urls.add(normalized);
    }

    addUrl(detailImage);
    for (final image in images) {
      addUrl(image.detailImage);
    }

    if (urls.isEmpty) {
      addUrl(mainImage);
    }
    return urls;
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'];
    final rawCategory = json['category'];
    final rawVariants = json['variants'];

    String categoryId = '';
    String categoryName = '';
    if (rawCategory is Map<String, dynamic>) {
      categoryId = toSafeString(rawCategory['id']);
      categoryName = toSafeString(
        rawCategory['name'] ?? rawCategory['title'],
      );
    } else if (rawCategory is String) {
      categoryName = toSafeString(rawCategory);
    }

    final images = <ProductImageModel>[];
    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is Map<String, dynamic>) {
          images.add(ProductImageModel.fromJson(item));
        }
      }
    }

    final topThumb = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_thumb',
        'thumbnail',
        'thumb',
        'preview',
        'small_image',
        'smallImage',
      ],
    );
    final topMedium = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_medium',
        'medium',
        'medium_image',
        'mediumImage',
      ],
    );
    final topLarge = _extractImageUrlByKeys(
      json,
      const <String>[
        'image_large',
        'large',
        'large_image',
        'largeImage',
        'original',
      ],
    );
    final topOriginal = _extractImageUrlByKeys(
      json,
      const <String>[
        'image',
        'main_image',
        'mainImage',
        'photo',
        'picture',
      ],
    );

    if (images.isEmpty) {
      final fallback = _firstNonEmptyImageUrl(
        <String>[topOriginal, topLarge, topMedium, topThumb],
      );
      if (fallback.isNotEmpty) {
        images.add(
          ProductImageModel(
            url: fallback,
            isMain: true,
            thumbUrl: _firstNonEmptyImageUrl(<String>[topThumb, topMedium]),
            mediumUrl: _firstNonEmptyImageUrl(<String>[topMedium, topLarge]),
            largeUrl: _firstNonEmptyImageUrl(<String>[topLarge, topOriginal]),
          ),
        );
      }
    }

    String pickFromImages(String Function(ProductImageModel image) resolver) {
      for (final image in images) {
        final value = resolver(image);
        if (value.isNotEmpty) {
          return value;
        }
      }
      return '';
    }

    final imageThumb = _firstNonEmptyImageUrl(
      <String>[topThumb, pickFromImages((image) => image.thumbUrl)],
    );
    final imageMedium = _firstNonEmptyImageUrl(
      <String>[
        topMedium,
        pickFromImages((image) => image.mediumUrl),
        imageThumb,
      ],
    );
    final imageLarge = _firstNonEmptyImageUrl(
      <String>[
        topLarge,
        topOriginal,
        pickFromImages((image) => image.largeUrl),
        pickFromImages((image) => image.url),
        imageMedium,
      ],
    );

    final variants = <ProductVariantModel>[];
    if (rawVariants is List) {
      for (final item in rawVariants) {
        if (item is Map<String, dynamic>) {
          variants.add(ProductVariantModel.fromJson(item));
        }
      }
    }

    final rawStock = json['stock'];
    final hasStock = rawStock != null;
    final oldPriceValue = toSafeDouble(json['old_price']);
    final oldPrice = oldPriceValue > 0 ? oldPriceValue : null;
    final isAdult = toSafeBool(
      json['isAdult'] ??
          json['is_adult'] ??
          json['adult'] ??
          json['adult_only'] ??
          json['is_18_plus'],
    );
    final ageRestricted = toSafeBool(
      json['ageRestricted'] ??
          json['age_restricted'] ??
          json['restricted_18'] ??
          json['requires_age_confirmation'],
    );

    return ProductModel(
      id: toSafeString(json['id']),
      slug: toSafeString(json['slug']),
      title: toSafeString(json['title'], fallback: 'Без названия'),
      price: toSafeDouble(json['price']),
      oldPrice: oldPrice,
      description: normalizeProductDescription(
        json['description'] ??
            json['full_description'] ??
            json['short_description'] ??
            json['details'],
      ),
      rating: toSafeDouble(json['rating']),
      reviewsCount: toSafeInt(json['reviews_count']),
      images: images,
      imageThumb: imageThumb,
      imageMedium: imageMedium,
      imageLarge: imageLarge,
      categoryId: categoryId,
      categoryName: categoryName,
      stock: hasStock ? toSafeInt(rawStock) : null,
      variants: variants,
      isAdult: isAdult,
      ageRestricted: ageRestricted,
    );
  }
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.image,
    required this.productsCount,
  });

  final String id;
  final String name;
  final String image;
  final int productsCount;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: toSafeString(json['id']),
      name: toSafeString(
        json['name'] ?? json['title'],
        fallback: 'Без названия',
      ),
      image: normalizeImageUrl(
        toSafeString(json['image'] ?? json['icon']),
      ),
      productsCount: toSafeInt(json['products_count'] ?? json['item_qty']),
    );
  }
}

class PaginatedProducts {
  const PaginatedProducts({
    required this.results,
    required this.nextPage,
    required this.hasMore,
  });

  final List<ProductModel> results;
  final int? nextPage;
  final bool hasMore;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.city,
    required this.photo,
    required this.createdAtIso,
    required this.updatedAtIso,
    required this.deliveryAddress,
  });

  final String id;
  final String phone;
  final String fullName;
  final String city;
  final String? photo;
  final String createdAtIso;
  final String updatedAtIso;
  final DeliveryAddress? deliveryAddress;

  AuthUser copyWith({
    String? fullName,
    String? city,
    String? photo,
    DeliveryAddress? deliveryAddress,
  }) {
    return AuthUser(
      id: id,
      phone: phone,
      fullName: fullName ?? this.fullName,
      city: city ?? this.city,
      photo: photo ?? this.photo,
      createdAtIso: createdAtIso,
      updatedAtIso: DateTime.now().toIso8601String(),
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'fullName': fullName,
      'city': city,
      'photo': photo,
      'createdAt': createdAtIso,
      'updatedAt': updatedAtIso,
      'deliveryAddress': deliveryAddress?.toJson(),
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawDelivery = json['deliveryAddress'];
    return AuthUser(
      id: toSafeString(json['id']),
      phone: toSafeString(json['phone']),
      fullName: toSafeString(json['fullName']),
      city: toSafeString(json['city']),
      photo: toSafeString(json['photo']).isEmpty
          ? null
          : toSafeString(json['photo']),
      createdAtIso: toSafeString(
        json['createdAt'],
        fallback: DateTime.now().toIso8601String(),
      ),
      updatedAtIso: toSafeString(
        json['updatedAt'],
        fallback: DateTime.now().toIso8601String(),
      ),
      deliveryAddress: rawDelivery is Map<String, dynamic>
          ? DeliveryAddress.fromJson(rawDelivery)
          : null,
    );
  }
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.country,
    required this.city,
    required this.address,
    required this.pickupPointLabel,
  });

  final String country;
  final String city;
  final String address;
  final String pickupPointLabel;

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'city': city,
      'address': address,
      'pickupPointLabel': pickupPointLabel,
    };
  }

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      country: toSafeString(json['country']),
      city: toSafeString(json['city']),
      address: toSafeString(json['address']),
      pickupPointLabel: toSafeString(json['pickupPointLabel']),
    );
  }
}

class FavoriteItem {
  const FavoriteItem({
    required this.productId,
    required this.slug,
    required this.title,
    required this.price,
    required this.image,
    required this.rating,
    required this.reviewsCount,
    required this.isAdult,
    required this.ageRestricted,
  });

  final String productId;
  final String slug;
  final String title;
  final double price;
  final String image;
  final double? rating;
  final int? reviewsCount;
  final bool isAdult;
  final bool ageRestricted;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'slug': slug,
      'title': title,
      'price': price,
      'image': image,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'isAdult': isAdult,
      'ageRestricted': ageRestricted,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      productId: toSafeString(json['productId']),
      slug: toSafeString(json['slug']),
      title: toSafeString(json['title']),
      price: toSafeDouble(json['price']),
      image: toSafeString(json['image'], fallback: '/icon-192.png'),
      rating: json['rating'] == null ? null : toSafeDouble(json['rating']),
      reviewsCount:
          json['reviewsCount'] == null ? null : toSafeInt(json['reviewsCount']),
      isAdult: toSafeBool(json['isAdult'] ?? json['is_adult']),
      ageRestricted:
          toSafeBool(json['ageRestricted'] ?? json['age_restricted']),
    );
  }
}

class CartItem {
  const CartItem({
    required this.itemId,
    required this.productId,
    required this.slug,
    required this.title,
    required this.price,
    required this.image,
    required this.quantity,
    required this.size,
    required this.color,
    required this.variantId,
    required this.maxQuantity,
    required this.isAdult,
    required this.ageRestricted,
  });

  final String itemId;
  final String productId;
  final String slug;
  final String title;
  final double price;
  final String image;
  final int quantity;
  final String? size;
  final String? color;
  final String? variantId;
  final int? maxQuantity;
  final bool isAdult;
  final bool ageRestricted;

  bool get isAdultRestricted => isAdult || ageRestricted;

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? title,
    String? slug,
    double? price,
    String? image,
    int? quantity,
    String? size,
    String? color,
    String? variantId,
    int? maxQuantity,
    bool? isAdult,
    bool? ageRestricted,
  }) {
    return CartItem(
      itemId: itemId,
      productId: productId,
      slug: slug ?? this.slug,
      title: title ?? this.title,
      price: price ?? this.price,
      image: image ?? this.image,
      quantity: quantity ?? this.quantity,
      size: size ?? this.size,
      color: color ?? this.color,
      variantId: variantId ?? this.variantId,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      isAdult: isAdult ?? this.isAdult,
      ageRestricted: ageRestricted ?? this.ageRestricted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'productId': productId,
      'slug': slug,
      'title': title,
      'price': price,
      'image': image,
      'quantity': quantity,
      'size': size,
      'color': color,
      'variantId': variantId,
      'maxQuantity': maxQuantity,
      'isAdult': isAdult,
      'ageRestricted': ageRestricted,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      itemId: toSafeString(json['itemId']),
      productId: toSafeString(json['productId']),
      slug: toSafeString(json['slug']),
      title: toSafeString(json['title']),
      price: toSafeDouble(json['price']),
      image: toSafeString(json['image'], fallback: '/icon-192.png'),
      quantity: toSafeInt(json['quantity'], fallback: 1),
      size: normalizeVariantSizeLabel(json['size']).isEmpty
          ? null
          : normalizeVariantSizeLabel(json['size']),
      color: toSafeString(json['color']).isEmpty
          ? null
          : toSafeString(json['color']),
      variantId: toSafeString(json['variantId']).isEmpty
          ? null
          : toSafeString(json['variantId']),
      maxQuantity:
          json['maxQuantity'] == null ? null : toSafeInt(json['maxQuantity']),
      isAdult: toSafeBool(json['isAdult'] ?? json['is_adult']),
      ageRestricted:
          toSafeBool(json['ageRestricted'] ?? json['age_restricted']),
    );
  }
}

class CustomerOrder {
  const CustomerOrder({
    required this.id,
    required this.number,
    required this.createdAtIso,
    required this.totalPrice,
    required this.paymentMethod,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.deliveryAddress,
    required this.fullName,
    required this.phone,
  });

  final String id;
  final String number;
  final String createdAtIso;
  final double totalPrice;
  final String paymentMethod;
  final String status;
  final String paymentStatus;
  final List<CartItem> items;
  final DeliveryAddress deliveryAddress;
  final String fullName;
  final String phone;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'createdAtIso': createdAtIso,
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod,
      'status': status,
      'paymentStatus': paymentStatus,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'deliveryAddress': deliveryAddress.toJson(),
      'fullName': fullName,
      'phone': phone,
    };
  }

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CartItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          items.add(CartItem.fromJson(item));
        }
      }
    }

    final rawDelivery = json['deliveryAddress'] ?? json['delivery_address'];
    final rawTotal = json['totalPrice'] ??
        json['total_amount'] ??
        json['total_price'] ??
        json['total'] ??
        json['amount'];
    return CustomerOrder(
      id: toSafeString(json['id']),
      number: toSafeString(json['number'] ?? json['order_number']),
      createdAtIso: toSafeString(
        json['createdAtIso'] ?? json['created_at'] ?? json['createdAt'],
      ),
      totalPrice: toSafeDouble(rawTotal),
      paymentMethod: toSafeString(
        json['paymentMethod'] ?? json['payment_method'],
      ),
      status: toSafeString(json['status'], fallback: 'created'),
      paymentStatus: toSafeString(
        json['paymentStatus'] ?? json['payment_status'],
        fallback: 'not_paid',
      ),
      items: items,
      deliveryAddress: rawDelivery is Map<String, dynamic>
          ? DeliveryAddress.fromJson(rawDelivery)
          : const DeliveryAddress(
              country: 'Кыргызстан',
              city: 'Ноокат',
              address: 'Пункт выдачи',
              pickupPointLabel: 'Ошская область, Ноокат',
            ),
      fullName: toSafeString(json['fullName'] ?? json['full_name']),
      phone: toSafeString(json['phone']),
    );
  }
}

String normalizeImageUrl(String value) {
  if (value.isEmpty) {
    return '';
  }
  if (value.startsWith('http://')) {
    return 'https://${value.substring(7)}';
  }
  if (value.startsWith('//')) {
    return 'https:$value';
  }
  if (value.startsWith('/')) {
    return 'https://kumarket.net$value';
  }
  return value;
}

List<Map<String, dynamic>> decodeJsonList(String raw) {
  if (raw.isEmpty) {
    return <Map<String, dynamic>>[];
  }
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return <Map<String, dynamic>>[];
  }
  final list = <Map<String, dynamic>>[];
  for (final item in decoded) {
    if (item is Map<String, dynamic>) {
      list.add(item);
    }
  }
  return list;
}
