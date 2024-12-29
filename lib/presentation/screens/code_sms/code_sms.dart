import 'package:flutter/material.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CodeSmsScreen extends StatelessWidget {
  const CodeSmsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const CodeSmcBody(),
    );
  }
}

class CodeSmcBody extends StatelessWidget {
  const CodeSmcBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Введите пятизначный код',
            style: AppTextStyles.s32w600h000000,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Код был отправлен на номер +7 914 287 15 18',
              style: AppTextStyles.s12w400hB2B2B2,
            ),
          ),
          const WidgetSmsCode(),
          const WidgetTimer(),
        ],
      ),
    );
  }
}

class WidgetSmsCode extends StatefulWidget {
  const WidgetSmsCode({super.key});

  @override
  State<WidgetSmsCode> createState() => _WidgetSmsCodeState();
}

class _WidgetSmsCodeState extends State<WidgetSmsCode> {
  late TextEditingController _textEditingController;

  final _maskFormater = MaskTextInputFormatter(
    mask: '#####',
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
      decoration: const InputDecoration(hintText: '*****'),
      inputFormatters: [_maskFormater],
      onChanged: (val) {
        if (val == '00000') {
          context.goNamed(Routers.pathProfileCreateScreen)
;        }
      },
    );
  }
}

class WidgetTimer extends StatefulWidget {
  const WidgetTimer({super.key});

  @override
  State<WidgetTimer> createState() => _WidgetTimerState();
}

class _WidgetTimerState extends State<WidgetTimer> {
  var isEnabledCodeSmc = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: isEnabledCodeSmc
          ? GestureDetector(
              onTap: () {
                setState(() => isEnabledCodeSmc = false);
              },
              child: Text(
                'Отправить код',
                style: AppTextStyles.s12w400h0968F5,
              ),
            )
          : Row(
              children: [
                Text(
                  'Отправить код заново ',
                  style: AppTextStyles.s12w400h000000,
                ),
                TimerCountdown(
                  timeTextStyle: AppTextStyles.s12w400h000000,
                  colonsTextStyle: AppTextStyles.s12w400h000000,
                  spacerWidth: 2,
                  enableDescriptions: false,
                  format: CountDownTimerFormat.minutesSeconds,
                  endTime: DateTime.now().add(
                    const Duration(
                      seconds: 30,
                    ),
                  ),
                  onEnd: () {
                    setState(() => isEnabledCodeSmc = true);
                  },
                )
              ],
            ),
    );
  }
}
