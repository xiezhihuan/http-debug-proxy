import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilterBar extends StatefulWidget {
  final Function(String? url, String? method, int? statusCode) onFilterChanged;
  final VoidCallback onClearLogs;
  final bool isConnected;

  const FilterBar({
    Key? key,
    required this.onFilterChanged,
    required this.onClearLogs,
    required this.isConnected,
  }) : super(key: key);

  @override
  _FilterBarState createState() => _FilterBarState();
}

class _FilterBarState extends State<FilterBar> {
  final TextEditingController _urlController = TextEditingController();
  String? _selectedMethod;
  String? _selectedStatusCode;
  bool _rememberClearChoice = false; // 是否记住清除选择

  final List<String> _methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'];
  final List<String> _statusCodes = ['200', '201', '204', '400', '401', '403', '404', '500', '502', '503'];

  @override
  void initState() {
    super.initState();
    _loadRememberChoice();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '过滤和搜索',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              _buildConnectionStatus(),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildUrlFilter(),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMethodFilter(),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatusCodeFilter(),
              ),
              SizedBox(width: 16),
              _buildClearButton(),
              SizedBox(width: 8),
              _buildClearLogsButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.isConnected ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isConnected ? Icons.wifi : Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            widget.isConnected ? '已连接' : '未连接',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlFilter() {
    return TextField(
      controller: _urlController,
      decoration: InputDecoration(
        labelText: 'URL过滤',
        hintText: '输入URL关键词...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onChanged: (value) => _applyFilter(),
    );
  }

  Widget _buildMethodFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedMethod,
      decoration: InputDecoration(
        labelText: 'HTTP方法',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('全部'),
        ),
        ..._methods.map((method) => DropdownMenuItem<String>(
          value: method,
          child: Text(method),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedMethod = value;
        });
        _applyFilter();
      },
    );
  }

  Widget _buildStatusCodeFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedStatusCode,
      decoration: InputDecoration(
        labelText: '状态码',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('全部'),
        ),
        ..._statusCodes.map((code) => DropdownMenuItem<String>(
          value: code,
          child: Text(code),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedStatusCode = value;
        });
        _applyFilter();
      },
    );
  }

  Widget _buildClearButton() {
    return ElevatedButton.icon(
      onPressed: _clearFilters,
      icon: Icon(Icons.clear),
      label: Text('清除过滤'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildClearLogsButton() {
    return ElevatedButton.icon(
      onPressed: _handleClearLogs, // 使用新的处理方法
      icon: Icon(Icons.delete_sweep),
      label: Text('清除日志'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade100,
        foregroundColor: Colors.red.shade700,
      ),
    );
  }

  void _applyFilter() {
    final url = _urlController.text.trim().isEmpty ? null : _urlController.text.trim();
    final statusCode = _selectedStatusCode != null ? int.tryParse(_selectedStatusCode!) : null;
    
    widget.onFilterChanged(url, _selectedMethod, statusCode);
  }

  void _clearFilters() {
    setState(() {
      _urlController.clear();
      _selectedMethod = null;
      _selectedStatusCode = null;
    });
    _applyFilter();
  }

  // 加载记住选择状态
  Future<void> _loadRememberChoice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _rememberClearChoice = prefs.getBool('remember_clear_choice') ?? false;
      });
    } catch (e) {
      print('加载记住选择状态失败: $e');
    }
  }

  // 保存记住选择状态
  Future<void> _saveRememberChoice(bool remember) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_clear_choice', remember);
      setState(() {
        _rememberClearChoice = remember;
      });
    } catch (e) {
      print('保存记住选择状态失败: $e');
    }
  }

  // 处理清除日志
  void _handleClearLogs() {
    if (_rememberClearChoice) {
      // 如果已记住选择，直接清除
      widget.onClearLogs();
    } else {
      // 否则显示确认对话框
      _showClearLogsDialog();
    }
  }

  void _showClearLogsDialog() {
    bool rememberChoice = false; // 临时记住选择状态
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('确认清除'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('确定要清除所有HTTP日志吗？此操作不可撤销。'),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: rememberChoice,
                        onChanged: (value) {
                          setDialogState(() {
                            rememberChoice = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          '下次不再提示',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
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
                    Navigator.of(context).pop();
                    if (rememberChoice) {
                      _saveRememberChoice(true); // 保存记住选择
                    }
                    widget.onClearLogs(); // 执行清除
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('确认'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
} 