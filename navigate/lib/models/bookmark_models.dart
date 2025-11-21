import 'dart:convert';

/// Represents a bookmark folder
class BookmarkFolder {
  final String id;
  final String name;
  final DateTime createdAt;
  
  BookmarkFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory BookmarkFolder.fromJson(Map<String, dynamic> json) {
    return BookmarkFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Represents a bookmark
class Bookmark {
  final String id;
  final String name;
  final String url;
  final String folderId;
  final DateTime createdAt;
  
  Bookmark({
    required this.id,
    required this.name,
    required this.url,
    required this.folderId,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'folderId': folderId,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      folderId: json['folderId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  
  Bookmark copyWith({
    String? id,
    String? name,
    String? url,
    String? folderId,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      folderId: folderId ?? this.folderId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
