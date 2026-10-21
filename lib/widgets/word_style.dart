import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../services/tts_service.dart';

/// Style for a vocabulary word: Arabic words get the book-style Amiri font
/// (if enabled in settings) and a slightly larger size so harakat are easy
/// to read. [scaled] applies the user's word-size setting (the big card word).
TextStyle? wordStyle(BuildContext context, String word, TextStyle? base, {bool scaled = false}) {
  final s = context.watch<SettingsProvider>();
  final arabic = detectScript(word) == WordScript.arabic;
  final useAmiri = arabic && s.arabicFont;
  var size = base?.fontSize ?? 16;
  if (useAmiri) size *= 1.15;
  if (scaled) size *= s.wordScale;
  return (base ?? const TextStyle()).copyWith(
    fontFamily: useAmiri ? 'Amiri' : null,
    fontSize: size,
    height: arabic ? 1.6 : null,
  );
}
