part of network;

/// 請求結果處理
/// 目前針對dxHttp的ResponseBean進行數據格式轉換
/// 未來可以替換成dio本身
class AResponse<T> {
  AResponse(this.data, {this.code, this.message});

  T? data;

  int? code;

  String? message;

  // 判空
  bool get isEmpty => data == null;

  // 是否請求成功
  bool get isSuccess => code == 200;

  // 是否需要重新登录
  bool get isUnAuthorized => code == 401 || code == 403;

  /// 對dio的Response進行JSON轉換
  static Future<AResponse<T>> convert<T>(
    Future<Response<String>> Function() futureTask,
    T? Function(dynamic data)? onResponse,
  ) async {
    try {
      return await futureTask().then(
        (dioResponse) => handleDioResponse(dioResponse, onResponse),
      );
    } catch (error) {
      logger.e("---- Response.convert() ====> catch request error: $error");
      if (error is DioException) {
        int code = 0;
        String msg = "";

        switch (error.type) {
          case DioExceptionType.cancel:
            msg = "請求取消";
            break;
          case DioExceptionType.connectionTimeout:
            code = timeOut;
            msg = "連接超時";
            break;
          case DioExceptionType.sendTimeout:
            code = timeOut;
            msg = "請求超時";
            break;
          case DioExceptionType.receiveTimeout:
            code = timeOut;
            msg = "響應超時";
            break;
          case DioExceptionType.badResponse:
            if (error.response != null) {
              if (error.response?.statusCode != null) {
                if (error.response?.statusCode == 401) {
                  code = 401;
                  msg = "认证错误";
                } else {
                  String? data = error.response!.data;
                  if (data != null && data.isNotEmpty) {
                    Map<String, dynamic> map =
                        jsonDecode(error.response!.data!);
                    msg = map['detail'] ?? '響應报文异常';
                    break;
                  }
                }
              }
            } else {
              msg = "響應报文异常";
            }
            break;
          case DioExceptionType.unknown:
            code = timeOut;
            msg = "網絡異常";
            break;
          default:
            break;
        }
        return AResponse(null, code: code, message: msg);
      }
      return AResponse(null, message: error.toString());
    }
  }

  static Future<Stream<AResponse<T>>> convertStream<T>(
      Future<Response<ResponseBody>> Function() futureTask,
      T? Function(dynamic data)? onResponse) async {
    try {
      return await futureTask().then(
        (streamResponse) => handleStreamResponse(
          streamResponse,
          onResponse,
        ),
      );
    } catch (error) {
      logger.e("---- Response.convert() ====> catch request error: $error");
      if (error is DioException) {
        int code = 0;
        String msg = "";
        switch (error.type) {
          case DioExceptionType.cancel:
            msg = "請求取消";
            break;
          case DioExceptionType.connectionTimeout:
            code = timeOut;
            msg = "連接超時";
            break;
          case DioExceptionType.sendTimeout:
            code = timeOut;
            msg = "請求超時";
            break;
          case DioExceptionType.receiveTimeout:
            code = timeOut;
            msg = "響應超時";
            break;
          case DioExceptionType.badResponse:
            if (error.response != null) {
              if (error.response?.statusCode != null) {
                if (error.response?.statusCode == 401) {
                  code = 401;
                  msg = "认证错误";
                } else {
                  String? data = error.response!.data;
                  if (data != null && data.isNotEmpty) {
                    Map<String, dynamic> map =
                        jsonDecode(error.response!.data!);
                    msg = map['message'] ?? '響應报文异常';
                    break;
                  }
                }
              }
            } else {
              msg = "響應报文异常";
            }
            break;
          case DioExceptionType.unknown:
            code = timeOut;
            msg = "網絡異常";
            break;
          default:
            break;
        }
        return Stream.value(AResponse(null, code: code, message: msg));
      }
      return Stream.value(AResponse(null, message: error.toString()));
    }
  }

  static Stream<AResponse<T>> handleStreamResponse<T>(
    Response<ResponseBody> streamResponse,
    T? Function(dynamic data)? onResponse,
  ) {
    // 用于标记是否已经发送过 start
    bool hasSentStart = false;

    // 1. 原始流 → JSON → AResponse
    final dataStream = streamResponse.data!.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(_jsonObjectDecoder())
        .map((json) {
      return AResponse<T>(
        onResponse?.call(json),
        code: 200,
        message: "streaming",
      );
    }).timeout(const Duration(seconds: 15), onTimeout: (sink) {
      sink.add(AResponse<T>(null, code: 504, message: "timeout"));
      sink.close();
    });

    // 2. 包装成完整生命周期：start → streaming → done/error/timeout
    return dataStream.transform(
      StreamTransformer<AResponse<T>, AResponse<T>>.fromHandlers(
        handleData: (data, sink) {
          // 第一次收到数据 → 先发 start
          if (!hasSentStart) {
            hasSentStart = true;
            sink.add(AResponse<T>(null, code: 200, message: "start"));
          }
          // 再发真实数据
          sink.add(data);
        },
        handleError: (err, stack, sink) {
          sink.add(AResponse<T>(null, code: 500, message: "error"));
          sink.close();
        },
        handleDone: (sink) {
          // 流正常结束
          sink.add(AResponse<T>(null, code: 200, message: "done"));
          sink.close();
        },
      ),
    );
  }

  static StreamTransformer<String, Map<String, dynamic>> _jsonObjectDecoder() {
    String buffer = '';
    int depth = 0;
    bool inString = false;
    bool escaped = false;

    return StreamTransformer.fromHandlers(
      handleData: (String chunk, EventSink<Map<String, dynamic>> sink) {
        for (int i = 0; i < chunk.length; i++) {
          final String char = chunk[i];
          buffer += char;

          if (escaped) {
            escaped = false;
            continue;
          }

          if (char == '\\') {
            escaped = true;
            continue;
          }

          if (char == '"') {
            inString = !inString;
          }

          if (!inString) {
            if (char == '{' || char == '[') {
              depth++;
            } else if (char == '}' || char == ']') {
              depth--;
            }
          }

          if (!inString && depth == 0 && buffer.trim().isNotEmpty) {
            try {
              final dynamic json = jsonDecode(buffer.trim());
              if (json is Map<String, dynamic>) {
                sink.add(json);
              } else {
                sink.addError(FormatException(
                    'Stream result is not a JSON object: ${buffer.trim()}'));
              }
            } catch (error, stack) {
              sink.addError(error, stack);
            }
            buffer = '';
          }
        }
      },
      handleDone: (EventSink<Map<String, dynamic>> sink) {
        if (buffer.trim().isNotEmpty) {
          try {
            final dynamic json = jsonDecode(buffer.trim());
            if (json is Map<String, dynamic>) {
              sink.add(json);
            } else {
              sink.addError(FormatException(
                  'Stream result is not a JSON object: ${buffer.trim()}'));
            }
          } catch (error, stack) {
            sink.addError(error, stack);
          }
        }
        sink.close();
      },
    );
  }

  /// 處理ResponseBean的map數據
  static AResponse<T> handleDioResponse<T>(
    Response<String> dioResponse,
    T? Function(dynamic data)? onResponse,
  ) {
    var map = jsonDecode(dioResponse.data!);
    var status = dioResponse.statusCode;
    var code = dioResponse.statusMessage;
    var result = map;
    if (map is Map) {
      status = map["status"] ?? dioResponse.statusCode;
      code = map["code"] ?? dioResponse.statusMessage;
      result = map["result"] ?? map; // data 可能是List 或 Object 或 基本數據類型（bool）
    }
    logger.w(
        ("---> header status code: ${dioResponse.statusCode}, message: ${dioResponse.statusMessage}"));
    logger.i("---> response: code[$code], || "
        "msg:[$code] || ,\n "
        "${const JsonEncoder.withIndent('  ').convert(result)}");
    return AResponse(
      onResponse?.call(result),
      code: status,
      message: code,
    );
  }
}
