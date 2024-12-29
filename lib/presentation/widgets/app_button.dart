import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

class AppButton extends StatelessWidget {
  final String title;
  final void Function() onTap;
  final Color color;

  AppButton.main({
    super.key,
    required this.title,
    required this.onTap,
  }) : color = AppColors.hex0968F5;

  AppButton.second({
    super.key,
    required this.title,
    required this.onTap,
  }) : color = AppColors.hex000000;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(
          color,
        ),
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, 52),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
