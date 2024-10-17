import 'package:flutter/material.dart';
import 'package:nomo_router/nomo_router.dart';
import 'package:nomo_ui_kit/components/app/app_bar/nomo_app_bar.dart';
import 'package:nomo_ui_kit/components/app/bottom_bar/nomo_bottom_bar.dart';
import 'package:nomo_ui_kit/components/app/bottom_bar/nomo_horizontal_tile.dart';
import 'package:nomo_ui_kit/components/app/routebody/nomo_route_body.dart';
import 'package:nomo_ui_kit/components/buttons/primary/nomo_primary_button.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/utils/layout_extensions.dart';
import 'package:walletkit_dart/walletkit_dart.dart';
import 'package:zeniq_swap_frontend/main.dart';
import 'package:zeniq_swap_frontend/pages/background.dart';
import 'package:zeniq_swap_frontend/routes.dart';
import 'package:zeniq_swap_frontend/theme.dart';

class HomePage extends StatelessWidget {
  final Widget nav;

  const HomePage({super.key, required this.nav});

  @override
  Widget build(BuildContext context) {
    return NomoRouteBody(
      maxContentWidth: 1200,
      background: AppBackground(),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          AppBar(),
          Expanded(child: nav),
        ],
      ),
    );
  }
}

class AppBar extends StatelessWidget {
  const AppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.responsiveValue(
        small: EdgeInsets.all(8),
        medium: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        large: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: NomoAppBar(
        backgroundColor: context.colors.background1.withOpacity(0.4),
        elevation: context.isDark ? 0 : 2,
        borderRadius: BorderRadius.circular(24),
        height: 64,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo.png',
              width: 42,
              height: 42,
            ),
            16.hSpacing,
            Menu(),
          ],
        ),
        trailling: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccountAction(),
            6.hSpacing,
            SettingsAction(),
          ],
        ),
      ),
    );
  }
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return PrimaryNomoButton(
      backgroundColor: context.colors.background3,
      foregroundColor: context.colors.foreground1,
      height: 42,
      width: 42,
      iconSize: 18,
      elevation: 1,
      borderRadius: BorderRadius.circular(16),
      icon: Icons.more_horiz,
      padding: EdgeInsets.zero,
      onPressed: () {
        NomoNavigator.of(context).push(SettingsDialogRoute());
      },
    );
  }
}

String shortenAddress(String address) {
  return "${address.substring(0, 6)}...${address.substring(address.length - 4)}";
}

class AccountAction extends StatelessWidget {
  const AccountAction({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: ValueListenableBuilder(
        valueListenable: $addressNotifier,
        builder: (context, address, connectWidget) {
          if (address == null) return connectWidget!;

          if ($metamask != null &&
              $metamask?.chainId != ZeniqSmartNetwork.chainId) {
            return SecondaryNomoButton(
              width: 148.0.ifElse(context.isSmall == false, other: 48),
              height: 42,
              backgroundColor: context.colors.background3,
              borderRadius: BorderRadius.circular(16),
              foregroundColor: context.colors.foreground1,
              selectionColor: context.colors.primary,
              border: Border.fromBorderSide(BorderSide.none),
              padding: EdgeInsets.symmetric(horizontal: 12),
              onPressed: () {
                $metamask?.switchChain(zeniqSmartChainInfo);
              },
              text: "Switch",
              iconSize: 18,
              icon: Icons.webhook_rounded,
              textStyle: context.typography.b1,
            );
          }

          return SecondaryNomoButton(
            width: 148.0.ifElse(context.isSmall == false, other: 48),
            height: 42,
            backgroundColor: context.colors.background3,
            borderRadius: BorderRadius.circular(16),
            foregroundColor: context.colors.foreground1,
            selectionColor: context.colors.primary,
            border: Border.fromBorderSide(BorderSide.none),
            padding: EdgeInsets.symmetric(horizontal: 12),
            onPressed: () {
              //   NomoNavigator.fromKey.push(ProfilePageRoute());
            },
            text: shortenAddress(address).ifElseNull(context.isSmall == false),
            iconSize: 18,
            icon: Icons.wallet,
            textStyle: context.typography.b1,
          );
        },
        child: SecondaryNomoButton(
          padding: EdgeInsets.symmetric(horizontal: 16),
          height: 42,
          backgroundColor: context.colors.primary.withOpacity(0.2),
          foregroundColor: context.colors.primary,
          selectionColor: context.colors.primary.darken(),
          border: Border.fromBorderSide(BorderSide.none),
          textStyle: context.typography.b1,
          borderRadius: BorderRadius.circular(24),
          spacing: 8,
          text: "Connect",
          icon: Icons.wallet,
          onPressed: () {
            $metamask?.connect();
          },
        ),
      ),
    );
  }
}

class Menu extends StatelessWidget {
  const Menu({super.key});
  void onMenuTap(String path) {
    NomoNavigator.fromKey.replaceNamed(path);
  }

  @override
  Widget build(BuildContext context) {
    NomoNavigatorInformationProvider.of(context);
    final selected = nestedNavObserver.currentNested?.path;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in menuItems)
          NomoHorizontalListTile(
            itemWidth:
                context.responsiveValue(small: 80, medium: 96, large: 128),
            item: item,
            height: 42,
            style: context.typography.h1
                .copyWith(fontSize: 28, fontWeight: FontWeight.w800),
            theme: NomoBottomBarThemeData(
              selectedForeground: context.colors.primary,
              foreground: context.colors.foreground2,
              borderRadius: BorderRadius.circular(24),
            ),
            selected: item.key == selected,
            onTap: () => onMenuTap(item.key),
          )
      ],
    );
  }
}
