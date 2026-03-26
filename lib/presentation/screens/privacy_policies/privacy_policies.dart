import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

class PrivacyPoliciesScreen extends StatelessWidget {
  const PrivacyPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Политика конфиденциальности')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Text(
            'Мы обрабатываем номер телефона и технические данные устройства '
            'исключительно для авторизации, доставки и улучшения сервиса. '
            'Данные не передаются третьим лицам без вашего согласия, за '
            'исключением случаев, предусмотренных законодательством.',
            style: AppTextStyles.body,
          ),
        ),
      ),
    );
  }
}
