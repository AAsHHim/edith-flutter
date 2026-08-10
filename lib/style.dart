import 'package:flutter/material.dart';

/// Central color tokens for the EDITH interface.
abstract final class EdithColors {
  static const Color background = Color(0xFF070B10);
  static const Color surface = Color(0xFF0E1821);
  static const Color elevatedSurface = Color(0xFF152534);
  static const Color primaryAccent = Color(0xFF27E5FF);
  static const Color secondaryAccent = Color(0xFF4E8CFF);
  static const Color primaryText = Color(0xFFF4FAFF);
  static const Color secondaryText = Color(0xFF91A7B8);
  static const Color success = Color(0xFF37D67A);
  static const Color warning = Color(0xFFFFB547);
  static const Color error = Color(0xFFFF5D6C);
  static const Color disabled = Color(0xFF536675);
}

/// Central typography tokens for the EDITH interface.
abstract final class EdithTextStyles {
  static const String fontFamily = 'SF Pro Display';

  static const TextStyle title = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.primaryText,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.primaryText,
    fontSize: 32,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.4,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.secondaryText,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.primaryText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle secondaryBody = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.secondaryText,
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle navigationLabel = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.secondaryText,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );

  static const TextStyle selectedNavigationLabel = TextStyle(
    fontFamily: fontFamily,
    color: EdithColors.background,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1,
  );
}

// Compatibility aliases for pages that have not yet moved to EDITH tokens.
// Their original values are intentionally retained to keep this commit scoped
// to the shared title and navigation bars.
const Color colorWhite = Color(0xFFFFFFFF);
const Color colorLight = Color(0xFFB6BEC9);
const Color colorPink = Color(0xFFF288BF);
const Color colorRed = Color(0xFFDC0000);
const Color colorDark = Color(0xFF292929);

const TextStyle textStyleWhiteTitle = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorWhite,
  fontSize: 18,
  fontWeight: FontWeight.w900,
);

const TextStyle textStyleLightTitle = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorLight,
  fontSize: 18,
  fontWeight: FontWeight.w900,
);

const TextStyle textStyleDarkTitle = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorDark,
  fontSize: 18,
  fontWeight: FontWeight.w900,
);

const TextStyle textStyleLightHeading = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorWhite,
  fontSize: 32,
  fontWeight: FontWeight.w200,
);

const TextStyle textStyleLightSubHeading = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorLight,
  fontSize: 14,
  fontWeight: FontWeight.w900,
);

const TextStyle textStyleWhite = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorWhite,
  fontSize: 14,
  fontWeight: FontWeight.w300,
);

const TextStyle textStyleLight = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorLight,
  fontSize: 14,
  fontWeight: FontWeight.w300,
);

const TextStyle textStylePink = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorPink,
  fontSize: 14,
  fontWeight: FontWeight.w300,
);

const TextStyle textStyleRed = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorRed,
  fontSize: 14,
  fontWeight: FontWeight.w300,
);

const TextStyle textStyleDark = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorDark,
  fontSize: 14,
  fontWeight: FontWeight.w300,
);

const TextStyle textStyleWhiteWidget = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorWhite,
  fontSize: 14,
  fontWeight: FontWeight.w900,
);

const TextStyle textStyleDarkWidget = TextStyle(
  fontFamily: EdithTextStyles.fontFamily,
  color: colorDark,
  fontSize: 14,
  fontWeight: FontWeight.w900,
);
