import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Ana Renkler
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color darkBlue = Color(0xFF172554);
  static const Color lightBlue = Color(0xFFEFF6FF);
  static const Color accentBlue = Color(0xFF38BDF8);

  // Durum Renkleri
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successForeground = Color(0xFF1B5E20);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFEF5350);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color formula = Color(0xFF7E57C2);
  static const Color formulaLight = Color(0xFFEDE7F6);
  static const Color teal = Color(0xFF26A69A);
  static const Color tealLight = Color(0xFFE0F2F1);
  static const Color brown = Color(0xFF8D6E63);
  static const Color brownLight = Color(0xFFEFEBE9);

  // Nötr Renkler
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F9FC);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color divider = Color(0xFFE2E8F0);

  // Tema
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentBlue,
        surface: white,
        error: error,
      ),
      dividerColor: divider,

      // AppBar Teması
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBlue,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: white,
        ),
      ),

      // Scaffold Teması
      scaffoldBackgroundColor: background,

      // Kart Teması
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider),
        ),
      ),

      // Elevated Button Teması
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      // Outlined Button Teması
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Text Button Teması
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // Input Decoration Teması
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
      ),

      // Floating Action Button Teması
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(primaryBlue.withValues(alpha: 0.45)),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(8),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        indicatorColor: lightBlue,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? primaryBlue
                : textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
      ),

      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: white,
        indicatorColor: lightBlue,
        elevation: 0,
        selectedIconTheme: IconThemeData(color: primaryBlue),
        unselectedIconTheme: IconThemeData(color: textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Dialog Teması
      dialogTheme: DialogThemeData(
        backgroundColor: white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // Snackbar Teması
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Chip Teması
      chipTheme: ChipThemeData(
        backgroundColor: lightBlue,
        selectedColor: primaryBlue,
        labelStyle: const TextStyle(fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Divider Teması
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // Text Teması
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textPrimary),
        bodySmall: TextStyle(fontSize: 12, color: textSecondary),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(fontSize: 11, color: textSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    const darkBackground = Color(0xFF0B1220);
    const darkSurface = Color(0xFF111827);
    const darkSurfaceRaised = Color(0xFF182235);
    const darkDivider = Color(0xFF334155);
    const darkText = Color(0xFFF1F5F9);
    const darkMutedText = Color(0xFF94A3B8);
    const darkPrimary = Color(0xFF60A5FA);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: darkPrimary,
      surface: darkSurface,
      error: const Color(0xFFF87171),
    );
    final light = theme;

    return light.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      cardColor: darkSurface,
      dividerColor: darkDivider,
      shadowColor: Colors.black.withValues(alpha: 0.45),
      appBarTheme: light.appBarTheme.copyWith(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: darkText,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: light.cardTheme.copyWith(
        color: darkSurface,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkDivider),
        ),
      ),
      dialogTheme: light.dialogTheme.copyWith(
        backgroundColor: darkSurfaceRaised,
        titleTextStyle: const TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: light.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: darkSurface,
        labelStyle: const TextStyle(color: darkMutedText),
        hintStyle: const TextStyle(color: darkMutedText),
        border: _darkInputBorder(darkDivider),
        enabledBorder: _darkInputBorder(darkDivider),
        focusedBorder: _darkInputBorder(darkPrimary, width: 2),
        errorBorder: _darkInputBorder(colorScheme.error),
        focusedErrorBorder: _darkInputBorder(colorScheme.error, width: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: light.filledButtonTheme.style?.copyWith(
          backgroundColor: const WidgetStatePropertyAll(darkPrimary),
          foregroundColor: const WidgetStatePropertyAll(Color(0xFF07111F)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: light.outlinedButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(darkPrimary),
          side: const WidgetStatePropertyAll(
            BorderSide(color: darkPrimary, width: 1.5),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: light.textButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(darkPrimary),
        ),
      ),
      navigationBarTheme: light.navigationBarTheme.copyWith(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xFF1E3A5F),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? darkPrimary
                : darkMutedText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: light.navigationRailTheme.copyWith(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0xFF1E3A5F),
        selectedIconTheme: const IconThemeData(color: darkPrimary),
        unselectedIconTheme: const IconThemeData(color: darkMutedText),
        selectedLabelTextStyle: const TextStyle(
          color: darkPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: darkMutedText,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkMutedText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: light.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: const Color(0xFF1E3A5F),
        side: const BorderSide(color: darkDivider),
        labelStyle: const TextStyle(color: darkText, fontSize: 13),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: darkText,
        iconColor: darkMutedText,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: darkSurfaceRaised,
        textStyle: TextStyle(color: darkText),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurfaceRaised,
        modalBackgroundColor: darkSurfaceRaised,
      ),
      iconTheme: const IconThemeData(color: darkMutedText),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(darkPrimary.withValues(alpha: 0.55)),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(8),
      ),
      textTheme: light.textTheme
          .apply(bodyColor: darkText, displayColor: darkText)
          .copyWith(
            bodySmall: const TextStyle(fontSize: 12, color: darkMutedText),
            labelMedium: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: darkMutedText,
            ),
            labelSmall: const TextStyle(fontSize: 11, color: darkMutedText),
          ),
    );
  }

  static OutlineInputBorder _darkInputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static Color tableRowColor(BuildContext context, int visibleIndex) {
    final theme = Theme.of(context);
    if (visibleIndex.isEven) return theme.colorScheme.surface;
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : const Color(0xFFF3F4F6);
  }

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surfaceContainer(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainer;

  static Color onSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceVariant(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color primaryContainer(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;

  static Color tintedSurface(BuildContext context, Color color) =>
      Color.alphaBlend(
        color.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.20 : 0.10,
        ),
        Theme.of(context).colorScheme.surface,
      );

  /// A readable accent on both light and dark tinted surfaces.
  static Color readableAccent(BuildContext context, Color color) =>
      readableInk(color, dark: Theme.of(context).brightness == Brightness.dark);

  /// The same rule without a context, so the home screen widget's marks can be
  /// given exactly the colour the app draws them in.
  static Color readableInk(Color color, {required bool dark}) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(
          dark
              ? hsl.lightness.clamp(0.68, 0.85)
              : hsl.lightness.clamp(0.25, 0.38),
        )
        .toColor();
  }

  /// The colours the home screen widget draws its table with, taken from the
  /// running theme so the widget can never drift from the app. Values are
  /// plain ARGB integers because they travel through JSON.
  static Map<String, int> widgetPalette(ThemeData theme) {
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    int argb(Color color) => color.toARGB32();
    return {
      'background': argb(theme.scaffoldBackgroundColor),
      'header': argb(colors.primaryContainer),
      'onHeader': argb(colors.onPrimaryContainer),
      'line': argb(colors.outlineVariant.withValues(alpha: 0.55)),
      'rowEven': argb(colors.surface),
      'rowOdd': argb(
        dark ? colors.surfaceContainerHigh : const Color(0xFFF3F4F6),
      ),
      // The tally paints today amber, not blue; header and cells differ.
      'todayHeader': argb(Colors.amber.withValues(alpha: 0.35)),
      'todayCell': argb(Colors.amber.withValues(alpha: 0.12)),
      'weekend': argb(Colors.orange.withValues(alpha: 0.08)),
      'text': argb(colors.onSurface),
      'muted': argb(colors.onSurfaceVariant),
      'accent': argb(colors.primary),
    };
  }

  static BoxDecoration cardDecorationFor(BuildContext context) => BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Theme.of(context).dividerColor),
  );

  // Yardımcı Metotlar
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration gradientDecoration({double radius = 12}) =>
      BoxDecoration(
        gradient: const LinearGradient(
          colors: [darkBlue, primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration coloredCardDecoration(
    Color color, {
    double radius = 10,
  }) => BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color.withValues(alpha: 0.3)),
  );
}
