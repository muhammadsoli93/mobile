import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/core/functions/setup_dependencies.dart';
import 'package:kumarket/data/services/cart_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final cartService = sl<CartService>();

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: AnimatedBuilder(
        animation: cartService,
        builder: (context, _) {
          return BottomNavigationBar(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            ),
            items: [
              const BottomNavigationBarItem(
                icon: _TabIcon(
                  asset: AppAssets.iconMainNoActive,
                ),
                activeIcon: _TabIcon(
                  asset: AppAssets.iconMainActive,
                ),
                label: '',
              ),
              const BottomNavigationBarItem(
                icon: _TabIcon(
                  asset: AppAssets.iconCategoriesNoActive,
                ),
                activeIcon: _TabIcon(
                  asset: AppAssets.iconCategoriesActive,
                ),
                label: '',
              ),
              BottomNavigationBarItem(
                icon: _TabIcon(
                  asset: AppAssets.iconShopingCartNoActive,
                  badgeCount: cartService.totalItems,
                ),
                activeIcon: _TabIcon(
                  asset: AppAssets.iconShopingCartActive,
                  badgeCount: cartService.totalItems,
                ),
                label: '',
              ),
              const BottomNavigationBarItem(
                icon: _TabIcon(
                  asset: AppAssets.iconProfileNoActive,
                ),
                activeIcon: _TabIcon(
                  asset: AppAssets.iconProfileActive,
                ),
                label: '',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.asset,
    this.badgeCount = 0,
  });

  final String asset;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(asset),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.hexFFFFFF,
                    fontSize: 9,
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
