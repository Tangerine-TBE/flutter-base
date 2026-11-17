import 'package:common/base/route/a_route.dart';
import 'package:go_router/go_router.dart';
import '../../../app_base/config/route_name.dart';
import '../page1/home_page.dart';

/// 服务项目的页面路由配置
class RouteConfig extends ARoute {
  @override
  String initialRoute = RouteName.home;

  @override
  String? loginRoute;

  @override
  GoRouter getGoRouter() {
    return GoRouter(routes: [
      GoRoute(
        path: RouteName.home,
        builder: (context, state) => const HomePage(),
      )
    ], initialLocation: loginRoute ?? RouteName.home);
  }
}
