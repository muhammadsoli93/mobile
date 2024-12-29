import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        selectedFontSize: 0,
        unselectedFontSize: 0,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Image.asset(AppAssets.iconMainNoActive),
            activeIcon: Image.asset(AppAssets.iconMainActive),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(AppAssets.iconCategoriesNoActive),
            activeIcon: Image.asset(AppAssets.iconCategoriesActive),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(AppAssets.iconShopingCartNoActive),
            activeIcon: Image.asset(AppAssets.iconShopingCartActive),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(AppAssets.iconProfileNoActive),
            activeIcon: Image.asset(AppAssets.iconProfileActive),
            label: '',
          ),
        ],
      ),
    );
  }
}
