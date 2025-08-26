import 'http_log.dart';

class FavoriteRequest {
  final String id;
  final String name;
  final String url;
  final String method;
  final Map<String, List<String>> headers;
  final String body;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? lastUsed;

  FavoriteRequest({
    required this.id,
    required this.name,
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    required this.tags,
    required this.createdAt,
    this.lastUsed,
  });

  // 从HttpLog创建收藏请求
  factory FavoriteRequest.fromHttpLog({
    required String id,
    required String name,
    required String url,
    required String method,
    required Map<String, List<String>> headers,
    required String body,
    List<String> tags = const [],
  }) {
    return FavoriteRequest(
      id: id,
      name: name,
      url: url,
      method: method,
      headers: headers,
      body: body,
      tags: tags,
      createdAt: DateTime.now(),
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'method': method,
      'headers': headers,
      'body': body,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
    };
  }

  // 从JSON创建
  factory FavoriteRequest.fromJson(Map<String, dynamic> json) {
    return FavoriteRequest(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      method: json['method'] as String,
      headers: Map<String, List<String>>.from(
        (json['headers'] as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            List<String>.from(value as List),
          ),
        ),
      ),
      body: json['body'] as String,
      tags: List<String>.from(json['tags'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsed: json['lastUsed'] != null 
          ? DateTime.parse(json['lastUsed'] as String)
          : null,
    );
  }

  // 复制并更新最后使用时间
  FavoriteRequest copyWithLastUsed() {
    return FavoriteRequest(
      id: id,
      name: name,
      url: url,
      method: method,
      headers: headers,
      body: body,
      tags: tags,
      createdAt: createdAt,
      lastUsed: DateTime.now(),
    );
  }

  // 复制并更新字段
  FavoriteRequest copyWith({
    String? name,
    List<String>? tags,
  }) {
    return FavoriteRequest(
      id: id,
      name: name ?? this.name,
      url: url,
      method: method,
      headers: headers,
      body: body,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      lastUsed: lastUsed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FavoriteRequest && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  // 转换为HttpLog用于重放对话框
  HttpLog toHttpLog() {
    return HttpLog(
      id: id,
      timestamp: createdAt,
      method: method,
      url: url,
      requestHeaders: headers,
      requestBody: body,
      requestBodyType: _inferContentType(),
      responseHeaders: {},
      responseBody: '',
      responseBodyType: 'text/plain',
      statusCode: 200, // 收藏的请求没有响应状态，使用默认值
      duration: 0, // 收藏的请求没有持续时间，使用默认值
    );
  }

  // 推断Content-Type
  String _inferContentType() {
    // 检查请求头中的Content-Type
    final contentTypeValues = headers['Content-Type'] ?? headers['content-type'];
    if (contentTypeValues != null && contentTypeValues.isNotEmpty) {
      return contentTypeValues.first;
    }
    
    // 根据请求体内容推断
    final trimmedBody = body.trim();
    if (trimmedBody.isNotEmpty) {
      if ((trimmedBody.startsWith('{') && trimmedBody.endsWith('}')) || 
          (trimmedBody.startsWith('[') && trimmedBody.endsWith(']'))) {
        return 'application/json';
      }
    }
    
    return 'text/plain';
  }
}
