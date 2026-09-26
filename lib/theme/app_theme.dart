import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_sizes.dart';

/// 全局主题 —— 卡通、圆润、温暖的儿童风格
///
/// 主色调：柔和粉蓝 + 浅紫（对应需求约束 5）。
/// 所有组件样式集中于此，便于后续整体换肤与迁移鸿蒙 / iOS。
class AppTheme {
  AppTheme._();

  /// 浅色主题（本 App 仅提供浅色，儿童场景下深色不友好）
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      // ---------- 全局字体 ----------
      //
      // 【为什么必须显式指定中文字体？】
      // Android / iOS 系统自带中文字体，`fontFamily: null` 即可正常显示。
      // 但 **Web 平台无法访问设备系统字体**：Flutter Web 引擎（CanvasKit）
      // 在字体表里找不到中文字形时，会去 fonts.gstatic.com 动态下载
      // Noto Sans SC —— 国内网络下这一步必定失败，界面所有中文变成空白。
      // 因此这里统一指定本地字体族 NotoSansSC（由 pubspec.yaml 声明）。
      //
      // 【v2 修复：字体子集必须覆盖动态文本】
      // v1 的子集仅按「App 静态文案」裁剪（987 个汉字、0 个数字与拉丁字母），
      // 导致孩子名字、日期数字、金币余额等**动态文本**缺字形而渲染空白。
      // v2 改为 GB2312 全量汉字 + ASCII + 常用标点（约 6800 字符），
      // 一劳永逸覆盖用户输入与日期数字。
      //
      // 【为什么还要 fontFamilyFallback？】
      // 中文子集字体不含 emoji 字形，须回退到 emoji 字体，否则宠物形象
      // 🐣🐶🐱、货币 🪙💛⭐ 等也会空白。回退顺序：
      //   1. NotoColorEmoji —— 彩色 emoji 主体
      //   2. NotoSymbols2   —— 补齐 NotoColorEmoji v1.39 未收录的 🪙 和 ☆
      fontFamily: 'NotoSansSC',
      fontFamilyFallback: const <String>[
        'NotoColorEmoji',
        'NotoSymbols2',
      ],

      // ---------- 文字主题：整体放大，适配儿童 ----------
      textTheme: _buildTextTheme(),

      // ---------- 应用栏 ----------
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: AppSizes.fontTitle,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        iconTheme: IconThemeData(
          color: AppColors.textPrimary,
          size: AppSizes.iconMd,
        ),
      ),

      // ---------- 主要按钮：大、圆润、有反馈（v2：圆角 16 + 主色柔影） ----------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          disabledBackgroundColor: AppColors.primaryLight,
          disabledForegroundColor: Colors.white70,
          minimumSize: Size(double.infinity, AppSizes.buttonHeight),
          elevation: 3,
          shadowColor: const Color(0x3D3E92CC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          minimumSize: Size(0, AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          minimumSize: Size(0, AppSizes.buttonHeight),
          side: const BorderSide(color: AppColors.primary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          textStyle: TextStyle(
            fontSize: AppSizes.fontBody,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: TextStyle(
            fontSize: AppSizes.fontLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ---------- 卡片：大圆角 + 柔和阴影（v2：补齐层次，不再全靠底色分层） ----------
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: const Color(0x1A3E92CC),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        ),
      ),

      // ---------- 输入框：圆润、无边框线、浅底（v2：圆角 14） ----------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSizes.spaceLg,
          vertical: AppSizes.spaceLg,
        ),
        hintStyle: TextStyle(
          fontSize: AppSizes.fontBody,
          color: AppColors.textHint,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),

      // ---------- 弹窗：大圆角 ----------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        titleTextStyle: TextStyle(
          fontSize: AppSizes.fontHeadline,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: AppSizes.fontBody,
          color: AppColors.textSecondary,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.radiusXl),
          ),
        ),
      ),

      // ---------- Chip / 标签：圆润胶囊 ----------
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: AppSizes.fontLabel,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: AppSizes.fontLabel,
          fontWeight: FontWeight.w600,
          color: AppColors.textOnPrimary,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSizes.spaceMd,
          vertical: AppSizes.spaceSm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCircle),
          side: BorderSide.none,
        ),
      ),

      // ---------- 进度条：圆角、加粗 ----------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceVariant,
        circularTrackColor: AppColors.surfaceVariant,
      ),

      // ---------- 分隔线 ----------
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: AppSizes.spaceLg,
      ),

      // ---------- 开关：品牌色 ----------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.secondary
              : AppColors.divider;
        }),
      ),

      // ---------- 滑动返回：使用 Cupertino 风格转场 ----------
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // 全平台统一使用 Cupertino 转场，以支持左侧边缘右滑返回
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// 构建文字主题
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: AppSizes.fontDisplay,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
      headlineLarge: TextStyle(
        fontSize: AppSizes.fontTitle,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: AppSizes.fontHeadline,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: AppSizes.fontHeadline,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: AppSizes.fontBody,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: AppSizes.fontBody,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: AppSizes.fontLabel,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontSize: AppSizes.fontCaption,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: AppSizes.fontLabel,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontSize: AppSizes.fontCaption,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontSize: AppSizes.fontTiny,
        fontWeight: FontWeight.w500,
        color: AppColors.textHint,
      ),
    );
  }
}
