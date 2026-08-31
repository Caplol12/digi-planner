import 'package:flutter/material.dart';
import '../models/page_style_model.dart';
import '../widgets/paper_pattern_painter.dart';
import '../widgets/color_picker_sheet.dart';

class ChoosePageStyleScreen extends StatefulWidget {
  final Function(PageStyleConfig) onBeginPlanner;
  final VoidCallback? onClose;

  const ChoosePageStyleScreen({
    super.key,
    required this.onBeginPlanner,
    this.onClose,
  });

  @override
  State<ChoosePageStyleScreen> createState() => _ChoosePageStyleScreenState();
}

class _ChoosePageStyleScreenState extends State<ChoosePageStyleScreen> {
  late PageSizeOption _selectedSize;
  PageOrientation _selectedOrientation = PageOrientation.portrait;
  PageSpread _selectedSpread = PageSpread.single;
  Color _selectedColor = Colors.white;
  PageType _selectedPageType = PageType.blank;

  // Quick background color presets matching screenshot
  final List<Color> _quickColors = [
    const Color(0xFFFFFFFF), // Pure White
    const Color(0xFFE1F5FE), // Light Blue / Sky
    const Color(0xFFFCE4EC), // Light Pink / Peach
    const Color(0xFFE8F5E9), // Light Green / Mint
    const Color(0xFFF3E5F5), // Light Purple / Lavender
    const Color(0xFFFFFBEB), // Cream / Butter
    const Color(0xFFFFF3E0), // Soft Peach
    const Color(0xFF1E293B), // Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    // Default size is iPhone (9:16) matching the highlighted card in the screenshot
    _selectedSize = PageSizeOption.defaultSizes[1];
  }

  PageStyleConfig get _currentConfig => PageStyleConfig(
        sizeOption: _selectedSize,
        orientation: _selectedOrientation,
        spread: _selectedSpread,
        backgroundColor: _selectedColor,
        pageType: _selectedPageType,
        title: '${_selectedSize.title} ${_selectedPageType.name.toUpperCase()}',
      );

  void _onRainbowPickerTap() {
    ColorPickerSheet.show(
      context,
      initialColor: _selectedColor,
      onColorSelected: (color) {
        setState(() {
          _selectedColor = color;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const activeBorderColor = Color(0xFFFF7043); // Coral orange from screenshot

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back / Close Button
                InkWell(
                  onTap: widget.onClose ?? () => Navigator.maybePop(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF333333)),
                  ),
                ),

                // Title: انتخاب سبک برگه
                const Text(
                  'انتخاب سبک برگه',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF263238),
                  ),
                ),

                const SizedBox(width: 36), // Balanced spacing for centered title
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Main Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= 1. PAGE SIZE =================
                _buildSectionHeader('اندازه و ابعاد برگه', 'Page Size'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 125,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: PageSizeOption.defaultSizes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final sizeOpt = PageSizeOption.defaultSizes[index];
                      final isSelected = _selectedSize.id == sizeOpt.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSize = sizeOpt;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 105,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? activeBorderColor : const Color(0xFFE2E8F0),
                              width: isSelected ? 2.2 : 1.2,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: activeBorderColor.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              else
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                sizeOpt.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? activeBorderColor : const Color(0xFF2D3748),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  sizeOpt.ratioLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A202C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEEEEEE), height: 1),
                const SizedBox(height: 18),

                // ================= 2. PAGE LAYOUT =================
                _buildSectionHeader('چیدمان و جهت صفحه', 'Page Layout'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Landscape / Portrait Toggle
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _buildSegmentButton(
                              title: 'عمودی',
                              isSelected: _selectedOrientation == PageOrientation.portrait,
                              onTap: () => setState(() => _selectedOrientation = PageOrientation.portrait),
                            ),
                            _buildSegmentButton(
                              title: 'افقی',
                              isSelected: _selectedOrientation == PageOrientation.landscape,
                              onTap: () => setState(() => _selectedOrientation = PageOrientation.landscape),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Single / Spread Toggle
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _buildSegmentButton(
                              title: 'تک صفحه‌ای',
                              isSelected: _selectedSpread == PageSpread.single,
                              onTap: () => setState(() => _selectedSpread = PageSpread.single),
                            ),
                            _buildSegmentButton(
                              title: 'دو صفحه‌ای',
                              isSelected: _selectedSpread == PageSpread.spread,
                              onTap: () => setState(() => _selectedSpread = PageSpread.spread),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEEEEEE), height: 1),
                const SizedBox(height: 18),

                // ================= 3. PAGE BACKGROUND COLOR =================
                _buildSectionHeader('رنگ پس‌زمینه برگه', 'Background Color'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // Rainbow / Custom Color Picker Button
                      GestureDetector(
                        onTap: _onRainbowPickerTap,
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const SweepGradient(
                              colors: [
                                Colors.red,
                                Colors.orange,
                                Colors.yellow,
                                Colors.green,
                                Colors.cyan,
                                Colors.blue,
                                Colors.purple,
                                Colors.red,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),

                      // Color Swatches
                      ..._quickColors.map((color) {
                        final isSelected = _selectedColor == color;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColor = color),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 50,
                            height: 50,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? activeBorderColor : const Color(0xFFCBD5E1),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: activeBorderColor.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                  ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check_rounded,
                                    color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                                        ? Colors.white
                                        : activeBorderColor,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFFEEEEEE), height: 1),
                const SizedBox(height: 18),

                // ================= 4. PAGE TYPE =================
                _buildSectionHeader('الگو و خط‌کشی کاغذ یادداشت', 'Page Type'),
                const SizedBox(height: 14),

                // Grid / Horizontal List of Page Types with Realistic Paper Thumbnails
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: PageTypeOption.defaultTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final typeOpt = PageTypeOption.defaultTypes[index];
                      final isSelected = _selectedPageType == typeOpt.type;

                      // Simulated miniature config for preview
                      final previewConfig = PageStyleConfig(
                        sizeOption: _selectedSize,
                        orientation: PageOrientation.portrait,
                        spread: PageSpread.single,
                        backgroundColor: _selectedColor,
                        pageType: typeOpt.type,
                      );

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPageType = typeOpt.type;
                          });
                        },
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 120,
                              height: 165,
                              decoration: BoxDecoration(
                                color: _selectedColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? activeBorderColor : const Color(0xFFE2E8F0),
                                  width: isSelected ? 2.5 : 1.2,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: activeBorderColor.withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )
                                  else
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: PaperPatternWidget(
                                  config: previewConfig,
                                  isThumbnail: true,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              typeOpt.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? activeBorderColor : const Color(0xFF2D3748),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Sticky Bottom CTA: Begin New Planner ->
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SafeArea(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () => widget.onBeginPlanner(_currentConfig),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeBorderColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: activeBorderColor.withValues(alpha: 0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'شروع پلنر جدید',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitlePersian) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '($subtitlePersian)',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}
