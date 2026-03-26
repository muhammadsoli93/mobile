import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

class AppButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final Color color;

  const AppButton.main({
    super.key,
    required this.title,
    required this.onTap,
  }) : color = AppColors.hex0968F5;

  const AppButton.second({
    super.key,
    required this.title,
    required this.onTap,
  }) : color = AppColors.hex000000;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(
          color,
        ),
        minimumSize: const WidgetStatePropertyAll(
          Size(double.infinity, 52),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      onPressed: onTap,
      child: Text(
        title,
        style: AppTextStyles.s16w600hFFFFFF,
      ),
    );
  }
}
