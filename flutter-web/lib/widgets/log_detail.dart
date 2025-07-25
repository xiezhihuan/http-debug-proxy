import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/http_log.dart';

class LogDetail extends StatelessWidget {
  final HttpLog? log;

  const LogDetail({Key? key, this.log}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (log == null) {
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
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: '复制详情',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfo(),
                  SizedBox(height: 24),
                  _buildRequestSection(),
                  SizedBox(height: 24),
                  _buildResponseSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfo() {
    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '基本信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoRow('方法', log!.method),
            _buildInfoRow('URL', log!.url),
            _buildInfoRow('状态码', '${log!.statusCode} (${log!.statusCodeText})'),
            _buildInfoRow('耗时', log!.formattedDuration),
            _buildInfoRow('时间', timeFormat.format(log!.timestamp)),
            _buildInfoRow('ID', log!.id),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '请求信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
            SizedBox(height: 12),
            if (log!.requestHeaders.isNotEmpty) ...[
              Text(
                '请求头',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _buildHeadersTable(log!.requestHeaders),
              SizedBox(height: 16),
            ],
            if (log!.requestBody.isNotEmpty) ...[
              Text(
                '请求体',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _buildCodeBlock(log!.requestBody),
            ] else ...[
              Text(
                '无请求体',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResponseSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '响应信息',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            SizedBox(height: 12),
            if (log!.responseHeaders.isNotEmpty) ...[
              Text(
                '响应头',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _buildHeadersTable(log!.responseHeaders),
              SizedBox(height: 16),
            ],
            if (log!.responseBody.isNotEmpty) ...[
              Text(
                '响应体',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              _buildCodeBlock(log!.responseBody),
            ] else ...[
              Text(
                '无响应体',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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
            child: SelectableText(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersTable(Map<String, List<String>> headers) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: headers.entries.map((entry) {
          return Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
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
                      fontWeight: FontWeight.w500,
                      fontFamily: 'monospace',
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

  Widget _buildCodeBlock(String content) {
    // 尝试格式化JSON
    bool isJson = false;
    dynamic jsonData;
    
    try {
      if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
        // 尝试解析JSON
        jsonData = json.decode(content);
        isJson = true;
      }
    } catch (e) {
      // 如果不是有效的JSON，保持原样
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isJson ? Colors.blue.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: isJson ? Colors.blue.shade300 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isJson) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'JSON (可折叠/展开)',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            SizedBox(height: 8),
            _buildJsonViewer(jsonData),
          ] else ...[
            SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildJsonViewer(dynamic data) {
    return _JsonViewerWidget(data: data);
  }

  String _formatJsonForClipboard(String content) {
    try {
      if (content.trim().startsWith('{') || content.trim().startsWith('[')) {
        final jsonData = json.decode(content);
        return JsonEncoder.withIndent('  ').convert(jsonData);
      }
    } catch (e) {
      // 如果不是有效的JSON，保持原样
    }
    return content;
  }

  void _copyToClipboard(BuildContext context) {
    if (log == null) return;

    final timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
    final buffer = StringBuffer();
    
    buffer.writeln('HTTP请求详情');
    buffer.writeln('============');
    buffer.writeln('方法: ${log!.method}');
    buffer.writeln('URL: ${log!.url}');
    buffer.writeln('状态码: ${log!.statusCode}');
    buffer.writeln('耗时: ${log!.formattedDuration}');
    buffer.writeln('时间: ${timeFormat.format(log!.timestamp)}');
    buffer.writeln('ID: ${log!.id}');
    buffer.writeln();
    
    buffer.writeln('请求头:');
    log!.requestHeaders.forEach((key, values) {
      buffer.writeln('  $key: ${values.join(', ')}');
    });
    buffer.writeln();
    
    buffer.writeln('请求体:');
    buffer.writeln(log!.requestBody.isEmpty ? '(无)' : _formatJsonForClipboard(log!.requestBody));
    buffer.writeln();
    
    buffer.writeln('响应头:');
    log!.responseHeaders.forEach((key, values) {
      buffer.writeln('  $key: ${values.join(', ')}');
    });
    buffer.writeln();
    
    buffer.writeln('响应体:');
    buffer.writeln(log!.responseBody.isEmpty ? '(无)' : _formatJsonForClipboard(log!.responseBody));

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('详情已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// JSON查看器组件
class _JsonViewerWidget extends StatefulWidget {
  final dynamic data;

  const _JsonViewerWidget({required this.data});

  @override
  _JsonViewerWidgetState createState() => _JsonViewerWidgetState();
}

class _JsonViewerWidgetState extends State<_JsonViewerWidget> {
  @override
  Widget build(BuildContext context) {
    return _buildJsonNode(widget.data, 0);
  }

  Widget _buildJsonNode(dynamic data, int level) {
    if (data == null) {
      return SelectableText(
        'null',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      );
    }

    if (data is bool) {
      return SelectableText(
        data.toString(),
        style: TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
    }

    if (data is num) {
      return SelectableText(
        data.toString(),
        style: TextStyle(
          color: Colors.orange.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      );
    }

    if (data is String) {
      // 处理长字符串的换行显示
      String displayText = data;
      if (data.length > 100) {
        displayText = data.substring(0, 100) + '...';
      }
      
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              '"$displayText"',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: data));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制: ${data.length > 50 ? data.substring(0, 50) + '...' : data}'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Icon(
              Icons.copy,
              size: 14,
              color: Colors.blue.shade600,
            ),
          ),
        ],
      );
    }

    if (data is List) {
      if (data.isEmpty) {
        return Row(
          children: [
            SelectableText('[]'),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '[]'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制空数组'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                Icons.copy,
                size: 14,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        );
      }

      return _JsonCollapsibleWidget(
        title: 'Array (${data.length} items)',
        children: data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: SelectableText(
                    '[$index]',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: _buildJsonNode(item, level + 1)),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final jsonString = JsonEncoder.withIndent('  ').convert(item);
                    Clipboard.setData(ClipboardData(text: jsonString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已复制数组项 [$index]'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    size: 12,
                    color: Colors.purple.shade600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        level: level,
        onCopy: () {
          final jsonString = JsonEncoder.withIndent('  ').convert(data);
          Clipboard.setData(ClipboardData(text: jsonString));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已复制整个数组'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }

    if (data is Map) {
      if (data.isEmpty) {
        return Row(
          children: [
            SelectableText('{}'),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: '{}'));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已复制空对象'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Icon(
                Icons.copy,
                size: 14,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        );
      }

      final children = data.entries.map((entry) {
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: [
                        SelectableText(
                          entry.key,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: entry.key));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('已复制键名: ${entry.key}'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy,
                            size: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  GestureDetector(
                    onTap: () {
                      final jsonString = JsonEncoder.withIndent('  ').convert(entry.value);
                      Clipboard.setData(ClipboardData(text: jsonString));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('已复制键值对: ${entry.key}'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 16),
                child: _buildJsonNode(entry.value, level + 1),
              ),
            ],
          ),
        );
      }).toList();

      return _JsonCollapsibleWidget(
        title: 'Object (${data.length} properties)',
        children: children,
        level: level,
        onCopy: () {
          final jsonString = JsonEncoder.withIndent('  ').convert(data);
          Clipboard.setData(ClipboardData(text: jsonString));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已复制整个对象'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      );
    }

    return Text(data.toString());
  }
}

// JSON可折叠组件
class _JsonCollapsibleWidget extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final int level;
  final VoidCallback? onCopy;

  const _JsonCollapsibleWidget({
    required this.title,
    required this.children,
    required this.level,
    this.onCopy,
  });

  @override
  _JsonCollapsibleWidgetState createState() => _JsonCollapsibleWidgetState();
}

class _JsonCollapsibleWidgetState extends State<_JsonCollapsibleWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 18,
                      color: Colors.blue.shade700,
                    ),
                    SizedBox(width: 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onCopy != null) ...[
                Spacer(),
                GestureDetector(
                  onTap: widget.onCopy,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Icon(
                      Icons.copy,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_isExpanded) ...[
          SizedBox(height: 4),
          ...widget.children,
        ],
      ],
    );
  }
} 