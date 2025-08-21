import 'package:flutter/material.dart';
import '../models/http_log.dart';
import '../services/http_service.dart';

class RequestSequenceDialog extends StatefulWidget {
  final List<HttpLog> allHttpLogs;
  final HttpLog? initialLog; // 可选的初始请求

  const RequestSequenceDialog({
    Key? key,
    required this.allHttpLogs,
    this.initialLog,
  }) : super(key: key);

  @override
  _RequestSequenceDialogState createState() => _RequestSequenceDialogState();
}

class _RequestSequenceDialogState extends State<RequestSequenceDialog> {
  final HttpService _httpService = HttpService();
  
  // 请求序列编排相关
  List<Map<String, dynamic>> _requestSequence = [];
  int _totalRounds = 100;
  
  // 执行状态
  bool _isExecuting = false;
  int _currentRoundIndex = 0;
  int _currentSequenceIndex = 0;
  List<Map<String, dynamic>> _executionResults = [];
  bool _canCancel = false;

  @override
  void initState() {
    super.initState();
    
    // 如果提供了初始请求，自动添加到序列
    if (widget.initialLog != null) {
      _addLogToSequence(widget.initialLog!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 1200,
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(),
            
            const SizedBox(height: 24),
            
            // 主要内容区域
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：请求序列管理
                  Expanded(
                    flex: 1,
                    child: _buildSequencePanel(),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // 右侧：历史请求选择
                  Expanded(
                    flex: 1,
                    child: _buildRequestSelectionPanel(),
                  ),
                ],
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
        Icon(Icons.playlist_play, color: Colors.blue, size: 32),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请求编排',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                '创建和管理HTTP请求序列，支持循环执行',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildSequencePanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 序列头部
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
                Icon(Icons.format_list_numbered, color: Colors.blue.shade700),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '请求序列 (${_requestSequence.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Container(
                  width: 100,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: '重复次数',
                      hintText: '100',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          
          // 序列列表
          Expanded(
            child: _requestSequence.isEmpty
                ? _buildEmptySequenceState()
                : _buildSequenceList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySequenceState() {
    return Container(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade400),
            SizedBox(height: 16),
            Text(
              '暂无请求序列',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '从右侧历史请求中选择并添加到序列',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSequenceList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _requestSequence.length,
      itemBuilder: (context, index) {
        final request = _requestSequence[index];
        return _buildSequenceItem(index, request);
      },
    );
  }

  Widget _buildSequenceItem(int index, Map<String, dynamic> request) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
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
              // 序号
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
              
              // 请求信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getMethodColor(request['method']),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            request['method'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['url'],
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (request['description']?.isNotEmpty == true) ...[
                      SizedBox(height: 4),
                      Text(
                        request['description'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 操作按钮
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

  Widget _buildRequestSelectionPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 选择头部
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.history, color: Colors.green.shade700),
                SizedBox(width: 8),
                Text(
                  '历史请求列表',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          // 请求列表
          Expanded(
            child: _buildRequestSelectionList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSelectionList() {
    final httpLogs = widget.allHttpLogs;

    if (httpLogs.isEmpty) {
      return Container(
        padding: EdgeInsets.all(40),
        child: Center(
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
        ),
      );
    }

    // 按时间倒序排列，最新的请求在前面
    final sortedLogs = List<HttpLog>.from(httpLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: sortedLogs.length,
      itemBuilder: (context, index) {
        final log = sortedLogs[index];
        return _buildRequestSelectionItem(log);
      },
    );
  }

  Widget _buildRequestSelectionItem(HttpLog log) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // HTTP方法标签
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getMethodColor(log.method),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.method,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              
              // 状态码标签
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusCodeColor(log.statusCode),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${log.statusCode}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 8),
              
              // URL
              Expanded(
                child: Text(
                  log.url,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              // 时间
              Text(
                _formatTimestamp(log.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showRequestDetails(log),
                icon: Icon(Icons.info_outline, size: 14),
                label: Text('详情', style: TextStyle(fontSize: 12)),
              ),
              SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _addLogToSequence(log),
                icon: Icon(Icons.add, size: 14),
                label: Text('添加', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // 进度指示器
        if (_isExecuting) ...[
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
                      '执行进度',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    if (_canCancel)
                      TextButton.icon(
                        onPressed: _cancelExecution,
                        icon: Icon(Icons.stop, color: Colors.red, size: 16),
                        label: Text('取消执行', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
                SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _totalRounds > 0 ? _currentRoundIndex / _totalRounds : 0,
                  backgroundColor: Colors.blue.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
                SizedBox(height: 8),
                Text(
                  '正在执行第 $_currentRoundIndex / $_totalRounds 轮，第 $_currentSequenceIndex / ${_requestSequence.length} 个请求',
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
              onPressed: _isExecuting ? null : () => Navigator.of(context).pop(),
              child: Text('关闭'),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _isExecuting || _requestSequence.isEmpty ? null : _executeSequence,
              icon: _isExecuting 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.play_arrow),
              label: Text(_isExecuting ? '执行中...' : '开始执行'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
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

  // 添加请求到序列
  void _addLogToSequence(HttpLog log) {
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('添加到序列'),
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
              // 转换请求头格式
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
              
              Navigator.of(context).pop();
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已添加请求到序列'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('添加'),
          ),
        ],
      ),
    );
  }

  // 编辑序列中的请求
  void _editSequenceRequest(int index) {
    final request = _requestSequence[index];
    final descriptionController = TextEditingController(text: request['description'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: '描述',
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
              setState(() {
                _requestSequence[index]['description'] = descriptionController.text;
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已更新请求 ${index + 1}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: Text('更新'),
          ),
        ],
      ),
    );
  }

  // 删除序列中的请求
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
          width: 500,
          height: 300,
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

  // 执行序列
  Future<void> _executeSequence() async {
    if (_requestSequence.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请先添加请求到序列中'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isExecuting = true;
      _currentRoundIndex = 0;
      _currentSequenceIndex = 0;
      _executionResults.clear();
      _canCancel = true;
    });

    try {
      // 执行请求序列
      await _executeRequestSequence();
      
      // 显示完成消息和统计信息
      _showExecutionResults();
      
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
        _isExecuting = false;
        _canCancel = false;
      });
    }
  }

  // 执行请求序列
  Future<void> _executeRequestSequence() async {
    for (int round = 0; round < _totalRounds; round++) {
      if (!_canCancel) break;
      
      setState(() {
        _currentRoundIndex = round + 1;
      });

      // 执行当前轮次的所有请求
      for (int seqIndex = 0; seqIndex < _requestSequence.length; seqIndex++) {
        if (!_canCancel) break;
        
        setState(() {
          _currentSequenceIndex = seqIndex + 1;
        });

        final request = _requestSequence[seqIndex];
        
        try {
          // 执行单个请求
          final result = await _httpService.replayRequest(
            originalLogId: widget.initialLog?.id ?? '',
            method: request['method'],
            url: request['url'],
            headers: request['requestHeaders'] ?? <String, String>{},
            body: request['requestBody'] ?? '',
          );

          _executionResults.add({
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
          _executionResults.add({
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

  // 取消执行
  void _cancelExecution() {
    setState(() {
      _canCancel = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('正在取消执行...'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // 显示执行结果
  void _showExecutionResults() {
    final successCount = _executionResults.where((r) => r['success'] == true).length;
    final failureCount = _executionResults.where((r) => r['success'] == false).length;
    final successRate = _executionResults.isNotEmpty ? (successCount / _executionResults.length * 100).toStringAsFixed(1) : '0.0';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assessment, color: Colors.blue),
            SizedBox(width: 8),
            Text('请求序列执行结果'),
          ],
        ),
        content: Container(
          width: 500,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('序列重复轮次: $_totalRounds')),
                  Expanded(child: Text('每轮请求数量: ${_requestSequence.length}')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('总请求次数: ${_totalRounds * _requestSequence.length}')),
                  Expanded(child: Text('成功率: $successRate%')),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('成功次数: $successCount', style: TextStyle(color: Colors.green))),
                  Expanded(child: Text('失败次数: $failureCount', style: TextStyle(color: Colors.red))),
                ],
              ),
              SizedBox(height: 16),
              Text(
                '详细结果：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _executionResults.length,
                  itemBuilder: (context, index) {
                    final result = _executionResults[index];
                    final isSuccess = result['success'] == true;
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
                      child: Text(
                        '第${result['round']}轮第${result['sequence']}个: ${result['method']} ${result['url']} - ${isSuccess ? '成功' : '失败'}',
                        style: TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
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
}
