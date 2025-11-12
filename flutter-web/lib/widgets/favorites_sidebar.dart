import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:html' as html;
import '../models/favorite_request.dart';
import '../services/favorites_service.dart';
import '../services/http_service.dart';
import 'replay_dialog.dart';

class FavoritesSidebar extends StatefulWidget {
  final VoidCallback? onFavoritesChanged;
  final Function(VoidCallback)? onRefreshCallback;

  const FavoritesSidebar({
    Key? key,
    this.onFavoritesChanged,
    this.onRefreshCallback,
  }) : super(key: key);

  @override
  _FavoritesSidebarState createState() => _FavoritesSidebarState();
}

class _FavoritesSidebarState extends State<FavoritesSidebar> {
  final FavoritesService _favoritesService = FavoritesService();
  final HttpService _httpService = HttpService();
  
  List<FavoriteRequest> _favorites = [];
  List<String> _tags = [];
  String? _selectedTag;
  bool _isLoading = false;
  bool _isCollapsed = true; // 默认折叠

  @override
  void initState() {
    super.initState();
    _loadData();
    // 向父组件注册刷新回调
    widget.onRefreshCallback?.call(refreshData);
  }

  void _loadData() {
    setState(() {
      _favorites = _favoritesService.getFavorites();
      _tags = _favoritesService.getAllTags();
    });
  }

  // 公开的刷新方法，供外部调用
  void refreshData() {
    _loadData();
  }

  List<FavoriteRequest> get _filteredFavorites {
    if (_selectedTag == null) {
      return _favorites;
    }
    return _favoritesService.getFavoritesByTag(_selectedTag!);
  }

  Map<String, List<FavoriteRequest>> get _groupedFavorites {
    final Map<String, List<FavoriteRequest>> grouped = {};
    
    for (final favorite in _filteredFavorites) {
      if (favorite.tags.isEmpty) {
        grouped.putIfAbsent('未分类', () => []).add(favorite);
      } else {
        for (final tag in favorite.tags) {
          if (_selectedTag == null || tag == _selectedTag) {
            grouped.putIfAbsent(tag, () => []).add(favorite);
          }
        }
      }
    }
    
    return grouped;
  }

  Future<void> _replayFavorite(FavoriteRequest favorite) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 准备请求头
      final headers = <String, String>{};
      favorite.headers.forEach((key, values) {
        if (values.isNotEmpty) {
          headers[key] = values.join(', ');
        }
      });

      // 执行重放请求
      final result = await _httpService.replayRequest(
        originalLogId: favorite.id,
        method: favorite.method,
        url: favorite.url,
        headers: headers,
        body: favorite.body,
      );

      // 更新最后使用时间
      await _favoritesService.updateLastUsed(favorite.id);
      _loadData();

      // 显示成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('重放成功! 日志ID: ${result['log_id'] ?? '未知'}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('重放失败: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editReplayFavorite(FavoriteRequest favorite) async {
    // 将收藏请求转换为HttpLog以便使用重放对话框
    final httpLog = favorite.toHttpLog();
    
    // 显示重放对话框
    showDialog(
      context: context,
      builder: (context) => ReplayDialog(
        originalLog: httpLog,
        allHttpLogs: [httpLog], // 只传入当前请求
      ),
    ).then((result) {
      if (result != null) {
        // 重放成功后更新最后使用时间
        _favoritesService.updateLastUsed(favorite.id);
        _loadData();
      }
    });
  }

  Future<void> _deleteFavorite(FavoriteRequest favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除收藏'),
        content: Text('确定要删除收藏 "${favorite.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _favoritesService.removeFavorite(favorite.id);
      if (success) {
        _loadData();
        widget.onFavoritesChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除收藏'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _exportFavorites() async {
    try {
      final exportData = _favoritesService.exportFavorites();
      final blob = html.Blob([exportData], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'http_debug_favorites_${DateTime.now().millisecondsSinceEpoch}.json')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('收藏列表已导出'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _importFavorites() async {
    final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.json';
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
      final files = uploadInput.files;
      if (files?.isEmpty ?? true) return;

      final file = files!.first;
      final reader = html.FileReader();
      
      reader.readAsText(file);
      reader.onLoadEnd.listen((e) async {
        try {
          final content = reader.result as String;
          final success = await _favoritesService.importFavorites(content, merge: true);
          
          if (success) {
            _loadData();
            widget.onFavoritesChanged?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('收藏列表导入成功'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('导入失败：文件格式不正确'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCollapsed) {
      return Container(
        width: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(right: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          children: [
            Container(
              height: 60,
              child: IconButton(
                icon: Icon(Icons.star_outline),
                onPressed: () => setState(() => _isCollapsed = false),
                tooltip: '展开收藏列表',
              ),
            ),
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    '收藏',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '收藏列表',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // 导入导出按钮
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 18),
                  onSelected: (value) {
                    switch (value) {
                      case 'import':
                        _importFavorites();
                        break;
                      case 'export':
                        _exportFavorites();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'import',
                      child: Row(
                        children: [
                          Icon(Icons.file_upload, size: 16),
                          SizedBox(width: 8),
                          Text('导入'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'export',
                      child: Row(
                        children: [
                          Icon(Icons.file_download, size: 16),
                          SizedBox(width: 8),
                          Text('导出'),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 18),
                  onPressed: () => setState(() => _isCollapsed = true),
                  tooltip: '折叠收藏列表',
                ),
              ],
            ),
          ),

          // 标签过滤
          if (_tags.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '标签过滤',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: Text('全部', style: TextStyle(fontSize: 11)),
                        selected: _selectedTag == null,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTag = selected ? null : _selectedTag;
                          });
                        },
                      ),
                      ..._tags.map((tag) {
                        return FilterChip(
                          label: Text(tag, style: TextStyle(fontSize: 11)),
                          selected: _selectedTag == tag,
                          onSelected: (selected) {
                            setState(() {
                              _selectedTag = selected ? tag : null;
                            });
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1),
          ],

          // 收藏列表
          Expanded(
            child: _favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.star_border,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无收藏',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '右键点击日志可添加收藏',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: _groupedFavorites.entries.map((entry) {
                      final tag = entry.key;
                      final favorites = entry.value;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 分组标题
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '(${favorites.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // 收藏项目
                          ...favorites.map((favorite) {
                            return _buildFavoriteItem(favorite);
                          }).toList(),
                          
                          SizedBox(height: 8),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(FavoriteRequest favorite) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 主要信息
          Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        favorite.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getMethodColor(favorite.method),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        favorite.method,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPathFromUrl(favorite.url),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (favorite.tags.isNotEmpty) ...[
                  SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: favorite.tags.map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          
          // 操作按钮
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Row(
              children: [
                // 快速重放按钮
                Expanded(
                  child: TextButton.icon(
                    onPressed: _isLoading ? null : () => _replayFavorite(favorite),
                    icon: _isLoading
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : Icon(Icons.replay, size: 14),
                    label: Text(
                      '重放',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size(0, 28),
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(width: 2),
                // 编辑重放按钮
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _editReplayFavorite(favorite),
                    icon: Icon(Icons.edit, size: 14),
                    label: Text(
                      '编辑',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size(0, 28),
                      foregroundColor: Colors.orange,
                    ),
                  ),
                ),
                SizedBox(width: 2),
                // 删除按钮
                TextButton.icon(
                  onPressed: () => _deleteFavorite(favorite),
                  icon: Icon(Icons.delete, size: 14),
                  label: Text(
                    '删除',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    minimumSize: Size(0, 28),
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isNotEmpty ? uri.path : url;
    } catch (e) {
      return url;
    }
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
