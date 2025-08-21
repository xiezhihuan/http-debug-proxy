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
  late Map<String, TextEditingController> _headerControllers;
  
  final HttpService _httpService = HttpService();
  bool _isReplaying = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.originalLog.url);
    _methodController = TextEditingController(text: widget.originalLog.method);
    _bodyController = TextEditingController(text: widget.originalLog.requestBody);
    
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
    _headerControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 1000, // 增加宽度
        height: 700,  // 增加高度
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            _buildHeader(),
            
            const SizedBox(height: 24),
            
            // 主要内容区域 - 使用Expanded确保充分利用空间
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧：基本信息和请求头
                  Expanded(
                    flex: 1,
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
                        Expanded(
                          child: _buildHeadersSection(),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // 右侧：请求体
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('请求体'),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _buildBodySection(),
                        ),
                      ],
                    ),
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
          
          // 请求头列表 - 使用Expanded确保充分利用空间
          Expanded(
            child: Container(
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
          Expanded(
            child: Container(
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
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _isReplaying ? null : () => Navigator.of(context).pop(),
          child: Text('取消'),
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
          label: Text(_isReplaying ? '重放中...' : '重放请求'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
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

    setState(() {
      _isReplaying = true;
    });

    try {
      // 构建请求头
      final headers = <String, String>{};
      _headerControllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          headers[key] = controller.text;
        }
      });

      // 发送重放请求
      final result = await _httpService.replayRequest(
        originalLogId: widget.originalLog.id,
        method: _methodController.text,
        url: _urlController.text,
        headers: headers,
        body: _bodyController.text,
      );

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请求重放成功！日志ID: ${result['log_id']}'),
          backgroundColor: Colors.green,
        ),
      );

      // 关闭对话框
      Navigator.of(context).pop(result);
      
    } catch (e) {
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请求重放失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isReplaying = false;
      });
    }
  }
}
