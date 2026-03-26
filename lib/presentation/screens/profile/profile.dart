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
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'Профиль',
            style: AppTextStyles.h1,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.hexFFFFFF,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Image.asset(
                  AppAssets.imageNoAvatar,
                  width: 120,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Вы не авторизованы',
                  style: AppTextStyles.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Войдите, чтобы отслеживать заказы и получать бонусы',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.s14w400hB2B2B2,
                ),
                const SizedBox(height: 14),
                AppButton.main(
                  title: 'Войти',
                  onTap: () => context.pushNamed(Routers.pathLoginScreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SettingTile(
            icon: Icons.language_rounded,
            title: 'Язык',
            value: 'Русский',
          ),
          const _SettingTile(
            icon: Icons.payments_outlined,
            title: 'Валюта',
            value: 'Тенге (₸)',
          ),
          const _SettingTile(
            icon: Icons.support_agent_rounded,
            title: 'Поддержка',
            value: '24/7',
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.hexFFFFFF,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.hex99A6B8),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.s16w600h000000,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.s14w400hB2B2B2,
          ),
        ],
      ),
    );
  }
}
