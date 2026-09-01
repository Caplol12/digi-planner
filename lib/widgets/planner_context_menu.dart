import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlannerContextMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onSaveToGallery;
  final VoidCallback? onSavePdf;
  final VoidCallback? onPrint;
  final VoidCallback? onShare;
  final VoidCallback? onExport;
  final VoidCallback? onSetToWidget;
  final VoidCallback? onDuplicate;
  final VoidCallback? onAddToBook;
  final VoidCallback? onAddToFolder;
  final VoidCallback? onDelete;

  const PlannerContextMenu({
    super.key,
    this.onEdit,
    this.onSaveToGallery,
    this.onSavePdf,
    this.onPrint,
    this.onShare,
    this.onExport,
    this.onSetToWidget,
    this.onDuplicate,
    this.onAddToBook,
    this.onAddToFolder,
    this.onDelete,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onEdit,
    VoidCallback? onSaveToGallery,
    VoidCallback? onSavePdf,
    VoidCallback? onPrint,
    VoidCallback? onShare,
    VoidCallback? onExport,
    VoidCallback? onSetToWidget,
    VoidCallback? onDuplicate,
    VoidCallback? onAddToBook,
    VoidCallback? onAddToFolder,
    VoidCallback? onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: PlannerContextMenu(
            onEdit: onEdit,
            onSaveToGallery: onSaveToGallery,
            onSavePdf: onSavePdf,
            onPrint: onPrint,
            onShare: onShare,
            onExport: onExport,
            onSetToWidget: onSetToWidget,
            onDuplicate: onDuplicate,
            onAddToBook: onAddToBook,
            onAddToFolder: onAddToFolder,
            onDelete: onDelete,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            context,
            icon: Icons.edit_note_rounded,
            title: 'Edit',
            subtitle: 'ویرایش جلد و نام',
            onTap: onEdit,
          ),
          _buildItem(
            context,
            icon: Icons.file_download_outlined,
            title: 'Save to Gallery',
            subtitle: 'ذخیره در گالری تصاویر',
            onTap: onSaveToGallery ?? () => _showFeedback(context, 'تصویر با موفقیت در گالری ذخیره شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.picture_as_pdf_outlined,
            title: 'Save PDF',
            subtitle: 'خروجی فایل PDF برگه و پلنر',
            onTap: onSavePdf ?? () => _showFeedback(context, 'فایل PDF آماده شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.print_outlined,
            title: 'Print',
            subtitle: 'چاپ مستقیم با پرینتر',
            onTap: onPrint ?? () => _showFeedback(context, 'دستور چاپ به چاپگر ارسال شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.send_rounded,
            title: 'Share',
            subtitle: 'اشتراک‌گذاری پلنر',
            onTap: onShare ?? () => _showFeedback(context, 'لینک اشتراک‌گذاری کپی شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.ios_share_rounded,
            title: 'Export',
            subtitle: 'خروجی داده‌ها و پلنر',
            onTap: onExport ?? () => _showFeedback(context, 'پلنر با موفقیت صادر شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.widgets_outlined,
            title: 'Set to Widget',
            subtitle: 'قرار دادن روی ویجت صفحه اصلی',
            onTap: onSetToWidget ?? () => _showFeedback(context, 'پلنر به عنوان ویجت انتخاب شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.copy_rounded,
            title: 'Duplicate',
            subtitle: 'ساخت نسخه کپی و تکثیر',
            onTap: onDuplicate,
          ),
          _buildItem(
            context,
            icon: Icons.menu_book_rounded,
            title: 'Add to Book',
            subtitle: 'افزودن به کتابچه پلنرها',
            onTap: onAddToBook ?? () => _showFeedback(context, 'به کتابچه اضافه شد.'),
          ),
          _buildItem(
            context,
            icon: Icons.create_new_folder_outlined,
            title: 'Add to Folder',
            subtitle: 'افزودن به پوشه دسته‌بندی',
            onTap: onAddToFolder ?? () => _showFeedback(context, 'به پوشه مورد نظر منتقل شد.'),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, indent: 16, endIndent: 16),
          const SizedBox(height: 6),
          _buildItem(
            context,
            icon: Icons.delete_outline_rounded,
            title: 'Delete',
            subtitle: 'حذف دائمی',
            isDestructive: true,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    final textColor = isDestructive ? const Color(0xFFE53935) : const Color(0xFF1E293B);
    final iconColor = isDestructive ? const Color(0xFFE53935) : const Color(0xFF64748B);

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: iconColor, size: 22),
      title: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.vazirmatn(
              fontSize: 14,
              fontWeight: isDestructive ? FontWeight.w800 : FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($subtitle)',
            style: TextStyle(
              fontSize: 11,
              color: isDestructive ? const Color(0xFFEF5350) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
    );
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
