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
  double _dragDx = 0;
  int _reselectToken = 0;
  int _transitionDirection = 0;

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

  bool _isTabRootLocation(String path) {
    return _tabPaths.contains(path);
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

  void _onHorizontalDragEnd(
    BuildContext context,
    DragEndDetails details,
    int selectedIndex,
  ) {
    if (!_isTabRootLocation(widget.location)) {
      if (_dragDx != 0) {
        setState(() {
          _dragDx = 0;
        });
      }
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final distance = _dragDx;

    if (_dragDx != 0) {
      setState(() {
        _dragDx = 0;
      });
    }

    int? direction;
    if (velocity.abs() >= 150) {
      direction = velocity < 0 ? 1 : -1;
    } else if (distance.abs() >= 52) {
      direction = distance < 0 ? 1 : -1;
    }

    if (direction == null) {
      return;
    }

    final nextIndex =
        (selectedIndex + direction).clamp(0, _tabPaths.length - 1);
    if (nextIndex == selectedIndex) {
      return;
    }

    _onTap(context, nextIndex, selectedIndex);
  }

  @override
  void didUpdateWidget(covariant PwaShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location == widget.location) {
      return;
    }

    final previousIndex = _indexFromLocation(oldWidget.location);
    final nextIndex = _indexFromLocation(widget.location);

    if (_isTabRootLocation(oldWidget.location) &&
        _isTabRootLocation(widget.location)) {
      final diff = nextIndex - previousIndex;
      if (diff > 0) {
        _transitionDirection = 1;
      } else if (diff < 0) {
        _transitionDirection = -1;
      } else {
        _transitionDirection = 0;
      }
    } else {
      _transitionDirection = 0;
    }

    _dragDx = 0;
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

    final dragOffset = _isTabRootLocation(widget.location) ? _dragDx : 0.0;

    return Scaffold(
      extendBody: true,
      body: SizedBox.expand(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) {
            if (!_isTabRootLocation(widget.location)) {
              return;
            }
            if (_dragDx != 0) {
              setState(() {
                _dragDx = 0;
              });
            }
          },
          onHorizontalDragUpdate: (details) {
            if (!_isTabRootLocation(widget.location)) {
              return;
            }
            setState(() {
              _dragDx = (_dragDx + details.delta.dx).clamp(-64.0, 64.0);
            });
          },
          onHorizontalDragCancel: () {
            if (_dragDx == 0) {
              return;
            }
            setState(() {
              _dragDx = 0;
            });
          },
          onHorizontalDragEnd: (details) {
            _onHorizontalDragEnd(context, details, selectedIndex);
          },
          child: Transform.translate(
            offset: Offset(dragOffset, 0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              reverseDuration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                double beginDx = 0;
                if (_transitionDirection > 0) {
                  beginDx = 0.10;
                } else if (_transitionDirection < 0) {
                  beginDx = -0.10;
                }

                final offsetAnimation = Tween<Offset>(
                  begin: Offset(beginDx, 0),
                  end: Offset.zero,
                ).animate(animation);

                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: offsetAnimation,
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey<String>(widget.location),
                child: SizedBox.expand(child: widget.child),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cartStore,
        builder: (context, _) {
          return SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: const Color(0x1F000000)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Color(0x147B2CF5),
                            blurRadius: 26,
                            offset: Offset(0, 10),
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
                              onTap: () =>
                                  _onTap(context, index, selectedIndex),
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
                                            duration: const Duration(
                                                milliseconds: 180),
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
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 1,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFF3B30),
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
            ),
          );
        },
      ),
    );
  }
}
