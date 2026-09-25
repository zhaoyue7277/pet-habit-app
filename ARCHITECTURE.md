# 小宠习惯 · 架构说明

> 儿童习惯养成与宠物陪伴 App —— Android 单机版
> 技术栈：**Flutter 3.38 (stable) + Dart 3.10 + Riverpod 2.x + Hive 2.x**
> 代码量：**44 个 Dart 文件 / 约 1.6 万行**，严格五层分层。

---

## 一、全局技术约束落实情况

| 约束 | 落地方式 | 对应文件 |
|---|---|---|
| 1. Flutter 最新稳定版 + Dart 3.x | `sdk: '>=3.5.0 <4.0.0'`，使用 Dart 3 语法（super 参数、模式匹配、`withValues`） | `pubspec.yaml` |
| 2. 纯本地存储、多孩隔离 | Hive（纯 Dart，零原生依赖）；**全部业务实体强制带 `childId`** | `models/`、`services/` |
| 3. 状态管理 | flutter_riverpod，全局 `ProviderScope` + `dataRevisionProvider` 全局刷新信号 | `main.dart`、`providers/` |
| 4. 路由 + 左边缘右滑返回 | `SlidePageRoute extends CupertinoPageRoute`，所有页面跳转统一走 `AppNavigator.push` | `routes/app_router.dart` |
| 5. 卡通 UI / 儿童字号 | `AppColors`（粉蓝 + 浅紫）+ `AppSizes`（正文 18 / 按钮高 56）+ `AppTheme` | `theme/` |
| 6. 音频 + 生命周期（切出即暂停） | `audioplayers` + `WidgetsBindingObserver`；**未使用前台服务** | `services/white_noise_service.dart`、`providers/pomodoro_providers.dart` |
| 7. 严格分层 + 可迁移 | Models / Services / Providers / Pages / Widgets 五层，平台能力只集中在 Services | 整个 `lib/` |

---

## 二、分层依赖方向

```
Pages / Widgets  （界面，只调用 Provider）
      ↑
   Providers     （状态，调用 Service，向界面暴露不可变数据）
      ↑
   Services      （纯逻辑：数据库读写 / 音频，不含任何 Flutter UI）
      ↑
    Models       （数据模型 + 枚举，纯 Dart，零依赖）
```

**关键原则：依赖单向向上，`Models` 不依赖任何人。**
唯一涉及平台能力的是 `Services` 层 —— 迁移鸿蒙 / iOS 时只需替换这一层。

---

## 三、关键设计决策

### 3.1 为什么选 Hive 而不是 Isar

| 维度 | Hive | Isar |
|---|---|---|
| 实现方式 | **纯 Dart** | 依赖原生库（ffi） |
| 鸿蒙迁移成本 | **低（零原生依赖）** | 高（需重写适配层） |
| 查询能力 | 弱（手写遍历即可） | 强（索引 / 复杂条件） |
| 代码生成 | 可选 | 必须 |

本项目数据量极小（单机 / 单家庭 / 几个孩子），**迁移友好度的权重远高于查询能力 → 选 Hive**。

### 3.2 为什么手写 TypeAdapter 而不用 build_runner

代码生成需要开发者本地执行 `flutter pub run build_runner build` 才能跑起来。
手写适配器让工程**「拿到即跑」**，同时也更便于迁移鸿蒙时逐个排查序列化逻辑。

> 代价：`services/adapters.dart` 有 900 行手工代码。
> 收益：零构建步骤 + 序列化逻辑完全透明可控。
> 已通过脚本校验：**15 个适配器的读写字段编号与模型 `@HiveField` 完全一致**。

### 3.3 约束 6 的冲突处理（切出即暂停）

原始需求同时要求「番茄钟后台运行（前台服务）」与「切出 App 暂停计时 / 白噪音」，
二者语义互斥。**最终决策（用户拍板）：方案 A —— 切出即暂停。**

```dart
// providers/pomodoro_providers.dart
class PomodoroController extends Notifier<PomodoroState>
    with WidgetsBindingObserver {

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundAt = DateTime.now();   // 记录切出时间戳
      _pauseInternal();                 // 暂停计时
      WhiteNoiseService.instance.pause();// 暂停白噪音
    } else if (state == AppLifecycleState.resumed) {
      final away = DateTime.now().difference(_backgroundAt!);
      if (away > const Duration(minutes: 5)) {
        _abort();   // 超过 5 分钟 → 本次作废，不发奖励（宠物垂头丧气提示）
      } else {
        _resumeInternal();  // 5 分钟内 → 恢复计时
      }
    }
  }
}
```

**因此本工程不需要前台服务权限**，`AndroidManifest.xml` 中也没有 `INTERNET` 权限，
从系统层面保证纯本地。

### 3.4 派生数据实时计算（不写定时器）

饱食度 / 心情会随时间衰减。**不采用「定时器定期写库」**（耗电且易漂移），
而是存一个 `lastDecayTime`，读取时按时间差实时计算：

```dart
// models/pet.dart
int currentSatiety([DateTime? now]) {
  final t = now ?? DateTime.now();
  final hours = t.difference(lastDecayTime).inMinutes / 60.0;
  return (satiety - hours * satietyDecayPerHour).clamp(0, 100).round();
}
```

好处：数据库写入次数极少，且无论 App 关闭多久，重开后数值都是正确的。

### 3.5 全局刷新信号 `dataRevisionProvider`

跨模块的数据联动（例如：完成番茄钟 → 金币变化 → 宠物经验变化 → 首页统计变化）
统一通过一个自增的 `int` 信号触发重建，避免 Provider 之间互相 `watch` 形成复杂依赖网：

```dart
// providers/core_providers.dart
final dataRevisionProvider = NotifierProvider<DataRevision, int>(DataRevision.new);

// 任意位置：ref.bumpRevision();   // 写入数据库后调用，全页面自动刷新
```

`HomeScaffold` 还额外用 `Timer.periodic` **每 5 分钟** `bump()` 一次，
满足「全局金币 / 宠物状态自动刷新」的需求。

### 3.6 任务分「计时类」与「检查类」

截图与用户反馈都强调：**并非所有任务都需要番茄钟**。

| 类型 | 判定字段 | 示例 | 完成方式 |
|---|---|---|---|
| 计时类 | `needsPomodoro == true` | 做一张试卷、订正错题 | 进入番茄钟，倒计时结束后发奖 |
| 检查类 | `needsPomodoro == false` | 书写工整、早睡早起、做家务 | 首页卡片一键勾选完成 |

该字段贯穿：任务卡片 UI、番茄钟任务列表、完成逻辑、学习时长统计口径。

### 3.7 家长 PIN 的安全存储

```dart
// services/database_service.dart
Future<void> setParentPin(String pin) async {
  final salt = _randomSalt();
  // SHA-256(盐 + PIN)，只存哈希与盐，不存明文
  settings.parentPinHash = sha256.convert(utf8.encode(salt + pin)).toString();
  settings.parentPinSalt = salt;
  await settingsBox.put('settings', settings);
}
```

> 这是本地儿童 App 的合理防护级别（防止孩子自己点「兑换」），
> 并非银行级安全方案 —— 数据本身就在孩子设备上。

---

## 四、数据模型一览（15 个 Hive 实体）

| 实体 | typeId | 说明 | 带 childId |
|---|---|---|---|
| `Child` | 0 | 孩子档案（双币余额 / 当前宠物 / 头像） | — （自身） |
| `Pet` | 1 | 宠物（等级 / 经验 / 皮肤 / 出战状态） | ✅ |
| `Task` | 2 | 任务（含 `needsPomodoro` / `subject` / 用时） | ✅ |
| `Habit` | 3 | 习惯（频率 / 时段 / 连击 / 双阶段奖励） | ✅ |
| `HabitCheckIn` | 4 | 习惯打卡记录（支撑日历与周报回溯） | ✅ |
| `ExchangeLog` | 5 | 兑换记录（通用 `coinType` + 审批状态） | ✅ |
| `AchievementDef` | 6 | 勋章**定义**（全局共享） | — （全局） |
| `ChildAchievement` | 7 | 孩子勋章**进度**（多孩各自独立） | ✅ |
| `ShopItem` | 8 | 商店商品定义（全局共享） | — （全局） |
| `InventoryItem` | 9 | 背包物品（已购） | ✅ |
| `HabitTemplate` | 10 | 习惯库模板（50 条种子） | — （全局） |
| `PetDialogue` | 11 | 宠物台词（按情绪 / 触发场景） | — （全局） |
| `DailyNote` | 12 | 每日日记与家长寄语 | ✅ |
| `PomodoroSession` | 13 | 番茄钟会话记录（支撑时长统计） | ✅ |
| `AppSettings` | 14 | 全局设置（家长 PIN 哈希 / 默认时长等，单例） | — （全局） |

> **设计要点**：
> - 「定义」与「进度」分离 —— 勋章 / 商品 / 习惯模板是全局数据，孩子各自的进度另建表，
>   避免每加一个孩子就复制一份商品清单。
> - 多孩隔离通过 `childId` 字段 + 查询时过滤实现，而非物理分库，
>   这样切换孩子时无需开关 Box。

---

## 五、页面导航图

```
HomeScaffold（4 Tab + 中央 FAB）
├── Tab 首页 🏳️   HomePage
│     ├─→ PomodoroPage        （计时类任务）
│     ├─→ TaskEditPage        （新建 / 编辑任务）
│     └─→ ReportPage
├── Tab 习惯乐园 🎠 HabitParkPage
│     └─→ HabitEditPage       （含习惯库 BottomSheet）
├── Tab 商店 🏪   ShopPage     （愿望商店 / 怪兽商店）
└── Tab 我的 🙂   ProfilePage
      ├─→ PetCenterPage       （喂食 / 抚摸 / 进化 / 时装）
      ├─→ AchievementPage     （四类勋章墙）
      ├─→ ReportPage
      ├─→ DiaryPage           （日历本 + 家长 Note）
      └─→ 兑换审批 / 家长设置面板
```

**所有页面跳转统一走 `AppNavigator.push(context, page)`** —— 它内部使用
`SlidePageRoute`，从而全站一致地支持「屏幕左边缘向右滑动返回」。

---

## 六、本地运行

```bash
# 环境要求：Flutter 3.38+ / Dart 3.10+
flutter --version

cd pet_habit
flutter pub get
flutter run                    # 连接 Android 设备或模拟器

# 打包
flutter build apk --release
```

### 迁移提示（鸿蒙 / iOS）

1. **`services/` 是唯一涉及平台能力的层**，迁移时只需替换该层实现；
2. `models/` 与 `theme/` 为纯 Dart，可直接复用；
3. `SlidePageRoute` 继承自 `CupertinoPageRoute`，iOS 上行为与系统原生一致；
4. 无需申请前台服务权限（因为「切出即暂停」）；
5. 音频若在鸿蒙不可用，只需替换 `WhiteNoiseService` 内部实现，调用方无需改动。

---

## 七、字体与资源方案（Web 平台适配）

### 问题背景

Flutter Web 与 Android/iOS 有一个关键差异：**Web 拿不到设备系统字体**。

- `ThemeData.fontFamily` 设为 `null` 时，Android/iOS 会用系统自带中文字体，显示正常；
- 但 Web（CanvasKit 渲染）在字体表中找不到中文字形时，会去
  `fonts.gstatic.com` **动态下载** Noto Sans SC —— 该域名在国内网络基本不可达，
  结果是**界面所有中文变成空白**（只剩按钮形状和图标）。

### 解决方案

在 `pubspec.yaml` 中声明 4 个字体族，全部本地打包：

| family | 文件 | 大小 | 用途 |
|---|---|---|---|
| `NotoSansSC` | NotoSansSC-Regular/Bold.otf | 298KB | 中文正文（400 / 700 两档字重） |
| `NotoColorEmoji` | NotoColorEmoji.ttf | 4.7MB | 彩色 emoji 主体 |
| `NotoSymbols2` | NotoSymbols2-Supplement.ttf | 1.7KB | 补齐 🪙 U+1FA99、☆ U+2606 |

`lib/theme/app_theme.dart` 中配置：

```dart
fontFamily: 'NotoSansSC',
fontFamilyFallback: const ['NotoColorEmoji', 'NotoSymbols2'],
```

### 字体子集化

中文字体从系统 `NotoSansCJK-Regular.ttc`（19.5MB）裁剪而来。
用脚本扫描 `lib/**.dart` 提取实际用到的 1125 个字符，
再用 `pyftsubset` 生成子集 —— 体积从 19.5MB 压到 148KB（**降低 99.2%**）。

重跑裁剪（新增中文文案后执行）：

```bash
# 1. 提取代码中所有中文字符
grep -rhoP '[\x{4e00}-\x{9fff}\x{3000}-\x{303f}\x{ff00}-\x{ffef}...]' \
     lib/ --include="*.dart" | sort -u | tr -d '\n' > /tmp/chars.txt

# 2. 生成子集（--font-number=2 对应 CJK SC）
pyftsubset /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc \
  --font-number=2 --text-file=/tmp/chars.txt \
  --output-file=assets/fonts/NotoSansSC-Regular.otf \
  --flavor=woff2 --layout-features='' --no-hinting --desubroutinize
```

> ⚠️ **注意**：`NotoColorEmoji` 是 CBDT/CBLC 彩色位图字体，**无法子集化**
> （fontTools 对 CBLC 索引表的解析存在兼容问题），因此整体引入 4.7MB。
> 该体积只在 Web 构建中产生实际影响；Android/iOS 用系统 emoji 字体，
> 字体文件虽会被一并打包进 assets，但不会影响运行。

### 一个容易踩的坑：DefaultTextStyle 断链

`DefaultTextStyle` 若被赋予一个**全新的 `TextStyle`**（而非 `merge`），
其 `fontFamily` 为 `null`，**不会自动继承 `ThemeData.fontFamily`**，
在 Web 上就会重新触发 Google Fonts 下载 → 文字空白。

正确写法：

```dart
DefaultTextStyle(
  style: DefaultTextStyle.of(context).style.merge(
    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
  ),
  child: child,
)
```

`lib/widgets/common_widgets.dart` 的 `BouncyButton` 曾因此导致按钮文字空白。

### 离线验证结果

阻断全部 `gstatic.com` / `googleapis.com` / `google.com` 请求后：

| 指标 | 结果 |
|---|---|
| flutter-view 挂载 | ✅ |
| 中文渲染字符数 | 238 |
| emoji 渲染数 | 41 |
| 运行时报错 | 0 |
| 被阻断的 Google 请求 | 43（全部失败但页面完整可用） |
