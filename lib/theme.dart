import 'package:flutter/material.dart';
import 'package:nomo_ui_kit/components/app/scaffold/nomo_scaffold.dart';
import 'package:nomo_ui_kit/components/buttons/secondary/nomo_secondary_button.dart';
import 'package:nomo_ui_kit/components/divider/nomo_divider.dart';
import 'package:nomo_ui_kit/components/info_item/nomo_info_item.dart';
import 'package:nomo_ui_kit/components/input/textInput/nomo_input.dart';
import 'package:nomo_ui_kit/components/loading/shimmer/shimmer.dart';
import 'package:nomo_ui_kit/theme/nomo_theme.dart';
import 'package:nomo_ui_kit/theme/sub/nomo_color_theme.dart';
import 'package:nomo_ui_kit/theme/sub/nomo_constants.dart';
import 'package:nomo_ui_kit/theme/sub/nomo_sizing_theme.dart';
import 'package:webon_kit_dart/webon_kit_dart.dart';

enum ColorMode { LIGHT, DARK }

enum SizingMode {
  SMALL,
  MEDIUM,
  LARGE,
}

class AppThemeDelegate extends NomoThemeDelegate<ColorMode, SizingMode> {
  @override
  NomoConstantsThemeData get constants {
    return NomoConstantsThemeData(
      constants: NomoConstants(),
      componentConstantsBuilder: (core) {
        return const NomoComponentConstants();
      },
    );
  }

  @override
  NomoComponentSizesNullable defaultComponentsSize(NomoSizes core) {
    return const NomoComponentSizesNullable(
      inputSizing: NomoInputSizingDataNullable(),
    );
  }

  @override
  ColorMode initialColorTheme() {
    final key = WebLocalStorage.getItem("theme");
    return key == "light" ? ColorMode.LIGHT : ColorMode.DARK;
  }

  @override
  SizingMode sizingThemeBuilder(double width) {
    return switch (width) {
      > 1080 => SizingMode.LARGE,
      > 580 => SizingMode.MEDIUM,
      _ => SizingMode.SMALL,
    };
  }

  @override
  NomoTypographyTheme get typography => NomoTypographyTheme(
        b1: TextStyle(fontFamily: "Roboto"),
        b2: TextStyle(fontFamily: "Roboto"),
        b3: TextStyle(fontFamily: "Roboto"),
        h1: TextStyle(fontFamily: "DancingScript"),
        h2: TextStyle(fontFamily: "DancingScript"),
        h3: TextStyle(fontFamily: "DancingScript"),
      );

  @override
  Map<SizingMode, NomoSizingThemeDataNullable> getSizingThemes() {
    return {
      SizingMode.SMALL: NomoSizingThemeDataNullable(
        key: const ValueKey('small'),
        sizes: const NomoSizes(
          fontSizeB1: 14,
          fontSizeB2: 18,
          fontSizeB3: 28,
          fontSizeH1: 36,
          fontSizeH2: 48,
          fontSizeH3: 64,
          spacing1: 4,
          spacing2: 6,
          spacing3: 8,
        ),
        buildComponents: (core) {
          return const NomoComponentSizesNullable(
            scaffoldSizing: NomoScaffoldSizingDataNullable(
              showSider: false,
            ),
          );
        },
      ),
      SizingMode.MEDIUM: NomoSizingThemeDataNullable(
        key: const ValueKey('medium'),
        sizes: const NomoSizes(
          fontSizeB1: 14,
          fontSizeB2: 18,
          fontSizeB3: 28,
          fontSizeH1: 36,
          fontSizeH2: 48,
          fontSizeH3: 64,
          spacing1: 4,
          spacing2: 6,
          spacing3: 8,
        ),
        buildComponents: (core) {
          return const NomoComponentSizesNullable(
            scaffoldSizing: NomoScaffoldSizingDataNullable(
              showSider: false,
            ),
          );
        },
      ),
      SizingMode.LARGE: NomoSizingThemeDataNullable(
        key: const ValueKey('large'),
        sizes: const NomoSizes(
          fontSizeB1: 14,
          fontSizeB2: 18,
          fontSizeB3: 28,
          fontSizeH1: 36,
          fontSizeH2: 48,
          fontSizeH3: 64,
          spacing1: 4,
          spacing2: 6,
          spacing3: 8,
        ),
        buildComponents: (core) {
          return const NomoComponentSizesNullable(
            scaffoldSizing: NomoScaffoldSizingDataNullable(
              showSider: false,
            ),
          );
        },
      ),
    };
  }

  @override
  Map<ColorMode, NomoColorThemeDataNullable> getColorThemes() {
    return {
      ColorMode.LIGHT: NomoColorThemeDataNullable(
        key: const ValueKey('light'),
        colors: const NomoColors(
          primary: primaryColor,
          onPrimary: Colors.white,
          primaryContainer: Color(0xffFCFAF7),
          secondary: secondary,
          onSecondary: Color(0xff000000),
          secondaryContainer: Color(0xffe6d0a3),
          background1: Color(0xFFffffff),
          background2: Color(0xFFfafafa),
          background3: Color(0xFFf5f5f5),
          surface: Colors.white,
          error: Colors.redAccent,
          disabled: Color(0xFFf0f0f0),
          foreground1: Color(0xCF000000),
          foreground2: Color(0xDF000000),
          foreground3: Colors.black54,
          brightness: Brightness.light,
          onDisabled: Color(0xFFd9d9d9),
        ),
        buildComponents: (core) {
          return NomoComponentColorsNullable(
            secondaryButtonColor: SecondaryNomoButtonColorDataNullable(
              foregroundColor: core.foreground1,
            ),
          );
        },
      ),
      ColorMode.DARK: NomoColorThemeDataNullable(
        key: const ValueKey('dark'),
        colors: const NomoColors(
          primary: primaryColor,
          onPrimary: Colors.white,
          primaryContainer: Color(0xffFCFAF7),
          secondary: secondary,
          onSecondary: Color(0xff000000),
          secondaryContainer: Color(0xffe6d0a3),
          background1: Color(0xff293138),
          background2: Color(0xff1e2428),
          background3: Color(0xff13191d),
          surface: Color(0xff2e363c),
          error: Colors.redAccent,
          disabled: Color(0xFFE0E0E0),
          foreground1: Color(0xEAFFFFFF),
          foreground2: Color(0xF0FFFFFF),
          foreground3: Color(0xFAFFFFFF),
          brightness: Brightness.dark,
          onDisabled: Colors.grey,
        ),
        buildComponents: (core) {
          return NomoComponentColorsNullable(
            secondaryButtonColor: SecondaryNomoButtonColorDataNullable(
              foregroundColor: core.foreground1,
            ),
          );
        },
      ),
    };
  }

  @override
  NomoComponentColorsNullable defaultComponentsColor(NomoColors core) {
    return NomoComponentColorsNullable(
      inputColor: NomoInputColorDataNullable(
        borderRadius: BorderRadius.circular(16),
        background: core.background2.withOpacity(0.5),
        border: Border.all(color: Colors.white10),
      ),
      infoItemColor: const NomoInfoItemColorDataNullable(),
      dividerColor: NomoDividerColorDataNullable(
        color: core.background1,
      ),
      shimmerColor: const ShimmerColorDataNullable(
        gradient: LinearGradient(
          colors: [
            Color(0x222FAAA5),
            Color.fromARGB(126, 104, 115, 154),
            Color(0x222FAAA5)
          ],
          stops: [0.1, 0.3, 0.4],
          begin: Alignment(-1.0, -0.3),
          end: Alignment(1.0, 0.3),
        ),
      ),
    );
  }
}

extension ThemeExtension on BuildContext {
  bool get isDark => colorTheme.key.value == "dark";
}

extension ThemeContextExtension on BuildContext {
  SizingMode get sizingMode => themeProvider.sizingMode as SizingMode;

  bool get isSmall => sizingMode == SizingMode.SMALL;
  bool get isMedium => sizingMode == SizingMode.MEDIUM;
  bool get isLarge => sizingMode == SizingMode.LARGE;

  T responsiveValue<T>({
    required T small,
    required T medium,
    required T large,
  }) {
    return switch (sizingMode) {
      SizingMode.SMALL => small,
      SizingMode.MEDIUM => medium,
      SizingMode.LARGE => large,
    };
  }
}
