# 小宠习惯 · 儿童习惯养成与宠物陪伴 App

> Android 单机版 Flutter App —— 用「宠物养成 + 双货币激励 + 习惯打卡」帮 10 岁左右的孩子建立学习与生活好习惯。
>
> 技术栈：**Flutter 3.38 (stable) + Dart 3.10 + Riverpod 2.x + Hive 2.x**
> 全程**纯本地运行**：无服务器、无第三方后端、无任何联网 API。

---

## 一、快速开始

```bash
# 1. 拉取依赖
flutter pub get

# 2. （可选）放入白噪音音频，见「四、资源准备」
#    不放入也能跑：音频缺失时服务自动降级为静默，不会崩溃

# 3. 运行（Android 真机 / 模拟器）
flutter run
```

> 首次启动会自动注入种子数据：**11 枚勋章 / 12 件商品 / 50 个习惯模板 / 20 条宠物台词**，
> 并创建一个默认孩子档案。想重置数据，卸载重装或清空 App 数据即可。

---

## 二、核心玩法

| 模块 | 说明 |
|---|---|
| **多孩隔离** | 首页顶部可下拉切换孩子，所有数据（金币 / 宠物 / 任务 / 习惯 / 勋章）按 `childId` 完全隔离 |
| **首页仪表盘** | 宠物形象（等级 / 经验 / 心情 / 饱食）+ 今日待办（按科目分组）+ 每 5 分钟自动刷新 |
| **番茄钟** | 选择计时类任务 → 倒计时 + 白噪音陪伴；**切出 App 即暂停**；离开 > 5 分钟本次作废（宠物垂头丧气提示，不扣任何东西） |
| **双货币** | **宠物币** → 买宠物食品/皮肤/道具；**心愿币** → 换现实奖励（零花钱、看电视等） |
| **心愿商店** | 余额不足 → 宠物卖萌拒绝（不弹密码框）；余额充足 → 家长 PIN 验证 → 扣币 → 撒花仪式感 |
| **宠物养成** | 1 级起喂食/抚摸，2/5/10/15 级逐级解锁商店/进化/时装/特殊互动；升级闪光特效 |
| **习惯打卡** | 每日频率 + 连击火苗 🔥 + 完成奖心愿币；达成目标连击额外发奖 |
| **成就勋章** | 成长 / 习惯 / 效率 / 知识 四类勋章墙，未解锁灰显，条件绑定本地数据变化 |
| **数据报告** | 周/月学习时长、任务完成率、科目均衡度、按时完成率（fl_chart 柱状图 + 饼图） |
| **打卡日记** | 日历本 UI 回看每日成果，底部家长寄语输入框（本地存储） |

---

## 三、目录结构（严格五层）

```
lib/
├── main.dart                  # 入口：Hive 初始化 → 种子数据 → 音频服务 → 挂载 ProviderScope
│
├── models/                    # ① 数据模型（15 个 Hive 实体 + 枚举）
│   ├── models.dart            #    统一导出（业务层只 import 这一个）
│   ├── enums.dart             #    全部枚举（中文 label + emoji）
│   ├── child.dart             #    孩子档案
│   ├── pet.dart               #    宠物（含实时衰减计算）
│   ├── task.dart              #    任务
│   ├── habit.dart             #    习惯 + 打卡记录 HabitCheckIn
│   ├── exchange_log.dart      #    兑换记录
│   ├── achievement.dart       #    勋章定义 + 孩子勋章进度
│   ├── shop_item.dart         #    商店商品 + 背包物品
│   ├── habit_template.dart    #    习惯模板 / 宠物台词 / 每日日记 / 番茄记录
│   └── app_settings.dart      #    全局设置（家长 PIN 哈希等）
│
├── services/                  # ② 服务层（与界面无关的纯逻辑）
│   ├── adapters.dart          #    手写全部 15 个 Hive TypeAdapter
│   ├── hive_init.dart         #    Box 注册与打开
│   ├── database_service.dart  #    单例：全部读写 / 业务规则 / 种子数据
│   └── white_noise_service.dart #  白噪音播放（缺失音频时降级静默）
│
├── providers/                 # ③ 状态层（Riverpod）
│   ├── core_providers.dart    #    全局刷新信号 + 当前孩子 + 余额
│   ├── pet_providers.dart     #    宠物实时状态与互动
│   ├── task_providers.dart    #    今日任务与统计
│   ├── habit_providers.dart   #    习惯与打卡
│   ├── shop_providers.dart    #    商店 / 兑换 / 审批
│   ├── settings_providers.dart#    设置 / 勋章 / 日记
│   └── pomodoro_providers.dart#    番茄钟状态机 + 生命周期防作弊
│
├── pages/                     # ④ 页面层（12 个页面）
│   ├── home_page.dart         #    首页仪表盘
│   ├── pomodoro_page.dart     #    番茄钟
│   ├── habit_park_page.dart   #    习惯游乐园
│   ├── habit_edit_page.dart   #    新建/编辑习惯
│   ├── shop_page.dart         #    双商店
│   ├── pet_center_page.dart   #    宠物中心
│   ├── achievement_page.dart  #    勋章墙
│   ├── report_page.dart       #    数据报告
│   ├── diary_page.dart        #    打卡日记
│   ├── task_edit_page.dart    #    新建/编辑任务
│   └── profile_page.dart      #    我的（含家长审批 / 设置）
│
├── widgets/                   # ⑤ 组件层
│   ├── home_scaffold.dart     #    4 Tab + 中央 FAB + 5 分钟自动刷新
│   ├── pet_avatar.dart        #    代码绘制宠物（CustomPainter）+ 4 种动画
│   ├── task_card.dart         #    任务卡片（计时类走秒 / 检查类勾选）
│   ├── pin_dialog.dart        #    家长 PIN 键盘 + 余额不足 + 兑换成功
│   ├── common_widgets.dart    #    通用卡片 / 按钮 / 标签 / 进度条
│   └── home_widgets.dart      #    问候栏 / 日期栏 / 统计卡 / 宠物气泡
│
├── routes/app_router.dart     # 全局路由（SlidePageRoute 自带左边缘右滑返回）
└── theme/                     # 配色 / 尺寸 / 主题（粉蓝 + 浅紫）
    ├── app_colors.dart
    ├── app_sizes.dart
    └── app_theme.dart
```

---

## 四、资源准备

### 音频（可选）

把白噪音文件放入 `assets/audio/`，文件名需与代码一致：

| 文件名 | 用途 |
|---|---|
| `rain.mp3` | 雨声 🌧️ |
| `ocean.mp3` | 海浪 🌊 |
| `forest.mp3` | 森林 🌲 |
| `fire.mp3` | 篝火 🔥 |
| `cafe.mp3` | 咖啡馆 ☕ |

> 未放入时：`WhiteNoiseService` 的 `_assetsAvailable` 为 `false`，播放操作静默跳过，**不会崩溃**，
> 番茄钟其余逻辑完全正常。

### 图片（可选）

`assets/images/` 用于后续替换宠物插画。当前宠物形象由 `widgets/pet_avatar.dart` 中的
`CustomPainter` 代码绘制，替换真实插画时只需改该文件的 `_buildPlaceholder` 方法。

---

## 五、数据存储说明

- 使用 **Hive**（纯 Dart，无原生依赖，便于迁移到鸿蒙 / iOS）。
- **TypeAdapter 全部手写**，不依赖 `build_runner` 代码生成 —— 拿到工程 `flutter pub get` 即可直接运行。
- ⚠️ **重要约定**：`@HiveField(n)` 编号一经发布**不可修改**，新增字段只能在末尾追加，
  且必须同步更新 `services/adapters.dart` 中的读写顺序。
- 派生数据（饱食度 / 心情）**不靠定时器写库**，而是根据 `lastDecayTime` 在读取时实时计算，
  省电且不会数据漂移。

---

## 六、迁移到鸿蒙 / iOS 的注意点

1. **数据层**：Hive 纯 Dart，可直接复用；`hive_flutter` 的路径 API 在鸿蒙需替换为原生实现。
2. **音频**：`audioplayers` 需确认鸿蒙支持情况，否则换 `just_audio` 或平台插件。
3. **通知**：`flutter_local_notifications` 需鸿蒙适配（当前版本未强依赖，可先移除）。
4. **路由手势**：`SlidePageRoute` 继承 `CupertinoPageRoute`，iOS 上天然一致；鸿蒙需验证手势区宽度。
5. **权限**：当前为单机版且「切出即暂停」，**无需前台服务权限**，迁移时也无需申请。
