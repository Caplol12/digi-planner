import 'package:flutter/material.dart';

class JournalItem {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final DateTime createdAt;
  final int pageCount;
  final List<Color> gradientColors;
  final IconData icon;
  final String content;
  final List<String> tags;
  bool isFavorite;

  JournalItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.createdAt,
    required this.pageCount,
    required this.gradientColors,
    required this.icon,
    this.content = '',
    this.tags = const [],
    this.isFavorite = false,
  });

  // Sample seed data matching PlanWiz style
  static List<JournalItem> sampleJournals = [
    JournalItem(
      id: 'j1',
      title: 'پلنر جامع بهره‌وری و اهداف ۱۴۰۵',
      subtitle: 'برنامه‌ریزی سالانه و مدیریت کارهای روزانه',
      category: 'برنامه‌ریزی',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      pageCount: 14,
      gradientColors: [const Color(0xFF1B2A4A), const Color(0xFF283E68)],
      icon: Icons.auto_stories_rounded,
      content: 'اهداف فصل بهار و مدیریت زمان پروژه‌ها...',
      tags: ['بهره‌وری', 'سالانه', 'کارهای روزانه'],
      isFavorite: true,
    ),
    JournalItem(
      id: 'j2',
      title: 'ژورنال ردیابی تمرکز و روزمرگی',
      subtitle: 'ثبت احساسات، عادات و خود‌مراقبتی',
      category: 'روزانه',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      pageCount: 8,
      gradientColors: [const Color(0xFFFF8A65), const Color(0xFFFFB74D)],
      icon: Icons.wb_sunny_rounded,
      content: 'امروز حس فوق‌العاده‌ای داشتم و ۳ کار مهم را انجام دادم.',
      tags: ['روزانه', 'تمرکز', 'سلامت'],
      isFavorite: false,
    ),
    JournalItem(
      id: 'j3',
      title: 'دفترچه ایده‌ها و یادداشت‌های استودیو',
      subtitle: 'طراحی اسکچ‌ها و افکار خلاقانه',
      category: 'خلاقیت',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      pageCount: 22,
      gradientColors: [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
      icon: Icons.lightbulb_rounded,
      content: 'ایده‌های مربوط به رابط کاربری ژورنال و تم‌های رنگی.',
      tags: ['طراحی', 'ایده', 'پروژه'],
      isFavorite: true,
    ),
  ];
}
