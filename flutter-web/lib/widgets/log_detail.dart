import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        content,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
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
    buffer.writeln(log!.requestBody.isEmpty ? '(无)' : log!.requestBody);
    buffer.writeln();
    
    buffer.writeln('响应头:');
    log!.responseHeaders.forEach((key, values) {
      buffer.writeln('  $key: ${values.join(', ')}');
    });
    buffer.writeln();
    
    buffer.writeln('响应体:');
    buffer.writeln(log!.responseBody.isEmpty ? '(无)' : log!.responseBody);

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('详情已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }
} 