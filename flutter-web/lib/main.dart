import 'package:flutter/material.dart';
import 'dart:async';
import 'models/http_log.dart';
import 'services/websocket_service.dart';
import 'services/http_service.dart';
import 'widgets/log_list.dart';
import 'widgets/log_detail.dart';
import 'widgets/filter_bar.dart';
import 'widgets/favorites_sidebar.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HTTP调试代理 - Debug View',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebSocketService _wsService;
  final HttpService _httpService = HttpService();
  
  List<HttpLog> _allLogs = [];
  List<HttpLog> _filteredLogs = [];
  HttpLog? _selectedLog;
  
  String? _filterUrl;
  String? _filterMethod;
  int? _filterStatusCode;
  
  bool _isListening = true; // 监听状态
  
  StreamSubscription<HttpLog>? _logSubscription;
  VoidCallback? _favoritesSidebarRefresh;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    print('🔧 [${timestamp}] 开始初始化服务...');
    
    // 获取单例实例
    _wsService = WebSocketService.instance;
    print('📱 [${timestamp}] WebSocketService单例获取成功');
    
    // 取消旧的订阅（如果存在）
    if (_logSubscription != null) {
      print('🔄 [${timestamp}] 取消旧的日志订阅');
      _logSubscription?.cancel();
    }
    
    // 连接WebSocket
    print('🔗 [${timestamp}] 开始连接WebSocket...');
    _wsService.connect();
    
    // 监听新日志
    _logSubscription = _wsService.logStream.listen((log) {
      print('📥 [${DateTime.now().millisecondsSinceEpoch}] 主界面收到新日志: ${log.id} - ${log.method} ${log.url}');
      setState(() {
        _allLogs.add(log);
        _applyFilters();
      });
    });
    print('👂 [${timestamp}] 日志流监听已设置');
    
    // 加载历史日志
    _loadHistoryLogs();
    
    // 获取当前监听状态
    _loadListeningStatus();
    
    print('✅ [${timestamp}] 服务初始化完成');
  }

  Future<void> _loadHistoryLogs() async {
    try {
      final logs = await _httpService.getLogs();
      setState(() {
        _allLogs = logs;
        _applyFilters();
      });
    } catch (e) {
      print('加载历史日志失败: $e');
    }
  }

  Future<void> _loadListeningStatus() async {
    try {
      final listening = await _httpService.getListeningStatus();
      setState(() {
        _isListening = listening;
      });
    } catch (e) {
      print('获取监听状态失败: $e');
    }
  }

  Future<void> _toggleListening() async {
    try {
      bool success;
      if (_isListening) {
        success = await _httpService.stopListening();
        if (success) {
          setState(() {
            _isListening = false;
          });
        }
      } else {
        success = await _httpService.startListening();
        if (success) {
          setState(() {
            _isListening = true;
          });
        }
      }
    } catch (e) {
      print('切换监听状态失败: $e');
    }
  }

  void _applyFilters() {
    _filteredLogs = _allLogs.where((log) {
      // URL过滤
      if (_filterUrl != null && _filterUrl!.isNotEmpty) {
        if (!log.url.toLowerCase().contains(_filterUrl!.toLowerCase())) {
          return false;
        }
      }
      
      // 方法过滤
      if (_filterMethod != null && _filterMethod!.isNotEmpty) {
        if (log.method.toUpperCase() != _filterMethod!.toUpperCase()) {
          return false;
        }
      }
      
      // 状态码过滤
      if (_filterStatusCode != null) {
        if (log.statusCode != _filterStatusCode) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  void _onFilterChanged(String? url, String? method, int? statusCode) {
    setState(() {
      _filterUrl = url;
      _filterMethod = method;
      _filterStatusCode = statusCode;
      _applyFilters();
    });
  }

  void _onLogSelected(HttpLog log) {
    setState(() {
      _selectedLog = log;
    });
  }

  Future<void> _onClearLogs() async {
    try {
      final success = await _httpService.clearLogs();
      if (success) {
        setState(() {
          _allLogs.clear();
          _filteredLogs.clear();
          _selectedLog = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('日志已清除'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('清除失败');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('清除日志失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 刷新收藏列表
  void _refreshFavorites() {
    _favoritesSidebarRefresh?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.bug_report, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'HTTP调试代理服务',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadHistoryLogs,
            tooltip: '刷新日志',
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // 最左侧：收藏侧边栏
              FavoritesSidebar(
                onFavoritesChanged: () {
                  // 收藏变化时的回调，可以在这里刷新相关状态
                },
                onRefreshCallback: (callback) {
                  // 保存刷新回调
                  _favoritesSidebarRefresh = callback;
                },
              ),
              
              // 中间：过滤栏 + 日志列表（上下结构）
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    // 上方：过滤栏
                    FilterBar(
                      onFilterChanged: _onFilterChanged,
                      onClearLogs: _onClearLogs,
                      isConnected: _wsService.isConnected,
                    ),
                    SizedBox(height: 16),
                    
                    // 下方：日志列表
                    Expanded(
                      child: LogList(
                        logs: _filteredLogs,
                        onLogSelected: _onLogSelected,
                        isListening: _isListening,
                        onToggleListening: _toggleListening,
                        onClearLogs: _onClearLogs,
                        selectedLog: _selectedLog,
                        onFavoriteAdded: _refreshFavorites,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              
              // 右侧：日志详情（占满右边）
              Expanded(
                flex: 2,
                child: LogDetail(
                  log: _selectedLog,
                  allHttpLogs: _allLogs,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '使用说明：将Android应用的网络请求代理到 localhost:8080，然后在此界面实时查看所有HTTP请求和响应数据。',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '总计: ${_filteredLogs.length}/${_allLogs.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    print('主界面销毁，清理资源...');
    _logSubscription?.cancel();
    _wsService.dispose();
    super.dispose();
  }
}
