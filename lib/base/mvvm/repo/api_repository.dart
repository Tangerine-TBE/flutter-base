library api_service;

import 'dart:typed_data';

import 'package:common/common/network/download/progress_listener.dart';
import 'package:common/common/top.dart';
import 'package:dio/dio.dart';

import '../../../common/network/dio_client.dart';
import 'dio_proxy.dart';

// beans
part '../model/data_holder.dart';

part '../model/local_model.dart';

/// 网络请求隔离层，目的是不暴露诸如TesoHttp、Http具体的请求实现给上层业务
/// BaseRepo
abstract class ApiRepository {
  late final CancelToken _globalCancelToken = CancelToken();

  abstract DioProxy proxy;

  /// 代理請求
  Future<AResponse<T>> requestOnFuture<T>(
    // 路由
    String path, {
    Method method = Method.get,
    Map<String, dynamic>? params,
    Options? options,
    T? Function(dynamic data)? format,
  }) async {
    var futureTask = proxy.requestOnFuture(
      path: path,
      method: method,
      params: params,
      options: options,
      cancelToken: _globalCancelToken,
    );

    return AResponse.convert<T>(
      () => futureTask,
      (data) => format?.call(data),
    );
  }

  Future<AResponse<T>> requetFormData<T>(
    // 路由
    String path, {
    List<FormData>? params,
    Options? options,
    T? Function(dynamic data)? format,
  }) async {
    var futureTask = proxy.formDataUpload(
      options: options,
      cancelToken: _globalCancelToken,
      url: path,
      data: params,
    );
    return AResponse.convert<T>(
      () => futureTask,
      (data) => format?.call(data),
    );
  }

  Future<Stream<AResponse<T>>> requestOnStream<T>(
    String path, {
    Method method = Method.get,
    Map<String, dynamic>? params,
    Options? options,
    T? Function(dynamic data)? format,
  }) {
    var futureTask = proxy.requestOnStream<T?>(
      path: path,
      options: options,
      method: method,
      params: params,
      // onResponse: (data) => format?.call(data),
    );
    return AResponse.convertStream<T>(
        () => futureTask, (data) => format?.call(data));
  }

  /// 单文件上传 bytes形式
  Future<AResponse<F>> uploadFileBytes<F>({
    required String url,
    required String formDataKey,
    required ByteData byteData,
    Map<String, dynamic> body = const {},
    Function(dynamic data)? format,
    String? filename,
    Function(int sent, int total)? progressListener,
  }) async {
    var futureTask = proxy.uploadFileBytes(
      url: url,
      formDataKey: formDataKey,
      byteData: byteData,
      filename: filename,
      body: body,
      progressListener: progressListener,
    );
    return AResponse.convert<F>(
      () => futureTask,
      (data) => format?.call(data),
    );
  }

  /// 单文件上传
  Future<AResponse<F>> uploadFile<F>({
    required String url,
    required String formDataKey,
    required String filePath,
    String? fileName,
    Function(dynamic data)? format,
    Function(int sent, int total)? progressListener,
  }) async {
    var futureTask = proxy.uploadFile(
      url: url,
      formDataKey: formDataKey,
      filePath: filePath,
      progressListener: progressListener,
    );

    return AResponse.convert<F>(
      () => futureTask,
      (data) => format?.call(data),
    );
  }

  /// 多文件上传
  Future<AResponse<F>> uploadFiles<F>({
    required String url,
    required String formDataKey,
    required List<String> filePaths,
    Function(dynamic data)? format,
    Function(int sent, int total)? progressListener,
  }) async {
    var futureTask = proxy.uploadFiles(
      url: url,
      formDataKey: formDataKey,
      filePaths: filePaths,
      progressListener: progressListener,
    );
    return AResponse.convert<F>(
      () => futureTask,
      (data) => format?.call(data),
    );
  }

  /// 下載
  Future download(
    String url, {
    required String savePath,
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    ProgressListener? progressListener,
  }) async {
    return proxy.download(
      url,
      savePath: savePath,
      params: params,
      cancelToken: _globalCancelToken,
      progressListener: progressListener,
    );
  }

  void cancelAll() {
    _globalCancelToken.cancel();
  }
}
