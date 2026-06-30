import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Color Palette ────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Brand — Quick Corporation
  static const Color primary = Color(0xFF6B7A3D);        // olive green (CTA, buttons, active)
  static const Color primaryDark = Color(0xFF4D5A2C);     // dark olive
  static const Color primaryLight = Color(0xFFF0F2E8);    // light olive tint

  // Sidebar / dark panels (auth brand panel, side nav)
  static const Color sidebarBg = Color(0xFF111111);
  static const Color sidebarHover = Color(0xFF1C1C1C);
  static const Color sidebarActive = Color(0xFF1C1C1C);
  static const Color sidebarText = Color(0xFF9A9A9A);
  static const Color sidebarTextActive = Color(0xFFFFFFFF);
  static const Color sidebarDivider = Color(0xFF2A2A2A);
  static const Color sidebarAccentBar = Color(0xFF6B7A3D);

  // Content backgrounds
  static const Color background = Color(0xFFFFFFFF);      // 70% White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F8F5);  // Cards / Sections
  static const Color cardBg = Color(0xFFF8F8F5);

  // Text (20% Black / Grey usage)
  static const Color textPrimary = Color(0xFF111111);     // headings
  static const Color textSecondary = Color(0xFF5A5A5A);   // body / icons
  static const Color textTertiary = Color(0xFF9A9A9A);    // captions / placeholders
  static const Color textHint = Color(0xFFBBBBBB);

  // Borders / Dividers
  static const Color divider = Color(0xFFD9D9D9);
  static const Color border = Color(0xFFD9D9D9);

  // Semantic — kept as universal UX signals; not brand accent colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF6B7A3D);            // olive (replaces blue)
  static const Color infoLight = Color(0xFFF0F2E8);       // light olive

  // POS-specific
  static const Color cartBg = Color(0xFFF8F8F5);
  static const Color cartItemBg = Color(0xFFFFFFFF);
  static const Color fonepayColor = Color(0xFF6BBD44);    // Fonepay brand green (keep as-is)
  static const Color cashColor = Color(0xFF10B981);
  static const Color splitColor = Color(0xFF6B7A3D);      // olive

  // Aliases
  static const Color accent = primary;
  static const Color refund = danger;
  static const Color navSelected = primary;               // olive for active nav
  static const Color navUnselected = textTertiary;
  static const Color keypadKey = surfaceVariant;

  // Avatar / category palette — olive-family tints, no blue/purple
  static const List<Color> avatarColors = [
    Color(0xFF6B7A3D), // olive
    Color(0xFF4D5A2C), // dark olive
    Color(0xFF8A9950), // medium olive
    Color(0xFF111111), // black
    Color(0xFF3A3A3A), // dark grey
    Color(0xFF5A5A5A), // grey
    Color(0xFF9A9A9A), // light grey
    Color(0xFFB5C090), // pale olive
  ];

  // Category chip palette — subtle tints for visual differentiation
  static const List<Color> categoryBg = [
    Color(0xFFE8EDD6), // olive-50
    Color(0xFFF8F8F5), // surface white
    Color(0xFFEEEEEB), // warm grey
    Color(0xFFE0E4D0), // olive-grey
    Color(0xFFDCE0C8), // deeper olive tint
  ];
  static const List<Color> categoryFg = [
    Color(0xFF4D5A2C), // dark olive
    Color(0xFF5A5A5A), // grey
    Color(0xFF5A5A5A),
    Color(0xFF4D5A2C),
    Color(0xFF3A4520),
  ];
}

// ─── Typography ───────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1.0, height: 1.1,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle titleLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textTertiary,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.1,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, letterSpacing: 0.3,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary, letterSpacing: 0.5,
  );

  // POS-specific
  static const TextStyle priceTag = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static const TextStyle kpiValue = TextStyle(
    fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -1,
  );
  static const TextStyle kpiLabel = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary, letterSpacing: 0.2,
  );
}

// ─── Spacing ──────────────────────────────────────────────────────────────────

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const EdgeInsets pagePadding = EdgeInsets.all(24);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);

  static const double sidebarWidth = 220;
  static const double cartPanelWidth = 340;
  static const double topBarHeight = 60;
}

// ─── Radius ───────────────────────────────────────────────────────────────────

class AppRadius {
  AppRadius._();
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 24;
  static const double pill = 100;

  static const BorderRadius smBR = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdBR = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgBR = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlBR = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillBR = BorderRadius.all(Radius.circular(pill));
}

// ─── Shadows ──────────────────────────────────────────────────────────────────

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x06000000), blurRadius: 1, offset: Offset(0, 0)),
  ];

  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> dialog = [
    BoxShadow(color: Color(0x26000000), blurRadius: 32, offset: Offset(0, 8)),
  ];
}

// ─── Theme ────────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.textSecondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.surfaceVariant,
      onSecondaryContainer: AppColors.textPrimary,
      tertiary: AppColors.success,
      onTertiary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      errorContainer: AppColors.dangerLight,
      onErrorContainer: Color(0xFFB91C1C),
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.divider,
      shadow: Color(0x1A000000),
      scrim: Color(0x40000000),
      inverseSurface: AppColors.sidebarBg,
      onInverseSurface: AppColors.sidebarTextActive,
      inversePrimary: Color(0xFF8A9950),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'SF Pro Display',
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.black,
        selectionColor: Color(0x336B7A3D),
        selectionHandleColor: Colors.black,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.divider,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 20),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBR,
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdBR,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        floatingLabelStyle: const TextStyle(color: Colors.black, fontSize: 12),
        isDense: true,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBR),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          minimumSize: const Size(0, 48),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBR),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          minimumSize: const Size(0, 48),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBR),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          minimumSize: const Size(0, 48),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smBR),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.pillBR),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 20,
        iconColor: AppColors.textSecondary,
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBR),
        titleTextStyle: AppTextStyles.headlineMedium,
        contentTextStyle: AppTextStyles.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.sidebarBg,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBR),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
