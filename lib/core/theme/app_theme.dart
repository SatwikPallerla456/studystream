import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The shared Tangerine layout rhythm. Values are intentionally limited so screens
/// stay visually related at every window size.
abstract final class AppSpace {
  static const double hairline = 2;
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const double jumbo = 80;
}

abstract final class AppRadius {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double pill = 999;
}

/// Breakpoints describe layout behaviour, not particular devices.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double expanded = 1200;
  static const double wide = 1440;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= compact && width < expanded;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= expanded;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Duration emphasized = Duration(milliseconds: 320);

  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}

abstract final class AppElevation {
  static const List<BoxShadow> level1 = [
    BoxShadow(color: Color(0x0D0B1814), blurRadius: 12, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> level2 = [
    BoxShadow(color: Color(0x140B1814), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

@immutable
class StudyColors extends ThemeExtension<StudyColors> {
  const StudyColors({
    required this.canvas,
    required this.surfaceRaised,
    required this.surfaceSubtle,
    required this.surfaceStrong,
    required this.outlineSoft,
    required this.textMuted,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.player,
    required this.playerRaised,
    required this.focusRing,
    required this.hover,
  });

  final Color canvas;
  final Color surfaceRaised;
  final Color surfaceSubtle;
  final Color surfaceStrong;
  final Color outlineSoft;
  final Color textMuted;
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color player;
  final Color playerRaised;
  final Color focusRing;
  final Color hover;

  @override
  StudyColors copyWith({
    Color? canvas,
    Color? surfaceRaised,
    Color? surfaceSubtle,
    Color? surfaceStrong,
    Color? outlineSoft,
    Color? textMuted,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? player,
    Color? playerRaised,
    Color? focusRing,
    Color? hover,
  }) {
    return StudyColors(
      canvas: canvas ?? this.canvas,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
      surfaceStrong: surfaceStrong ?? this.surfaceStrong,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      textMuted: textMuted ?? this.textMuted,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      player: player ?? this.player,
      playerRaised: playerRaised ?? this.playerRaised,
      focusRing: focusRing ?? this.focusRing,
      hover: hover ?? this.hover,
    );
  }

  @override
  StudyColors lerp(covariant StudyColors? other, double t) {
    if (other == null) return this;
    return StudyColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      surfaceStrong: Color.lerp(surfaceStrong, other.surfaceStrong, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      player: Color.lerp(player, other.player, t)!,
      playerRaised: Color.lerp(playerRaised, other.playerRaised, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
    );
  }
}

extension StudyThemeContext on BuildContext {
  StudyColors get studyColors => Theme.of(this).extension<StudyColors>()!;
}

abstract final class AppTheme {
  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFFA94F08),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFFFE4CE),
    onPrimaryContainer: Color(0xFF5B2805),
    secondary: Color(0xFF755A22),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFE9B2),
    onSecondaryContainer: Color(0xFF3C2A00),
    tertiary: Color(0xFF426277),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFCBE8FB),
    onTertiaryContainer: Color(0xFF102F41),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE4E2),
    onErrorContainer: Color(0xFF7A271A),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF252321),
    onSurfaceVariant: Color(0xFF69645F),
    outline: Color(0xFF8F8780),
    outlineVariant: Color(0xFFE2DCD7),
    shadow: Color(0xFF171310),
    scrim: Color(0xFF171310),
    inverseSurface: Color(0xFF35312D),
    onInverseSurface: Color(0xFFF9F5F2),
    inversePrimary: Color(0xFFF1A15A),
    surfaceTint: Color(0xFFA94F08),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFD37918),
    onPrimary: Color(0xFF381A04),
    primaryContainer: Color(0xFF5B300E),
    onPrimaryContainer: Color(0xFFFFE4CE),
    secondary: Color(0xFFE8C66F),
    onSecondary: Color(0xFF3D2F00),
    secondaryContainer: Color(0xFF574500),
    onSecondaryContainer: Color(0xFFFFE9B2),
    tertiary: Color(0xFFAFCDE2),
    onTertiary: Color(0xFF163448),
    tertiaryContainer: Color(0xFF2D4B5E),
    onTertiaryContainer: Color(0xFFCBE8FB),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF292827),
    onSurface: Color(0xFFF0ECE8),
    onSurfaceVariant: Color(0xFFBCB5AF),
    outline: Color(0xFF958E88),
    outlineVariant: Color(0xFF46413D),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFF0ECE8),
    onInverseSurface: Color(0xFF35312D),
    inversePrimary: Color(0xFFA94F08),
    surfaceTint: Color(0xFFD37918),
  );

  static const _lightExtras = StudyColors(
    canvas: Color(0xFFF5F2EF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEEE9E5),
    surfaceStrong: Color(0xFFE6DFD8),
    outlineSoft: Color(0xFFE2DCD7),
    textMuted: Color(0xFF756D66),
    success: Color(0xFF247A4D),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD8F3E3),
    warning: Color(0xFF8B6100),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFEDC2),
    info: Color(0xFF2E6786),
    infoContainer: Color(0xFFDCEFFA),
    player: Color(0xFF0E0E0E),
    playerRaised: Color(0xFF191919),
    focusRing: Color(0xFFA94F08),
    hover: Color(0x0FA94F08),
  );

  static const _darkExtras = StudyColors(
    canvas: Color(0xFF191919),
    surfaceRaised: Color(0xFF222120),
    surfaceSubtle: Color(0xFF292827),
    surfaceStrong: Color(0xFF34312F),
    outlineSoft: Color(0xFF403C38),
    textMuted: Color(0xFFB3ABA5),
    success: Color(0xFF75D19B),
    onSuccess: Color(0xFF00391F),
    successContainer: Color(0xFF174B31),
    warning: Color(0xFFF0C66B),
    onWarning: Color(0xFF412D00),
    warningContainer: Color(0xFF4F3C0B),
    info: Color(0xFFA8D5EE),
    infoContainer: Color(0xFF23485B),
    player: Color(0xFF0E0E0E),
    playerRaised: Color(0xFF191919),
    focusRing: Color(0xFFD37918),
    hover: Color(0x14D37918),
  );

  static ThemeData light() => _theme(_lightScheme, _lightExtras);

  static ThemeData dark() => _theme(_darkScheme, _darkExtras);

  static ThemeData _theme(ColorScheme colors, StudyColors extras) {
    final textTheme = _textTheme(colors);
    final border = BorderSide(color: extras.outlineSoft);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      borderSide: border,
    );

    ButtonStyle buttonStyle({bool outlined = false}) => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      side: outlined ? WidgetStatePropertyAll(border) : null,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) return extras.hover;
        return null;
      }),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
      extensions: [extras],
      scaffoldBackgroundColor: extras.canvas,
      canvasColor: extras.canvas,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: extras.canvas,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: extras.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: border,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerColor: extras.outlineSoft,
      dividerTheme: DividerThemeData(color: extras.outlineSoft, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extras.surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: extras.textMuted),
        hintStyle: TextStyle(color: extras.textMuted),
        errorMaxLines: 2,
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: extras.outlineSoft.withValues(alpha: .6),
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colors.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle()),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle(outlined: true),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle()),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpace.sm,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs,
        ),
        iconColor: colors.onSurfaceVariant,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: extras.textMuted,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: extras.surfaceRaised,
        elevation: 0,
        useIndicator: true,
        indicatorColor: colors.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        selectedIconTheme: IconThemeData(color: colors.onPrimaryContainer),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: colors.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: extras.textMuted,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: extras.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : extras.textMuted,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          side: WidgetStatePropertyAll(border),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primaryContainer
                : extras.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: extras.surfaceRaised,
        selectedColor: colors.primaryContainer,
        side: border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        labelStyle: textTheme.labelMedium,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: extras.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpace.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: border,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: extras.surfaceRaised,
        modalBackgroundColor: extras.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: extras.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: border,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: extras.surfaceStrong,
        circularTrackColor: extras.surfaceStrong,
        linearMinHeight: 7,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          colors.outline.withValues(alpha: .7),
        ),
        radius: const Radius.circular(AppRadius.pill),
        thickness: const WidgetStatePropertyAll(7),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        textStyle: textTheme.labelMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : extras.surfaceStrong,
        ),
        trackOutlineColor: WidgetStatePropertyAll(extras.outlineSoft),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: extras.surfaceStrong,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: .12),
        trackHeight: 6,
      ),
      focusColor: extras.focusRing.withValues(alpha: .16),
      hoverColor: extras.hover,
    );
  }

  static TextTheme _textTheme(ColorScheme colors) => TextTheme(
    displayLarge: TextStyle(
      fontSize: 48,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: colors.onSurface,
    ),
    displayMedium: TextStyle(
      fontSize: 40,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.1,
      color: colors.onSurface,
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: -.7,
      color: colors.onSurface,
    ),
    headlineMedium: TextStyle(
      fontSize: 23,
      height: 1.22,
      fontWeight: FontWeight.w500,
      letterSpacing: -.45,
      color: colors.onSurface,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.28,
      fontWeight: FontWeight.w500,
      letterSpacing: -.25,
      color: colors.onSurface,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -.1,
      color: colors.onSurface,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: colors.onSurfaceVariant,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: colors.onSurfaceVariant,
    ),
    bodySmall: TextStyle(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: colors.onSurfaceVariant,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: colors.onSurface,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: .25,
      color: colors.onSurfaceVariant,
    ),
  );
}
