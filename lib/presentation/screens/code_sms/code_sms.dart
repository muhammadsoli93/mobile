import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CodeSmsScreen extends StatefulWidget {
  const CodeSmsScreen({super.key});

  @override
  State<CodeSmsScreen> createState() => _CodeSmsScreenState();
}

class _CodeSmsScreenState extends State<CodeSmsScreen> {
  final _codeController = TextEditingController();
  final _codeFormatter = MaskTextInputFormatter(
    mask: '######',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  bool _canResend = false;
  DateTime _endTime = DateTime.now().add(const Duration(seconds: 30));

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onResend() {
    setState(() {
      _canResend = false;
      _codeController.clear();
      _endTime = DateTime.now().add(const Duration(seconds: 30));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Введите код из WhatsApp',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: 8),
              const Text(
                'Код отправлен на указанный номер',
                style: AppTextStyles.s14w400hB2B2B2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [_codeFormatter],
                decoration: const InputDecoration(hintText: '123456'),
                onChanged: (value) {
                  if (_codeFormatter.getUnmaskedText().length == 6) {
                    context.goNamed(Routers.pathProfileCreateScreen);
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_canResend)
                TextButton(
                  onPressed: _onResend,
                  child: const Text('Отправить код повторно'),
                )
              else
                Row(
                  children: [
                    const Text(
                      'Повторная отправка через ',
                      style: AppTextStyles.s14w400h000000,
                    ),
                    TimerCountdown(
                      endTime: _endTime,
                      enableDescriptions: false,
                      format: CountDownTimerFormat.minutesSeconds,
                      timeTextStyle: AppTextStyles.s14w400h000000.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      colonsTextStyle: AppTextStyles.s14w400h000000.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      spacerWidth: 2,
                      onEnd: () => setState(() => _canResend = true),
                    ),
                  ],
                ),
              const Spacer(),
              const Text(
                'Для демо: введите любые 5 цифр',
                style: TextStyle(
                  color: AppColors.hex99A6B8,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
