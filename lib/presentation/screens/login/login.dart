import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _maskFormatter = MaskTextInputFormatter(
    mask: '+7 ### ### ## ##',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool get _isValidPhone => _maskFormatter.getUnmaskedText().length == 10;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Введите номер телефона',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 8),
              const Text(
                'Мы отправим код подтверждения в WhatsApp',
                style: AppTextStyles.s14w400hB2B2B2,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [_maskFormatter],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: '+7 777 777 77 77',
                ),
              ),
              const Spacer(),
              const _AgreementLinks(),
              const SizedBox(height: 10),
              AppButton.main(
                title: 'Получить WhatsApp',
                onTap: _isValidPhone
                    ? () => context.pushNamed(Routers.pathCodeSmsScreen)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgreementLinks extends StatelessWidget {
  const _AgreementLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Продолжая, вы принимаете ',
          style: AppTextStyles.s12w400hB2B2B2,
          textAlign: TextAlign.center,
        ),
        GestureDetector(
          onTap: () => context.pushNamed(Routers.pathPublicOfferScreen),
          child: const Text(
            'Публичную оферту',
            style: AppTextStyles.s12w400hB2B2B2Underline,
          ),
        ),
        const Text(
          ' и ',
          style: AppTextStyles.s12w400hB2B2B2,
        ),
        GestureDetector(
          onTap: () => context.pushNamed(Routers.pathPrivacyPoliciesScreen),
          child: const Text(
            'Политику конфиденциальности',
            style: AppTextStyles.s12w400hB2B2B2Underline,
          ),
        ),
      ],
    );
  }
}
