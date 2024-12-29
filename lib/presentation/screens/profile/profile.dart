import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const ProfileScreenBodyNoAuth(),
    );
  }
}

class ProfileScreenBodyNoAuth extends StatelessWidget {
  const ProfileScreenBodyNoAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(AppAssets.imageNoAvatar),
          const SizedBox(height: 40),
          Text(
            'Вы не авторизовались',
            style: AppTextStyles.s32w600h000000,
            textAlign: TextAlign.center,
          ),
          Text(
            'На ваш профиль действуют ограничения',
            style: AppTextStyles.s14w400hB2B2B2,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AppButton.main(
              title: 'Войти',
              onTap: () => context.pushNamed(Routers.pathLoginScreen),
            ),
          ),
          const CardButton(
            title: 'Язык',
            text: 'Русский',
          ),
          const CardButton(
            title: 'Валюта',
            text: 'Ru',
          )
        ],
      ),
    );
  }
}

class CardButton extends StatelessWidget {
  const CardButton({super.key, required this.text, required this.title});
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTextStyles.s16w600h000000,
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.hexF3F3F3,
              borderRadius: BorderRadius.circular(48),
            ),
            child: Text(
              text,
              style: AppTextStyles.s16w600hB2B2B2,
            ),
          ),
        ],
      ),
    );
  }
}
