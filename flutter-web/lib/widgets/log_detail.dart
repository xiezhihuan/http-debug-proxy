import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:json_editor_flutter/json_editor_flutter.dart';
import '../models/http_log.dart';
import 'replay_dialog.dart';

class LogDetail extends StatefulWidget {
  final HttpLog? log;

  const LogDetail({Key? key, this.log}) : super(key: key);

  @override
  _LogDetailState createState() => _LogDetailState();
}

class _LogDetailState extends State<LogDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.log == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '选择一个请求查看详情',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 头部区域
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '请求详情',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                // 复制URL按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.blue.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _copyUrlToClipboard(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link,
                            size: 14,
                            color: Colors.blue.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '复制URL',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 重放请求按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.green.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _replayRequest(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.replay,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '重放请求',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                // 复制为curl请求按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _copyAsCurl(context),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '复制为curl',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: '复制完整详情',
                ),
              ],
            ),
          ),
          
          // Tab栏
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 4),
                      Text('概览'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.upload, size: 16),
                      SizedBox(width: 4),
                      Text('请求'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download, size: 16),
                      SizedBox(width: 4),
                      Text('响应'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 4),
                      Text('预览'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt, size: 16),
                      SizedBox(width: 4),
                      Text('标头'),
                    ],
                  ),
                ),
              ],
              labelColor: Colors.blue.shade700,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blue.shade700,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              unselectedLabelStyle: TextStyle(fontSize: 12),
            ),
          ),
          
          // Tab内容区域
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildRequestTab(),
                _buildResponseTab(),
                _buildPreviewTab(),
                _buildHeadersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('请求概览'),
          SizedBox(height: 12),
          _buildInfoCard([
            _buildInfoRow('请求URL', widget.log!.url),
            _buildInfoRow('请求方法', widget.log!.method),
            _buildInfoRow('状态码', '${widget.log!.statusCode} (${widget.log!.statusCodeText})'),
          ]),
          SizedBox(height: 16),
          
          _buildSectionTitle('时间信息'),
          SizedBox(height: 12),
          _buildInfoCard([
            _buildInfoRow('发起时间', timeFormat.format(widget.log!.timestamp)),
            _buildInfoRow('响应耗时', widget.log!.formattedDuration),
            _buildInfoRow('请求ID', widget.log!.id),
          ]),
        ],
      ),
    );
  }

  Widget _buildRequestTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('请求体'),
              SizedBox(height: 12),
              _buildBodyTypeIndicator(widget.log!.requestBodyType, '请求'),
            ],
          ),
        ),
        Expanded(
          child: widget.log!.requestBody.isNotEmpty
            ? _buildBodyContent(widget.log!.requestBody, widget.log!.requestBodyType, context, isRequest: true)
            : _buildEmptyState('无请求体'),
        ),
      ],
    );
  }

  Widget _buildResponseTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('原始响应体'),
              SizedBox(height: 12),
              _buildBodyTypeIndicator(widget.log!.responseBodyType, '响应'),
            ],
          ),
        ),
        Expanded(
          child: widget.log!.responseBody.isNotEmpty
            ? _buildBodyContent(widget.log!.responseBody, widget.log!.responseBodyType, context, isRequest: false)
            : _buildEmptyState('无响应体'),
        ),
      ],
    );
  }

  Widget _buildPreviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('响应预览'),
              SizedBox(height: 12),
              _buildBodyTypeIndicator(widget.log!.responseBodyType, '响应'),
            ],
          ),
        ),
        Expanded(
          child: widget.log!.responseBody.isNotEmpty
            ? _buildBodyContent(widget.log!.responseBody, widget.log!.responseBodyType, context, isPreview: true)
            : _buildEmptyState('无响应内容可预览'),
        ),
      ],
    );
  }

  Widget _buildHeadersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('请求头'),
          SizedBox(height: 12),
          widget.log!.requestHeaders.isNotEmpty
            ? _buildHeadersTable(widget.log!.requestHeaders)
            : _buildEmptyState('无请求头'),
          SizedBox(height: 24),
          
          _buildSectionTitle('响应头'),
          SizedBox(height: 12),
          _buildCompressionInfo(),
          SizedBox(height: 12),
          widget.log!.responseHeaders.isNotEmpty 
            ? _buildHeadersTable(widget.log!.responseHeaders)
            : _buildEmptyState('无响应头'),
        ],
      ),
    );
  }

  Widget _buildCompressionInfo() {
    final contentEncoding = widget.log!.responseHeaders['content-encoding'];
    if (contentEncoding == null || contentEncoding.isEmpty) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          border: Border.all(color: Colors.green.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            SizedBox(width: 8),
            Text(
              '未压缩响应',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final isCompressed = contentEncoding.any((enc) => 
      enc.contains('gzip') || enc.contains('deflate') || enc.contains('br')
    );
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCompressed ? Colors.orange.shade50 : Colors.blue.shade50,
        border: Border.all(color: isCompressed ? Colors.orange.shade200 : Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isCompressed ? Icons.compress : Icons.info,
            color: isCompressed ? Colors.orange.shade600 : Colors.blue.shade600,
            size: 20,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCompressed ? '压缩响应' : '特殊编码',
                  style: TextStyle(
                    color: isCompressed ? Colors.orange.shade700 : Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '编码格式: ${contentEncoding.join(', ')}',
                  style: TextStyle(
                    color: isCompressed ? Colors.orange.shade600 : Colors.blue.shade600,
                    fontSize: 12,
                  ),
                ),
                if (isCompressed) ...[
                  SizedBox(height: 4),
                  Text(
                    '代理服务器已自动解压',
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHeadersTable(Map<String, List<String>> headers) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: headers.entries.map((entry) {
          final isLast = entry == headers.entries.last;
          return Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: isLast ? null : Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SelectableText(
                    entry.value.join(', '),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormattedCodeBlock(String content, BuildContext context, {bool isRequest = false}) {
    // 尝试格式化JSON
    String displayContent = content;
    bool isJson = false;
    
    try {
      if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
        final jsonData = json.decode(content);
        displayContent = JsonEncoder.withIndent('    ').convert(jsonData); // 改为4个空格
        isJson = true;
      }
    } catch (e) {
      // 如果不是有效的JSON，保持原样
      displayContent = content;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isRequest ? Colors.green.shade50 : Colors.blue.shade50,
        border: Border.all(
          color: isRequest ? Colors.green.shade300 : Colors.blue.shade300,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部标签和复制按钮
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRequest ? Colors.green.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isJson ? 'JSON 格式化' : '文本内容',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRequest ? Colors.green.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: displayContent));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已复制${isJson ? 'JSON' : '文本'}内容'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, size: 12, color: Colors.green.shade700),
                        SizedBox(width: 4),
                        Text(
                          '复制',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 内容区域
          Expanded( // 使用Expanded让内容区域填充剩余空间
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: SelectableText(
                displayContent,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.4, // 行高，让代码更易读
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String content, BuildContext context, {bool isRequest = false, bool isPreview = false}) {
    // 尝试格式化JSON
    bool isJson = false;
    dynamic jsonData;
    
    try {
      if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
        jsonData = json.decode(content);
        isJson = true;
      }
    } catch (e) {
      // 如果不是有效的JSON，保持原样
    }

    if (isJson && (isPreview || !isRequest)) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isRequest ? Colors.green.shade50 : Colors.blue.shade50,
          border: Border.all(
            color: isRequest ? Colors.green.shade300 : Colors.blue.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isRequest ? Colors.green.shade100 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'JSON 预览',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isRequest ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  Spacer(),
                  _buildCopyButton(context, jsonData),
                ],
              ),
            ),
            Expanded( // 使用Expanded让JSON编辑器填充剩余空间
              child: JsonEditor(
                json: JsonEncoder.withIndent('    ').convert(jsonData), // 改为4个空格
                onChanged: (value) {},
                enableMoreOptions: false,
                enableKeyEdit: false,
                enableValueEdit: false,
                themeColor: isRequest ? Colors.green.shade600 : Colors.blue.shade600,
                editors: [Editors.tree],
                enableHorizontalScroll: true,
                searchDuration: Duration(milliseconds: 300),
                hideEditorsMenuButton: true,
                expandedObjects: [],
              ),
            ),
          ],
        ),
      );
         } else {
       return _buildFormattedCodeBlock(content, context, isRequest: isRequest);
     }
  }

  Widget _buildBodyTypeIndicator(String bodyType, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bodyType == 'json' ? Colors.green.shade100 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label 体类型: $bodyType',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: bodyType == 'json' ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }

  Widget _buildBodyContent(String content, String bodyType, BuildContext context, {bool isRequest = false, bool isPreview = false}) {
    if (bodyType == 'json') {
      return _buildCodeBlock(content, context, isRequest: isRequest, isPreview: isPreview);
    } else {
      return _buildFormattedCodeBlock(content, context, isRequest: isRequest);
    }
  }

  Widget _buildCopyButton(BuildContext context, dynamic jsonData) {
    return GestureDetector(
      onTap: () {
        final jsonString = JsonEncoder.withIndent('    ').convert(jsonData); // 改为4个空格
        Clipboard.setData(ClipboardData(text: jsonString));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已复制JSON数据'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 12, color: Colors.green.shade700),
            SizedBox(width: 4),
            Text(
              '复制',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    if (widget.log == null) return;

    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    final buffer = StringBuffer();
    
    buffer.writeln('HTTP请求详情');
    buffer.writeln('============');
    buffer.writeln('方法: ${widget.log!.method}');
    buffer.writeln('URL: ${widget.log!.url}');
    buffer.writeln('状态码: ${widget.log!.statusCode}');
    buffer.writeln('耗时: ${widget.log!.formattedDuration}');
    buffer.writeln('时间: ${timeFormat.format(widget.log!.timestamp)}');
    buffer.writeln('ID: ${widget.log!.id}');
    buffer.writeln();
    
    buffer.writeln('请求头:');
    widget.log!.requestHeaders.forEach((key, values) {
      buffer.writeln('  $key: ${values.join(', ')}');
    });
    buffer.writeln();
    
    buffer.writeln('请求体:');
    buffer.writeln(widget.log!.requestBody.isEmpty ? '(无)' : widget.log!.requestBody);
    buffer.writeln();
    
    buffer.writeln('响应头:');
    widget.log!.responseHeaders.forEach((key, values) {
      buffer.writeln('  $key: ${values.join(', ')}');
    });
    buffer.writeln();
    
    buffer.writeln('响应体:');
    buffer.writeln(widget.log!.responseBody.isEmpty ? '(无)' : widget.log!.responseBody);

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('详情已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _copyUrlToClipboard(BuildContext context) {
    if (widget.log == null) return;

    Clipboard.setData(ClipboardData(text: widget.log!.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('URL已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _replayRequest(BuildContext context) {
    if (widget.log == null) return;

    // 显示重放请求对话框
    showDialog(
      context: context,
      builder: (context) => ReplayDialog(originalLog: widget.log!),
    );
  }

  void _copyAsCurl(BuildContext context) {
    if (widget.log == null) return;

    final buffer = StringBuffer();
    
    // 构建curl命令
    buffer.write('curl');
    
    // 添加HTTP方法（如果不是GET）
    if (widget.log!.method.toUpperCase() != 'GET') {
      buffer.write(' -X ${widget.log!.method.toUpperCase()}');
    }
    
    // 添加URL
    buffer.write(' "${widget.log!.url}"');
    
    // 添加请求头
    widget.log!.requestHeaders.forEach((key, values) {
      // 跳过一些不需要的头部
      if (key.toLowerCase() != 'host' && 
          key.toLowerCase() != 'content-length' &&
          key.toLowerCase() != 'connection') {
        final value = values.join(', ');
        buffer.write(' \\\n  -H "$key: $value"');
      }
    });
    
    // 添加请求体（如果有的话）
    if (widget.log!.requestBody.isNotEmpty) {
      // 检查Content-Type
      final contentType = widget.log!.requestHeaders['Content-Type']?.firstOrNull ?? '';
      if (contentType.contains('application/json')) {
        // JSON数据，使用-d参数
        buffer.write(' \\\n  -d \'${widget.log!.requestBody}\'');
      } else if (contentType.contains('application/x-www-form-urlencoded')) {
        // 表单数据，使用-d参数
        buffer.write(' \\\n  -d "${widget.log!.requestBody}"');
      } else {
        // 其他类型，使用--data-binary参数
        buffer.write(' \\\n  --data-binary "${widget.log!.requestBody}"');
      }
    }
    
    // 添加换行符
    buffer.write('\n');
    
    final curlCommand = buffer.toString();
    Clipboard.setData(ClipboardData(text: curlCommand));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('curl命令已复制到剪贴板'),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

 