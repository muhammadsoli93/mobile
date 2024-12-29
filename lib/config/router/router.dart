import 'package:go_router/go_router.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/presentation/screens/categories/categories.dart';
import 'package:kumarket/presentation/screens/code_sms/code_sms.dart';
import 'package:kumarket/presentation/screens/home/home.dart';
import 'package:kumarket/presentation/screens/info/info.dart';
import 'package:kumarket/presentation/screens/login/login.dart';
import 'package:kumarket/presentation/screens/main/main.dart';
import 'package:kumarket/presentation/screens/privacy_policies/privacy_policies.dart';
import 'package:kumarket/presentation/screens/profile/profile.dart';
import 'package:kumarket/presentation/screens/profile_create/profile_create.dart';
import 'package:kumarket/presentation/screens/public_offer/public_offer.dart';
import 'package:kumarket/presentation/screens/shoping_cart/shoping_cart.dart';
import 'package:kumarket/presentation/screens/splash/splash.dart';

final router = GoRouter(
  initialLocation: Routers.pathSplashScreen,
  routes: [
    GoRoute(
      path: Routers.pathSplashScreen,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      name: Routers.pathInfoScreen,
      path: Routers.pathInfoScreen,
      builder: (context, state) => const InfoScreen(),
    ),
    GoRoute(
        name: Routers.pathLoginScreen,
        path: Routers.pathLoginScreen,
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            name: Routers.pathCodeSmsScreen,
            path: Routers.pathCodeSmsScreen,
            builder: (context, state) => const CodeSmsScreen(),
          ),
        ]),
    GoRoute(
      name: Routers.pathProfileCreateScreen,
      path: Routers.pathProfileCreateScreen,
      builder: (context, state) => const ProfileCreateScreen(),
    ),
    GoRoute(
      name: Routers.pathPrivacyPoliciesScreen,
      path: Routers.pathPrivacyPoliciesScreen,
      builder: (context, state) => const PrivacyPoliciesScreen(),
    ),
    GoRoute(
      name: Routers.pathPublicOfferScreen,
      path: Routers.pathPublicOfferScreen,
      builder: (context, state) => const PublicOfferScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeScreen(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routers.pathMainScreen,
              builder: (context, state) => const MainScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routers.pathCategoriesScreen,
              builder: (context, state) => const CategoriesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routers.pathShopingCartScreen,
              builder: (context, state) => const ShopingCartScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: Routers.pathProfileScreen,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
