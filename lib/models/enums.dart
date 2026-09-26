/// 全局枚举定义
///
/// 说明：
/// 1. 所有枚举的 [index] 会被 Hive 直接持久化，**顺序不可随意调整**，
///    如需增删请追加到末尾，避免历史数据错位。
/// 2. 每个枚举都提供 `label` 中文名，便于 UI 直接展示，业务层不写死中文。
library;

/// 任务优先级（对应截图：I 必须做 / II 应该做 / III 可以做）
enum Priority {
  must('I', '必须做'),
  should('II', '应该做'),
  could('III', '可以做');

  const Priority(this.romanNumeral, this.label);

  /// 罗马数字序号，用于 UI 展示
  final String romanNumeral;

  /// 中文名
  final String label;
}

/// 任务难度（对应截图：简单 / 中等 / 困难）
enum Difficulty {
  easy('简单'),
  medium('中等'),
  hard('困难');

  const Difficulty(this.label);
  final String label;
}

/// 奖励货币类型（对应截图：💛 心愿币 / 🪙 宠物币）
enum RewardType {
  wishCoin('心愿币', '💛'),
  petCoin('宠物币', '🪙'),
  custom('自定义奖励', '🎁');

  const RewardType(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 任务状态
enum TaskStatus {
  todo('未完成'),
  doing('进行中'),
  done('已完成');

  const TaskStatus(this.label);
  final String label;
}

/// 重复频率（对应截图：新建任务页默认「无」）
enum RepeatFrequency {
  once('无'),
  daily('每天'),
  weekly('每周'),
  monthly('每月');

  const RepeatFrequency(this.label);
  final String label;
}

/// 打卡频率（对应截图：创建习惯页「打卡频率：每天」）
enum HabitFrequency {
  daily('每天'),
  weekly('每周'),
  custom('自定义');

  const HabitFrequency(this.label);
  final String label;
}

/// 打卡时段（对应截图：「全天任意」为默认值）
enum TimeSlot {
  anytime('全天任意', '🌤️'),
  morning('早晨', '🌅'),
  noon('中午', '☀️'),
  evening('傍晚', '🌆'),
  night('睡前', '🌙');

  const TimeSlot(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 打卡方式（对应截图：创建习惯页「快速打卡」）
enum CheckInMode {
  quick('快速打卡'),
  confirmed('确认打卡');

  const CheckInMode(this.label);
  final String label;
}

/// 奖励时效（对应截图：「一次性奖励」）
enum RewardValidity {
  once('一次性奖励'),
  repeatable('可重复领取');

  const RewardValidity(this.label);
  final String label;
}

/// 兑换状态（待审批 / 已完成 / 已拒绝）
enum ExchangeStatus {
  pending('待审批'),
  done('已完成'),
  rejected('已拒绝');

  const ExchangeStatus(this.label);
  final String label;
}

/// 习惯打卡的验收状态（v1.4.0 新增）
///
/// **顺序即持久化值**（与 [HabitCheckIn.verifyStatusRaw] 对应），
/// 因此 `pending` 必须是 0 —— 这样「字段缺失」时能安全兜底到「待验收」，
/// 而不会把新打卡误判为已通过。
///
/// ⚠️ 不可调整顺序，只能在末尾追加。
enum HabitVerifyStatus {
  /// 孩子已打卡，等家长确认；奖励**尚未发放**
  pending('待验收', '⏳'),

  /// 家长已确认，奖励已发放
  approved('已通过', '✅'),

  /// 家长驳回（如「今天没真读」），可附原因；孩子补做后可重新提交
  rejected('已驳回', '↩️');

  const HabitVerifyStatus(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 习惯库分类（对应截图：学习 / 健康 / 生活 / 兴趣）
enum HabitCategory {
  study('学习', '📚'),
  health('健康', '💪'),
  life('生活', '🏠'),
  interest('兴趣', '🎨');

  const HabitCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 勋章分类（对应需求：成长、习惯、效率、知识）
enum AchievementCategory {
  growth('成长', '🌱'),
  habit('习惯', '🔥'),
  efficiency('效率', '⚡'),
  knowledge('知识', '📖');

  const AchievementCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 商店类型（对应截图：「心愿商店 ❤️」/「怪兽商店 🐾」）
enum ShopType {
  wish('心愿商店', '❤️'),
  monster('怪兽商店', '🐾');

  const ShopType(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 商品类型（怪兽商店内细分）
enum ShopItemType {
  food('食物', '🍎'),
  skin('皮肤', '👗'),
  prop('道具', '🎁'),
  reality('现实奖励', '🎮');

  const ShopItemType(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 宠物品种
///
/// v1.2 起新增 3 个 3D 模型品种（[modelPath] 非空），形象由本地化的
/// model-viewer 渲染（Web 用 HtmlElementView，Android 用 WebView 加载
/// 本地 asset，均无需网络）。原有 4 个品种仍为代码绘制的卡通形象。
enum PetSpecies {
  monster('小怪兽', 0xFF7EC8E3, null),
  unicorn('小独角兽', 0xFFF7B8D0, null),
  dragon('小火龙', 0xFF9FD9A8, null),
  cat('小猫咪', 0xFFC3AED6, null),

  /// 3D 模型品种（由 model-viewer 渲染，离线可用）
  starPet('机器猫', 0xFF3E92CC, 'assets/3d/pet_1.glb'),
  babyCat('小奶猫', 0xFFFF8A5C, 'assets/3d/pet_2.glb'),
  jumpPet('跳跳仔', 0xFF5FB87A, 'assets/3d/pet_3.glb');

  const PetSpecies(this.label, this.bodyColorValue, this.modelPath);

  final String label;

  /// 占位形象的主色（ARGB），用于代码绘制宠物
  final int bodyColorValue;

  /// 3D 模型资源路径（null = 代码绘制的 2D 形象）
  final String? modelPath;
}

/// 宠物状态（用于台词与形象表现）
enum PetMoodState {
  happy('开心', '😊'),
  normal('正常', '🙂'),
  hungry('饿了', '😋'),
  sleepy('困了', '😴'),
  sad('委屈', '🥺'),
  excited('兴奋', '🤩');

  const PetMoodState(this.label, this.emoji);
  final String label;
  final String emoji;
}

/// 白噪音类型（音频文件需用户放入 assets/audio/ 目录）
enum WhiteNoiseType {
  rain('雨声', 'rain.mp3', '🌧️'),
  ocean('海浪', 'ocean.mp3', '🌊'),
  forest('森林', 'forest.mp3', '🌲'),
  fire('篝火', 'fire.mp3', '🔥'),
  cafe('咖啡馆', 'cafe.mp3', '☕');

  const WhiteNoiseType(this.label, this.assetName, this.emoji);

  final String label;

  /// 音频文件名，实际路径为 assets/audio/{assetName}
  final String assetName;
  final String emoji;
}

/// 宠物等级解锁能力（对应需求：1/2/5/10/15 级解锁）
enum PetAbility {
  feed('基础喂食', 1),
  pet('抚摸互动', 1),
  shop('宠物商店', 2),
  evolve('宠物进化', 5),
  dressUp('时装系统', 10),
  special('特殊互动', 15);

  const PetAbility(this.label, this.unlockLevel);

  final String label;

  /// 解锁所需等级
  final int unlockLevel;

  /// 判断某等级是否已解锁该能力
  static List<PetAbility> unlockedAt(int level) =>
      PetAbility.values.where((a) => level >= a.unlockLevel).toList();
}
