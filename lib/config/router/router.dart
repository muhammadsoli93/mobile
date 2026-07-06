import 'dart:io' show Platform;
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:kumarket/presentation/pwa_clone/auth_profile_screen.dart';
import 'package:kumarket/presentation/pwa_clone/cart_checkout_screen.dart';
import 'package:kumarket/presentation/pwa_clone/home_catalog_screen.dart';
import 'package:kumarket/presentation/pwa_clone/legal_screen.dart';
import 'package:kumarket/presentation/pwa_clone/orders_delivery_screen.dart';
import 'package:kumarket/presentation/pwa_clone/product_screen.dart';
import 'package:kumarket/presentation/pwa_clone/pwa_shell.dart';

const String _configuredInitialLocation = String.fromEnvironment(
  'INITIAL_LOCATION',
  defaultValue: '/',
);

String _resolveInitialLocation() {
  if (_configuredInitialLocation.startsWith('/')) {
    return _configuredInitialLocation;
  }
  return '/';
}

Page<void> _pwaPage({
  required GoRouterState state,
  required Widget child,
}) {
  if (Platform.isIOS) {
    return CupertinoPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: child,
        ),
      );
    },
  );
}

final router = GoRouter(
  initialLocation: _resolveInitialLocation(),
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return PwaShellScaffold(
          location: state.uri.toString(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/catalog',
          pageBuilder: (context, state) {
            return _pwaPage(
              state: state,
              child: CatalogScreen(
                initialCategoryId: state.uri.queryParameters['category'],
              ),
            );
          },
        ),
        GoRoute(
          path: '/product/:id',
          pageBuilder: (context, state) {
            return _pwaPage(
              state: state,
              child: ProductScreen(
                routeId: state.pathParameters['id'] ?? '',
              ),
            );
          },
        ),
        GoRoute(
          path: '/cart',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const CartScreen(),
          ),
        ),
        GoRoute(
          path: '/checkout',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const CheckoutScreen(),
          ),
        ),
        GoRoute(
          path: '/auth',
          pageBuilder: (context, state) {
            return _pwaPage(
              state: state,
              child: AuthScreen(
                redirectPath: state.uri.queryParameters['redirect'],
              ),
            );
          },
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) {
            return _pwaPage(
              state: state,
              child: OrdersScreen(
                created: state.uri.queryParameters['created'] == '1',
              ),
            );
          },
        ),
        GoRoute(
          path: '/delivery-address',
          pageBuilder: (context, state) {
            return _pwaPage(
              state: state,
              child: DeliveryAddressScreen(
                regionSlug: state.uri.queryParameters['region'],
              ),
            );
          },
        ),
        GoRoute(
          path: '/privacy-policy',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const LegalDocumentScreen(
              title: 'Политика конфиденциальности',
              body: privacyPolicyText,
            ),
          ),
        ),
        GoRoute(
          path: '/user-agreement',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const LegalDocumentScreen(
              title: 'Пользовательское соглашение',
              body: userAgreementText,
            ),
          ),
        ),
        GoRoute(
          path: '/sales-rules',
          pageBuilder: (context, state) => _pwaPage(
            state: state,
            child: const LegalDocumentScreen(
              title: 'Правила продажи',
              body: salesRulesText,
            ),
          ),
        ),
      ],
    ),
  ],
);
