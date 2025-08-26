import 'package:flutter/material.dart';
import '../models/http_log.dart';
import '../models/favorite_request.dart';
import '../services/favorites_service.dart';

class AddFavoriteDialog extends StatefulWidget {
  final HttpLog httpLog;

  const AddFavoriteDialog({
    Key? key,
    required this.httpLog,
  }) : super(key: key);

  @override
  _AddFavoriteDialogState createState() => _AddFavoriteDialogState();
}

class _AddFavoriteDialogState extends State<AddFavoriteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _tagController;
  final FavoritesService _favoritesService = FavoritesService();
  
  List<String> _selectedTags = [];
  List<String> _availableTags = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // 生成默认名称
    final defaultName = '${widget.httpLog.method} ${_getPathFromUrl(widget.httpLog.url)}';
    _nameController = TextEditingController(text: defaultName);
    _tagController = TextEditingController();
    
    // 加载可用标签
    _loadAvailableTags();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _loadAvailableTags() {
    setState(() {
      _availableTags = _favoritesService.getAllTags();
    });
  }

  String _getPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isNotEmpty ? uri.path : url;
    } catch (e) {
      return url;
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        if (!_availableTags.contains(tag)) {
          _availableTags.add(tag);
        }
      });
      _tagController.clear();
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  Future<void> _saveFavorite() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请输入收藏名称'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 生成唯一ID
      final id = _favoritesService.generateId(widget.httpLog);

      // 创建收藏请求
      final favoriteRequest = FavoriteRequest.fromHttpLog(
        id: id,
        name: _nameController.text.trim(),
        url: widget.httpLog.url,
        method: widget.httpLog.method,
        headers: widget.httpLog.requestHeaders,
        body: widget.httpLog.requestBody,
        tags: _selectedTags,
      );

      // 保存收藏
      final success = await _favoritesService.addFavorite(favoriteRequest);

      if (success) {
        // 保存新标签
        for (final tag in _selectedTags) {
          await _favoritesService.addTag(tag);
        }

        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.star, color: Colors.white),
                SizedBox(width: 8),
                Text('已添加到收藏'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('该请求已在收藏列表中'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('添加收藏失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '添加到收藏',
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
            ),

            SizedBox(height: 24),

            // 请求信息预览
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '请求信息',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getMethodColor(widget.httpLog.method),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.httpLog.method,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.httpLog.url,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 收藏名称
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '收藏名称 *',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: '输入收藏名称',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // 标签
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '标签分类',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                
                // 添加标签输入框
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          hintText: '添加标签',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: _addTag,
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addTag(_tagController.text.trim()),
                      child: Text('添加'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // 已选标签
                if (_selectedTags.isNotEmpty) ...[
                  Text(
                    '已选标签:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedTags.map((tag) {
                      return Chip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        deleteIcon: Icon(Icons.close, size: 16),
                        onDeleted: () => _removeTag(tag),
                        backgroundColor: Colors.blue.shade50,
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 8),
                ],

                // 可用标签
                if (_availableTags.isNotEmpty) ...[
                  Text(
                    '可用标签:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _availableTags
                        .where((tag) => !_selectedTags.contains(tag))
                        .map((tag) {
                      return ActionChip(
                        label: Text(tag, style: TextStyle(fontSize: 12)),
                        onPressed: () => _addTag(tag),
                        backgroundColor: Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),

            SizedBox(height: 32),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text('取消'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveFavorite,
                  child: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('添加收藏'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'PATCH':
        return Colors.purple;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
