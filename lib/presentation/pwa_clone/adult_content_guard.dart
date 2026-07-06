import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kumarket/app_core/app_store.dart';
import 'package:kumarket/app_core/models.dart';
import 'package:kumarket/presentation/pwa_clone/widgets/age_confirmation_modal.dart';

bool isAdultProduct(ProductModel product) => product.isAdultRestricted;

AdultAgeConfirmationStore useAdultAgeConfirmation(AppStore app) =>
    app.adultAgeConfirmation;

bool canShowAdultContent(AppStore app) =>
    useAdultAgeConfirmation(app).canShowAdultContent;

Future<bool> ensureAdultContentAccess({
  required BuildContext context,
  required AppStore app,
  required ProductModel product,
  bool showDeniedMessage = true,
}) async {
  if (!isAdultProduct(product) || canShowAdultContent(app)) {
    return true;
  }

  final confirmed = await showAgeConfirmationModal(context);
  if (!confirmed) {
    if (!context.mounted) {
      return false;
    }
    if (showDeniedMessage) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content:
              Text('Этот товар доступен только пользователям старше 18 лет.'),
        ),
      );
    }
    return false;
  }

  useAdultAgeConfirmation(app).confirmAdultAge();
  return true;
}

Future<void> guardAdultProductAction({
  required BuildContext context,
  required AppStore app,
  required ProductModel product,
  required FutureOr<void> Function() onAllowed,
}) async {
  final allowed = await ensureAdultContentAccess(
    context: context,
    app: app,
    product: product,
  );
  if (!allowed) {
    return;
  }
  await onAllowed();
}
