import 'package:flutter/material.dart';

import 'app_scale.dart';

/// 全局尺寸 / 字号 / 间距规范 —— 专为儿童设计
///
/// **设计原则：**
/// 1. 字号整体比常规 App 放大一档，保证儿童可读性；
/// 2. 按钮最小点击区域 ≥ 56，远大于 Material 默认的 48，降低误触率；
/// 3. 圆角统一加大，营造柔和卡通的视觉感受；
/// 4. 交互反馈明显（缩放、震动、颜色变化）。
///
/// **v1.4.0 重要变更：从「固定常量」改为「动态取值」**
///
/// 这些值现在是 **getter**，每次读取时会乘以 [AppScale.scale]
/// （由屏幕尺寸算出的 0.88 ~ 1.12 之间的因子）。
///
/// 这样做的**关键好处**：全项目约 800 处 `AppSizes.fontBody` 之类的调用
/// **一行都不用改**，就自动获得了屏幕自适应能力。
///
/// 设计值（下面每个注释里写的数字）是「基准宽度 390 下的理想值」，
/// 实际取值会按设备屏幕等比缩放并钳制在合理区间内。
///
/// ⚠️ 注意：因为这些值不再是编译期常量，**不能再用于 `const` 构造**。
/// 例如 `const TextStyle(fontSize: AppSizes.fontBody)` 需要改成
/// `TextStyle(fontSize: AppSizes.fontBody)`。这是本次改造的必然代价。
class AppSizes {
  AppSizes._();

  // ==================== 字号（适合儿童） ====================
  /// 大数字（倒计时、余额）
  static double get fontDisplay => AppScale.s(40);

  /// 页面主标题
  static double get fontTitle => AppScale.s(26);

  /// 卡片标题
  static double get fontHeadline => AppScale.s(22);

  /// 正文
  static double get fontBody => AppScale.s(18);

  /// 标签
  static double get fontLabel => AppScale.s(16);

  /// 辅助说明（下限）
  ///
  /// **v1.4.0 提高了下限保护**：这个字号在窄屏上原本会缩到 12.3，
  /// 中文小字已接近不可读。儿童 App 尤其不能牺牲可读性，
  /// 因此这里对最小字号做了额外兜底（不低于 13）。
  static double get fontCaption {
    final v = AppScale.s(14);
    return v < 13 ? 13 : v;
  }

  /// 极小字（仅用于次要信息）
  ///
  /// 同样有可读性下限保护（不低于 11）。
  static double get fontTiny {
    final v = AppScale.s(12);
    return v < 11 ? 11 : v;
  }

  // ==================== 间距 ====================
  static double get spaceXs => AppScale.s(4);
  static double get spaceSm => AppScale.s(8);
  static double get spaceMd => AppScale.s(12);
  static double get spaceLg => AppScale.s(16);
  static double get spaceXl => AppScale.s(24);
  static double get spaceXxl => AppScale.s(32);

  // ==================== 圆角（卡片 20 / 按钮 16 / 输入 14） ====================
  static double get radiusSm => AppScale.s(10);
  static double get radiusMd => AppScale.s(16);
  static double get radiusLg => AppScale.s(22);
  static double get radiusXl => AppScale.s(28);

  /// 圆形（超大值，用于胶囊按钮）
  ///
  /// **不参与缩放**：它本质是「无限大圆角」，缩放没有意义，
  /// 且保持大值可确保任何尺寸下都是完美的胶囊形。
  static const double radiusCircle = 999;

  /// 输入框圆角（v2 新增）
  static double get radiusInput => AppScale.s(14);

  // ==================== 组件尺寸 ====================
  /// 主要按钮高度（大按钮，易于点击）
  ///
  /// **有可点击性下限**：即便窄屏缩放后也不低于 52，
  /// 保证儿童手指点击区域足够（Material 建议 ≥48）。
  static double get buttonHeight {
    final v = AppScale.s(56);
    return v < 52 ? 52 : v;
  }

  /// 次要按钮高度（同样有下限保护）
  static double get buttonSmallHeight {
    final v = AppScale.s(44);
    return v < 42 ? 42 : v;
  }

  /// 底部导航栏高度
  ///
  /// **不缩放**：底部导航要贴合系统手势区域，用固定高度更稳妥，
  /// 缩放反而可能与系统导航条冲突。
  static const double bottomNavHeight = 68;

  /// 中间悬浮按钮直径
  static double get fabSize => AppScale.s(64);

  /// 卡片圆角
  static double get cardRadius => AppScale.s(20);

  /// 图标尺寸
  static double get iconSm => AppScale.s(20);
  static double get iconMd => AppScale.s(28);
  static double get iconLg => AppScale.s(40);

  // ==================== 宠物形象 ====================
  /// 首页宠物尺寸
  static double get petHomeSize => AppScale.s(130);

  /// 宠物中心宠物尺寸
  static double get petCenterSize => AppScale.s(200);

  // ==================== 动效时长 ====================
  //
  // 【为什么时长不缩放？】
  // 缩放因子描述的是「屏幕物理尺寸」，与「时间感知」无关。
  // 若时长跟着缩放，会出现「大屏手机上动画莫名变慢」的怪异感。
  // 时间相关的值一律保持固定。

  /// 快速反馈
  static const Duration durationFast = Duration(milliseconds: 150);

  /// 常规过渡
  static const Duration durationNormal = Duration(milliseconds: 300);

  /// 庆祝动画
  static const Duration durationCelebrate = Duration(milliseconds: 900);
}

/// 全局阴影规范 —— v2：统一采用「主色淡蓝柔影」，来自纸感 + 柔影的设计原则
///
/// 阴影的 blur / offset 不随屏幕缩放（视觉上缩放会导致阴影过重或过轻），
/// 因此这里保持 const。
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
