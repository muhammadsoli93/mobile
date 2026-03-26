import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.created,
  });

  final bool created;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final AppStore _app = AppStore.instance;

  @override
  void initState() {
    super.initState();
    _app.orders.addListener(_rebuild);
    _app.auth.addListener(_rebuild);
  }

  @override
  void dispose() {
    _app.orders.removeListener(_rebuild);
    _app.auth.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _app.auth.user;
    if (user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Для просмотра заказов войдите в аккаунт.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context
                    .push('/auth?redirect=${Uri.encodeComponent('/orders')}'),
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = _app.orders.orders;
    if (orders.isEmpty) {
      return Container(
        color: const Color(0xFFF2F2F7),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 50, color: Color(0xFF9CA3AF)),
                const SizedBox(height: 8),
                const Text(
                  'Заказов пока нет',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Оформите заказ в корзине, и он появится здесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
        children: [
          const Text(
            'Мои заказы',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (widget.created)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F9EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x8034C759)),
              ),
              child: const Text(
                'Заказ успешно создан.',
                style: TextStyle(
                  color: Color(0xFF1E7E34),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 10),
          ...orders.map((order) => _OrderCard(order: order)),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
  });

  final CustomerOrder order;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(order.createdAtIso);
    final createdLabel = createdAt == null
        ? order.createdAtIso
        : '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1F3C3C43)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.number,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _OrderBadge(
                text: order.paymentStatus == 'paid' ? 'Оплачен' : 'Не оплачен',
                accent: order.paymentStatus == 'paid',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${order.totalPrice.toStringAsFixed(0)} сом',
            style: const TextStyle(
              color: Color(0xFF7B2CF5),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            createdLabel,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress.pickupPointLabel,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '- ${item.title} x${item.quantity}',
                style: const TextStyle(
                  color: Color(0xFF4B5563),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({
    required this.text,
    required this.accent,
  });

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFF3E8FF) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: accent ? const Color(0xFF7B2CF5) : const Color(0xFF667085),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({
    super.key,
    required this.regionSlug,
  });

  final String? regionSlug;

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final AppStore _app = AppStore.instance;

  static const List<_PickupRegion> _regions = <_PickupRegion>[
    _PickupRegion(
      slug: 'bishkek',
      name: 'Бишкек',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'bishkek-pervomaysky',
          name: 'Первомайский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'bishkek-leninsky',
          name: 'Ленинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'bishkek-oktyabrsky',
          name: 'Октябрьский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'bishkek-sverdlovsky',
          name: 'Свердловский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'chuy',
      name: 'Чуйская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'chuy-tokmok',
          name: 'Токмок',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-kara-balta',
          name: 'Кара-Балта',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-kant',
          name: 'Кант',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-shopokov',
          name: 'Шопоков',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-alamudun',
          name: 'Аламудунский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-ysyk-ata',
          name: 'Ысык-Атинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-jaiyl',
          name: 'Жайылский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-kemin',
          name: 'Кеминский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-moskva',
          name: 'Московский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-panfilov',
          name: 'Панфиловский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-sokuluk',
          name: 'Сокулукский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'chuy-chui',
          name: 'Чуйский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'issyk-kul',
      name: 'Иссык-Кульская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'issyk-kul-karakol',
          name: 'Каракол',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-balykchy',
          name: 'Балыкчы',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-cholpon-ata',
          name: 'Чолпон-Ата',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-ak-suu',
          name: 'Ак-Суйский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-jeti-oguz',
          name: 'Джети-Огузский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-issyk-kul',
          name: 'Иссык-Кульский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-ton',
          name: 'Тонский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'issyk-kul-tyup',
          name: 'Тюпский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'naryn',
      name: 'Нарынская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'naryn-city',
          name: 'Нарын',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'naryn-at-bashy',
          name: 'Ат-Башинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'naryn-ak-talaa',
          name: 'Ак-Талинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'naryn-jumgal',
          name: 'Жумгальский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'naryn-kochkor',
          name: 'Кочкорский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'naryn-naryn',
          name: 'Нарынский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'talas',
      name: 'Таласская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'talas-city',
          name: 'Талас',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'talas-bakai-ata',
          name: 'Бакай-Атинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'talas-kara-buura',
          name: 'Кара-Бууринский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'talas-manas',
          name: 'Манасский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'talas-talas',
          name: 'Таласский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'jalal-abad',
      name: 'Жалал-Абадская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'jalal-abad-city',
          name: 'Жалал-Абад',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-kara-kul',
          name: 'Кара-Куль',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-kerben',
          name: 'Кербен',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-kok-jangak',
          name: 'Кок-Жангак',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-mailuu-suu',
          name: 'Майлуу-Суу',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-tash-kumyr',
          name: 'Таш-Кумыр',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-aksy',
          name: 'Аксыйский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-ala-buka',
          name: 'Ала-Букинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-bazar-korgon',
          name: 'Базар-Коргонский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-nooken',
          name: 'Ноокенский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-suzak',
          name: 'Сузакский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-toktogul',
          name: 'Токтогульский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-toguz-toro',
          name: 'Тогуз-Тороуский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'jalal-abad-chatkal',
          name: 'Чаткальский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'osh',
      name: 'Ошская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'osh-city',
          name: 'Ош',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-kara-suu',
          name: 'Кара-Суу',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-uzgen',
          name: 'Узген',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-nookat',
          name: 'Ноокат',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.available,
        ),
        _PickupPoint(
          slug: 'osh-aravan',
          name: 'Араванский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-alay',
          name: 'Алайский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-kara-kuldzha',
          name: 'Кара-Кулджинский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-kara-suu-district',
          name: 'Кара-Суйский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-nookat-district',
          name: 'Ноокатский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-uzgen-district',
          name: 'Узгенский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'osh-chon-alai',
          name: 'Чон-Алайский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
    _PickupRegion(
      slug: 'batken',
      name: 'Баткенская область',
      points: <_PickupPoint>[
        _PickupPoint(
          slug: 'batken-city',
          name: 'Баткен',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-kyzyl-kiya',
          name: 'Кызыл-Кыя',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-sulukta',
          name: 'Сулюкта',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-razzakov',
          name: 'Раззаков',
          kind: _PickupPointKind.city,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-batken',
          name: 'Баткенский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-kadamjai',
          name: 'Кадамжайский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
        _PickupPoint(
          slug: 'batken-leilek',
          name: 'Лейлекский район',
          kind: _PickupPointKind.district,
          availability: _PickupAvailability.developing,
        ),
      ],
    ),
  ];

  String? _manualSelectedPointSlug;
  bool _authRedirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _app.auth.addListener(_rebuild);
  }

  @override
  void dispose() {
    _app.auth.removeListener(_rebuild);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DeliveryAddressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.regionSlug != widget.regionSlug) {
      _manualSelectedPointSlug = null;
    }
  }

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  _PickupRegion? _regionBySlug(String? slug) {
    final normalized = (slug ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final region in _regions) {
      if (region.slug == normalized) {
        return region;
      }
    }
    return null;
  }

  _PickupAvailability _regionAvailability(_PickupRegion region) {
    for (final point in region.points) {
      if (point.availability == _PickupAvailability.available) {
        return _PickupAvailability.available;
      }
    }
    return _PickupAvailability.developing;
  }

  String _formatPickupAddress(_PickupRegion region, _PickupPoint point) {
    return '${region.name}, ${point.name}';
  }

  String _normalizePickupLabel(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _pointSubtitle(_PickupPoint point) {
    if (point.kind == _PickupPointKind.city) {
      if (point.name == 'Ош') {
        return 'Город республиканского значения';
      }
      return 'Город областного значения';
    }
    return 'Пункт выдачи по району';
  }

  _PickupSelection? _findPickupSelectionByAddress(String rawAddress) {
    final value = _normalizePickupLabel(rawAddress);
    if (value.isEmpty) {
      return null;
    }
    for (final region in _regions) {
      final regionName = _normalizePickupLabel(region.name);
      for (final point in region.points) {
        final pointName = _normalizePickupLabel(point.name);
        if (value == pointName ||
            value.contains('$regionName, $pointName') ||
            value.contains(pointName)) {
          return _PickupSelection(region: region, point: point);
        }
      }
    }
    return null;
  }

  void _handleBack(_PickupRegion? currentRegion) {
    setState(() {
      _manualSelectedPointSlug = null;
    });
    if (currentRegion != null) {
      context.go('/delivery-address');
      return;
    }
    context.go('/profile');
  }

  void _openRegion(String slug) {
    setState(() {
      _manualSelectedPointSlug = null;
    });
    context.go('/delivery-address?region=$slug');
  }

  String _redirectPath() {
    final region = (widget.regionSlug ?? '').trim();
    if (region.isEmpty) {
      return '/delivery-address';
    }
    return '/delivery-address?region=$region';
  }

  Future<void> _saveAddress({
    required _PickupRegion region,
    required _PickupPoint point,
  }) async {
    final pickupPointLabel = _formatPickupAddress(region, point);
    final address = DeliveryAddress(
      country: 'Кыргызстан',
      city: pickupPointLabel,
      address: point.name,
      pickupPointLabel: pickupPointLabel,
    );
    final result = await _app.auth.updateDeliveryAddress(address);
    if (!mounted) {
      return;
    }
    if (result.ok) {
      context.go('/profile');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _app.auth.user;
    if (user == null) {
      if (!_authRedirectScheduled) {
        _authRedirectScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          context.go('/auth?redirect=${Uri.encodeComponent(_redirectPath())}');
        });
      }
      return Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.9,
            colors: [
              Color(0xFFFCFCFD),
              Color(0xFFF4F4F6),
              Color(0xFFEEF1F5),
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF7B2CF5)),
        ),
      );
    }

    _authRedirectScheduled = false;
    final currentRegion = _regionBySlug(widget.regionSlug);
    final currentSelection = _findPickupSelectionByAddress(
      user.deliveryAddress?.pickupPointLabel ?? user.city,
    );
    final selectedPointSlug = _manualSelectedPointSlug ??
        ((currentRegion != null &&
                currentSelection?.region.slug == currentRegion.slug)
            ? currentSelection!.point.slug
            : null);

    _PickupPoint? selectedPoint;
    if (currentRegion != null && selectedPointSlug != null) {
      for (final point in currentRegion.points) {
        if (point.slug == selectedPointSlug) {
          selectedPoint = point;
          break;
        }
      }
    }

    final canSave = currentRegion != null &&
        selectedPoint != null &&
        selectedPoint.availability == _PickupAvailability.available;

    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.9,
          colors: [
            Color(0xFFFCFCFD),
            Color(0xFFF4F4F6),
            Color(0xFFEEF1F5),
          ],
        ),
      ),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 190),
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFE7E9F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F0F172A),
                          blurRadius: 38,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _handleBack(currentRegion),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6F9),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF3D4357),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Адрес доставки',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF343748),
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 54),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (currentRegion == null) ...[
                          const Text(
                            'Сейчас доступен только пункт выдачи в Ноокате. Остальные области, города и районы уже добавлены в структуру и временно отмечены как находящиеся в разработке.',
                            style: TextStyle(
                              color: Color(0xFFB0B7C6),
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          GridView.builder(
                            itemCount: _regions.length,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.92,
                            ),
                            itemBuilder: (context, index) {
                              final region = _regions[index];
                              return _DeliveryRegionCard(
                                region: region,
                                active: currentSelection?.region.slug ==
                                        region.slug ||
                                    _regionAvailability(region) ==
                                        _PickupAvailability.available,
                                availability: _regionAvailability(region),
                                onTap: () => _openRegion(region.slug),
                              );
                            },
                          ),
                        ] else ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Пункты выдачи',
                                      style: TextStyle(
                                        color: Color(0xFF2F3140),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        height: 1.1,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Выберите район или город, где клиент сможет получить заказ через пункт выдачи.',
                                      style: TextStyle(
                                        color: Color(0xFFB0B7C6),
                                        fontSize: 15,
                                        height: 1.45,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2E8FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  currentRegion.name,
                                  style: const TextStyle(
                                    color: Color(0xFF8F35FF),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...currentRegion.points.map((point) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DeliveryPickupPointCard(
                                point: point,
                                selected: selectedPointSlug == point.slug,
                                subtitle: _pointSubtitle(point),
                                onTap: () {
                                  if (point.availability !=
                                      _PickupAvailability.available) {
                                    return;
                                  }
                                  setState(() {
                                    _manualSelectedPointSlug = point.slug;
                                  });
                                },
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 86,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFE7E9F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x120F172A),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF9A3CF9),
                            Color(0xFFC24CF9),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x479A3CF9),
                            blurRadius: 30,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: canSave
                            ? () {
                                if (selectedPoint == null) {
                                  return;
                                }
                                _saveAddress(
                                  region: currentRegion,
                                  point: selectedPoint,
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: const Color(0xFFF2F4F7),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFFA1ACBE),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Сохранить адрес'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupRegion {
  const _PickupRegion({
    required this.slug,
    required this.name,
    required this.points,
  });

  final String slug;
  final String name;
  final List<_PickupPoint> points;
}

class _PickupSelection {
  const _PickupSelection({
    required this.region,
    required this.point,
  });

  final _PickupRegion region;
  final _PickupPoint point;
}

enum _PickupPointKind {
  city,
  district,
}

enum _PickupAvailability {
  available,
  developing,
}

class _PickupPoint {
  const _PickupPoint({
    required this.slug,
    required this.name,
    required this.kind,
    required this.availability,
  });

  final String slug;
  final String name;
  final _PickupPointKind kind;
  final _PickupAvailability availability;
}

class _DeliveryRegionCard extends StatelessWidget {
  const _DeliveryRegionCard({
    required this.region,
    required this.active,
    required this.availability,
    required this.onTap,
  });

  final _PickupRegion region;
  final bool active;
  final _PickupAvailability availability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: active ? const Color(0xFFBF8CFF) : const Color(0xFFECEEF4),
          ),
          color: active ? const Color(0xFFF7F1FF) : Colors.white,
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x1F8F35FF),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.location_city_rounded,
                color:
                    active ? const Color(0xFF8F35FF) : const Color(0xFFB7BFD1),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              region.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2F3140),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            _DeliveryStatusBadge(availability: availability),
          ],
        ),
      ),
    );
  }
}

class _DeliveryPickupPointCard extends StatelessWidget {
  const _DeliveryPickupPointCard({
    required this.point,
    required this.selected,
    required this.subtitle,
    required this.onTap,
  });

  final _PickupPoint point;
  final bool selected;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAvailable = point.availability == _PickupAvailability.available;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: selected ? const Color(0xFFBF8CFF) : const Color(0xFFECEEF4),
          ),
          color: selected ? const Color(0xFFF7F1FF) : Colors.white,
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1F8F35FF),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.store_rounded,
                color: selected || isAvailable
                    ? const Color(0xFF8F35FF)
                    : const Color(0xFFAEB7CA),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.name,
                    style: const TextStyle(
                      color: Color(0xFF2F3140),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFB0B7C6),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DeliveryStatusBadge(availability: point.availability),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: isAvailable
                  ? _DeliveryRadioMark(active: selected)
                  : const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFA6B0C3),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStatusBadge extends StatelessWidget {
  const _DeliveryStatusBadge({
    required this.availability,
  });

  final _PickupAvailability availability;

  @override
  Widget build(BuildContext context) {
    final isAvailable = availability == _PickupAvailability.available;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: isAvailable ? const Color(0xFFEEF4FF) : const Color(0xFFF2F4F7),
      ),
      child: Text(
        isAvailable ? 'Доступно' : 'В разработке',
        style: TextStyle(
          color:
              isAvailable ? const Color(0xFF5385FF) : const Color(0xFFA1ACBE),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DeliveryRadioMark extends StatelessWidget {
  const _DeliveryRadioMark({
    required this.active,
  });

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFF8F35FF) : const Color(0xFFCFCBE0),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? const Color(0xFF8F35FF) : Colors.transparent,
        ),
      ),
    );
  }
}
