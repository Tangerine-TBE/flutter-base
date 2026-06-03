import 'package:common/common/widget/loading/g_loading.dart';
import 'package:get/get.dart';

import '../../../common/log/a_logger.dart';
import '../../../common/network/dio_client.dart';
import '../../../common/network/status_code.dart';
import '../../helper/navigation_helper.dart';
import '../repo/api_repository.dart';

/// Controller基類
/// BaseVM
abstract class BaseViewModel extends SuperController with NavigationHelper {
  /// 頁面狀態 - loading
  void showLoading({bool userInteraction = true}) =>
      GLoading.instance.showLoading(userInteraction);

  /// 頁面狀態 - 空
  void showEmpty();

  /// 頁面狀態 - 錯誤
  void showError(String? message);

  /// 远程错误 - 500 默认调用showError错误
  void handleServerError(String? message) => showError(message);

  /// 401 403 token過期/更新，需要重新登錄
  void handleUnAuthorizedError(String? message);

  /// 頁面狀態 - 重置
  void resetShow() {}

  /// 頁面狀態 - loading、空、錯誤均關閉
  void dismiss() => GLoading.instance.dismiss();

  /// 生命週期 - onInit
  @override
  void onInit() {
    super.onInit();
  }

  /// 生命週期 - onClose
  @override
  void onClose() {
    dismiss();
    super.onClose();
  }

  /// 執行future
  Future<T?> apiLaunch<T>(
    Future<AResponse<T>> Function() futureTask, {
    bool enableLoading = true,
  }) async {
    resetShow();
    if (enableLoading) showLoading();
    AResponse<T> response = await futureTask();
    if (enableLoading) dismiss();

    // status - error
    if (!response.isSuccess) {
      handleResponseError(response);
      return null;
    }

    // status - empty
    var data = response.data;
    if (data is DataHolder) {
      if (data.isEmpty()) showEmpty();
    } else if (response.isEmpty) {
      showEmpty();
    }

    return response.data;
  }

  /// 當需要多個請求同時發出時使用
  /// 如：
  ///     apiAsync(() async {
  ///        var r1 = await mineService.getR1();
  ///        var r2 = await mineService.getR2();
  ///        var r3 = await mineService.getR3();
  ///     });
  @Deprecated("废弃准备删除，无法支持异步请求")
  void apiAsync(Future Function() futureTask) async {
    resetShow();
    showLoading();
    await futureTask();
    dismiss();
  }

  /// 转换 AResponse -> 业务模型
  /// 當需要多個請求同時發出時使用
  /// @return 返回值是动态混合列表，需要开发者自行处理
  /// 如：
  ///     List<dynamic> results = await apiLaunchMany(() {
  ///        mineService.getR1();
  ///        mineService.getR2();
  ///        mineService.getR3();
  ///     });
  Future<List<dynamic>> apiLaunchMany(
    List<Future<AResponse<dynamic>>> futures, {
    bool enableLoading = true,
  }) async {
    resetShow();
    if (enableLoading) showLoading();
    List<AResponse<dynamic>> responses = await Future.wait(futures);
    if (enableLoading) dismiss();

    List<dynamic> results = [];
    List<AResponse> errors = []; // 错误响应的集合

    for (var response in responses) {
      if (!response.isSuccess) errors.add(response);
      dynamic data = response.data;
      if (data is DataHolder) {
        results.add(data.dataList ?? data.data);
      } else {
        results.add(data);
      }
    }

    if (errors.isNotEmpty) {
      for (AResponse error in errors) {
        bool isBreak =
            handleResponseError(error, breakOn: [unauthorized, forbidden]);
        if (isBreak) break;
      }
    }

    return results;
  }

  /// 錯誤代碼處理
  /// breakCode: 如果和请求code匹配，就返回true
  bool handleResponseError(
    AResponse response, {
    List<int> breakOn = const [],
  }) {
    logE(
      "----- base_controller._handleResponseError(): code: ${response.code}, message: ${response.message}",
    );

    // 是否需要打断处理
    bool isBreak = false;

    if (breakOn.contains(response.code)) isBreak = true;

    switch (response.code) {
      case clientError:
        _handleClientError(response.message);
        break;
      case unauthorized:
      case forbidden:
        handleUnAuthorizedError(response.message);
        break;
      case timeOut:
        showError(response.message);
        break;
      case serverError:
        _handleServerError(response.message);
        break;
      default:
        showError(response.message);
        break;
    }
    return isBreak;
  }

  /// 400 客户端错误
  void _handleClientError(String? msg) {
    showError(msg);
  }

  /// 500 服務器錯誤
  void _handleServerError(String? msg) {
    handleServerError(msg);
  }

  /// lifecycle
  @override
  void onDetached() {}

  @override
  void onInactive() {}

  @override
  void onPaused() {}

  @override
  void onResumed() {}
}
