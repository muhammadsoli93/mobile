import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const LoginScreenBody(),
    );
  }
}

class LoginScreenBody extends StatelessWidget {
  const LoginScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Введите номер телефона',
            style: AppTextStyles.s32w600h000000,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Мы отправим вам код подтверждения на этот номер',
              style: AppTextStyles.s12w400hB2B2B2,
            ),
          ),
          const WidgetPhoneNumber(),
          const Spacer(),
          const WidgetBottom(),
        ],
      ),
    );
  }
}

class WidgetPhoneNumber extends StatefulWidget {
  const WidgetPhoneNumber({super.key});

  @override
  State<WidgetPhoneNumber> createState() => _WidgetPhoneNumberState();
}

class _WidgetPhoneNumberState extends State<WidgetPhoneNumber> {
  late TextEditingController _textEditingController ;

  final _maskFormater = MaskTextInputFormatter(
    mask: '+ 7 ### ### ## ##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
  void initState() {
   _textEditingController = TextEditingController();
    super.initState();
  }
  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textEditingController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(hintText: '+7 984 112 23 45'),
      inputFormatters: [_maskFormater],
    );
  }
}

class WidgetBottom extends StatelessWidget {
  const WidgetBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text:
                  'Нажимая кнопку "Получить СМС", я подтверждаю, что ознакомлен(а) с условиями',
              style: AppTextStyles.s12w400hB2B2B2,
              children: [
                TextSpan(
                  text: ' Публичной оферты',
                  style: AppTextStyles.s12w400hB2B2B2Underline,
                  recognizer: TapGestureRecognizer()
                    ..onTap =
                        () => context.pushNamed(Routers.pathPublicOfferScreen),
                ),
                TextSpan(
                  text: ' и',
                  style: AppTextStyles.s12w400hB2B2B2,
                ),
                TextSpan(
                  text: ' Политики конфиденциальности',
                  style: AppTextStyles.s12w400hB2B2B2Underline,
                  recognizer: TapGestureRecognizer()
                    ..onTap = () =>
                        context.pushNamed(Routers.pathPrivacyPoliciesScreen),
                ),
                TextSpan(
                  text: ' и принимаю их условия',
                  style: AppTextStyles.s12w400hB2B2B2,
                ),
              ],
            ),
          ),
        ),
        AppButton.main(
          title: 'Получить СМС',
          onTap: () {
            context.pushNamed(Routers.pathCodeSmsScreen);
          },
        ),
      ],
    );
  }
}
