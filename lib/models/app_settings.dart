import 'package:hive/hive.dart';


/// 全局设置表（单例，**无 childId**）
///
/// 存放与具体孩子无关的应用级配置：家长 PIN、白噪音偏好、番茄钟时长等。
@HiveType(typeId: 14)
class AppSettings extends HiveObject {
  AppSettings({
    this.parentPinHash = '',
    this.parentPinSalt = '',
    this.hasSetPin = false,
    this.defaultPomodoroMinutes = 25,
    this.breakMinutes = 5,
    this.allowAbandonMinutes = 5,
    this.selectedWhiteNoiseIndex,
    this.whiteNoiseVolume = 0.6,
    this.autoStartWhiteNoise = false,
    this.refreshIntervalMinutes = 5,
    this.hasCompletedOnboarding = false,
    this.lastOpenTime,
  });

  /// 家长 PIN 的 SHA-256 哈希（加盐）
  @HiveField(0)
  String parentPinHash;

  /// PIN 盐值（随机生成，与 PIN 拼接后哈希）
  @HiveField(1)
  String parentPinSalt;

  /// 是否已设置过 PIN（首次使用需引导设置）
  @HiveField(2)
  bool hasSetPin;

  /// 默认番茄钟时长（分钟）
  @HiveField(3)
  int defaultPomodoroMinutes;

  /// 默认休息时长（分钟）
  @HiveField(4)
  int breakMinutes;

  /// 番茄钟允许切出的宽限时间（分钟）—— 超过则本次作废
  @HiveField(5)
  int allowAbandonMinutes;

  /// 上次选择的白噪音类型索引（为空表示不自动播放）
  @HiveField(6)
  int? selectedWhiteNoiseIndex;

  /// 白噪音音量 0.0 - 1.0
  @HiveField(7)
  double whiteNoiseVolume;

  /// 进入番茄钟是否自动播放白噪音
  @HiveField(8)
  bool autoStartWhiteNoise;

  /// 全局状态自动刷新间隔（分钟）
  @HiveField(9)
  int refreshIntervalMinutes;

  /// 是否已完成首次引导（建档、选宠物等）
  @HiveField(10)
  bool hasCompletedOnboarding;

  /// 上次打开 App 的时间（用于「两天没见」类台词判断）
  @HiveField(11)
  DateTime? lastOpenTime;

  AppSettings copyWith({
    String? parentPinHash,
    String? parentPinSalt,
    bool? hasSetPin,
    int? defaultPomodoroMinutes,
    int? breakMinutes,
    int? allowAbandonMinutes,
    int? selectedWhiteNoiseIndex,
    double? whiteNoiseVolume,
    bool? autoStartWhiteNoise,
    int? refreshIntervalMinutes,
    bool? hasCompletedOnboarding,
    DateTime? lastOpenTime,
    bool clearSelectedWhiteNoise = false,
  }) {
    return AppSettings(
      parentPinHash: parentPinHash ?? this.parentPinHash,
      parentPinSalt: parentPinSalt ?? this.parentPinSalt,
      hasSetPin: hasSetPin ?? this.hasSetPin,
      defaultPomodoroMinutes: defaultPomodoroMinutes ?? this.defaultPomodoroMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      allowAbandonMinutes: allowAbandonMinutes ?? this.allowAbandonMinutes,
      selectedWhiteNoiseIndex: clearSelectedWhiteNoise
          ? null
          : (selectedWhiteNoiseIndex ?? this.selectedWhiteNoiseIndex),
      whiteNoiseVolume: whiteNoiseVolume ?? this.whiteNoiseVolume,
      autoStartWhiteNoise: autoStartWhiteNoise ?? this.autoStartWhiteNoise,
      refreshIntervalMinutes: refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      lastOpenTime: lastOpenTime ?? this.lastOpenTime,
    );
  }
}
