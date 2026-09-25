import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/database_service.dart';
import 'services/hive_init.dart';
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

  // 初始化本地数据库（纯本地，无任何网络依赖）
  await HiveInit.init();

  // 注入全局配置数据（仅首次启动时执行）
  await DatabaseService.instance.seedIfNeeded();

  // 初始化音频服务
  await WhiteNoiseService.instance.init();

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
