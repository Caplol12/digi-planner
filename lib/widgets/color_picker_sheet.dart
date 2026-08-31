import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final Function(Color) onColorSelected;

  const ColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  static void show(
    BuildContext context, {
    required Color initialColor,
    required Function(Color) onColorSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ColorPickerSheet(
        initialColor: initialColor,
        onColorSelected: onColorSelected,
      ),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late Color _selectedColor;
  double _hue = 0.0;
  double _saturation = 0.8;
  double _lightness = 0.9;

  final List<Color> _presetColors = [
    // Standard Neutrals & Pastels
    const Color(0xFFFFFFFF), // Pure White
    const Color(0xFFFAF9F6), // Warm Ivory
    const Color(0xFFFFFBEB), // Butter Cream
    const Color(0xFFFFF0F5), // Lavender Blush
    const Color(0xFFF0FDF4), // Mint Cream
    const Color(0xFFEFF6FF), // Ice Blue
    const Color(0xFFF5F3FF), // Soft Lilac
    const Color(0xFFFFF1F2), // Rose Petal
    const Color(0xFFFFF7ED), // Soft Peach
    const Color(0xFFF8FAFC), // Crisp Slate Light

    // Vibrant & Pastel Tones
    const Color(0xFFFFE0B2), // Peach
    const Color(0xFFFFCDD2), // Soft Coral
    const Color(0xFFF8BBD0), // Soft Pink
    const Color(0xFFE1BEE7), // Soft Purple
    const Color(0xFFC5CAE9), // Periwinkle
    const Color(0xFFBBDEFB), // Sky Blue
    const Color(0xFFB2EBF2), // Aqua
    const Color(0xFFC8E6C9), // Mint Green
    const Color(0xFFDCEDC8), // Lime Pastle
    const Color(0xFFFFF9C4), // Lemon Chiffon

    // Deep / Dark Paper
    const Color(0xFF1E293B), // Slate Dark
    const Color(0xFF18181B), // Charcoal
    const Color(0xFF14213D), // Midnight Navy
    const Color(0xFF1C2826), // Forest Night
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    final hsv = HSVColor.fromColor(_selectedColor);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _lightness = hsv.value;
  }

  void _updateFromHsv() {
    setState(() {
      _selectedColor = HSVColor.fromAHSV(1.0, _hue, _saturation, _lightness).toColor();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'انتخاب رنگ پس‌زمینه برگه',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preset Grid
            const Text(
              'پالت رنگ‌های پیشنهادی (Presets):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedColor = color;
                      final hsv = HSVColor.fromColor(color);
                      _hue = hsv.hue;
                      _saturation = hsv.saturation;
                      _lightness = hsv.value;
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Custom Sliders
            const Text(
              'تنظیم رنگ دلخواه (Hue & Brightness):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),

            // Hue Slider
            Row(
              children: [
                const Text('طیف رنگ:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _hue,
                    min: 0.0,
                    max: 360.0,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) {
                      _hue = v;
                      _updateFromHsv();
                    },
                  ),
                ),
              ],
            ),

            // Saturation Slider
            Row(
              children: [
                const Text('غلظت:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _saturation,
                    min: 0.0,
                    max: 1.0,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) {
                      _saturation = v;
                      _updateFromHsv();
                    },
                  ),
                ),
              ],
            ),

            // Lightness Slider
            Row(
              children: [
                const Text('روشنایی:', style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _lightness,
                    min: 0.2,
                    max: 1.0,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (v) {
                      _lightness = v;
                      _updateFromHsv();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  widget.onColorSelected(_selectedColor);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'تایید و انتخاب رنگ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
