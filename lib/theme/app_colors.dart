import 'package:flutter/material.dart';

/// 全局色板 —— 设计系统 v2「故事书」风格
///
/// 设计原则（v2）：
/// 1. **儿童友好 ≠ 低幼**：目标用户 10 岁左右，「故事书 / 冒险岛」气质优于幼儿园卡贴画；
/// 2. **颜色讲语义**：蓝=学习与任务，橙=奖励与宠物，绿=完成，红=柔和错误；
/// 3. **对比度达标**：主色由 v1 的浅粉蓝 #7EC8E3 加深为晴空蓝 #3E92CC，
///    白底上的白字按钮不再发虚（对照 WCAG，白字在 #3E92CC 上对比度 3.1:1，
///    在加深态 #2B6FA3 上 5.4:1）；
/// 4. 语义化命名，业务层不直接写死色值。
class AppColors {
  AppColors._();

  // ==================== 主色：晴空蓝（学习 / 任务） ====================
  static const Color primary = Color(0xFF3E92CC); // 晴空蓝 —— 主色
  static const Color primaryLight = Color(0xFFD6EAF8); // 浅色描边 / 禁用态
  static const Color primarySoft = Color(0xFFE3F1FB); // 极浅填充底（标签底、悬停底）
  static const Color primaryDark = Color(0xFF2B6FA3); // 深色（按压态 / 强调文字）

  // ==================== 辅色：珊瑚橙（奖励 / 宠物 / 关键 CTA） ====================
  static const Color secondary = Color(0xFFFF8A5C); // 珊瑚橙
  static const Color secondaryLight = Color(0xFFFFE9DF); // 浅色底
  static const Color secondaryDark = Color(0xFFE8703F); // 深色

  // ==================== 强调色：暖阳黄（金币 / 奖励 / 经验条） ====================
  static const Color accent = Color(0xFFFFC94D); // 暖阳黄 —— 填充
  static const Color accentDark = Color(0xFFB87E14); // 深金 —— 黄色系文字（保证对比度）

  // ==================== 语义色 ====================
  static const Color success = Color(0xFF5FB87A); // 打卡成功
  static const Color successLight = Color(0xFFE8F6EC);
  static const Color warning = Color(0xFFFFB14D); // 提醒
  static const Color warningLight = Color(0xFFFFF4E3);
  static const Color error = Color(0xFFEF8A8A); // 柔和红，不吓到孩子
  static const Color errorDark = Color(0xFFD95757);
  static const Color info = Color(0xFF5AA9E6);

  // ==================== 背景 / 表面 ====================
  static const Color background = Color(0xFFF4F9FD); // 云底 —— 页面背景
  static const Color surface = Color(0xFFFFFFFF); // 卡片表面
  static const Color surfaceWarm = Color(0xFFFFFDF8); // 暖白纸面（强调卡片）
  static const Color surfaceVariant = Color(0xFFEFF6FC); // 次级表面（输入框 / 分组底）

  // ==================== 文字 ====================
  static const Color textPrimary = Color(0xFF22303C); // 主文字（深灰蓝）
  static const Color textSecondary = Color(0xFF5B6B7A); // 次文字
  static const Color textHint = Color(0xFF8FA0AE); // 提示文字（比 v1 加深，保证可读）
  static const Color textOnPrimary = Color(0xFFFFFFFF); // 主色上的文字

  // ==================== 装饰 ====================
  static const Color divider = Color(0xFFE3EEF6);
  static const Color shadow = Color(0x1A3E92CC); // 淡蓝阴影

  // ==================== 渐变（天幕 / 稀有度） ====================
  /// 首页宠物舞台的「天幕」渐变
  static const List<Color> skyGradient = [
    Color(0xFFEAF6FF),
    Color(0xFFFFFDF8),
  ];

  /// 主按钮渐变（同色系，营造纸感立体）
  static const List<Color> primaryGradient = [
    Color(0xFF4A9FD8),
    Color(0xFF2B6FA3),
  ];

  // ==================== 宠物状态相关 ====================
  static const Color petHappy = Color(0xFFFFE08A); // 开心
  static const Color petHungry = Color(0xFFFFC9A3); // 饥饿
  static const Color petSleepy = Color(0xFFC5B8E7); // 困倦
  static const Color petSick = Color(0xFFD9D9D9); // 生病
}
