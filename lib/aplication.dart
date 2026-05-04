import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_scroll_behavior.dart';
import 'package:kumarket/config/UI/app_theme.dart';
import 'package:kumarket/config/router/router.dart';

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'KUMarket',
      routerConfig: router,
      theme: appTheme,
      scrollBehavior: const AppScrollBehavior(),
    );
  }
}
