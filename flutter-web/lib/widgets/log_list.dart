import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/http_log.dart';

class LogList extends StatelessWidget {
  final List<HttpLog> logs;
  final Function(HttpLog) onLogSelected;

  const LogList({
    Key? key,
    required this.logs,
    required this.onLogSelected,
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
                Text(
                  'HTTP请求日志 (${logs.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

  const LogTile({
    Key? key,
    required this.log,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss.SSS');
    
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: _buildStatusIndicator(),
        title: Row(
          children: [
            _buildMethodChip(),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                log.url,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
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
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(width: 16),
            Text(
              log.formattedDuration,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: _buildStatusChip(),
        dense: true,
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
} 