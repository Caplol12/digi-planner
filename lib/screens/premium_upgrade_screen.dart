import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_subscription_service.dart';
import '../theme/app_theme.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final VoidCallback? onOpenAiSettings;

  const PremiumUpgradeScreen({
    super.key,
    this.onOpenAiSettings,
  });

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isActivating = false;
  String? _errorMessage;
  String? _successMessage;

  static const bool isStoreBuild = bool.fromEnvironment('IS_STORE_BUILD', defaultValue: false);
  static const String telegramId = '@metarwa';
  static const String telegramLink = 'https://t.me/metarwa';

  @override
  void initState() {
    super.initState();
    _initSubscriptionState();
  }

  Future<void> _initSubscriptionState() async {
    await AiSubscriptionService.instance.ensureInitialized();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse(telegramLink);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await _copyTelegramId();
      }
    } catch (_) {
      await _copyTelegramId();
    }
  }

  Future<void> _copyTelegramId() async {
    await Clipboard.setData(const ClipboardData(text: telegramId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('آیدی metarwa@ در حافظه کپی شد.'),
            ],
          ),
          backgroundColor: const Color(0xFF1E88E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _handleActivateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'لطفاً کد فعال‌سازی را وارد نمایید.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final success = await AiSubscriptionService.instance.activateWithCode(code);

    if (!mounted) return;

    setState(() {
      _isActivating = false;
      if (success) {
        _successMessage = 'اشتراک پرمیوم با موفقیت فعال شد! اکنون بدون محدودیت می‌توانید از هوش مصنوعی استفاده کنید.';
        _errorMessage = null;
        _codeController.clear();
      } else {
        _errorMessage = 'کد فعال‌سازی وارد شده صحیح نیست. لطفاً جهت دریافت کد با آیدی @metarwa در تلگرام در ارتباط باشید.';
        _successMessage = null;
      }
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text('حساب شما به پرمیوم ارتقا یافت! ✨', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AiSubscriptionService.instance,
      builder: (context, _) {
        final isPremium = AiSubscriptionService.instance.isPremium;
        final usageCount = AiSubscriptionService.instance.usageCount;
        final remaining = AiSubscriptionService.instance.remainingFreeUsage;
        final isExhausted = !isPremium && remaining <= 0;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: context.c.background,
            appBar: AppBar(
              backgroundColor: context.c.background,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: context.c.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'ارتقا به پرمیوم',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.c.textPrimary,
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Hero Card with Crown/Diamond
                  _buildHeroBanner(isPremium: isPremium, isExhausted: isExhausted, usageCount: usageCount, remaining: remaining),

                  const SizedBox(height: 20),

                  // Official Telegram Contact Section (Hidden in Store builds to comply with guidelines)
                  if (!isStoreBuild) ...[
                    _buildTelegramContactBox(),
                    const SizedBox(height: 20),
                  ],

                  // License Code Activation Box
                  if (!isPremium) _buildActivationCodeBox(),

                  if (!isPremium) const SizedBox(height: 20),

                  // Premium Features List
                  _buildFeaturesCard(),

                  const SizedBox(height: 20),

                  // Alternative Free Solution (Google AI Studio Key)
                  _buildAlternativeKeyCard(context),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroBanner({
    required bool isPremium,
    required bool isExhausted,
    required int usageCount,
    required int remaining,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
              : isExhausted
                  ? [const Color(0xFFD84315), const Color(0xFFBF360C)]
                  : [const Color(0xFFE65100), const Color(0xFFEF6C00)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? const Color(0xFF2E7D32) : const Color(0xFFE65100)).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPremium ? Icons.verified_rounded : Icons.diamond_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isPremium
                ? 'اشتراک پرمیوم شما فعال است'
                : isExhausted
                    ? 'پایان سهمیه رایگان هوش مصنوعی'
                    : 'ارتقا به نسخه پرمیوم نامحدود',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'شما به صورت نامحدود و همیشگی به هوش مصنوعی پیش‌فرض دسترسی دارید.'
                : isExhausted
                    ? 'سقف ۱۵ بار استفاده رایگان شما از هوش مصنوعی پیش‌فرض به پایان رسیده است.'
                    : 'شما تاکنون $usageCount از ${AiSubscriptionService.maxFreeUsage} بار استفاده کرده‌اید ($remaining بار باقی‌مانده).',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),

          // Progress Bar / Status Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPremium
                      ? Icons.all_inclusive_rounded
                      : isExhausted
                          ? Icons.block_rounded
                          : Icons.timelapse_rounded,
                  size: 18,
                  color: isPremium ? Colors.amberAccent : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  isPremium
                      ? 'دسترسی نامحدود فعال'
                      : isExhausted
                          ? 'استفاده رایگان: ۱۵ / ۱۵ (اتمام سهمیه)'
                          : 'استفاده رایگان: $usageCount / ${AiSubscriptionService.maxFreeUsage}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramContactBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0288D1).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0288D1).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F5FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.send_rounded, color: Color(0xFF0288D1), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'فعال‌سازی سریع از طریق تلگرام',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF01579B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Required exact message
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF0288D1), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'برای فعال سازی پرمیوم به ایدی @metarwa در تلگرام پیام بدید',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0369A1),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Open Telegram + Copy ID
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _openTelegram,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0288D1),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.telegram, size: 20),
                  label: const Text(
                    'پیام در تلگرام (metarwa@)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _copyTelegramId,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0288D1),
                    side: const BorderSide(color: Color(0xFF0288D1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'کپی آیدی',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivationCodeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Color(0xFFD97706), size: 20),
              SizedBox(width: 8),
              Text(
                'کد فعال‌سازی دارید؟',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'اگر پس از ارتباط با تلگرام کد فعال‌سازی دریافت کردید، آن را در کادر زیر وارد کنید:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 12),

          // Code Input Field
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'کد فعال‌سازی (مثال: METARWA-VIP)...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],

          if (_successMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _successMessage!,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isActivating ? null : _handleActivateCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isActivating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'ثبت و فعال‌سازی فوری پرمیوم',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesCard() {
    final features = [
      {'icon': Icons.all_inclusive_rounded, 'title': 'استفاده نامحدود از هوش مصنوعی پیش‌فرض', 'desc': 'اسکن بدون سقف تمام صفحات و قالب‌های شما'},
      {'icon': Icons.bolt_rounded, 'title': 'بیشترین سرعت در تشخیص دیداری برگه', 'desc': 'تبدیل تصاویر دست‌نویس و چاپی به کادرهای ویرایش‌پذیر'},
      {'icon': Icons.chat_rounded, 'title': 'دستیار هوشمند چت و تغییرات چیدمان', 'desc': 'ویرایش، جابه‌جایی و حذف کادرها با دستور صوتی/متنی'},
      {'icon': Icons.security_rounded, 'title': 'بدون نیاز به ساخت اکانت گوگل و کلید اختصاصی', 'desc': 'سیستم کاملاً آماده و پیکربندی‌شده بدون پیچیدگی'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مزایای نسخه پرمیوم:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          ...features.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item['icon'] as IconData, size: 18, color: const Color(0xFFE65100)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          Text(
                            item['desc'] as String,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAlternativeKeyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF0284C7), size: 20),
              SizedBox(width: 8),
              Text(
                'گزینه جایگزین کاملاً رایگان:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'اگر نمی‌خواهید پرمیوم تهیه کنید، می‌توانید از طریق سایت aistudio.google.com یک کلید رایگان Gemini شخصی دریافت کنید و آن را در بخش تنظیمات وارد نمایید تا بدون محدودیت و به رایگان استفاده کنید.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.5),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                widget.onOpenAiSettings?.call();
              },
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF0284C7)),
              label: const Text(
                'تنظیم کلید شخصی Google AI Studio',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
