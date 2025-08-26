import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import '../models/favorite_request.dart';
import '../models/http_log.dart';

class FavoritesService {
  static const String _storageKey = 'http_debug_proxy_favorites';
  static const String _tagsKey = 'http_debug_proxy_favorite_tags';

  // 获取所有收藏
  List<FavoriteRequest> getFavorites() {
    try {
      final String? favoritesJson = html.window.localStorage[_storageKey];
      if (favoritesJson == null || favoritesJson.isEmpty) {
        return [];
      }

      final List<dynamic> favoritesList = jsonDecode(favoritesJson);
      return favoritesList
          .map((json) => FavoriteRequest.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('获取收藏列表失败: $e');
      return [];
    }
  }

  // 保存收藏列表
  Future<bool> saveFavorites(List<FavoriteRequest> favorites) async {
    try {
      final String favoritesJson = jsonEncode(
        favorites.map((favorite) => favorite.toJson()).toList(),
      );
      html.window.localStorage[_storageKey] = favoritesJson;
      return true;
    } catch (e) {
      debugPrint('保存收藏列表失败: $e');
      return false;
    }
  }

  // 添加收藏
  Future<bool> addFavorite(FavoriteRequest favorite) async {
    final favorites = getFavorites();
    
    // 检查是否已存在
    if (favorites.any((f) => f.id == favorite.id)) {
      return false; // 已存在
    }

    favorites.add(favorite);
    return await saveFavorites(favorites);
  }

  // 删除收藏
  Future<bool> removeFavorite(String id) async {
    final favorites = getFavorites();
    favorites.removeWhere((favorite) => favorite.id == id);
    return await saveFavorites(favorites);
  }

  // 更新收藏
  Future<bool> updateFavorite(FavoriteRequest updatedFavorite) async {
    final favorites = getFavorites();
    final index = favorites.indexWhere((f) => f.id == updatedFavorite.id);
    
    if (index == -1) {
      return false; // 不存在
    }

    favorites[index] = updatedFavorite;
    return await saveFavorites(favorites);
  }

  // 更新最后使用时间
  Future<bool> updateLastUsed(String id) async {
    final favorites = getFavorites();
    final index = favorites.indexWhere((f) => f.id == id);
    
    if (index == -1) {
      return false;
    }

    favorites[index] = favorites[index].copyWithLastUsed();
    return await saveFavorites(favorites);
  }

  // 检查是否已收藏
  bool isFavorited(String id) {
    final favorites = getFavorites();
    return favorites.any((favorite) => favorite.id == id);
  }

  // 从HttpLog创建收藏请求
  String generateId(HttpLog log) {
    // 使用URL + 方法 + 时间戳生成唯一ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${log.method}_${log.url.hashCode}_$timestamp';
  }

  // 获取所有标签
  List<String> getAllTags() {
    try {
      final String? tagsJson = html.window.localStorage[_tagsKey];
      if (tagsJson == null || tagsJson.isEmpty) {
        return [];
      }

      final List<dynamic> tagsList = jsonDecode(tagsJson);
      return List<String>.from(tagsList);
    } catch (e) {
      debugPrint('获取标签列表失败: $e');
      return [];
    }
  }

  // 保存标签列表
  Future<bool> saveTags(List<String> tags) async {
    try {
      final String tagsJson = jsonEncode(tags);
      html.window.localStorage[_tagsKey] = tagsJson;
      return true;
    } catch (e) {
      debugPrint('保存标签列表失败: $e');
      return false;
    }
  }

  // 添加新标签
  Future<bool> addTag(String tag) async {
    final tags = getAllTags();
    if (!tags.contains(tag)) {
      tags.add(tag);
      return await saveTags(tags);
    }
    return true;
  }

  // 根据标签获取收藏
  List<FavoriteRequest> getFavoritesByTag(String tag) {
    final favorites = getFavorites();
    return favorites.where((favorite) => favorite.tags.contains(tag)).toList();
  }

  // 导出收藏列表
  String exportFavorites() {
    final favorites = getFavorites();
    final tags = getAllTags();
    
    final exportData = {
      'version': '1.0',
      'exportDate': DateTime.now().toIso8601String(),
      'favorites': favorites.map((f) => f.toJson()).toList(),
      'tags': tags,
    };

    return jsonEncode(exportData);
  }

  // 导入收藏列表
  Future<bool> importFavorites(String jsonData, {bool merge = true}) async {
    try {
      final Map<String, dynamic> importData = jsonDecode(jsonData);
      
      // 验证数据格式
      if (!importData.containsKey('favorites')) {
        return false;
      }

      final List<dynamic> importedFavoritesList = importData['favorites'];
      final List<FavoriteRequest> importedFavorites = importedFavoritesList
          .map((json) => FavoriteRequest.fromJson(json))
          .toList();

      List<FavoriteRequest> currentFavorites = [];
      if (merge) {
        currentFavorites = getFavorites();
      }

      // 合并收藏（避免重复）
      for (final imported in importedFavorites) {
        if (!currentFavorites.any((f) => f.id == imported.id)) {
          currentFavorites.add(imported);
        }
      }

      // 导入标签
      if (importData.containsKey('tags')) {
        final List<String> importedTags = List<String>.from(importData['tags']);
        final currentTags = getAllTags();
        
        for (final tag in importedTags) {
          if (!currentTags.contains(tag)) {
            currentTags.add(tag);
          }
        }
        
        await saveTags(currentTags);
      }

      return await saveFavorites(currentFavorites);
    } catch (e) {
      debugPrint('导入收藏列表失败: $e');
      return false;
    }
  }

  // 清空所有收藏
  Future<bool> clearAllFavorites() async {
    html.window.localStorage.remove(_storageKey);
    html.window.localStorage.remove(_tagsKey);
    return true;
  }
}
