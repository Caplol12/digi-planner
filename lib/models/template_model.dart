import 'dart:typed_data';
import 'package:flutter/material.dart';

class TemplateCategory {
  final String id;
  final String title;
  final IconData icon;

  const TemplateCategory({
    required this.id,
    required this.title,
    required this.icon,
  });

  static const List<TemplateCategory> defaultCategories = [
    TemplateCategory(id: 'all', title: 'همه قالب‌ها', icon: Icons.grid_view_rounded),
    TemplateCategory(id: 'daily', title: 'برنامه‌ریزی روزانه', icon: Icons.today_rounded),
    TemplateCategory(id: 'focus', title: 'پلنر تمرکز و ADHD', icon: Icons.bolt_rounded),
    TemplateCategory(id: 'diary', title: 'خاطرات و شکرگزاری', icon: Icons.favorite_rounded),
    TemplateCategory(id: 'bullet', title: 'بولت ژورنال و عادات', icon: Icons.format_list_bulleted_rounded),
  ];
}

class JournalTemplate {
  final String id;
  final String title;
  final String categoryId;
  final String subtitle;
  final Color themeColor;
  final Color cardBackground;
  final bool isPro;
  final IconData icon;
  final String? imageAsset;
  final Uint8List? imageBytes;
  final List<String> tags;
  final List<TemplateSection> sections;
  bool isFavorite;

  JournalTemplate({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.subtitle,
    required this.themeColor,
    required this.cardBackground,
    this.isPro = false,
    required this.icon,
    this.imageAsset,
    this.imageBytes,
    required this.tags,
    required this.sections,
    this.isFavorite = false,
  });

  static List<JournalTemplate> sampleTemplates = [
    JournalTemplate(
      id: 't1',
      title: 'Daily Planner (پلنر روزانه مینیمال)',
      categoryId: 'daily',
      subtitle: 'افکار صبحگاهی، زمان‌بندی ساعتی و لیست کارهای روز',
      themeColor: const Color(0xFF5B7A9C),
      cardBackground: const Color(0xFFF3F7FD),
      isPro: false,
      icon: Icons.calendar_view_day_rounded,
      imageAsset: 'assets/templates/daily_planner.jpg',
      tags: ['Daily Planner', 'Schedule', 'To-Do', 'Priorities', 'Morning Thoughts'],
      sections: [
        TemplateSection(title: 'افکار صبحگاهی', type: SectionType.text, items: ['نکات مهم صبحگاهی...']),
        TemplateSection(title: 'زمان‌بندی ساعتی', type: SectionType.timeline, items: ['5 AM تا 10 PM']),
        TemplateSection(title: 'کارهای کاری و شخصی', type: SectionType.checklist, items: ['Work To-Do', 'Personal To-Do']),
      ],
      isFavorite: true,
    ),
    JournalTemplate(
      id: 't2',
      title: 'ADHD Daily Planner (پلنر تمرکز و ذهن‌آگاهی)',
      categoryId: 'focus',
      subtitle: 'تمرکز روز، خودمراقبتی، تخلیه ذهن و اولویت‌بندی ۳ گانه',
      themeColor: const Color(0xFFFF8A65),
      cardBackground: const Color(0xFFFFF7F2),
      isPro: true,
      icon: Icons.psychology_rounded,
      imageAsset: 'assets/templates/adhd_planner.jpg',
      tags: ['ADHD Daily Planner', 'Focus', 'Brain Dump', 'Self Care', 'Priorities'],
      sections: [
        TemplateSection(title: 'تمرکز امروز (Today Focus)', type: SectionType.text, items: ['تسک اصلی']),
        TemplateSection(title: 'خودمراقبتی (آب، قدم‌زدن، مدیتیشن)', type: SectionType.badges, items: ['آب', 'ورزش', 'تنفس']),
        TemplateSection(title: 'تخلیه ذهن (Brain Dump)', type: SectionType.text, items: ['یادداشت آزاد']),
      ],
      isFavorite: false,
    ),
    JournalTemplate(
      id: 't3',
      title: 'Gratitude Diary (ژورنال شکرگزاری و خاطرات گلدار)',
      categoryId: 'diary',
      subtitle: 'طرح وینتیج گلدار، ۳ شکرگزاری روزانه، داستان روز و تاکید مثبت',
      themeColor: const Color(0xFF9C6B8D),
      cardBackground: const Color(0xFFFDF7FA),
      isPro: false,
      icon: Icons.favorite_border_rounded,
      imageAsset: 'assets/templates/gratitude_diary.jpg',
      tags: ['Gratitude', 'Diary', 'Vintage Floral', 'Reflections', 'Affirmation'],
      sections: [
        TemplateSection(title: '۳ دلیلی که شکرگزارم', type: SectionType.checklist, items: ['دلیل ۱', 'دلیل ۲', 'دلیل ۳']),
        TemplateSection(title: 'داستان و افکار روزانه', type: SectionType.text, items: ['خاطره امروز']),
      ],
      isFavorite: true,
    ),
    JournalTemplate(
      id: 't4',
      title: 'Weekly Focus & Habit Tracker (بولت ژورنال عادات)',
      categoryId: 'bullet',
      subtitle: 'جدول ردیابی ۳۱ روزه عادات، برنامه‌ریزی هفتگی و اهداف',
      themeColor: const Color(0xFF5A8E72),
      cardBackground: const Color(0xFFF2F8F4),
      isPro: true,
      icon: Icons.check_circle_outline_rounded,
      imageAsset: 'assets/templates/bullet_habit.jpg',
      tags: ['Bullet Journal', 'Habit Tracker', 'Weekly Focus', 'Goals'],
      sections: [
        TemplateSection(title: 'برنامه روزهای هفته', type: SectionType.checklist, items: ['Monday تا Sunday']),
        TemplateSection(title: 'ماتریس ردیابی عادات', type: SectionType.badges, items: ['ورزش', 'مطالعه', 'آب']),
      ],
      isFavorite: false,
    ),
  ];
}

enum SectionType { text, checklist, timeline, badges }

class TemplateSection {
  final String title;
  final SectionType type;
  final List<String> items;

  TemplateSection({
    required this.title,
    required this.type,
    required this.items,
  });
}


