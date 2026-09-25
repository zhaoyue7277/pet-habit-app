import 'package:flutter/material.dart';

/// 全局尺寸 / 字号 / 间距规范 —— 专为 10 岁儿童设计
///
/// **设计原则：**
/// 1. 字号整体比常规 App 放大一档，保证儿童可读性；
/// 2. 按钮最小点击区域 ≥ 56，远大于 Material 默认的 48，降低误触率；
/// 3. 圆角统一加大，营造柔和卡通的视觉感受；
/// 4. 交互反馈明显（缩放、震动、颜色变化）。
class AppSizes {
  AppSizes._();

  // ==================== 字号（适合 10 岁儿童） ====================
  static const double fontDisplay = 40; // 大数字（倒计时、余额）
  static const double fontTitle = 26; // 页面主标题
  static const double fontHeadline = 22; // 卡片标题
  static const double fontBody = 18; // 正文
  static const double fontLabel = 16; // 标签
  static const double fontCaption = 14; // 辅助说明（下限）
  static const double fontTiny = 12; // 极小字（仅用于次要信息）

  // ==================== 间距 ====================
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  // ==================== 圆角（v2：卡片 20 / 按钮 16 / 输入 14） ====================
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 28;
  static const double radiusCircle = 999;

  /// 输入框圆角（v2 新增）
  static const double radiusInput = 14;

  // ==================== 组件尺寸 ====================
  /// 主要按钮高度（大按钮，易于点击）
  static const double buttonHeight = 56;

  /// 次要按钮高度
  static const double buttonSmallHeight = 44;

  /// 底部导航栏高度
  static const double bottomNavHeight = 68;

  /// 中间悬浮按钮直径（对应截图：底部导航中间粉色圆形 + 按钮）
  static const double fabSize = 64;

  /// 卡片圆角
  static const double cardRadius = 20;

  /// 图标尺寸
  static const double iconSm = 20;
  static const double iconMd = 28;
  static const double iconLg = 40;

  // ==================== 宠物形象 ====================
  /// 首页宠物尺寸
  static const double petHomeSize = 130;

  /// 宠物中心宠物尺寸
  static const double petCenterSize = 200;

  // ==================== 动效时长 ====================
  /// 快速反馈
  static const Duration durationFast = Duration(milliseconds: 150);

  /// 常规过渡
  static const Duration durationNormal = Duration(milliseconds: 300);

  /// 庆祝动画
  static const Duration durationCelebrate = Duration(milliseconds: 900);
}

/// 全局阴影规范 —— v2：统一采用「主色淡蓝柔影」，来自纸感 + 柔影的设计原则
class AppShadows {
  AppShadows._();

  /// 卡片柔和阴影（淡蓝，避免生硬黑边）
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A3E92CC), // rgba(62,146,204,.10)
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  /// 强调阴影（浮起的卡片 / 底部导航）
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x263E92CC),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];

  /// 悬浮按钮阴影（跟随主色，替代 v1 的粉色阴影）
  static const List<BoxShadow> fab = [
    BoxShadow(
      color: Color(0x483E92CC),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  /// 主色按钮阴影
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x3D3E92CC),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];
}
