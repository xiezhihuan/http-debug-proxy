import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:html' as html;
import '../models/http_log.dart';

class HttpService {
  String? _baseUrl;

  /// 根据当前页面URL动态构建API基础地址
  String _getBaseUrl() {
    if (_baseUrl != null) {
      return _baseUrl!;
    }

    try {
      final location = html.window.location;
      final protocol = location.protocol;
      final host = location.host; // host已经包含端口号
      
      // 构建API基础URL
      final apiUrl = '$protocol//$host';
      print('动态构建API地址: $apiUrl (来源: ${location.href})');
      return apiUrl;
    } catch (e) {
      print('构建API地址失败，使用默认地址: $e');
      // 如果无法获取当前页面URL，使用默认值
      return 'http://localhost:8091';
    }
  }

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

      final uri = Uri.parse('${_getBaseUrl()}/api/logs').replace(queryParameters: queryParams);
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
      final url = '${_getBaseUrl()}/api/logs/clear';
      print('清除日志请求URL: $url');
      final response = await http.post(Uri.parse(url));
      print('清除日志响应: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('清除日志错误: $e');
      return false;
    }
  }

  Future<bool> startListening() async {
    try {
      final response = await http.post(Uri.parse('${_getBaseUrl()}/api/listening/start'));
      return response.statusCode == 200;
    } catch (e) {
      print('开始监听错误: $e');
      return false;
    }
  }

  Future<bool> stopListening() async {
    try {
      final response = await http.post(Uri.parse('${_getBaseUrl()}/api/listening/stop'));
      return response.statusCode == 200;
    } catch (e) {
      print('停止监听错误: $e');
      return false;
    }
  }

  Future<bool> getListeningStatus() async {
    try {
      final response = await http.get(Uri.parse('${_getBaseUrl()}/api/listening/status'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['listening'] ?? false;
      }
      return false;
    } catch (e) {
      print('获取监听状态错误: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> replayRequest({
    required String originalLogId,
    required String method,
    required String url,
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final requestData = {
        'original_log_id': originalLogId,
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
      };

      final response = await http.post(
        Uri.parse('${_getBaseUrl()}/api/replay'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        throw Exception('重放请求失败: ${response.statusCode}');
      }
    } catch (e) {
      print('重放请求错误: $e');
      rethrow;
    }
  }
} 