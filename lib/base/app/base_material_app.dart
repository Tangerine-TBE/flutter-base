import 'package:common/common/widget/loading/g_loading.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../common/launcher/a_launcher_strategy.dart';
import '../../common/log/a_logger.dart';
import '../route/a_route.dart';

/// 封装通用app，给客户端项目继承
// ignore: must_be_immutable
abstract class BaseMaterialApp<T extends ALauncherStrategy>
    extends StatelessWidget {
  BaseMaterialApp(this.launcherStrategy,
      this.route, {
        super.key,
      }) {
    init();
  }

  /// 启动策略
  late T launcherStrategy;

  /// 页面路由
  late ARoute route;

  /// material app
  GetMaterialApp buildApp(BuildContext context) =>
      GetMaterialApp(
        builder: (context, child) {
          // 安装loading
          child = GLoading.instance.init(context, child);
          return child;
        },
        popGesture: true,
        getPages: route.getPages(),
        initialRoute: route.initialRoute,
        defaultTransition: Transition.rightToLeftWithFade,
      );


  /// 环境变量配置交给客户端处理
  void buildConfig(T launcherStrategy);

  /// 初始化架构内可用的东西
  /// 可重写
  void init() {
    // 安装默认logger
    installLogger(launcherStrategy.isDebug);

    // 构建环境变量
    buildConfig(launcherStrategy);
  }

  Widget? widget;

  @override
  Widget build(BuildContext context) {
    widget ??=buildApp(context);

    return widget!;
  }
}
