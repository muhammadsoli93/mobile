import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';
import 'package:kumarket/config/router/routers.dart';
import 'package:kumarket/core/functions/price_formatter.dart';
import 'package:kumarket/core/functions/setup_dependencies.dart';
import 'package:kumarket/data/services/cart_service.dart';
import 'package:kumarket/presentation/widgets/app_button.dart';

class ShopingCartScreen extends StatelessWidget {
  const ShopingCartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartService = sl<CartService>();
    return SafeArea(
      child: AnimatedBuilder(
        animation: cartService,
        builder: (context, _) {
          if (cartService.isEmpty) {
            return _EmptyCart(
              onTap: () => context.go(Routers.pathMainScreen),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  children: [
                    const Text(
                      'Корзина',
                      style: AppTextStyles.h1,
                    ),
                    const SizedBox(height: 12),
                    ...cartService.lines.map(
                      (line) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.hexFFFFFF,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.shopping_bag_outlined),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    style: AppTextStyles.s16w600h000000,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatPrice(line.product.price),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.hex000000,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            cartService.removeOne(line.product),
                                        icon: const Icon(Icons.remove_rounded),
                                      ),
                                      Text(
                                        '${line.quantity}',
                                        style: AppTextStyles.s16w600h000000,
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            cartService.add(line.product),
                                        icon: const Icon(Icons.add_rounded),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  cartService.removeAll(line.product.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _CheckoutCard(cartService: cartService),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        children: [
          const Text(
            'Корзина',
            style: AppTextStyles.h1,
          ),
          const Spacer(),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.hexFFFFFF,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.shopping_cart_outlined,
              size: 44,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Пока пусто',
            style: AppTextStyles.h2,
          ),
          const SizedBox(height: 6),
          const Text(
            'Добавьте товары на главном экране',
            style: AppTextStyles.s14w400hB2B2B2,
          ),
          const SizedBox(height: 16),
          AppButton.main(
            title: 'Перейти к товарам',
            onTap: onTap,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({required this.cartService});

  final CartService cartService;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.hexFFFFFF,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        children: [
          _SummaryRow(
            title: 'Товары',
            value: formatPrice(cartService.subtotal),
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            title: 'Доставка',
            value: formatPrice(cartService.delivery),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: AppColors.hexE7E7E7),
          ),
          _SummaryRow(
            title: 'Итого',
            value: formatPrice(cartService.total),
            bold: true,
          ),
          const SizedBox(height: 12),
          AppButton.main(
            title: 'Оформить заказ',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.title,
    required this.value,
    this.bold = false,
  });

  final String title;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style =
        bold ? AppTextStyles.s16w600h000000 : AppTextStyles.s14w400h000000;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: style),
        Text(value, style: style),
      ],
    );
  }
}
