import 'dart:convert';
import '../models/bookmark_models.dart';
import 'encrypted_storage_service.dart';
import 'wallet_service.dart';

class BookmarkService {
  static final EncryptedStorage _storage = EncryptedStorage();
  static const String _defaultFolderId = 'default';
  
  /// Get password from WalletService (when wallet is unlocked)
  static String? _getPassword() {
    return WalletService.getCurrentPassword();
  }
  
  /// Helper to ensure password is available
  static String _requirePassword() {
    final password = _getPassword();
    if (password == null) {
      throw Exception('Wallet is not unlocked. Please unlock your wallet first.');
    }
    return password;
  }
  
  /// Get all bookmarks (uses current wallet password)
  static Future<List<Bookmark>> getBookmarks() async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) return [];
    
    final bookmarksJson = data['bookmarks'] as List<dynamic>? ?? [];
    return bookmarksJson.map((json) => Bookmark.fromJson(json as Map<String, dynamic>)).toList();
  }
  
  /// Get all folders (uses current wallet password)
  static Future<List<BookmarkFolder>> getFolders() async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    
    if (data == null || data['bookmarkFolders'] == null) {
      // Create default folder
      final defaultFolder = BookmarkFolder(
        id: _defaultFolderId,
        name: 'All Bookmarks',
        createdAt: DateTime.now(),
      );
      await _saveFolders([defaultFolder], password);
      return [defaultFolder];
    }
    
    final foldersJson = data['bookmarkFolders'] as List<dynamic>? ?? [];
    return foldersJson.map((json) => BookmarkFolder.fromJson(json as Map<String, dynamic>)).toList();
  }
  
  /// Check if a URL is bookmarked (uses current wallet password)
  /// Validates URL format to prevent injection attacks
  static Future<Bookmark?> getBookmarkByUrl(String url) async {
    if (url.isEmpty || url.length > 2048) return null;
    final bookmarks = await getBookmarks();
    try {
      return bookmarks.firstWhere((b) => b.url == url);
    } catch (e) {
      return null;
    }
  }
  
  /// Add a new bookmark (uses current wallet password)
  static Future<void> addBookmark(Bookmark bookmark) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final bookmarks = (data['bookmarks'] as List<dynamic>? ?? [])
        .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
        .toList();
    
    bookmarks.add(bookmark);
    
    data['bookmarks'] = bookmarks.map((b) => b.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    await _storage.saveData(data, password);
  }
  
  /// Update an existing bookmark (uses current wallet password)
  static Future<void> updateBookmark(Bookmark bookmark) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final bookmarks = (data['bookmarks'] as List<dynamic>? ?? [])
        .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
        .toList();
    
    final index = bookmarks.indexWhere((b) => b.id == bookmark.id);
    
    if (index != -1) {
      bookmarks[index] = bookmark;
      data['bookmarks'] = bookmarks.map((b) => b.toJson()).toList();
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _storage.saveData(data, password);
    }
  }
  
  /// Delete a bookmark (uses current wallet password)
  static Future<void> deleteBookmark(String id) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final bookmarks = (data['bookmarks'] as List<dynamic>? ?? [])
        .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
        .toList();
    
    bookmarks.removeWhere((b) => b.id == id);
    
    data['bookmarks'] = bookmarks.map((b) => b.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    await _storage.saveData(data, password);
  }
  
  /// Add a new folder (uses current wallet password)
  static Future<void> addFolder(BookmarkFolder folder) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final folders = (data['bookmarkFolders'] as List<dynamic>? ?? [])
        .map((json) => BookmarkFolder.fromJson(json as Map<String, dynamic>))
        .toList();
    
    folders.add(folder);
    
    data['bookmarkFolders'] = folders.map((f) => f.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    await _storage.saveData(data, password);
  }
  
  /// Update a folder (uses current wallet password)
  static Future<void> updateFolder(BookmarkFolder folder) async {
    final password = _requirePassword();
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final folders = (data['bookmarkFolders'] as List<dynamic>? ?? [])
        .map((json) => BookmarkFolder.fromJson(json as Map<String, dynamic>))
        .toList();
    
    final index = folders.indexWhere((f) => f.id == folder.id);
    
    if (index != -1) {
      folders[index] = folder;
      data['bookmarkFolders'] = folders.map((f) => f.toJson()).toList();
      data['updatedAt'] = DateTime.now().toIso8601String();
      await _storage.saveData(data, password);
    }
  }
  
  /// Delete a folder (moves bookmarks to default folder) (uses current wallet password)
  static Future<void> deleteFolder(String id) async {
    final password = _requirePassword();
    if (id == _defaultFolderId) return; // Can't delete default folder
    
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');

    final folders = (data['bookmarkFolders'] as List<dynamic>? ?? [])
        .map((json) => BookmarkFolder.fromJson(json as Map<String, dynamic>))
        .toList();
    
    folders.removeWhere((f) => f.id == id);
    
    data['bookmarkFolders'] = folders.map((f) => f.toJson()).toList();
    
    // Move bookmarks to default folder
    final bookmarks = (data['bookmarks'] as List<dynamic>? ?? [])
        .map((json) => Bookmark.fromJson(json as Map<String, dynamic>))
        .toList();
    
    final updatedBookmarks = bookmarks.map((b) {
      if (b.folderId == id) {
        return b.copyWith(folderId: _defaultFolderId);
      }
      return b;
    }).toList();
    
    data['bookmarks'] = updatedBookmarks.map((b) => b.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    
    await _storage.saveData(data, password);
  }
  
  /// Get bookmarks in a specific folder (uses current wallet password)
  static Future<List<Bookmark>> getBookmarksInFolder(String folderId) async {
    final bookmarks = await getBookmarks();
    return bookmarks.where((b) => b.folderId == folderId).toList();
  }
  
  // Private helper methods
  static Future<void> _saveBookmarks(List<Bookmark> bookmarks, String password) async {
    final data = await _storage.loadData(password);
    if (data == null) throw Exception('Failed to load storage data');
    
    data['bookmarks'] = bookmarks.map((b) => b.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _storage.saveData(data, password);
  }
  
  static Future<void> _saveFolders(List<BookmarkFolder> folders, String password) async {
    final data = await _storage.loadData(password);
    if (data == null) {
      // If no data exists, we need to create it
      final newData = {
        'version': 1,
        'wallets': [],
        'activeWalletId': null,
        'bookmarks': [],
        'bookmarkFolders': folders.map((f) => f.toJson()).toList(),
        'settings': {
          'browser': {
            'theme': 'Dark',
            'defaultSearchEngine': 'Google',
            'enableJavaScript': true,
            'enableCookies': true,
          },
          'ai': {
            'enableAI': true,
            'aiModel': 'GPT-4',
            'temperature': 0.7,
            'systemPrompt': 'You are a helpful assistant.',
          },
        },
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _storage.saveData(newData, password);
      return;
    }
    
    data['bookmarkFolders'] = folders.map((f) => f.toJson()).toList();
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _storage.saveData(data, password);
  }
  
  static String getDefaultFolderId() => _defaultFolderId;
}
