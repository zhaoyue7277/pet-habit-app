import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/database_service.dart';
import 'services/hive_init.dart';
import 'services/pet_3d_preloader.dart';
import 'services/recording_service.dart';
import 'services/white_noise_service.dart';
import 'theme/app_scale.dart';
import 'theme/app_theme.dart';
import 'widgets/home_scaffold.dart';

/// App 入口
///
/// **启动流程：**
/// 1. 初始化 Hive 并注册全部适配器
/// 2. 注入全局种子数据（勋章定义、商店商品、习惯库模板、宠物台词）
/// 3. 初始化白噪音服务
/// 4. 启动 Riverpod 容器并渲染主界面
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 竖屏锁定（儿童 App 固定竖屏，避免横屏布局错乱）
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ---------- 状态栏 / 导航栏样式（v1.2 修复「状态栏分割明显」） ----------
  // 让状态栏背景与页面背景（云底 #F4F9FD）同色，消除系统状态栏与
  // App 内容之间的生硬分割线；图标保持深色（浅色背景上的深色图标）。
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFFF4F9FD),
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 初始化本地数据库（纯本地，无任何网络依赖）
  await HiveInit.init();

  // 注入全局配置数据（仅首次启动时执行）
  await DatabaseService.instance.seedIfNeeded();

  // 初始化音频服务
  await WhiteNoiseService.instance.init();

  // 预热录音服务（不主动申请权限，仅构造播放器/录音器实例，
  // 让用户点「开始朗读」时的首次响应更快）
  // ignore: unawaited_futures
  RecordingService.instance.hasPermission();

  // 预热 3D 宠物资源（viewer 页面 + model-viewer 引擎 + Draco 解码器）。
  //
  // 【为什么】pet_*.glb 用了 Draco 压缩，而 model-viewer 的解码器不内嵌在
  // bundle 中。若不预热，用户进入首页时 WebView 才去读这些资源，首屏 3D
  // 区域会明显空白/转圈。这里在启动阶段提前读进 asset 缓存。
  //
  // 默认不带模型（3 个 glb 共约 16MB，启动阶段全读会吃内存）；
  // 模型在宠物品种确定后由 Pet3DPreloader.warmModel() 单独预热。
  // 预加载是「尽力而为」：失败不影响主流程，3D 组件自身有超时兜底。
  startPet3DPreload();

  runApp(
    const ProviderScope(
      child: PetHabitApp(),
    ),
  );
}

/// 应用根组件
class PetHabitApp extends ConsumerWidget {
  const PetHabitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '宠物乐园',
      debugShowCheckedModeBanner: false,

      // ---------- 主题 ----------
      theme: AppTheme.light(),

      // ---------- 全局屏幕自适应 + 锁定文字缩放 ----------
      //
      // 【v1.4.0 关键改造：从「锁死系统字号」升级为「按屏幕自适应」】
      //
      // 背景：v1.2 时曾把 textScaler 锁为 noScaling，用来修「系统字号设大
      // 导致布局错乱」。但那只解决了「用户改系统字号」这一种情况，
      // **没有解决「屏幕本身就大小不一」这个更根本的问题**——所有设备
      // 共用一套绝对尺寸，窄屏上文字被截断成「课外…」。
      //
      // 现在改为两层策略：
      //   1. AppScale.init(context) —— 按屏幕短边算出 0.88~1.12 的缩放
      //      因子，AppSizes 的所有尺寸据此动态取值（见 theme/app_scale.dart）；
      //   2. textScaler 依然锁定 —— 因为我们的字号已按屏幕调过一轮，
      //      再叠加系统字号会让两套缩放互相打架。锁定的目的是「只让
      //      App 控制字号」，而不是「禁止自适应」。
      //
      // 注意：这里用 LayoutBuilder 而非直接读 MediaQuery，是因为
      // builder 回调的 context 在 MaterialApp 内部，MediaQuery 可能
      // 尚未插入；用 LayoutBuilder 拿到的 constraints 是最可靠的。
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling,
              ),
              child: _ScaleBootstrap(
                size: constraints.biggest,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
        );
      },

      // ---------- 本地化（中文） ----------
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('zh', 'CN'),

      // ---------- 主界面 ----------
      home: const HomeScaffold(),

      // ---------- 全局路由转场 ----------
      // 在 ThemeData.pageTransitionsTheme 中已统一配置为
      // CupertinoPageTransitionsBuilder，因此所有 push 的页面
      // 天然支持「从屏幕左侧向右滑动返回上一页」。
      // 若使用自定义 route（如 SlidePageRoute），同样实现了相同的位移动画。
    );
  }
}

/// 缩放因子注入器（v1.4.0 新增）
///
/// **职责**：在每帧布局前，把当前屏幕尺寸写进 [AppScale]，让
/// [AppSizes] 的所有 getter 能在同一帧内取到正确的缩放值。
///
/// **为什么必须是一个 StatefulWidget，而不是直接在上面调静态方法？**
///
/// `AppScale.init()` 会写静态字段。如果在 `build` 里直接调用，会变成
/// 「读静态值 → 改静态值 → 同一帧内被下游读取」，虽然在本场景可用，
/// 但属于「build 期间产生副作用」，Flutter 的调试断言在某些情况下
/// 会报 `setState()/markNeedsBuild() called during build` 类问题。
///
/// 这里改在 `didChangeDependencies`（尺寸变化时系统会触发它）里注入，
/// 时机安全：它在 build 之前执行，下游 widget 构建时读到的即为最新值。
///
/// **为什么用传入的 `size` 而不是 `MediaQuery.of(context).size`？**
/// 外层 `LayoutBuilder` 给的 constraints 是本层可用的**权威**尺寸，
/// 而 `MediaQuery` 在这层可能还带着「未扣减系统栏」的原始值，
/// 两者在部分设备上会有差异。用 constraints 更准。
class _ScaleBootstrap extends StatefulWidget {
  const _ScaleBootstrap({required this.size, required this.child});

  /// 本层可用尺寸（来自外层 LayoutBuilder 的 constraints.biggest）
  final Size size;

  /// 实际页面内容
  final Widget child;

  @override
  State<_ScaleBootstrap> createState() => _ScaleBootstrapState();
}

class _ScaleBootstrapState extends State<_ScaleBootstrap> {
  /// 上一次注入的尺寸，用于跳过「尺寸没变」的无谓刷新
  Size _lastSize = Size.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyScaleIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _ScaleBootstrap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _applyScaleIfNeeded();
  }

  /// 尺寸变化时刷新缩放因子。
  ///
  /// 屏幕旋转 / 分屏 / 折叠屏展开都会让 `size` 变化，从而走到这里。
  void _applyScaleIfNeeded() {
    final size = widget.size;
    if (size == _lastSize) return;
    _lastSize = size;
    // 直接按约束尺寸算，不依赖 context 里的 MediaQuery。
    AppScale.initFromSize(size);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
