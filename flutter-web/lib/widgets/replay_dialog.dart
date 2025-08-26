import 'package:flutter/material.dart';
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.originalLog.url);
    _methodController = TextEditingController(text: widget.originalLog.method);
    
    // 初始化请求体，如果是JSON则格式化显示
    String initialBody = widget.originalLog.requestBody;
    if (initialBody.isNotEmpty && _isInitialJsonContent()) {
      try {
        final jsonObject = jsonDecode(initialBody);
        const encoder = JsonEncoder.withIndent('    '); // 4个空格
        initialBody = encoder.convert(jsonObject);
      } catch (e) {
        // 如果JSON解析失败，保持原始内容
      }
    }
    _bodyController = TextEditingController(text: initialBody);
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
        width: 1200, // 增加宽度以适应左右布局
        height: 800,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(),
            
            const SizedBox(height: 24),
            
            // 主要内容区域 - 左右分栏
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧面板 - 基本信息和请求头
                  Expanded(
                    flex: 4, // 40%宽度
                    child: _buildLeftPanel(),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // 右侧面板 - 请求体
                  Expanded(
                    flex: 6, // 60%宽度
                    child: _buildRightPanel(),
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

  // 左侧面板 - 基本信息和请求头
  Widget _buildLeftPanel() {
    return SingleChildScrollView(
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
        ],
      ),
    );
  }

  // 右侧面板 - 请求体
  Widget _buildRightPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('请求体'),
        const SizedBox(height: 12),
        Expanded(
          child: _buildBodySection(),
        ),
      ],
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
        // URL 输入框
        _buildTextField(
          controller: _urlController,
          label: '请求 URL',
          hint: '输入完整的请求URL，例如：https://httpbin.org/post',
          maxLines: 2,
        ),
        
        const SizedBox(height: 16),
        
        // HTTP方法和Content-Type
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
        
        // 重放次数和执行方式
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
          
          // 请求头列表 - 紧凑布局
          Container(
            constraints: BoxConstraints(
              maxHeight: 300, // 限制最大高度
            ),
            padding: EdgeInsets.all(12),
            child: _headerControllers.isEmpty
                ? Center(
                    child: Text(
                      '暂无请求头',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      children: _headerControllers.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, color: Colors.red, size: 16),
                                      onPressed: () => _removeHeader(entry.key),
                                      padding: EdgeInsets.zero,
                                      constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    hintText: '请求头值',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    isDense: true,
                                  ),
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
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
          // 请求体类型指示器和JSON操作按钮
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
                Expanded(
                  child: Text(
                    '请求体类型: ${_getContentTypeFromHeaders()}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // JSON格式化按钮
                if (_isJsonContentType()) ...[
                  TextButton.icon(
                    onPressed: _formatJson,
                    icon: Icon(Icons.auto_fix_high, size: 16, color: Colors.green.shade700),
                    label: Text(
                      '格式化JSON',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _compressJson,
                    icon: Icon(Icons.compress, size: 16, color: Colors.orange.shade700),
                    label: Text(
                      '压缩JSON',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // 请求体输入区域 - 充满可用空间
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true, // 充满容器高度
                decoration: InputDecoration(
                  hintText: '输入请求体内容...\n\n示例 JSON:\n{\n    "key": "value",\n    "number": 123,\n    "boolean": true\n}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  contentPadding: EdgeInsets.all(12),
                  alignLabelWithHint: true,
                ),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.4, // 设置行高，让文本更易读
                ),
                scrollPhysics: BouncingScrollPhysics(), // 添加弹性滚动
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
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

  // 检查是否为JSON内容类型
  bool _isJsonContentType() {
    final contentType = _getContentTypeFromHeaders().toLowerCase();
    return contentType.contains('json');
  }

  // 检查初始请求是否为JSON类型（用于初始化时判断）
  bool _isInitialJsonContent() {
    // 检查原始请求的Content-Type
    final headers = widget.originalLog.requestHeaders;
    final contentTypeValues = headers['Content-Type'] ?? headers['content-type'];
    if (contentTypeValues != null && contentTypeValues.isNotEmpty) {
      final contentType = contentTypeValues.first.toLowerCase();
      return contentType.contains('json');
    }
    
    // 如果没有Content-Type头，尝试通过内容判断
    final body = widget.originalLog.requestBody.trim();
    if (body.isNotEmpty) {
      return (body.startsWith('{') && body.endsWith('}')) || 
             (body.startsWith('[') && body.endsWith(']'));
    }
    
    return false;
  }

  // 格式化JSON（使用4个空格缩进）
  void _formatJson() {
    try {
      final jsonText = _bodyController.text.trim();
      if (jsonText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请求体为空，无法格式化'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 尝试解析JSON
      final jsonObject = jsonDecode(jsonText);
      
      // 使用4个空格进行格式化
      const encoder = JsonEncoder.withIndent('    '); // 4个空格
      final formattedJson = encoder.convert(jsonObject);
      
      setState(() {
        _bodyController.text = formattedJson;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON格式化成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // JSON无效时不进行格式化，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON格式无效，无法格式化'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 压缩JSON（去除格式化，变成一行）
  void _compressJson() {
    try {
      final jsonText = _bodyController.text.trim();
      if (jsonText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('请求体为空，无法压缩'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 尝试解析JSON
      final jsonObject = jsonDecode(jsonText);
      
      // 压缩为一行（不使用缩进）
      final compressedJson = jsonEncode(jsonObject);
      
      setState(() {
        _bodyController.text = compressedJson;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON压缩成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // JSON无效时不进行压缩，显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON格式无效，无法压缩'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      if (!_canCancel) break;
      
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
      if (!_canCancel) break;
      
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
                          Expanded(
                            child: Text(
                              '第${result['index']}次: ${isSuccess ? '成功' : '失败'}',
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