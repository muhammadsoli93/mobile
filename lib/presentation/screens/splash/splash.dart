import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/core/functions/setup_dependencies.dart';
import 'package:kumarket/data/services/permission_service.dart';
import 'package:kumarket/data/services/storage_service.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SplashScreenBody(),
    );
  }
}

class SplashScreenBody extends StatefulWidget {
  const SplashScreenBody({super.key});

  @override
  State<SplashScreenBody> createState() => _SplashScreenBodyState();
}

class _SplashScreenBodyState extends State<SplashScreenBody> {

  Future<void> redirect() async {
    await requestPermission();
    await Future.delayed(const Duration(seconds: 1));
    await navigation();
  }

  Future<void> navigation() async {
    final storageService = sl<StorageService>();
    if (storageService.getIsIntroScreen && mounted) {
      context.go(Routers.pathMainScreen);
    } else {
      storageService.setIsIntroScreen = true;
      if (mounted) {
        context.pushReplacementNamed(Routers.pathInfoScreen);
      }
    }
  }

  Future<void> requestPermission() async {
    final permissionService = sl<PermissionService>();
    await permissionService.requestCamera();
    await permissionService.requestPhotoOrStorage();
  }

  @override
  void initState() {
    redirect();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        AppAssets.imageSplash,
      ),
    );
  }
}
