import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const Color kGreen = Color(0xFF2E7D32);
const Color kRed = Color(0xFFC62828);

class AppState extends ChangeNotifier {
  int book = 0; // 0 = ব্যবসা, 1 = ব্যক্তিগত
  void setBook(int b) {
    book = b;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

final AppState app = AppState();

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

String bn(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 48 && r <= 57) {
      b.write(_bnDigits[r - 48]);
    } else {
      b.write(String.fromCharCode(r));
    }
  }
  return b.toString();
}

String toEn(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x09E6 && r <= 0x09EF) {
      b.write(r - 0x09E6);
    } else if (r == 44) {
      // কমা বাদ
    } else {
      b.write(String.fromCharCode(r));
    }
  }
  return b.toString();
}

final NumberFormat _nf = NumberFormat('#,##0.##');

String money(num v) {
  final neg = v < 0;
  return '${neg ? '-' : ''}৳${bn(_nf.format(v.abs()))}';
}

const _months = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'
];

String fmtDate(DateTime d) =>
    '${bn(d.day.toString())} ${_months[d.month - 1]} ${bn(d.year.toString())}';

String fmtMs(int ms) => fmtDate(DateTime.fromMillisecondsSinceEpoch(ms));

class Range {
  final int? from;
  final int? to;
  const Range(this.from, this.to);
}

const rangeLabels = ['আজ', 'এই মাস', 'গত মাস', 'এই বছর', 'সব'];

Range rangeFor(int i) {
  final n = DateTime.now();
  int ms(DateTime d) => d.millisecondsSinceEpoch;
  switch (i) {
    case 0:
      return Range(ms(DateTime(n.year, n.month, n.day)),
          ms(DateTime(n.year, n.month, n.day + 1)));
    case 1:
      return Range(
          ms(DateTime(n.year, n.month, 1)), ms(DateTime(n.year, n.month + 1, 1)));
    case 2:
      return Range(
          ms(DateTime(n.year, n.month - 1, 1)), ms(DateTime(n.year, n.month, 1)));
    case 3:
      return Range(ms(DateTime(n.year, 1, 1)), ms(DateTime(n.year + 1, 1, 1)));
    default:
      return const Range(null, null);
  }
}

const paymentMethods = ['ক্যাশ', 'বিকাশ', 'নগদ', 'রকেট', 'ব্যাংক'];

List<String> categoriesFor(int book, String type) {
  if (type == 'income') {
    return book == 0
        ? ['বিক্রি', 'সেবা আয়', 'কমিশন', 'অন্যান্য আয়']
        : ['বেতন', 'ব্যবসা থেকে', 'উপহার', 'অন্যান্য আয়'];
  }
  return book == 0
      ? ['পণ্য ক্রয়', 'কর্মচারী বেতন', 'দোকান ভাড়া', 'বিদ্যুৎ-গ্যাস-পানি', 'যাতায়াত', 'মেরামত', 'মার্কেটিং', 'অন্যান্য ব্যয়']
      : ['বাজার/খাবার', 'বাসা ভাড়া', 'বিল', 'যাতায়াত', 'চিকিৎসা', 'শিক্ষা', 'বিনোদন', 'কেনাকাটা', 'অন্যান্য ব্যয়'];
}
