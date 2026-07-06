import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';
import 'package:kumarket/presentation/pwa_clone/adult_content_guard.dart';
import 'package:kumarket/presentation/pwa_clone/widgets/product_card_widget.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.redirectPath});

  final String? redirectPath;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AppStore.instance.auth;
  final _phoneController = TextEditingController(text: '+996');
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();

  bool _verifyStep = false;
  bool _profileStep = false;
  String _info = 'Введите номер телефона и получите код по WhatsApp.';
  String _error = '';
  bool _busy = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool _isPlaceholderName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'user' ||
        normalized == 'пользователь';
  }

  void _requestCode() {
    if (_busy) {
      return;
    }
    unawaited(_requestCodeAsync());
  }

  Future<void> _requestCodeAsync() async {
    setState(() => _busy = true);
    final result = await _auth.requestCode(_phoneController.text);
    if (!mounted) {
      return;
    }
    _phoneController.text = result.normalizedPhone;
    if (!result.ok) {
      setState(() {
        _error = result.message;
        _busy = false;
      });
      return;
    }
    setState(() {
      _error = '';
      _verifyStep = true;
      _profileStep = false;
      _codeController.clear();
      _info = result.message;
      _busy = false;
    });
  }

  void _login() {
    if (_busy) {
      return;
    }
    unawaited(_loginAsync());
  }

  Future<void> _loginAsync() async {
    setState(() => _busy = true);
    final result = await _auth.login(
      phone: _phoneController.text,
      code: _codeController.text,
      fullName: '',
      city: '',
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      setState(() {
        _error = result.message;
        _busy = false;
      });
      return;
    }

    final user = result.user;
    if (user == null || _isPlaceholderName(user.fullName)) {
      setState(() {
        _busy = false;
        _verifyStep = false;
        _profileStep = true;
        _error = '';
        _info = 'Введите имя, чтобы завершить регистрацию.';
      });
      return;
    }

    setState(() => _busy = false);
    _goNext();
  }

  void _saveName() {
    if (_busy) {
      return;
    }
    unawaited(_saveNameAsync());
  }

  Future<void> _saveNameAsync() async {
    final fullName = _nameController.text.trim();
    if (fullName.isEmpty) {
      setState(() => _error = 'Введите имя.');
      return;
    }

    setState(() => _busy = true);
    final result = await _auth.updateProfile(
      fullName: fullName,
      city: '',
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      setState(() {
        _error = result.message;
        _busy = false;
      });
      return;
    }

    setState(() => _busy = false);
    _goNext();
  }

  void _goNext() {
    final redirect = widget.redirectPath;
    if (redirect != null && redirect.startsWith('/')) {
      context.go(redirect);
      return;
    }
    context.go('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final title = _profileStep
        ? 'Шаг 3: Ваше имя'
        : (_verifyStep
            ? 'Шаг 2: Подтверждение входа'
            : 'Шаг 1: Номер телефона');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF0F7FF), Color(0xFFF2F2F7)],
        ),
      ),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5E1FCF), Color(0xFF9D6BFF)],
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.24)),
                  ),
                  child: const Text(
                    'KuMarket Login',
                    style: TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Вход в KuMarket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _info,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x1F3C3C43)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: !_profileStep,
                  decoration:
                      const InputDecoration(labelText: 'Номер телефона'),
                ),
                if (_verifyStep) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Код из WhatsApp'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _verifyStep = false;
                              _error = '';
                              _codeController.clear();
                            });
                          },
                    child: const Text('Изменить номер'),
                  ),
                ],
                if (_profileStep) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Ваше имя'),
                  ),
                ],
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error,
                    style: const TextStyle(
                      color: Color(0xFFBE123C),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _busy
                        ? null
                        : (_profileStep
                            ? _saveName
                            : (_verifyStep ? _login : _requestCode)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2CF5),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      _busy
                          ? 'Загрузка...'
                          : (_profileStep
                              ? 'Сохранить и продолжить'
                              : (_verifyStep ? 'Войти' : 'Получить код')),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const int _maxPhotoSizeBytes = 2 * 1024 * 1024;
  static const String _notificationsStorageKey =
      'kumarket_notifications_enabled_v1';

  final _app = AppStore.instance;
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  bool _editing = false;
  bool _isSaved = false;
  bool _notificationsEnabled = true;
  bool _profileSaving = false;
  String _formError = '';
  String? _draftPhoto;
  String? _notificationsScope;

  @override
  void initState() {
    super.initState();
    _app.auth.addListener(_syncFromStore);
    _app.favorites.addListener(_syncFromStore);
    _syncFromStore();
  }

  @override
  void dispose() {
    _app.auth.removeListener(_syncFromStore);
    _app.favorites.removeListener(_syncFromStore);
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  ProductModel _favoriteToProduct(FavoriteItem item) {
    final img = normalizeImageUrl(item.image);
    return ProductModel(
      id: item.productId,
      slug: item.slug,
      title: item.title,
      price: item.price,
      oldPrice: null,
      description: '',
      rating: item.rating ?? 0,
      reviewsCount: item.reviewsCount ?? 0,
      images: [ProductImageModel(url: img, isMain: true, thumbUrl: img, mediumUrl: img, largeUrl: img)],
      imageThumb: img,
      imageMedium: img,
      imageLarge: img,
      categoryId: '',
      categoryName: '',
      stock: null,
      variants: const [],
      isAdult: item.isAdult,
      ageRestricted: item.ageRestricted,
    );
  }

  Future<void> _openFavoriteProduct(ProductModel product) async {
    await guardAdultProductAction(
      context: context,
      app: _app,
      product: product,
      onAllowed: () {
        if (!mounted) return;
        context.push('/product/${product.routeId}');
      },
    );
  }

  String _notificationsKey(String? phone) {
    final normalizedPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return '$_notificationsStorageKey::${normalizedPhone.isEmpty ? 'guest' : normalizedPhone}';
  }

  void _syncFromStore() {
    final user = _app.auth.user;
    if (!_editing) {
      _nameController.text = user?.fullName ?? '';
      _cityController.text = user?.city ?? '';
      _draftPhoto = user?.photo;
    }
    final scope = _notificationsKey(user?.phone);
    if (_notificationsScope != scope) {
      _notificationsScope = scope;
      _notificationsEnabled = _app.storage.read(scope) != '0';
    }
    if (mounted) setState(() {});
  }

  void _persistNotifications() {
    _app.storage.write(
      _notificationsKey(_app.auth.user?.phone),
      _notificationsEnabled ? '1' : '0',
    );
  }

  void _startEdit() {
    final user = _app.auth.user;
    if (user == null) return;
    setState(() {
      _editing = true;
      _formError = '';
      _nameController.text = user.fullName;
      _cityController.text = user.city;
      _draftPhoto = user.photo;
    });
  }

  void _cancelEdit() {
    final user = _app.auth.user;
    if (user == null) return;
    setState(() {
      _editing = false;
      _formError = '';
      _nameController.text = user.fullName;
      _cityController.text = user.city;
      _draftPhoto = user.photo;
    });
  }

  Future<void> _pickPhoto() async {
    setState(() => _formError = '');
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxPhotoSizeBytes) {
      setState(() => _formError = 'Размер фото не должен превышать 2 МБ.');
      return;
    }

    final path = file.path.toLowerCase();
    final mime = path.endsWith('.png')
        ? 'image/png'
        : path.endsWith('.webp')
            ? 'image/webp'
            : path.endsWith('.gif')
                ? 'image/gif'
                : 'image/jpeg';
    setState(() {
      _draftPhoto = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  void _saveProfile() {
    if (_profileSaving) {
      return;
    }
    unawaited(_saveProfileAsync());
  }

  Future<void> _saveProfileAsync() async {
    final fullName = _nameController.text.trim();
    final city = _cityController.text.trim();
    if (fullName.isEmpty) {
      setState(() => _formError = 'Enter full name.');
      return;
    }
    if (city.isEmpty) {
      setState(() => _formError = 'Enter city.');
      return;
    }

    setState(() => _profileSaving = true);
    final result = await _app.auth.updateProfile(
      fullName: fullName,
      city: city,
      photo: _draftPhoto,
    );
    if (!mounted) {
      return;
    }
    if (!result.ok) {
      setState(() {
        _formError = result.message;
        _profileSaving = false;
      });
      return;
    }

    setState(() {
      _formError = '';
      _editing = false;
      _isSaved = true;
      _profileSaving = false;
    });

    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isSaved = false);
    });
  }

  void _logout() {
    _app.auth.logout();
    context.go('/auth?redirect=${Uri.encodeComponent('/profile')}');
  }

  Future<void> _openContacts() async {
    await Clipboard.setData(const ClipboardData(text: 'Nookaat@yandex.ru'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email скопирован: Nookaat@yandex.ru')),
    );
  }

  void _goToAuth() {
    context.push('/auth?redirect=${Uri.encodeComponent('/profile')}');
  }

  Widget _buildGuestProfile(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F7),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
        children: [
          _ProfileFlagHeader(
            fullName: 'Гость',
            phone: 'Без авторизации',
            initials: 'KM',
            photo: null,
            decodeDataImage: _decodeDataImage,
          ),
          const _InfoBanner(
            ok: false,
            text: 'Вы не авторизованы. Доступны настройки и документы. Для заказов выполните вход.',
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Аккаунт'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Войти или зарегистрироваться',
              subtitle: 'Авторизация по номеру телефона',
              icon: Icons.login_rounded,
              iconColor: const Color(0xFF7B2CF5),
              onTap: _goToAuth,
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Данные пользователя'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Адрес доставки',
              subtitle: 'Требуется авторизация',
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFF43F5E),
              onTap: _goToAuth,
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Заказы'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Мои заказы',
              subtitle: 'Требуется авторизация',
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF9F7AEA),
              onTap: _goToAuth,
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Избранное'),
          const SizedBox(height: 8),
          _FavoritesSection(
            favorites: _app.favorites.items,
            onOpen: (item) => unawaited(_openFavoriteProduct(_favoriteToProduct(item))),
            onRemove: (item) => _app.favorites.toggleStored(item),
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Настройки'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            const _RowAction(
              title: 'Язык',
              icon: Icons.language_rounded,
              iconColor: Color(0xFF38BDF8),
              trailing: _Pill(label: 'Русский'),
            ),
            const _RowAction(
              title: 'Валюта',
              icon: Icons.currency_ruble_rounded,
              iconColor: Color(0xFF818CF8),
              trailing: _CurrencyPill(),
            ),
            _RowAction(
              title: 'Уведомления',
              icon: Icons.notifications_none_rounded,
              iconColor: const Color(0xFFF59E0B),
              trailing: _SettingSwitch(
                checked: _notificationsEnabled,
                onToggle: () {
                  setState(
                      () => _notificationsEnabled = !_notificationsEnabled);
                  _persistNotifications();
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Документы'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Политика конфиденциальности',
              subtitle: 'Условия обработки персональных данных',
              icon: Icons.check_rounded,
              iconColor: const Color(0xFF4ADE80),
              onTap: () => context.push('/privacy-policy'),
            ),
            _RowAction(
              title: 'Пользовательское соглашение',
              subtitle: 'Основные правила использования сервиса',
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFC4B5FD),
              onTap: () => context.push('/user-agreement'),
            ),
            _RowAction(
              title: 'Правила продажи',
              subtitle: 'Публичная оферта и условия оформления заказа',
              icon: Icons.request_quote_outlined,
              iconColor: const Color(0xFFFBBF24),
              onTap: () => context.push('/sales-rules'),
            ),
            _RowAction(
              title: 'Контакты',
              subtitle: 'Связь с поддержкой и компанией',
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFFF472B6),
              onTap: _openContacts,
            ),
          ]),
        ],
      ),
    );
  }

  Uint8List? _decodeDataImage(String? value) {
    final raw = (value ?? '').trim();
    if (!raw.startsWith('data:image')) return null;
    final i = raw.indexOf(',');
    if (i <= 0 || i >= raw.length - 1) return null;
    try {
      return base64Decode(raw.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  String _initials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return 'KM';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = _app.auth.user;
    if (user == null) {
      return _buildGuestProfile(context);
    }

    final initials =
        _initials(user.fullName.isEmpty ? 'KuMarket' : user.fullName);
    final deliverySubtitle =
        user.deliveryAddress?.pickupPointLabel ?? 'Не добавлен';
    final previewPhoto = _editing ? _draftPhoto : user.photo;

    return Container(
      color: const Color(0xFFF3F4F7),
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 132),
        children: [
          _ProfileFlagHeader(
            fullName: user.fullName,
            phone: user.phone,
            initials: initials,
            photo: user.photo,
            decodeDataImage: _decodeDataImage,
          ),
          if (_isSaved) const _InfoBanner(ok: true, text: 'Профиль сохранен'),
          if (_formError.isNotEmpty) _InfoBanner(ok: false, text: _formError),
          const SizedBox(height: 14),
          const _SectionTitle('Аккаунт'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Изменить',
              subtitle: 'Обновить имя, телефон и данные профиля',
              icon: Icons.edit_outlined,
              iconColor: const Color(0xFFF59E0B),
              onTap: _startEdit,
            ),
          ]),
          if (_editing)
            _EditCard(
              nameController: _nameController,
              cityController: _cityController,
              previewPhoto: previewPhoto,
              initials: initials,
              onPickPhoto: _pickPhoto,
              onSave: _saveProfile,
              onCancel: _cancelEdit,
              decodeDataImage: _decodeDataImage,
            ),
          const SizedBox(height: 14),
          const _SectionTitle('Данные пользователя'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Адрес доставки',
              subtitle: deliverySubtitle,
              icon: Icons.location_on_outlined,
              iconColor: const Color(0xFFF43F5E),
              onTap: () => context.push('/delivery-address'),
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Заказы'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Мои заказы',
              subtitle: 'Список заказов и детали по каждому заказу',
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF9F7AEA),
              onTap: () => context.push('/orders'),
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Избранное'),
          const SizedBox(height: 8),
          _FavoritesSection(
            favorites: _app.favorites.items,
            onOpen: (item) => unawaited(_openFavoriteProduct(_favoriteToProduct(item))),
            onRemove: (item) => _app.favorites.toggleStored(item),
          ),
          const SizedBox(height: 14),
          const _SectionTitle('Настройки'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            const _RowAction(
              title: 'Язык',
              icon: Icons.language_rounded,
              iconColor: Color(0xFF38BDF8),
              trailing: _Pill(label: 'Русский'),
            ),
            const _RowAction(
              title: 'Валюта',
              icon: Icons.currency_ruble_rounded,
              iconColor: Color(0xFF818CF8),
              trailing: _CurrencyPill(),
            ),
            _RowAction(
              title: 'Уведомления',
              icon: Icons.notifications_none_rounded,
              iconColor: const Color(0xFFF59E0B),
              trailing: _SettingSwitch(
                checked: _notificationsEnabled,
                onToggle: () {
                  setState(
                      () => _notificationsEnabled = !_notificationsEnabled);
                  _persistNotifications();
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          const _SectionTitle('Документы'),
          const SizedBox(height: 8),
          _ProfileGroup(children: [
            _RowAction(
              title: 'Политика конфиденциальности',
              subtitle: 'Условия обработки персональных данных',
              icon: Icons.check_rounded,
              iconColor: const Color(0xFF4ADE80),
              onTap: () => context.push('/privacy-policy'),
            ),
            _RowAction(
              title: 'Пользовательское соглашение',
              subtitle: 'Основные правила использования сервиса',
              icon: Icons.description_outlined,
              iconColor: const Color(0xFFC4B5FD),
              onTap: () => context.push('/user-agreement'),
            ),
            _RowAction(
              title: 'Правила продажи',
              subtitle: 'Публичная оферта и условия оформления заказа',
              icon: Icons.request_quote_outlined,
              iconColor: const Color(0xFFFBBF24),
              onTap: () => context.push('/sales-rules'),
            ),
            _RowAction(
              title: 'Контакты',
              subtitle: 'Связь с поддержкой и компанией',
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFFF472B6),
              onTap: _openContacts,
            ),
            _RowAction(
              title: 'Выход',
              subtitle: 'Завершить текущую сессию',
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFF60A5FA),
              danger: true,
              onTap: _logout,
            ),
          ]),
        ],
      ),
    );
  }
}

class _ProfileFlagHeader extends StatelessWidget {
  const _ProfileFlagHeader({
    required this.fullName,
    required this.phone,
    required this.initials,
    required this.photo,
    required this.decodeDataImage,
  });

  final String fullName;
  final String phone;
  final String initials;
  final String? photo;
  final Uint8List? Function(String?) decodeDataImage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: SizedBox(
        height: 270,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/Flag_of_Kyrgyzstan.png',
                fit: BoxFit.cover),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x05000000), Color(0x2E000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 4),
                      ),
                      child: _ProfilePhoto(
                        photo: photo,
                        initials: initials,
                        size: 82,
                        decodeDataImage: decodeDataImage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                height: 1.04),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: const TextStyle(
                                color: Color(0xF2FFFFFF),
                                fontSize: 18,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({
    required this.photo,
    required this.initials,
    required this.size,
    required this.decodeDataImage,
  });

  final String? photo;
  final String initials;
  final double size;
  final Uint8List? Function(String?) decodeDataImage;

  @override
  Widget build(BuildContext context) {
    final source = (photo ?? '').trim();
    final dataBytes = decodeDataImage(source);
    final cacheSize = (size * 2).round();

    if (dataBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.memory(dataBytes,
            width: size, height: size, fit: BoxFit.cover),
      );
    }
    if (source.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          source,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
          errorBuilder: (_, __, ___) =>
              _InitialsAvatar(initials: initials, size: size),
        ),
      );
    }
    return _InitialsAvatar(initials: initials, size: size);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
            color: Color(0xFFEF0909),
            fontSize: 24,
            fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? const Color(0xFFECFDF3) : const Color(0xFFFFF4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: ok ? const Color(0xFFBBF7D0) : const Color(0xFFFECDD3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ok ? const Color(0xFF047857) : const Color(0xFFBE123C),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
            color: Color(0xFF9AA4BB),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _ProfileGroup extends StatelessWidget {
  const _ProfileGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E8EF)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEDF0F5)),
          ],
        ],
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        danger ? const Color(0xFFDC2626) : const Color(0xFF111827);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F8),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  if ((subtitle ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                            color: Color(0xFF9AA3B5),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFBCC3D4)),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({required this.checked, required this.onToggle});

  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 34,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFF2371F3) : const Color(0xFFD7DCE7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: checked ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

class _EditCard extends StatelessWidget {
  const _EditCard({
    required this.nameController,
    required this.cityController,
    required this.previewPhoto,
    required this.initials,
    required this.onPickPhoto,
    required this.onSave,
    required this.onCancel,
    required this.decodeDataImage,
  });

  final TextEditingController nameController;
  final TextEditingController cityController;
  final String? previewPhoto;
  final String initials;
  final VoidCallback onPickPhoto;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final Uint8List? Function(String?) decodeDataImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E8EF)),
      ),
      child: Column(
        children: [
          _ProfileField(
              label: 'ФИО', controller: nameController, hint: 'Введите ФИО'),
          const SizedBox(height: 10),
          _ProfileField(
              label: 'Город', controller: cityController, hint: 'Ваш город'),
          const SizedBox(height: 10),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Фото профиля',
              style: TextStyle(
                  color: Color(0xFF99A2B3),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
                onPressed: onPickPhoto, child: const Text('Выбрать фото')),
          ),
          if ((previewPhoto ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FD),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEBEFF6)),
              ),
              child: Row(
                children: [
                  _ProfilePhoto(
                    photo: previewPhoto,
                    initials: initials,
                    size: 56,
                    decodeDataImage: decodeDataImage,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Фото профиля обновлено',
                        style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: ElevatedButton(
                      onPressed: onSave, child: const Text('Сохранить'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton(
                      onPressed: onCancel, child: const Text('Отмена'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF99A2B3),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4)),
        const SizedBox(height: 6),
        TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F3F6),
          borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF9AA3B5),
              fontSize: 14,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  const _CurrencyPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
          color: const Color(0xFFF2F3F6),
          borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('сом',
              style: TextStyle(
                  color: Color(0xFF9AA3B5),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Image.asset('assets/images/Flag_of_Kyrgyzstan.png',
                width: 16, height: 12, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}

class _FavoritesSection extends StatelessWidget {
  const _FavoritesSection({
    required this.favorites,
    required this.onOpen,
    required this.onRemove,
  });

  final List<FavoriteItem> favorites;
  final void Function(FavoriteItem) onOpen;
  final void Function(FavoriteItem) onRemove;

  @override
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 14),
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
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: favorites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = favorites[index];
          final img = normalizeImageUrl(item.image);
          final product = ProductModel(
            id: item.productId,
            slug: item.slug,
            title: item.title,
            price: item.price,
            oldPrice: null,
            description: '',
            rating: item.rating ?? 0,
            reviewsCount: item.reviewsCount ?? 0,
            images: [ProductImageModel(url: img, isMain: true, thumbUrl: img, mediumUrl: img, largeUrl: img)],
            imageThumb: img,
            imageMedium: img,
            imageLarge: img,
            categoryId: '',
            categoryName: '',
            stock: null,
            variants: const [],
            isAdult: item.isAdult,
            ageRestricted: item.ageRestricted,
          );
          return SizedBox(
            width: 140,
            child: ProductCardWidget(
              product: product,
              isFavorite: true,
              isAdultRestricted: isAdultProduct(product),
              canShowAdultContent: canShowAdultContent(AppStore.instance),
              onOpen: () => onOpen(item),
              onToggleFavorite: () => onRemove(item),
              onAddToCart: () {},
            ),
          );
        },
      ),
    );
  }
}
