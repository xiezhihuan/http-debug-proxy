import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/http_log.dart';
import '../services/http_service.dart';

class ReplayDialog extends StatefulWidget {
  final HttpLog originalLog;

  const ReplayDialog({
    Key? key,
    required this.originalLog,
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
                  value: _totalReplayCount > 0 ? _currentReplayIndex / _totalReplayCount : 0,
                  backgroundColor: Colors.blue.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                ),
                SizedBox(height: 8),
                Text(
                  '正在重放第 $_currentReplayIndex / $_totalReplayCount 次',
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
      _canCancel = true;
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
            Text('重放结果统计'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('总重放次数', '$_totalReplayCount'),
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
                          Text(
                            '第${result['index']}次: ${isSuccess ? '成功' : '失败'}',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (isSuccess) ...[
                            Spacer(),
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
