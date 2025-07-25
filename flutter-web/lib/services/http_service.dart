import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/http_log.dart';

class HttpService {
  String _baseUrl = 'http://localhost:8091';

  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  Future<List<HttpLog>> getLogs({
    String? url,
    String? method,
    int? statusCode,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (url != null && url.isNotEmpty) queryParams['url'] = url;
      if (method != null && method.isNotEmpty) queryParams['method'] = method;
      if (statusCode != null) queryParams['status_code'] = statusCode.toString();

      final uri = Uri.parse('$_baseUrl/api/logs').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => HttpLog.fromJson(json)).toList();
      } else {
        throw Exception('获取日志失败: ${response.statusCode}');
      }
    } catch (e) {
      print('获取日志错误: $e');
      return [];
    }
  }

  Future<bool> clearLogs() async {
    try {
      final response = await http.post(Uri.parse('$_baseUrl/api/logs/clear'));
      return response.statusCode == 200;
    } catch (e) {
      print('清除日志错误: $e');
      return false;
    }
  }
} 