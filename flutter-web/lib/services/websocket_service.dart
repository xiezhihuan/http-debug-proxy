import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/http_log.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<HttpLog> _logController = StreamController<HttpLog>.broadcast();
  String _serverUrl = 'ws://localhost:8091/api/ws';
  bool _isConnected = false;

  Stream<HttpLog> get logStream => _logController.stream;
  bool get isConnected => _isConnected;

  void connect({String? serverUrl}) {
    if (serverUrl != null) {
      _serverUrl = serverUrl;
    }

    print('正在连接WebSocket: $_serverUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _isConnected = true;
      
      print('WebSocket连接成功: $_serverUrl');

      _channel!.stream.listen(
        (data) {
          print('收到WebSocket消息: $data');
          try {
            final jsonData = json.decode(data);
            print('解析JSON成功: $jsonData');
            final message = WebSocketMessage.fromJson(jsonData);
            print('消息类型: ${message.type}');
            
            if (message.type == 'new_log') {
              final httpLog = HttpLog.fromJson(message.data);
              print('添加新日志: ${httpLog.id} - ${httpLog.method} ${httpLog.url}');
              _logController.add(httpLog);
            }
          } catch (e) {
            print('解析WebSocket消息失败: $e');
            print('原始数据: $data');
          }
        },
        onError: (error) {
          print('WebSocket错误: $error');
          _isConnected = false;
          _reconnect();
        },
        onDone: () {
          print('WebSocket连接关闭');
          _isConnected = false;
          _reconnect();
        },
      );
    } catch (e) {
      print('WebSocket连接失败: $e');
      _isConnected = false;
      _reconnect();
    }
  }

  void _reconnect() {
    if (!_isConnected) {
      print('5秒后尝试重连...');
      Timer(Duration(seconds: 5), () {
        connect();
      });
    }
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _logController.close();
  }
} 