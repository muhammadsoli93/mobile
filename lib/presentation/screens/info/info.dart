import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: InfoScreenBody(),
      ),
    );
  }
}

class InfoScreenBody extends StatelessWidget {
  const InfoScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Покупки из Китая\nбыстро и безопасно',
            style: AppTextStyles.h1,
          ),
          const SizedBox(height: 8),
          const Text(
            'Тысячи товаров с удобной доставкой и прозрачной ценой.',
            style: AppTextStyles.s14w400hB2B2B2,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Image.asset(
                AppAssets.image1,
                height: 330,
                fit: BoxFit.contain,
              ),
            ),
          ),
          AppButton.main(
            title: 'Начать покупки',
            onTap: () => context.go(Routers.pathMainScreen),
          ),
        ],
      ),
    );
  }
}
