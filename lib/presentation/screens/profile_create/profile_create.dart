import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_assets.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';

final _formKey = GlobalKey<FormState>();

class ProfileCreateScreen extends StatelessWidget {
  const ProfileCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const ProfileCreateBody(),
    );
  }
}

class ProfileCreateBody extends StatelessWidget {
  const ProfileCreateBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'Заполните профиль',
              style: AppTextStyles.s32w600h000000,
            ),
          ),
          const CreateAvatarProfile(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'Введите имя',
              style: AppTextStyles.s12w600h000000,
            ),
          ),
          const WidgetCreateProfile(),
          const WidgetBottom(),
        ],
      ),
    );
  }
}

class CreateAvatarProfile extends StatelessWidget {
  const CreateAvatarProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 45, bottom: 12),
      child: Image.asset(AppAssets.imageNoAvatar),
    );
  }
}

class WidgetCreateProfile extends StatefulWidget {
  const WidgetCreateProfile({super.key});

  @override
  State<WidgetCreateProfile> createState() => _WidgetCreateProfileState();
}

class _WidgetCreateProfileState extends State<WidgetCreateProfile> {
  late TextEditingController _textEditingController;

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
    return Form(
      key: _formKey,
      child: TextFormField(
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Введите имя';
          }
          return null;
        },
        controller: _textEditingController,
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(hintText: 'ФИО'),
        onChanged: (val) {
          if (val == '00000') {
            context.goNamed(Routers.pathProfileCreateScreen);
          }
        },
      ),
    );
  }
}

class WidgetBottom extends StatelessWidget {
  const WidgetBottom({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: AppButton.main(
        title: 'Начать',
        onTap: () {
          if (_formKey.currentState!.validate()) {
            context.go(Routers.pathMainScreen);
          } else {}
        },
      ),
    );
  }
}
