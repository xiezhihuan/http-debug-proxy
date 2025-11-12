import 'dart:convert';
import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:html' as html;
import '../models/http_log.dart';

class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;

  WebSocketMessage({required this.type, required this.data});

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      data: json['data'] as Map<String, dynamic>,
    );
  }
}

class WebSocketService {
  static WebSocketService? _instance;
  static WebSocketService get instance {
    _instance ??= WebSocketService._internal();
    return _instance!;
  }
  
  WebSocketService._internal() {
    _instanceId = DateTime.now().millisecondsSinceEpoch;
    print('🆔 WebSocketService实例创建 - ID: $_instanceId');
  }
  
  late final int _instanceId;
  WebSocketChannel? _channel;
  StreamController<HttpLog> _logController = StreamController<HttpLog>.broadcast();
  String? _serverUrl;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;
  StreamSubscription? _streamSubscription;
  bool _isDisposed = false;

  Stream<HttpLog> get logStream => _logController.stream;
  bool get isConnected => _isConnected;

  /// 根据当前页面URL动态构建WebSocket地址
  String _buildWebSocketUrl() {
    if (_serverUrl != null) {
      return _serverUrl!;
    }

    try {
      final location = html.window.location;
      final protocol = location.protocol == 'https:' ? 'wss:' : 'ws:';
      
      // location.host 已经包含了端口号（如果有的话），不需要再单独添加
      // 例如：location.host = "192.168.100.88:8091" 或 "example.com"
      final host = location.host;
      
      // 构建WebSocket URL
      final wsUrl = '$protocol//$host/api/ws';
      print('动态构建WebSocket地址: $wsUrl (来源: ${location.href})');
      return wsUrl;
    } catch (e) {
      print('构建WebSocket地址失败，使用默认地址: $e');
      // 如果无法获取当前页面URL，使用默认值
      return 'ws://localhost:8091/api/ws';
    }
  }

  void connect({String? serverUrl}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    print('🚀 [${timestamp}] WebSocket连接请求开始 - 实例ID: $_instanceId');
    
    // 如果已经disposed，不允许连接
    if (_isDisposed) {
      print('❌ [${timestamp}] WebSocketService已被销毁，无法连接 - 实例ID: $_instanceId');
      return;
    }
    
    // 如果已经连接，不重复连接
    if (_isConnected && _channel != null) {
      print('⚠️ [${timestamp}] WebSocket已连接，跳过重复连接 - 实例ID: $_instanceId');
      return;
    }
    
    // 强制断开现有连接
    _forceDisconnect();
    
    if (serverUrl != null) {
      _serverUrl = serverUrl;
    }
    
    final url = _buildWebSocketUrl();
    print('🔌 [${timestamp}] 正在连接WebSocket: $url - 实例ID: $_instanceId');
    print('📊 [${timestamp}] 连接状态: _isConnected=$_isConnected, _isReconnecting=$_isReconnecting, _isDisposed=$_isDisposed - 实例ID: $_instanceId');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      _isReconnecting = false;
      
      print('✅ [${timestamp}] WebSocket连接成功: $url');
      
      _streamSubscription = _channel!.stream.listen(
        (data) {
          if (_isDisposed) {
            print('⚠️ 服务已销毁，忽略消息');
            return;
          }
          
          print('📨 收到WebSocket消息: $data');
          try {
            final jsonData = json.decode(data);
            final message = WebSocketMessage.fromJson(jsonData);
            print('📋 消息类型: ${message.type}');
            
            if (message.type == 'new_log') {
              final httpLog = HttpLog.fromJson(message.data);
              print('📝 添加新日志: ${httpLog.id} - ${httpLog.method} ${httpLog.url}');
              if (!_logController.isClosed) {
                _logController.add(httpLog);
              }
            }
          } catch (e) {
            print('❌ 解析WebSocket消息失败: $e');
            print('原始数据: $data');
          }
        },
        onError: (error) {
          print('❌ [${DateTime.now().millisecondsSinceEpoch}] WebSocket错误: $error');
          _isConnected = false;
          // 不自动重连，避免无限循环
        },
        onDone: () {
          print('🔌 [${DateTime.now().millisecondsSinceEpoch}] WebSocket连接关闭');
          _isConnected = false;
          // 不自动重连，避免无限循环
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('❌ [${timestamp}] WebSocket连接失败: $e');
      _isConnected = false;
    }
  }
  
  /// 强制断开连接，确保彻底清理
  void _forceDisconnect() {
    print('强制断开WebSocket连接');
    _isConnected = false;
    _isReconnecting = false;
    
    // 取消重连定时器
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // 取消流订阅
    _streamSubscription?.cancel();
    _streamSubscription = null;
    
    // 关闭WebSocket连接
    if (_channel != null) {
      try {
        _channel!.sink.close(1000, 'Force disconnect');
        print('WebSocket连接已强制关闭');
      } catch (e) {
        print('强制关闭WebSocket连接时出错: $e');
      }
      _channel = null;
    }
  }


  void disconnect() {
    _forceDisconnect();
  }

  void dispose() {
    print('销毁WebSocketService');
    _isDisposed = true;
    _forceDisconnect();
    
    if (!_logController.isClosed) {
      _logController.close();
    }
    
    // 重置单例实例
    _instance = null;
  }
} 