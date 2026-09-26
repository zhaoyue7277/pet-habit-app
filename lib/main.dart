import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/database_service.dart';
import 'services/hive_init.dart';
import 'services/pet_3d_preloader.dart';
import 'services/recording_service.dart';
import 'services/white_noise_service.dart';
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

      // ---------- 锁定文字缩放（v1.2 修复真机布局错乱/截断） ----------
      // 部分手机系统字号设为「大/超大」时，Flutter 默认跟随系统缩放，
      // 导致「习惯乐园」Tab、「待办任务」标题、日期数字等被挤出容器
      // （换行 / 截断 / 与按钮重叠）。儿童 App 的布局按固定字号设计，
      // 这里统一锁定为不缩放，保证任何系统字号设置下布局稳定。
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child ?? const SizedBox.shrink(),
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
