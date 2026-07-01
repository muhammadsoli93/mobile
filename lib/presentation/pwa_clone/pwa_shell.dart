import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/app_core/app_store.dart';

class PwaTabReselectEvent {
  const PwaTabReselectEvent({
    required this.index,
    required this.token,
  });

  final int index;
  final int token;
}

final ValueNotifier<PwaTabReselectEvent?> pwaTabReselectNotifier =
    ValueNotifier<PwaTabReselectEvent?>(null);

class PwaShellScaffold extends StatefulWidget {
  const PwaShellScaffold({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  @override
  State<PwaShellScaffold> createState() => _PwaShellScaffoldState();
}

class _PwaShellScaffoldState extends State<PwaShellScaffold> {
  int _reselectToken = 0;

  static const List<String> _tabPaths = <String>[
    '/',
    '/catalog',
    '/cart',
    '/profile',
  ];

  int _indexFromLocation(String path) {
    if (path == '/') {
      return 0;
    }
    if (path.startsWith('/catalog') || path.startsWith('/product/')) {
      return 1;
    }
    if (path.startsWith('/cart') || path.startsWith('/checkout')) {
      return 2;
    }
    return 3;
  }

  String _pathFromIndex(int index) {
    final safeIndex = index.clamp(0, _tabPaths.length - 1);
    return _tabPaths[safeIndex];
  }

  void _onTap(BuildContext context, int index, int selectedIndex) {
    if (index == selectedIndex && (index == 0 || index == 1)) {
      _reselectToken += 1;
      pwaTabReselectNotifier.value = PwaTabReselectEvent(
        index: index,
        token: _reselectToken,
      );
      return;
    }
    if (index == selectedIndex) {
      return;
    }
    HapticFeedback.selectionClick();
    context.go(_pathFromIndex(index));
  }

  @override
  Widget build(BuildContext context) {
    final cartStore = AppStore.instance.cart;
    final selectedIndex = _indexFromLocation(widget.location);

    final navItems = <({
      String label,
      IconData icon,
      IconData activeIcon,
    })>[
      (
        label: 'Главная',
        icon: Icons.home_filled,
        activeIcon: Icons.home_filled,
      ),
      (
        label: 'Каталог',
        icon: Icons.grid_view_rounded,
        activeIcon: Icons.grid_view_rounded,
      ),
      (
        label: 'Корзина',
        icon: Icons.shopping_cart_rounded,
        activeIcon: Icons.shopping_cart_rounded,
      ),
      (
        label: 'Профиль',
        icon: Icons.person_rounded,
        activeIcon: Icons.person_rounded,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: widget.child,
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cartStore,
        builder: (context, _) {
          return SafeArea(
            top: false,
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x29000000)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 18,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: List.generate(navItems.length, (index) {
                        final item = navItems[index];
                        final active = selectedIndex == index;

                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _onTap(context, index, selectedIndex),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0x167B2CF5)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                height: 56,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AnimatedScale(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          curve: Curves.easeOut,
                                          scale: active ? 1.08 : 1,
                                          child: Icon(
                                            active
                                                ? item.activeIcon
                                                : item.icon,
                                            size: 24,
                                            color: active
                                                ? const Color(0xFF7B2CF5)
                                                : const Color(0xFF8E8E93),
                                          ),
                                        ),
                                        if (index == 2 && cartStore.count > 0)
                                          Positioned(
                                            top: -7,
                                            right: -9,
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 18,
                                                minHeight: 18,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 1,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF3B30),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                cartStore.count > 99
                                                    ? '99+'
                                                    : '${cartStore.count}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      curve: Curves.easeOut,
                                      style: TextStyle(
                                        color: active
                                            ? const Color(0xFF7B2CF5)
                                            : const Color(0xFF8E8E93),
                                        fontSize: 11,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                      child: Text(
                                        item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
