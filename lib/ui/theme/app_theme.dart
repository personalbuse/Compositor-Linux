import 'package:flutter/material.dart';

class AppTheme {
  static const Color canvasBackground = Color(0xFF1B1B1B);
  static const Color windowBackground = Color(0xFF242424);
  static const Color surfaceColor = Color(0xFF2D2D2D);
  static const Color surfaceHoverColor = Color(0xFF363636);
  static const Color borderColor = Color(0xFF3D3D3D);
  static const Color borderActiveColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF808080);
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentBlueHover = Color(0xFF0066CC);
  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentOrange = Color(0xFFFF9F0A);
  static const Color toolbarBackground = Color(0xFF1A1A1A);
  static const Color railBackground = Color(0xFF1A1A1A);
  static const Color panelBackground = Color(0xFF1A1A1A);
  static const Color statusBarBackground = Color(0xFF1A1A1A);
  static const Color checkerboardLight = Color(0xFF595959);
  static const Color checkerboardDark = Color(0xFF4D4D4D);
  static const Color documentShadow = Color(0x59000000);
  static const Color documentBorder = Color(0x21FFFFFF);
  static const Color selectionBlue = Color(0xFF007AFF);
  static const Color hoverOverlay = Color(0x1FFFFFFF);
  static const Color activeOverlay = Color(0x33FFFFFF);

  static const double railWidth = 56.0;
  static const double railButtonSize = 36.0;
  static const double railSpacing = 10.0;
  static const double toolbarHeight = 40.0;
  static const double statusBarHeight = 30.0;
  static const double layersPanelDefaultWidth = 252.0;
  static const double toolHeaderHeight = 44.0;
  static const double borderRadius = 7.0;
  static const double borderWidth = 1.0;

  static const TextStyle statusBarStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11,
    fontFeatures: [FontFeature.tabularFigures()],
    color: textSecondary,
    height: 1.0,
  );

  static const TextStyle layerNameStyle = TextStyle(
    fontSize: 13,
    color: textPrimary,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle layerNameSmallStyle = TextStyle(
    fontSize: 11,
    color: textSecondary,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle toolbarTitleStyle = TextStyle(
    fontSize: 13,
    color: textPrimary,
    fontWeight: FontWeight.w500,
  );

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: windowBackground,
      canvasColor: windowBackground,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentBlue,
        surface: surfaceColor,
        background: windowBackground,
        error: accentRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: toolbarBackground,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: toolbarTitleStyle,
        toolbarHeight: toolbarHeight,
      ),
      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 20,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 13),
        bodySmall: TextStyle(color: textSecondary, fontSize: 11),
        labelLarge: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: borderColor,
        thickness: borderWidth,
        space: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentBlue,
        inactiveTrackColor: borderColor,
        thumbColor: accentBlue,
        overlayColor: accentBlue.withValues(alpha: 0.2),
        valueIndicatorColor: accentBlue,
        valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontSize: 11),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: const TextStyle(color: textPrimary, fontSize: 13),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: const BorderSide(color: accentBlue),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(surfaceColor),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: const BorderSide(color: borderColor),
            ),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: borderColor),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 13),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: borderColor),
        ),
        titleTextStyle: const TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 13),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: borderColor),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 11),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        preferBelow: false,
        verticalOffset: 8,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderColor),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      focusColor: accentBlue.withValues(alpha: 0.2),
      hoverColor: hoverOverlay,
      highlightColor: activeOverlay,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
    );
  }
}