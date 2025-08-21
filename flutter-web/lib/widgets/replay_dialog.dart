import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/http_log.dart';
import '../services/http_service.dart';

class ReplayDialog extends StatefulWidget {
  final HttpLog originalLog;
  final List<HttpLog> allHttpLogs;

  const ReplayDialog({
    Key? key,
    required this.originalLog,
    required this.allHttpLogs,
  }) : super(key: key);

  @override
  _ReplayDialogState createState() => _ReplayDialogState();
}

class _ReplayDialogState extends State<ReplayDialog> {
  late TextEditingController _urlController;
  late TextEditingController _methodController;
  late TextEditingController _bodyController;
  late TextEditingController _replayCountController;
  late Map<String, TextEditingController> _headerControllers;
  
  final HttpService _httpService = HttpService();
  bool _isReplaying = false;
  bool _isConcurrent = false;
  int _currentReplayIndex = 0;
  int _totalReplayCount = 0;
  List<Map<String, dynamic>> _replayResults = [];
  bool _canCancel = false;
  
  // 请求编排相关
  bool _isSequenceMode = false;
  List<Map<String, dynamic>> _requestSequence = [];
  int _currentSequenceIndex = 0;
  int _currentRoundIndex = 0;
  int _totalRounds = 0;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.originalLog.url);
    _methodController = TextEditingController(text: widget.originalLog.method);
    _bodyController = TextEditingController(text: widget.originalLog.requestBody);
    _replayCountController = TextEditingController(text: '1');
    
    // 初始化请求头控制器
    _headerControllers = {};
    widget.originalLog.requestHeaders.forEach((key, values) {
      _headerControllers[key] = TextEditingController(text: values.join(', '));
    });
    
    // 初始化序列模式相关变量
    _totalRounds = 100;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _methodController.dispose();
    _bodyController.dispose();
    _replayCountController.dispose();
    _headerControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 1000, // 增加宽度
        height: 800,  // 增加高度，确保有足够空间
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(),
            
            const SizedBox(height: 24),
            
            // 主要内容区域 - 使用垂直布局确保每个区域都有足够空间
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 基本信息
                    _buildSectionTitle('基本信息'),
                    const SizedBox(height: 12),
                    _buildBasicInfoSection(),
                    
                    const SizedBox(height: 24),
                    
                    // 请求头
                    _buildSectionTitle('请求头'),
                    const SizedBox(height: 12),
                    _buildHeadersSection(),
                    
                    const SizedBox(height: 24),
                    
                    // 请求体
                    _buildSectionTitle('请求体'),
                    const SizedBox(height: 12),
                    _buildBodySection(),
                    
                    // 请求序列编排（仅在序列模式下显示）
                    if (_isSequenceMode) ...[
                      const SizedBox(height: 24),
                      _buildSequenceSection(),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.replay, color: Colors.blue, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '重放请求',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      children: [
        // URL 输入框 - 占据更多空间
        _buildTextField(
          controller: _urlController,
          label: '请求 URL',
          hint: '输入完整的请求URL，例如：https://httpbin.org/post',
          maxLines: 2, // 允许换行显示长URL
        ),
        
        const SizedBox(height: 16),
        
        // HTTP方法和请求体类型选择
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildTextField(
                controller: _methodController,
                label: 'HTTP 方法',
                hint: 'GET, POST, PUT, DELETE...',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildContentTypeField(),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 重放次数设置和执行方式选择
        Row(
          children: [
            Expanded(
              flex: 1,
              child: _buildTextField(
                controller: _replayCountController,
                label: '重放次数',
                hint: '1-1000',
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: _buildExecutionModeField(),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // 请求编排模式选择
        _buildSequenceModeField(),
      ],
    );
  }

  Widget _buildContentTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Content-Type',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _getContentTypeFromHeaders(),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _getContentTypeFromHeaders() {
    final contentType = _headerControllers['Content-Type']?.text;
    return contentType?.isNotEmpty == true ? contentType! : 'application/json';
  }

  Widget _buildExecutionModeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '执行方式',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: Text('顺序执行', style: TextStyle(fontSize: 14)),
                subtitle: Text('一次完成后再执行下一次', style: TextStyle(fontSize: 12)),
                value: false,
                groupValue: _isConcurrent,
                onChanged: (value) {
                  setState(() {
                    _isConcurrent = value ?? false;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: Text('并发执行', style: TextStyle(fontSize: 14)),
                subtitle: Text('同时执行多个请求', style: TextStyle(fontSize: 12)),
                value: true,
                groupValue: _isConcurrent,
                onChanged: (value) {
                  setState(() {
                    _isConcurrent = value ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSequenceModeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '请求编排模式',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                title: Text('单请求重放', style: TextStyle(fontSize: 14)),
                subtitle: Text('重复执行当前请求', style: TextStyle(fontSize: 12)),
                value: false,
                groupValue: _isSequenceMode,
                onChanged: (value) {
                  setState(() {
                    _isSequenceMode = value ?? false;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                title: Text('请求序列编排', style: TextStyle(fontSize: 14)),
                subtitle: Text('按顺序执行多个请求', style: TextStyle(fontSize: 12)),
                value: true,
                groupValue: _isSequenceMode,
                onChanged: (value) {
                  setState(() {
                    _isSequenceMode = value ?? false;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSequenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '请求序列编排',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addRequestToSequence,
              icon: Icon(Icons.add),
              label: Text('添加请求'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 序列配置
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // 序列头部
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '序列重复次数',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: TextEditingController(text: '100'),
                        decoration: InputDecoration(
                          hintText: '1-1000',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _totalRounds = int.tryParse(value) ?? 100;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // 请求序列列表
              if (_requestSequence.isEmpty)
                Container(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade400),
                        SizedBox(height: 16),
                        Text(
                          '暂无请求序列',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '点击"添加请求"按钮添加请求到序列中',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  height: 300,
                  child: ListView.builder(
                    itemCount: _requestSequence.length,
                    itemBuilder: (context, index) {
                      final request = _requestSequence[index];
                      return _buildSequenceItem(index, request);
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSequenceItem(int index, Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request['method']} ${request['url']}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    if (request['description']?.isNotEmpty == true)
                      Text(
                        request['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue, size: 18),
                    onPressed: () => _editSequenceRequest(index),
                    tooltip: '编辑请求',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () => _removeSequenceRequest(index),
                    tooltip: '删除请求',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addRequestToSequence() {
    showDialog(
      context: context,
      builder: (context) => _buildAddRequestDialog(),
    );
  }

  void _editSequenceRequest(int index) {
    showDialog(
      context: context,
      builder: (context) => _buildEditRequestDialog(index),
    );
  }

  void _removeSequenceRequest(int index) {
    setState(() {
      _requestSequence.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除请求 ${index + 1}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildAddRequestDialog() {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add, color: Colors.green),
          SizedBox(width: 8),
          Text('从历史请求中选择'),
        ],
      ),
      content: Container(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // 搜索和过滤区域
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: '搜索请求',
                        hintText: '输入URL、方法或关键词搜索',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        // TODO: 实现搜索功能
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  DropdownButton<String>(
                    value: 'all',
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('所有方法')),
                      DropdownMenuItem(value: 'GET', child: Text('GET')),
                      DropdownMenuItem(value: 'POST', child: Text('POST')),
                      DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                      DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                    ],
                    onChanged: (value) {
                      // TODO: 实现方法过滤
                    },
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 16),
            
            // 请求列表
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildRequestSelectionList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'),
        ),
      ],
    );
  }

  Widget _buildRequestSelectionList() {
    // 使用真实的HTTP日志数据
    final httpLogs = widget.allHttpLogs;

    if (httpLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              '暂无HTTP请求记录',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '请先进行一些HTTP请求以生成记录',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    // 按时间倒序排列，最新的请求在前面
    final sortedLogs = List<HttpLog>.from(httpLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      itemCount: sortedLogs.length,
      itemBuilder: (context, index) {
        final log = sortedLogs[index];
        return _buildRequestSelectionItem(log);
      },
    );
  }

  Widget _buildRequestSelectionItem(HttpLog log) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // HTTP方法标签
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMethodColor(log.method),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.method,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              
              // 状态码标签
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusCodeColor(log.statusCode),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${log.statusCode}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12),
              
              // URL
              Expanded(
                child: Text(
                  log.url,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // 时间
              Text(
                _formatTimestamp(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // 请求头预览
          if (log.requestHeaders.isNotEmpty) ...[
            Text(
              '请求头: ${log.requestHeaders.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join(', ')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
          ],
          
          // 请求体预览
          if (log.requestBody.isNotEmpty) ...[
            Text(
              '请求体: ${log.requestBody}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
          ],
          
          SizedBox(height: 12),
          
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showRequestDetails(log),
                icon: Icon(Icons.info_outline, size: 16),
                label: Text('查看详情'),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addSelectedRequestToSequence(log),
                icon: Icon(Icons.add, size: 16),
                label: Text('添加到序列'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditRequestDialog(int index) {
    final request = _requestSequence[index];
    final urlController = TextEditingController(text: request['url']);
    final methodController = TextEditingController(text: request['method']);
    final descriptionController = TextEditingController(text: request['description'] ?? '');
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: Colors.blue),
          SizedBox(width: 8),
          Text('编辑请求 ${index + 1}'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: urlController,
            decoration: InputDecoration(
              labelText: '请求URL',
              hintText: 'https://api.example.com/endpoint',
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: methodController,
                  decoration: InputDecoration(
                    labelText: 'HTTP方法',
                    hintText: 'GET, POST, PUT, DELETE',
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '登录请求',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (urlController.text.isNotEmpty) {
              setState(() {
                _requestSequence[index] = {
                  'url': urlController.text,
                  'method': methodController.text.toUpperCase(),
                  'description': descriptionController.text,
                };
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已更新请求 ${index + 1}'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
          child: Text('更新'),
        ),
      ],
    );
  }

  // 获取HTTP方法的颜色
  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 获取状态码的颜色
  Color _getStatusCodeColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.blue;
    } else if (statusCode >= 400 && statusCode < 500) {
      return Colors.orange;
    } else if (statusCode >= 500) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  // 格式化时间戳
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${timestamp.month}-${timestamp.day} ${timestamp.hour}:${timestamp.minute}';
    }
  }

  // 显示请求详情
  void _showRequestDetails(HttpLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('请求详情'),
          ],
        ),
        content: Container(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('请求方法', log.method),
                _buildDetailRow('请求URL', log.url),
                _buildDetailRow('状态码', '${log.statusCode}'),
                _buildDetailRow('时间', _formatTimestamp(log.timestamp)),
                SizedBox(height: 16),
                Text(
                  '请求头:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.requestHeaders.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n').isNotEmpty 
                      ? log.requestHeaders.entries.map((e) => '${e.key}: ${e.value.join(', ')}').join('\n')
                      : '无',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '请求体:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.requestBody.isNotEmpty ? log.requestBody : '无',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 构建详情行
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  // 添加选中的请求到序列
  void _addSelectedRequestToSequence(HttpLog log) {
    // 显示描述编辑对话框
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('编辑描述'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '请为这个请求添加描述信息（可选）：',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: '描述',
                hintText: '例如：用户登录、获取用户信息等',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              // 转换请求头格式：从 Map<String, List<String>> 到 Map<String, String>
              final headersMap = <String, String>{};
              log.requestHeaders.forEach((key, values) {
                headersMap[key] = values.join(', ');
              });
              
              // 添加到序列
              setState(() {
                _requestSequence.add({
                  'url': log.url,
                  'method': log.method,
                  'description': descriptionController.text,
                  'requestHeaders': headersMap,
                  'requestBody': log.requestBody,
                });
              });
              
              Navigator.of(context).pop(); // 关闭描述编辑对话框
              Navigator.of(context).pop(); // 关闭请求选择对话框
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已添加请求到序列'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('添加到序列'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersSection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 添加新请求头的区域
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: '请求头名称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty && !_headerControllers.containsKey(value)) {
                        setState(() {
                          _headerControllers[value] = TextEditingController();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _addNewHeader,
                  icon: Icon(Icons.add),
                  label: Text('添加'),
                ),
              ],
            ),
          ),
          
          // 请求头列表 - 固定高度确保完整显示
          Container(
            height: 200, // 固定高度，确保有足够空间
            padding: EdgeInsets.all(16),
            child: _headerControllers.isEmpty
                ? Center(
                    child: Text(
                      '暂无请求头，点击上方"添加"按钮添加',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: _headerControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: TextEditingController(text: entry.key),
                                  decoration: InputDecoration(
                                    labelText: '名称',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (value) {
                                    if (value != entry.key) {
                                      final oldKey = entry.key;
                                      final controller = _headerControllers.remove(oldKey)!;
                                      _headerControllers[value] = controller;
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    labelText: '值',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeHeader(entry.key),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodySection() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 请求体类型指示器
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                const SizedBox(width: 8),
                Text(
                  '请求体类型: ${_getContentTypeFromHeaders()}',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // 请求体输入区域
          Container(
            height: 200, // 固定高度，确保有足够空间
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _bodyController,
              maxLines: null, // 允许无限行数
              expands: true, // 填充可用空间
              decoration: InputDecoration(
                hintText: '输入请求体内容...\n\n示例 JSON:\n{\n  "key": "value",\n  "number": 123,\n  "boolean": true\n}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                contentPadding: EdgeInsets.all(12),
                alignLabelWithHint: true,
              ),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 进度指示器
        if (_isReplaying) ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '重放进度',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    if (_canCancel)
                      TextButton.icon(
                        onPressed: _cancelReplay,
                        icon: Icon(Icons.stop, color: Colors.red, size: 16),
                        label: Text('取消重放', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _isSequenceMode 
                    ? (_totalRounds > 0 ? _currentRoundIndex / _totalRounds : 0)
                    : (_totalReplayCount > 0 ? _currentReplayIndex / _totalReplayCount : 0),
                  backgroundColor: Colors.blue.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
                SizedBox(height: 8),
                Text(
                  _isSequenceMode
                    ? '正在执行第 $_currentRoundIndex / $_totalRounds 轮，第 $_currentSequenceIndex / ${_requestSequence.length} 个请求'
                    : '正在重放第 $_currentReplayIndex / $_totalReplayCount 次',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
        ],
        
        // 操作按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isReplaying ? null : () => Navigator.of(context).pop(),
              child: Text('关闭'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isReplaying ? null : _replayRequest,
              icon: _isReplaying 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.replay),
              label: Text(_isReplaying ? '重放中...' : '开始重放'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  void _addNewHeader() {
    final newKey = 'New-Header-${_headerControllers.length + 1}';
    setState(() {
      _headerControllers[newKey] = TextEditingController();
    });
  }

  void _removeHeader(String key) {
    setState(() {
      _headerControllers.remove(key)?.dispose();
    });
  }

  Future<void> _replayRequest() async {
    if (_isSequenceMode) {
      // 序列模式：检查是否有请求序列
      if (_requestSequence.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请先添加请求到序列中'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 检查序列重复次数
      if (_totalRounds < 1 || _totalRounds > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请输入有效的序列重复次数（1-1000）'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _isReplaying = true;
        _currentRoundIndex = 0;
        _currentSequenceIndex = 0;
        _replayResults.clear();
        _canCancel = true;
      });

      try {
        // 执行请求序列
        await _executeRequestSequence();
        
        // 显示完成消息和统计信息
        _showReplayResults();
        
      } catch (e) {
        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请求序列执行失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isReplaying = false;
          _canCancel = false;
        });
      }
    } else {
      // 单请求模式：原有的重放逻辑
      if (_urlController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('请输入URL')),
        );
        return;
      }

      // 解析重放次数
      final replayCount = int.tryParse(_replayCountController.text);
      if (replayCount == null || replayCount < 1 || replayCount > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请输入有效的重放次数（1-1000）'),
            backgroundColor: Colors.red,
        ),
        );
        return;
      }

      setState(() {
        _isReplaying = true;
        _currentReplayIndex = 0;
        _totalReplayCount = replayCount;
        _replayResults.clear();
        _canCancel = false;
      });

      try {
        // 构建请求头
        final headers = <String, String>{};
        _headerControllers.forEach((key, controller) {
          if (controller.text.isNotEmpty) {
            headers[key] = controller.text;
          }
        });

        if (_isConcurrent) {
          // 并发执行
          await _executeConcurrentReplay(headers, replayCount);
        } else {
          // 顺序执行
          await _executeSequentialReplay(headers, replayCount);
        }

        // 显示完成消息和统计信息
        _showReplayResults();
        
      } catch (e) {
        // 显示错误消息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('重放请求失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isReplaying = false;
          _canCancel = false;
        });
      }
    }
  }

  Future<void> _executeSequentialReplay(Map<String, String> headers, int count) async {
    for (int i = 0; i < count; i++) {
      if (!_canCancel) break; // 检查是否被取消
      
      setState(() {
        _currentReplayIndex = i + 1;
      });

      try {
        final result = await _httpService.replayRequest(
          originalLogId: widget.originalLog.id,
          method: _methodController.text,
          url: _urlController.text,
          headers: headers,
          body: _bodyController.text,
        );

        _replayResults.add({
          'index': i + 1,
          'success': true,
          'log_id': result['log_id'],
          'timestamp': DateTime.now(),
        });

        // 添加延迟避免过快请求
        await Future.delayed(Duration(milliseconds: 100));
        
      } catch (e) {
        _replayResults.add({
          'index': i + 1,
          'success': false,
          'error': e.toString(),
          'timestamp': DateTime.now(),
        });
      }
    }
  }

  Future<void> _executeRequestSequence() async {
    for (int round = 0; round < _totalRounds; round++) {
      if (!_canCancel) break; // 检查是否被取消
      
      setState(() {
        _currentRoundIndex = round + 1;
      });

      // 执行当前轮次的所有请求
      for (int seqIndex = 0; seqIndex < _requestSequence.length; seqIndex++) {
        if (!_canCancel) break; // 检查是否被取消
        
        setState(() {
          _currentSequenceIndex = seqIndex + 1;
        });

        final request = _requestSequence[seqIndex];
        
        try {
          // 执行单个请求
          final result = await _httpService.replayRequest(
            originalLogId: widget.originalLog.id,
            method: request['method'],
            url: request['url'],
            headers: request['requestHeaders'] ?? <String, String>{},
            body: request['requestBody'] ?? '',
          );

          _replayResults.add({
            'round': round + 1,
            'sequence': seqIndex + 1,
            'url': request['url'],
            'method': request['method'],
            'success': true,
            'log_id': result['log_id'],
            'timestamp': DateTime.now(),
          });

          // 添加延迟避免过快请求
          await Future.delayed(Duration(milliseconds: 100));
          
        } catch (e) {
          _replayResults.add({
            'round': round + 1,
            'sequence': seqIndex + 1,
            'url': request['url'],
            'method': request['method'],
            'success': false,
            'error': e.toString(),
            'timestamp': DateTime.now(),
          });
        }
      }
    }
  }

  Future<void> _executeConcurrentReplay(Map<String, String> headers, int count) async {
    final futures = <Future>[];
    
    for (int i = 0; i < count; i++) {
      if (!_canCancel) break; // 检查是否被取消
      
      final future = _executeSingleReplay(headers, i + 1);
      futures.add(future);
    }

    await Future.wait(futures);
  }

  Future<void> _executeSingleReplay(Map<String, String> headers, int index) async {
    try {
      final result = await _httpService.replayRequest(
        originalLogId: widget.originalLog.id,
        method: _methodController.text,
        url: _urlController.text,
        headers: headers,
        body: _bodyController.text,
      );

      setState(() {
        _replayResults.add({
          'index': index,
          'success': true,
          'log_id': result['log_id'],
          'timestamp': DateTime.now(),
        });
        _currentReplayIndex = _replayResults.length;
      });
      
    } catch (e) {
      setState(() {
        _replayResults.add({
          'index': index,
          'success': false,
          'error': e.toString(),
          'timestamp': DateTime.now(),
        });
        _currentReplayIndex = _replayResults.length;
      });
    }
  }

  void _cancelReplay() {
    setState(() {
      _canCancel = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在取消重放...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showReplayResults() {
    final successCount = _replayResults.where((r) => r['success'] == true).length;
    final failureCount = _replayResults.where((r) => r['success'] == false).length;
    final successRate = _replayResults.isNotEmpty ? (successCount / _replayResults.length * 100).toStringAsFixed(1) : '0.0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assessment, color: Colors.blue),
            SizedBox(width: 8),
            Text(_isSequenceMode ? '请求序列执行结果' : '重放结果统计'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSequenceMode) ...[
              _buildResultRow('序列重复轮次', '$_totalRounds'),
              _buildResultRow('每轮请求数量', '${_requestSequence.length}'),
              _buildResultRow('总请求次数', '${_totalRounds * _requestSequence.length}'),
            ] else ...[
              _buildResultRow('总重放次数', '$_totalReplayCount'),
            ],
            _buildResultRow('成功次数', '$successCount', Colors.green),
            _buildResultRow('失败次数', '$failureCount', Colors.red),
            _buildResultRow('成功率', '$successRate%', Colors.blue),
            SizedBox(height: 16),
            Text(
              '详细结果：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: _replayResults.map((result) {
                    final isSuccess = result['success'] == true;
                    String resultText;
                    
                    if (_isSequenceMode) {
                      resultText = '第${result['round']}轮第${result['sequence']}个: ${result['method']} ${result['url']} - ${isSuccess ? '成功' : '失败'}';
                    } else {
                      resultText = '第${result['index']}次: ${isSuccess ? '成功' : '失败'}';
                    }
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 4),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSuccess ? Colors.green.shade200 : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.check_circle : Icons.error,
                            color: isSuccess ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              resultText,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          if (isSuccess) ...[
                            Text(
                              'ID: ${result['log_id']}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, [Color? color]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
