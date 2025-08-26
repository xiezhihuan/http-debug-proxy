import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/http_log.dart';
import 'request_sequence_dialog.dart';
import '../services/http_service.dart';

class LogList extends StatefulWidget {
  final List<HttpLog> logs;
  final Function(HttpLog) onLogSelected;
  final bool isListening;
  final VoidCallback onToggleListening;
  final VoidCallback onClearLogs; // 添加清除日志回调
  final HttpLog? selectedLog; // 添加选中日志参数

  const LogList({
    Key? key,
    required this.logs,
    required this.onLogSelected,
    required this.isListening,
    required this.onToggleListening,
    required this.onClearLogs, // 添加清除日志回调
    required this.selectedLog, // 添加选中日志参数
  }) : super(key: key);

  @override
  _LogListState createState() => _LogListState();
}

class _LogListState extends State<LogList> {
  void _openRequestSequenceDialog() {
    showDialog(
      context: context,
      builder: (context) => RequestSequenceDialog(
        allHttpLogs: widget.logs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // 头部区域
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
                Icon(Icons.list, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HTTP请求日志 (${widget.logs.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 监听状态切换按钮
                Container(
                  decoration: BoxDecoration(
                    color: widget.isListening ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isListening ? Colors.green.shade300 : Colors.red.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: widget.onToggleListening,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isListening ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 16,
                            color: widget.isListening ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                          SizedBox(width: 6),
                          Text(
                            widget.isListening ? '监听中' : '已停止',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: widget.isListening ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // 请求编排按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.purple.shade300,
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _openRequestSequenceDialog,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.playlist_play,
                            size: 16,
                            color: Colors.purple.shade700,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '请求编排',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // 清除日志按钮
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
                    onTap: widget.onClearLogs,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear_all,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '清除日志',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 日志列表
          Expanded(
            child: widget.logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无HTTP请求日志',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '开始监听后将显示所有HTTP请求',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final log = widget.logs[widget.logs.length - 1 - index]; // 最新的在上面
                      return LogTile(
                        log: log,
                        allLogs: widget.logs,
                        onTap: () => widget.onLogSelected(log),
                        isSelected: widget.selectedLog?.id == log.id, // 通过ID比较判断是否选中
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
  final List<HttpLog> allLogs;
  final VoidCallback onTap;
  final bool isSelected;

  const LogTile({
    Key? key,
    required this.log,
    required this.allLogs,
    required this.onTap,
    required this.isSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      onSecondaryTap: () {
        // 阻止浏览器默认右键菜单
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMethodChip(log.method),
              SizedBox(width: 8),
              _buildStatusCodeChip(log.statusCode),
            ],
          ),
          title: Text(
            log.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${log.formattedDuration} • ${DateFormat('HH:mm:ss').format(log.timestamp)}',
                style: TextStyle(fontSize: 12),
              ),
              if (log.requestBody.isNotEmpty)
                Text(
                  '请求体: ${log.requestBody.length} 字符',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
            ],
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect relativeRect = RelativeRect.fromRect(
      Rect.fromPoints(position, position),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: relativeRect,
      items: [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.replay, color: Colors.blue),
            title: Text('重放请求'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // 延迟执行，避免菜单关闭动画冲突
            Future.delayed(Duration(milliseconds: 100), () {
              _directReplayRequest(context, log);
            });
          },
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.playlist_play, color: Colors.purple),
            title: Text('请求编排'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            // 延迟执行，避免菜单关闭动画冲突
            Future.delayed(Duration(milliseconds: 100), () {
              showDialog(
                context: context,
                builder: (context) => RequestSequenceDialog(
                  allHttpLogs: allLogs,
                  initialLog: log,
                ),
              );
            });
          },
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.copy, color: Colors.green),
            title: Text('复制URL'),
            contentPadding: EdgeInsets.zero,
          ),
          onTap: () {
            _copyRequestToClipboard(context);
          },
        ),
      ],
    );
  }

  void _copyRequestToClipboard(BuildContext context) {
    // 只复制URL
    final url = log.url;
    
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('URL已复制到剪贴板')),
    );
  }

  Widget _buildMethodChip(String method) {
    Color color;
    switch (method.toUpperCase()) {
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
        method.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusCodeChip(int statusCode) {
    Color color;
    if (statusCode >= 200 && statusCode < 300) {
      color = Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      color = Colors.blue;
    } else if (statusCode >= 400 && statusCode < 500) {
      color = Colors.orange;
    } else if (statusCode >= 500) {
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
        statusCode.toString(),
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 直接重放请求功能
  Future<void> _directReplayRequest(BuildContext context, HttpLog log) async {
    final httpService = HttpService();
    
    // 显示加载提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            Text('正在重放请求...'),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 30), // 较长时间，等待请求完成
      ),
    );

    try {
      // 使用原始请求的所有参数
      final headers = <String, String>{};
      log.requestHeaders.forEach((key, values) {
        if (values.isNotEmpty) {
          headers[key] = values.join(', ');
        }
      });

      final result = await httpService.replayRequest(
        originalLogId: log.id,
        method: log.method,
        url: log.url,
        headers: headers,
        body: log.requestBody,
      );

      // 隐藏加载提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('重放请求成功! 日志ID: ${result['log_id'] ?? '未知'}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      
    } catch (e) {
      // 隐藏加载提示
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // 显示失败提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('重放请求失败: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

} 