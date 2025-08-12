import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/http_log.dart';

class LogList extends StatelessWidget {
  final List<HttpLog> logs;
  final Function(HttpLog) onLogSelected;
  final bool isListening;
  final VoidCallback onToggleListening;
  final HttpLog? selectedLog; // 添加选中日志参数

  const LogList({
    Key? key,
    required this.logs,
    required this.onLogSelected,
    required this.isListening,
    required this.onToggleListening,
    required this.selectedLog, // 添加选中日志参数
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Icon(Icons.list, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HTTP请求日志 (${logs.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 监听控制按钮
                Container(
                  decoration: BoxDecoration(
                    color: isListening ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isListening ? Colors.green.shade300 : Colors.red.shade300,
                      width: 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onToggleListening,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isListening ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 16,
                              color: isListening ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            SizedBox(width: 6),
                            Text(
                              isListening ? '监听中' : '已停止',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isListening ? Colors.green.shade700 : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          '暂无HTTP请求记录',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '等待Android应用发送请求...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[logs.length - 1 - index]; // 最新的在上面
                      return LogTile(
                        log: log,
                        onTap: () => onLogSelected(log),
                        isSelected: selectedLog?.id == log.id, // 通过ID比较判断是否选中
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class LogTile extends StatelessWidget {
  final HttpLog log;
  final VoidCallback onTap;
  final bool isSelected;

  const LogTile({
    Key? key,
    required this.log,
    required this.onTap,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss.SSS');
    
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(
            color: isSelected ? Colors.blue.shade400 : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIndicator(),
            if (isSelected) ...[
              SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: Colors.blue.shade600,
                size: 16,
              ),
            ],
          ],
        ),
        title: Row(
          children: [
            _buildMethodChip(),
            SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: log.url,
                waitDuration: Duration(milliseconds: 500),
                child: Text(
                  log.url,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: isSelected ? Colors.blue.shade800 : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  // 根据HTTP方法决定是否省略URL
                  overflow: _shouldEllipsisUrl(log.method) 
                      ? TextOverflow.ellipsis 
                      : null,
                  // 对于非GET请求，允许换行显示完整URL
                  softWrap: !_shouldEllipsisUrl(log.method),
                  maxLines: _shouldEllipsisUrl(log.method) ? 1 : null,
                ),
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(
              timeFormat.format(log.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              ),
            ),
            SizedBox(width: 16),
            Text(
              log.formattedDuration,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: _buildStatusChip(),
        dense: true,
        selected: isSelected,
        selectedTileColor: Colors.transparent, // 使用自定义背景色
      ),
    );
  }

  Widget _buildMethodChip() {
    Color color;
    switch (log.method.toUpperCase()) {
      case 'GET':
        color = Colors.green;
        break;
      case 'POST':
        color = Colors.blue;
        break;
      case 'PUT':
        color = Colors.orange;
        break;
      case 'DELETE':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        log.method.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color color;
    if (log.statusCode >= 200 && log.statusCode < 300) {
      color = Colors.green;
    } else if (log.statusCode >= 300 && log.statusCode < 400) {
      color = Colors.blue;
    } else if (log.statusCode >= 400 && log.statusCode < 500) {
      color = Colors.orange;
    } else if (log.statusCode >= 500) {
      color = Colors.red;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        log.statusCode.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    Color color;
    if (log.statusCode >= 200 && log.statusCode < 300) {
      color = Colors.green;
    } else if (log.statusCode >= 400) {
      color = Colors.red;
    } else {
      color = Colors.orange;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  bool _shouldEllipsisUrl(String method) {
    // GET请求省略显示（节省空间），其他请求完整显示
    return method.toUpperCase() == 'GET';
  }
} 