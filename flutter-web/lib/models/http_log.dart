class HttpLog {
  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, List<String>> requestHeaders;
  final String requestBody;
  final Map<String, List<String>> responseHeaders;
  final String responseBody;
  final int statusCode;
  final int duration;

  HttpLog({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.requestBody,
    required this.responseHeaders,
    required this.responseBody,
    required this.statusCode,
    required this.duration,
  });

  factory HttpLog.fromJson(Map<String, dynamic> json) {
    return HttpLog(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      method: json['method'] ?? '',
      url: json['url'] ?? '',
      requestHeaders: Map<String, List<String>>.from(
        json['request_headers']?.map((key, value) => 
          MapEntry(key, List<String>.from(value))) ?? {}
      ),
      requestBody: json['request_body'] ?? '',
      responseHeaders: Map<String, List<String>>.from(
        json['response_headers']?.map((key, value) => 
          MapEntry(key, List<String>.from(value))) ?? {}
      ),
      responseBody: json['response_body'] ?? '',
      statusCode: json['status_code'] ?? 0,
      duration: json['duration'] ?? 0,
    );
  }

  String get statusCodeText {
    if (statusCode >= 200 && statusCode < 300) return '成功';
    if (statusCode >= 300 && statusCode < 400) return '重定向';
    if (statusCode >= 400 && statusCode < 500) return '客户端错误';
    if (statusCode >= 500) return '服务器错误';
    return '未知';
  }

  String get formattedDuration {
    if (duration < 1000) return '${duration}ms';
    return '${(duration / 1000).toStringAsFixed(2)}s';
  }
}

class WebSocketMessage {
  final String type;
  final dynamic data;

  WebSocketMessage({required this.type, required this.data});

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] ?? '',
      data: json['data'],
    );
  }
} 