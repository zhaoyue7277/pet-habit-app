import 'package:flutter/material.dart';

/// 全局屏幕自适应标尺（v1.4.0 新增）
///
/// **为什么需要这个文件？**
///
/// v1.3.0 及之前，[AppSizes] 的所有尺寸都是 `static const` 绝对像素值，
/// 完全不随屏幕变化。这导致在窄屏 / 不同分辨率手机上：
///   · 有的格子放不下 4 个汉字 → 被截断成「课外…」
///   · 有的按钮过小 → 点击区域不足
///   · 有的间距过大 → 内容拥挤或溢出
///
/// 之前的应对是 `main.dart` 里锁死 [TextScaler.noScaling]（禁用系统字号
/// 缩放）。那只解决了「用户改系统字号」一种情况，**没有解决「屏幕本身就
/// 不一样」这个更根本的问题**——等于用「锁死」换来稳定，代价是所有设备
/// 共用一套绝对尺寸。
///
/// **本文件的方案（方案 A：LayoutBuilder + 缩放因子）**
///
/// 以 [designWidth] 为基准宽度（390，接近主流手机逻辑宽度），算出
/// `scale = 当前屏宽 / 基准宽度`，再用它去缩放所有尺寸。
///
/// **三条关键约束（都为了让缩放「稳」而不是「乱」）：**
///
/// 1. **设上下限**：`scale` 被钳制在 [minScale] ~ [maxScale]。
///    窄屏不缩太小（否则字看不清，儿童 App 尤其忌这个）；
///    宽屏不放太大（否则元素巨大显得傻）。
/// 2. **按短边计算**：竖屏下用宽度、横屏下用高度中较小的那个，
///    避免平板 / 折叠屏展开后算出离谱的比例。
/// 3. **只缩放「尺寸类」数值**：字号、间距、圆角、图标尺寸缩放；
///    **动效时长不缩放**（时间感知不该跟着屏幕变）。
///
/// **用法**：
///
/// - 在 `main.dart` 的 `builder` 里用 [AppScale.init] 注入屏幕宽度；
/// - 业务代码**继续写 `AppSizes.fontBody`**，因为它已改为动态取值
///   （见 `app_sizes.dart`），无需逐个改调用点。
class AppScale {
  AppScale._();

  // ==================== 基准与区间 ====================

  /// 设计基准宽度（iPhone 14 / 主流安卓的逻辑宽度约 390）
  static const double designWidth = 390;

  /// 缩放下限：窄屏最多缩到 0.88（再小字就看不清了）
  static const double minScale = 0.88;

  /// 缩放上限：宽屏最多放到 1.12（再大元素会显得笨重）
  static const double maxScale = 1.12;

  /// 当前有效缩放因子。默认 1.0（未初始化时 = 不做缩放，行为与旧版一致）
  static double _scale = 1.0;

  /// 最近一次注入的屏幕尺寸（供需要「真实像素」的场景读取）
  static Size _screenSize = Size.zero;

  /// 当前缩放因子（只读）
  static double get scale => _scale;

  /// 当前屏幕尺寸（只读）
  static Size get screenSize => _screenSize;

  /// 屏幕短边长度（竖屏=宽，横屏=高，平板展开后仍取短边）
  static double get shortSide {
    if (_screenSize == Size.zero) return designWidth;
    return _screenSize.width < _screenSize.height
        ? _screenSize.width
        : _screenSize.height;
  }

  /// 由 [MediaQuery] 数据计算缩放因子（纯函数，便于单测）
  ///
  /// 用**短边**而非宽度：竖屏手机短边=宽（符合直觉），
  /// 平板横屏时短边=高，避免「展开后宽度很大 → 元素被放到巨大」。
  static double computeScale(Size size) {
    if (size.width <= 0 || size.height <= 0) return 1.0;
    final base = size.width < size.height ? size.width : size.height;
    final raw = base / designWidth;
    return raw.clamp(minScale, maxScale);
  }

  /// 初始化 / 刷新缩放因子。
  ///
  /// 在 `MaterialApp.builder` 中调用——那里能拿到权威的 [MediaQuery]，
  /// 且屏幕旋转、分屏、字体设置变化时都会重建，自动跟随。
  static void init(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return;
    initFromSize(mq.size);
  }

  /// 用一个显式尺寸初始化 / 刷新缩放因子。
  ///
  /// 相比 [init]，这个版本不依赖 `context`，可以安全地在
  /// `didChangeDependencies` 之外、或无法拿到 MediaQuery 的场景调用。
  /// 传入 `Size.zero` 会被忽略，避免把有效值覆盖成无效值。
  static void initFromSize(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _screenSize = size;
    _scale = computeScale(size);
  }

  /// 把一个「设计尺寸」换算成当前设备的实际尺寸。
  ///
  /// 业务代码一般不直接调它——[AppSizes] 已经封装好了。
  static double s(double designValue) => designValue * _scale;

  /// 缩放并取整（用于必须为整数像素的场景，如某些绘制参数）
  static double round(double designValue) =>
      (designValue * _scale).roundToDouble();

  // ==================== 自适应断点 ====================

  /// 屏幕宽度分档（用于决定栅格列数等「结构性」布局，而非简单缩放）
  ///
  /// **为什么网格列数不能只靠缩放？**
  /// 缩放只能等比放大/缩小每个格子，但「文字放不放得下」取决于
  /// **格子宽度 = 可用宽度 / 列数**。窄屏若仍用 4 列，格子被压得很扁，
  /// 就算字号缩小了，可用宽度依然不够。所以列数要**按宽度分档**。
  static double get widthForLayout =>
      _screenSize == Size.zero ? designWidth : _screenSize.width;

  /// 是否为窄屏（< 360，如部分小屏安卓 / 分屏状态）
  static bool get isNarrow => widthForLayout < 360;

  /// 是否为宽屏（>= 420，如大屏手机 / 折叠屏展开）
  static bool get isWide => widthForLayout >= 420;

  /// 按屏幕宽度给出推荐的栅格列数。
  ///
  /// [wideColumns] / [normalColumns] / [narrowColumns] 分别对应
  /// 宽屏 / 常规 / 窄屏三档的列数，由调用方按业务语义指定。
  static int columnsFor({
    required int narrowColumns,
    required int normalColumns,
    required int wideColumns,
  }) {
    if (isNarrow) return narrowColumns;
    if (isWide) return wideColumns;
    return normalColumns;
  }
}
