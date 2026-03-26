import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

class PublicOfferScreen extends StatelessWidget {
  const PublicOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Публичная оферта')),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Text(
            'Используя приложение KUMarket, вы соглашаетесь с условиями '
            'оферты: оформление заказов, сроки доставки, правила оплаты и '
            'возврата. Полная версия документа предоставляется после релиза.',
            style: AppTextStyles.body,
          ),
        ),
      ),
    );
  }
}
