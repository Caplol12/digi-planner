import 'package:flutter/material.dart';

enum PageOrientation { portrait, landscape }
enum PageSpread { single, spread }

enum PageType {
  blank,
  lined,
  wideLined,
  grid,
  dotGrid,
  cornell,
  todo,
  dailySchedule,
  weeklyPlanner,
  musicStaff,
}

class PageSizeOption {
  final String id;
  final String title;
  final String ratioLabel;
  final double widthRatio;
  final double heightRatio;
  final IconData icon;

  const PageSizeOption({
    required this.id,
    required this.title,
    required this.ratioLabel,
    required this.widthRatio,
    required this.heightRatio,
    this.icon = Icons.crop_portrait_rounded,
  });

  double get aspectRatio => widthRatio / heightRatio;

  static const List<PageSizeOption> defaultSizes = [
    PageSizeOption(
      id: 'square',
      title: 'Square',
      ratioLabel: '1:1',
      widthRatio: 1.0,
      heightRatio: 1.0,
      icon: Icons.crop_square_rounded,
    ),
    PageSizeOption(
      id: 'iphone',
      title: 'iPhone',
      ratioLabel: '9:16',
      widthRatio: 9.0,
      heightRatio: 16.0,
      icon: Icons.phone_iphone_rounded,
    ),
    PageSizeOption(
      id: 'letter',
      title: 'Letter',
      ratioLabel: '8.5x11',
      widthRatio: 8.5,
      heightRatio: 11.0,
      icon: Icons.description_outlined,
    ),
    PageSizeOption(
      id: 'a4',
      title: 'A4',
      ratioLabel: '8.3 x 11.7',
      widthRatio: 8.27,
      heightRatio: 11.69,
      icon: Icons.article_outlined,
    ),
    PageSizeOption(
      id: 'a5',
      title: 'A5',
      ratioLabel: '5.8 x 8.3',
      widthRatio: 5.83,
      heightRatio: 8.27,
      icon: Icons.menu_book_rounded,
    ),
    PageSizeOption(
      id: 'tablet',
      title: 'Tablet',
      ratioLabel: '3:4',
      widthRatio: 3.0,
      heightRatio: 4.0,
      icon: Icons.tablet_mac_rounded,
    ),
  ];
}

class PageTypeOption {
  final PageType type;
  final String title;
  final String subtitle;
  final IconData icon;

  const PageTypeOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  static const List<PageTypeOption> defaultTypes = [
    PageTypeOption(
      type: PageType.blank,
      title: 'Blank',
      subtitle: 'ساده و خالی بدون خط',
      icon: Icons.crop_square_rounded,
    ),
    PageTypeOption(
      type: PageType.lined,
      title: 'Lined',
      subtitle: 'خط‌دار استاندارد دفترچه',
      icon: Icons.format_align_justify_rounded,
    ),
    PageTypeOption(
      type: PageType.wideLined,
      title: 'Wide Lined',
      subtitle: 'خط‌دار با فاصله درشت',
      icon: Icons.view_headline_rounded,
    ),
    PageTypeOption(
      type: PageType.grid,
      title: 'Grid',
      subtitle: 'شطرنجی و نموداری',
      icon: Icons.grid_on_rounded,
    ),
    PageTypeOption(
      type: PageType.dotGrid,
      title: 'Dotted',
      subtitle: 'نقطه‌ای بولت ژورنال',
      icon: Icons.grain_rounded,
    ),
    PageTypeOption(
      type: PageType.cornell,
      title: 'Cornell',
      subtitle: 'یادداشت‌برداری کورنل',
      icon: Icons.view_sidebar_rounded,
    ),
    PageTypeOption(
      type: PageType.todo,
      title: 'To-Do List',
      subtitle: 'چک‌لیست و کارهای روزانه',
      icon: Icons.checklist_rounded,
    ),
    PageTypeOption(
      type: PageType.dailySchedule,
      title: 'Daily Plan',
      subtitle: 'زمان‌بندی ساعتی روز',
      icon: Icons.schedule_rounded,
    ),
    PageTypeOption(
      type: PageType.weeklyPlanner,
      title: 'Weekly',
      subtitle: 'ستون‌های روزهای هفته',
      icon: Icons.view_week_rounded,
    ),
    PageTypeOption(
      type: PageType.musicStaff,
      title: 'Music Staff',
      subtitle: '۵ خط حامل موسیقی',
      icon: Icons.music_note_rounded,
    ),
  ];
}

class PageStyleConfig {
  PageSizeOption sizeOption;
  PageOrientation orientation;
  PageSpread spread;
  Color backgroundColor;
  PageType pageType;
  String title;

  PageStyleConfig({
    PageSizeOption? sizeOption,
    this.orientation = PageOrientation.portrait,
    this.spread = PageSpread.single,
    this.backgroundColor = Colors.white,
    this.pageType = PageType.blank,
    this.title = 'برگه یادداشت جدید',
  }) : sizeOption = sizeOption ?? PageSizeOption.defaultSizes[1]; // default iPhone 9:16 matching screenshot

  double get effectiveAspectRatio {
    double base = sizeOption.aspectRatio;
    if (orientation == PageOrientation.landscape) {
      base = 1.0 / base;
    }
    if (spread == PageSpread.spread) {
      base = base * 2.0;
    }
    return base;
  }

  bool get isDarkBackground {
    return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
  }

  Color get patternLineColor {
    if (isDarkBackground) {
      return Colors.white.withValues(alpha: 0.18);
    }
    return const Color(0xFFCBD5E1); // Clean subtle slate
  }

  Color get secondaryPatternColor {
    if (isDarkBackground) {
      return Colors.white.withValues(alpha: 0.35);
    }
    return const Color(0xFF94A3B8);
  }

  Color get marginLineColor {
    if (isDarkBackground) {
      return const Color(0xFFFF8A80).withValues(alpha: 0.5);
    }
    return const Color(0xFFEF5350).withValues(alpha: 0.6); // Rose margin
  }

  Map<String, dynamic> toJson() {
    return {
      'sizeId': sizeOption.id,
      'orientation': orientation.name,
      'spread': spread.name,
      'backgroundColor': backgroundColor.toARGB32(),
      'pageType': pageType.name,
      'title': title,
    };
  }

  factory PageStyleConfig.fromJson(Map<String, dynamic> json) {
    final sizeId = json['sizeId'] as String? ?? 'iphone';
    final size = PageSizeOption.defaultSizes.firstWhere(
      (s) => s.id == sizeId,
      orElse: () => PageSizeOption.defaultSizes[1],
    );

    final orientation = (json['orientation'] == 'landscape')
        ? PageOrientation.landscape
        : PageOrientation.portrait;

    final spread = (json['spread'] == 'spread')
        ? PageSpread.spread
        : PageSpread.single;

    final colorVal = json['backgroundColor'] as int? ?? 0xFFFFFFFF;
    final typeName = json['pageType'] as String? ?? 'blank';
    final pageType = PageType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => PageType.blank,
    );

    return PageStyleConfig(
      sizeOption: size,
      orientation: orientation,
      spread: spread,
      backgroundColor: Color(colorVal),
      pageType: pageType,
      title: json['title'] as String? ?? 'برگه یادداشت جدید',
    );
  }
}
