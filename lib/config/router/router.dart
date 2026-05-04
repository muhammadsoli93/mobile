import 'package:go_router/go_router.dart';
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

final router = GoRouter(
  initialLocation: _resolveInitialLocation(),
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return PwaShellScaffold(
          location: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/catalog',
          builder: (context, state) {
            return CatalogScreen(
              initialCategoryId: state.uri.queryParameters['category'],
            );
          },
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            return ProductScreen(
              routeId: state.pathParameters['id'] ?? '',
            );
          },
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) {
            return AuthScreen(
              redirectPath: state.uri.queryParameters['redirect'],
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) {
            return OrdersScreen(
              created: state.uri.queryParameters['created'] == '1',
            );
          },
        ),
        GoRoute(
          path: '/delivery-address',
          builder: (context, state) {
            return DeliveryAddressScreen(
              regionSlug: state.uri.queryParameters['region'],
            );
          },
        ),
        GoRoute(
          path: '/privacy-policy',
          builder: (context, state) => const LegalDocumentScreen(
            title: 'Политика конфиденциальности',
            body: privacyPolicyText,
          ),
        ),
        GoRoute(
          path: '/user-agreement',
          builder: (context, state) => const LegalDocumentScreen(
            title: 'Пользовательское соглашение',
            body: userAgreementText,
          ),
        ),
        GoRoute(
          path: '/sales-rules',
          builder: (context, state) => const LegalDocumentScreen(
            title: 'Правила продажи',
            body: salesRulesText,
          ),
        ),
      ],
    ),
  ],
);
