import 'package:flutter/cupertino.dart';

/// 自定义路由转场 —— 自带「从屏幕左侧向右滑动返回上一页」手势
///
/// **对应需求约束 4：** 全局路由必须支持左边缘右滑返回。
///
/// **实现要点（不依赖主题兜底，独立生效）：**
/// 直接继承 [CupertinoPageRoute]，复用 Flutter 内建的
/// `CupertinoRouteTransitionMixin` —— 它同时提供：
///  * Cupertino 风格的水平位移转场（新页面从右滑入、旧页面视差左移）；
///  * **屏幕左边缘手势返回**（跟手拖动、松手自动判定 pop / 回弹）。
///
/// 这样即使将来把 `ThemeData.pageTransitionsTheme` 换成其他风格，
/// 只要走 [AppNavigator] 跳转，左滑返回依旧独立生效。
class SlidePageRoute<T> extends CupertinoPageRoute<T> {
  SlidePageRoute({
    required this.child,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  }) : super(
          builder: (context) => child,
        );

  final Widget child;
}

/// 从底部弹出的路由（用于模态页面，如番茄钟全屏）
class ModalPageRoute<T> extends PageRouteBuilder<T> {
  ModalPageRoute({
    required this.child,
    super.settings,
  }) : super(
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideUp = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ));
            return SlideTransition(position: slideUp, child: child);
          },
        );

  final Widget child;
}

/// 无转场路由（用于底部 Tab 切换）
class NoTransitionPageRoute<T> extends PageRouteBuilder<T> {
  NoTransitionPageRoute({
    required this.child,
    super.settings,
  }) : super(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => child,
        );

  final Widget child;
}

/// 全局页面跳转封装
///
/// 统一入口的好处：将来要改全局转场风格（例如迁移鸿蒙时
/// 换成平台原生手势），只需改这一处。
///
/// **所有页面级跳转都应使用本类**，而非直接 `Navigator.push`，
/// 以保证「左边缘右滑返回」全局一致。
class AppNavigator {
  AppNavigator._();

  /// 推入新页面（带左滑返回手势）
  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context).push<T>(SlidePageRoute(child: page));
  }

  /// 推入全屏模态页面（从底部滑入）
  static Future<T?> pushModal<T>(
    BuildContext context,
    Widget page, {
    RouteSettings? settings,
  }) {
    return Navigator.of(context).push<T>(
      ModalPageRoute(child: page, settings: settings),
    );
  }

  /// 替换当前页面（新页面同样带左滑返回手势）
  static Future<T?> replace<T, TO>(BuildContext context, Widget page) {
    return Navigator.of(context)
        .pushReplacement<T, TO>(SlidePageRoute(child: page));
  }

  /// 返回上一页
  static void pop<T>(BuildContext context, [T? result]) {
    Navigator.of(context).pop(result);
  }

  /// 回到根页面
  static void popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// 全局路由名称常量
///
/// 集中管理，避免字符串散落各处；将来接入命名路由或鸿蒙迁移时便于替换。
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String habitPark = '/habit-park';
  static const String shop = '/shop';
  static const String profile = '/profile';

  static const String pomodoro = '/pomodoro';
  static const String petCenter = '/pet-center';
  static const String taskEdit = '/task-edit';
  static const String habitEdit = '/habit-edit';
  static const String achievement = '/achievement';
  static const String report = '/report';
  static const String diary = '/diary';
  static const String exchangeLogs = '/exchange-logs';
  static const String parentSettings = '/parent-settings';
}

/// 路由表（使用 onGenerateRoute 统一生成，保证全页面都带左滑手势）
///
/// 当前页面跳转统一走 [AppNavigator] 的直接 push，
/// 本类保留作为「命名路由」扩展位，便于后续接入深链接（deep link）。
class AppRouter {
  AppRouter._();

  /// 页面构造器注册表（由 main.dart 填充）
  static final Map<String, Widget Function(Object? args)> _routeBuilders = {};

  /// 注册页面构造器
  static void register(String name, Widget Function(Object? args) builder) {
    _routeBuilders[name] = builder;
  }

  /// 生成路由
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = _routeBuilders[settings.name];
    if (builder == null) return null;
    return SlidePageRoute(
      child: builder(settings.arguments),
      settings: settings,
    );
  }
}

/// Cupertino 风格的手势返回包装器
///
/// 使用 [SlidePageRoute] 或主题中的 `CupertinoPageTransitionsBuilder`
/// 时无需额外处理；本组件保留为扩展位（例如将来需要整屏可滑时接入）。
class SwipeBackWrapper extends StatelessWidget {
  const SwipeBackWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
