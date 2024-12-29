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
      body: InfoScreenBody(),
    );
  }
}

class InfoScreenBody extends StatelessWidget {
  const InfoScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 100, 30, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Платформа для заказа товаров из Китая',
            style: AppTextStyles.s32w600h000000,
          ),
          const SizedBox(height: 10),
          Text(
            'Принимайте заказы',
            style: AppTextStyles.s12w400hB2B2B2,
          ),
          Expanded(
            child: Center(
              child: Image.asset(
                AppAssets.image1,
                height: 352,
                width: 290,
              ),
            ),
          ),
          AppButton.main(
            title: 'Далее',
            onTap: () {
               context.go(Routers.pathMainScreen);
            },
          ),
        ],
      ),
    );
  }
}
