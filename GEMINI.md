# Agent Guidelines & Instructions

## Testing Policy (`flutter test`)
- **General Usage**: Running `flutter test` is generally permitted when working specifically on tests or when explicitly requested by the user.
- **FORBIDDEN in Post-Coding Verification**: Do **NOT** run `flutter test` as an automated verification, sanity check, or extra validation step after completing code implementation. Performing test runs at the end of coding tasks takes too much time.
- **Verification Alternative**: When code implementation is finished, verify changes via code inspection or static analysis instead of executing test suites.

---

## دستورالعمل تست‌ها (فارسی)
- **استفاده عمومی**: استفاده از `flutter test` به طور کلی مجاز است (مثلاً در تسک‌های مربوط به تست‌نویسی یا زمانی که کاربر صریحاً آن را بخواهد).
- **ممنوعیت در فاز راستی‌آزمایی**: اجرای `flutter test` در پایان کدنویسی جهت راستی‌آزمایی، تایید نهایی کار یا انجام تست‌های اضافی توسط ایجنت **اکیداً غیرمجاز** است، زیرا زمان زیادی می‌گیرد.
- **روش راستی‌آزمایی مجاز**: پس از پایان پیاده‌سازی، برای اعتبارسنجی فقط از بررسی ساختار کد یا آنالیز استاتیک استفاده کنید و از اجرای تست‌های خودکار خودداری نمایید.
