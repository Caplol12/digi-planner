import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

/// Helper extensions and utilities for Persian / Jalali calendar dates
extension PersianDateTimeExtension on DateTime {
  /// Converts Gregorian DateTime to Jalali object
  Jalali get toJalali => Jalali.fromDateTime(this);

  /// Formatted Shamsi date string, e.g. "۱۴۰۵/۰۶/۱۳"
  String toPersianDateStr({bool withPersianDigits = true}) {
    final j = toJalali;
    final y = j.year.toString().padLeft(4, '0');
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    final str = '$y/$m/$d';
    return withPersianDigits ? str.toPersianDigits : str;
  }

  /// Formatted Shamsi date with time string, e.g. "۱۴۰۵/۰۶/۱۳ ۱۱:۴۵"
  String toPersianDateTimeStr({bool withPersianDigits = true}) {
    final j = toJalali;
    final y = j.year.toString().padLeft(4, '0');
    final m = j.month.toString().padLeft(2, '0');
    final d = j.day.toString().padLeft(2, '0');
    final hh = hour.toString().padLeft(2, '0');
    final mm = minute.toString().padLeft(2, '0');
    final str = '$y/$m/$d $hh:$mm';
    return withPersianDigits ? str.toPersianDigits : str;
  }
}

extension PersianDigitsExtension on String {
  /// Converts English ASCII digits 0-9 to Persian digits ۰-۹
  String get toPersianDigits {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = this;
    for (int i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }
    return result;
  }

  /// Converts Persian digits ۰-۹ to English ASCII digits 0-9
  String get toEnglishDigits {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var result = this;
    for (int i = 0; i < persian.length; i++) {
      result = result.replaceAll(persian[i], english[i]);
    }
    return result;
  }
}

/// Helper to show Persian date picker with Jalali calendar
Future<DateTime?> showPersianDatePickerModal({
  required BuildContext context,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final initJalali = Jalali.fromDateTime(initialDate ?? DateTime.now());
  final minJalali = Jalali.fromDateTime(firstDate ?? DateTime(2020));
  final maxJalali = Jalali.fromDateTime(lastDate ?? DateTime(2035));

  try {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: initJalali,
      firstDate: minJalali,
      lastDate: maxJalali,
    );

    if (picked != null) {
      return picked.toDateTime();
    }
  } catch (_) {
    // Fallback if Persian picker has any context constraints
    if (!context.mounted) return null;
    final fallback = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2035),
    );
    return fallback;
  }
  return null;
}
