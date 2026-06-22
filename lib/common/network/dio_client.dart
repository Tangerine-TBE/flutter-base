library network;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:common/common/top.dart';

// import 'package:dio/adapter_browser.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:logger/logger.dart';
import 'dart:convert';

import 'download/progress_listener.dart';
import 'status_code.dart';

// parts
part 'dio_config.dart';

part './logger.dart';

part './a_response.dart';

enum Method { get, post, put, delete, patch }

/// 封裝 - 初始化入口install()
abstract class DioClient {
  late DioConfig config = loadOptions();

  late Dio _dio;

  DioConfig loadOptions();

  /// 初始化_dio
  void install() {
    _dio = Dio(config);
    _dio.interceptors
      ..add(LogInterceptor(requestBody: true, responseBody: true))
      ..addAll(config.interceptors ?? []);
    // SSL证书
    HttpClientAdapter httpClientAdapter = _dio.httpClientAdapter;
    if (httpClientAdapter is IOHttpClientAdapter) {
      // 1. pem string
      if (!config.pem.isNullOrEmpty) {
        httpClientAdapter.onHttpClientCreate = (client) {
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) =>
                  cert.pem == config.pem.val;
          //代理
          _appendProxy(client);
        };
      } else if (!config.pemFilepath.isNullOrEmpty) {
        httpClientAdapter.onHttpClientCreate = (client) {
          // 2. pem file
          SecurityContext sc = SecurityContext();
          // file is the path of certificate
          sc.setTrustedCertificates(config.pemFilepath.val);
          HttpClient httpClient = HttpClient(context: sc);
          //代理
          _appendProxy(httpClient);
          return httpClient;
        };
      } else {
        httpClientAdapter.onHttpClientCreate = (client) {
          // 3. no verification
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          // 代理
          _appendProxy(client);
        };
      }
    }
    // else if (httpClientAdapter is BrowserHttpClientAdapter) {
    //   // TODO 浏览器adapter
    // }
  }

  _appendProxy(HttpClient httpClient) {
    //代理
    if (!config.proxy.isNullOrEmpty) {
      httpClient.findProxy =
          (uri) => "PROXY ${config.proxy}:${config.proxyPort}";
    }
  }

  /// 单文件上传，ByteData形式
  Future<Response<String>> uploadFileBytes({
    required String url,
    required String formDataKey,
    required ByteData byteData,
    Map<String, dynamic> body = const {},
    String? filename,
    Function(int sent, int total)? progressListener,
  }) async {
    List<int> fileData = byteData.buffer.asUint8List();
    MultipartFile file = MultipartFile.fromBytes(fileData, filename: filename);
    body[formDataKey] = file;
    FormData formData = FormData.fromMap(body);
    return await _dio.post(
      url,
      data: formData,
      onSendProgress: progressListener,
    );
  }

  /// 单文件上传
  Future<Response<String>> uploadFile({
    required String url,
    required String formDataKey,
    required String filePath,
    String? fileName,
    Function(int sent, int total)? progressListener,
  }) async {
    FormData formData = FormData.fromMap({
      formDataKey: await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });
    return await _dio.post(
      url,
      data: formData,
      onSendProgress: progressListener,
    );
  }

  /// 多文件上传
  Future<Response<String>> uploadFiles({
    required String url,
    required String formDataKey,
    required List<String> filePaths,
    Function(int sent, int total)? progressListener,
  }) async {
    FormData formData = FormData.fromMap({
      formDataKey: filePaths.map((filepath) async {
        return await MultipartFile.fromFile(filepath);
      }).toList(),
    });
    return await _dio.post(
      url,
      data: formData,
      onSendProgress: progressListener,
    );
  }

  /// 下載
  Future<Response<dynamic>> download(
    String url, {
    required String savePath,
    Map<String, dynamic>? params,
    CancelToken? cancelToken,
    ProgressListener? progressListener,
  }) async {
    return await _dio.download(
      url,
      savePath,
      queryParameters: params,
      onReceiveProgress: progressListener,
      cancelToken: cancelToken,
    );
  }

  Future<Response<String>> requestOnFuture({
    required String path,
    Map<String, dynamic>? params,
    Options? options,
    Method method = Method.get,
    CancelToken? cancelToken,
  }) async {
    Response<String> response = await _dioRequest(
      path,
      params: params,
      options: options,
      method: method,
      cancelToken: cancelToken,
    );
    return response;
  }

  /// 流式请求，用于接收服务器端持续返回的 JSON 对象流
  Future<Response<ResponseBody>> requestOnStream<T>({
    required String path,
    Map<String, dynamic>? params,
    Options? options,
    Method method = Method.get,
    CancelToken? cancelToken,
    AResponse<T> Function(dynamic data)? onResponse,
  }) async {
    Response<ResponseBody> response = await _dioRequestStream(
      path,
      params: params,
      options: options,
      method: method,
      cancelToken: cancelToken,
    );
    return response;
    // return response.data!.stream.cast<List<int>>().transform(utf8.decoder);
  }

  Future<Response<ResponseBody>> _dioRequestStream(
    String path, {
    Map<String, dynamic>? params,
    Options? options,
    Method method = Method.get,
    CancelToken? cancelToken,
  }) async {
    options = options?.copyWith(responseType: ResponseType.stream) ??
        Options(responseType: ResponseType.stream);

    Response<ResponseBody> response;
    switch (method) {
      case Method.get:
        response = await _dio.get(
          path,
          queryParameters: params,
          options: options,
          cancelToken: cancelToken,
        );
        break;
      case Method.post:
        response = await _dio.post(
          path,
          data: params,
          cancelToken: cancelToken,
          options: options,
        );
        break;
      case Method.put:
        response = await _dio.put(
          path,
          data: params,
          options: options,
          cancelToken: cancelToken,
        );
        break;
      case Method.delete:
        response = await _dio.delete(path,
            data: params, options: options, cancelToken: cancelToken);
        break;
      case Method.patch:
        response = await _dio.patch(path,
            data: params, options: options, cancelToken: cancelToken);
        break;
    }
    return response;
  }

  ///dio--request请求
  Future<Response<String>> _dioRequest(
    String path, {
    Map<String, dynamic>? params,
    Options? options,
    Method method = Method.get,
    CancelToken? cancelToken,
  }) async {
    Response<String> response;
    switch (method) {
      case Method.get:
        response = await _dio.get(
          path,
          queryParameters: params,
          options: options,
          cancelToken: cancelToken,
        );
        break;
      case Method.post:
        response = await _dio.post(
          path,
          data: params,
          cancelToken: cancelToken,
          options: options,
        );
        break;
      case Method.put:
        response = await _dio.put(
          path,
          data: params,
          options: options,
          cancelToken: cancelToken,
        );
        break;
      case Method.delete:
        response = await _dio.delete(path,
            queryParameters: params,
            options: options,
            cancelToken: cancelToken);
        break;
      case Method.patch:
        response = await _dio.patch(path,
            data: params, options: options, cancelToken: cancelToken);
        break;
    }
    return response;
  }
}
