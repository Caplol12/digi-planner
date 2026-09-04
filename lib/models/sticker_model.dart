import 'package:flutter/material.dart';

class StickerItem {
  final String id;
  final String content; // Emoji, icon character or label
  final String? imagePath; // Optional path for gallery photos
  final bool isEmoji;
  Offset position;
  double scale;
  double rotation; // in radians
  bool isSelected;

  StickerItem({
    required this.id,
    this.content = '⭐',
    this.imagePath,
    this.isEmoji = true,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.isSelected = true,
  });

  StickerItem copyWith({
    String? id,
    String? content,
    String? imagePath,
    bool? isEmoji,
    Offset? position,
    double? scale,
    double? rotation,
    bool? isSelected,
  }) {
    return StickerItem(
      id: id ?? this.id,
      content: content ?? this.content,
      imagePath: imagePath ?? this.imagePath,
      isEmoji: isEmoji ?? this.isEmoji,
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'imagePath': imagePath,
        'isEmoji': isEmoji,
        'dx': position.dx,
        'dy': position.dy,
        'scale': scale,
        'rotation': rotation,
      };

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        id: json['id'] ?? 'stk_${DateTime.now().millisecondsSinceEpoch}',
        content: json['content'] ?? '⭐',
        imagePath: json['imagePath'] as String?,
        isEmoji: json['isEmoji'] ?? (json['imagePath'] == null),
        position: Offset(json['dx']?.toDouble() ?? 100.0, json['dy']?.toDouble() ?? 100.0),
        scale: json['scale']?.toDouble() ?? 1.0,
        rotation: json['rotation']?.toDouble() ?? 0.0,
      );
}

class StickerCategory {
  final String title;
  final List<String> stickers;

  const StickerCategory({required this.title, required this.stickers});

  static const List<StickerCategory> defaults = [
    StickerCategory(
      title: 'حال و هوا و احساسات',
      stickers: ['☕', '🌿', '✨', '☀️', '🌸', '🧘‍♀️', '💧', '🌙', '🎧', '🥑', '🕯️', '🎨'],
    ),
    StickerCategory(
      title: 'اهداف و اولویت‌ها',
      stickers: ['🎯', '⭐', '🔥', '📌', '💡', '🏆', '🚀', '✅', '⏳', '📈', '🔑', '💎'],
    ),
    StickerCategory(
      title: 'مطالعه و کار',
      stickers: ['📚', '💻', '📝', '📅', '💼', '📎', '✏️', '📖', '🗂️', '📊', '🔍', '📮'],
    ),
  ];
}
