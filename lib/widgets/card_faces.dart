import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../l10n/strings.dart';
import '../providers/settings_provider.dart';
import '../services/tts_service.dart';

/// Shared rounded surface for both card faces.
class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child, required this.label});
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FRONT: word + IPA + TTS
// ---------------------------------------------------------------------------

class CardFront extends StatelessWidget {
  const CardFront({super.key, required this.card});
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showIpa =
        context.select<SettingsProvider, bool>((s) => s.showPronunciation);

    return _CardSurface(
      label: switch (detectScript(card.word)) {
        WordScript.arabic => S.of(context).labelArabic,
        WordScript.cyrillic => S.of(context).labelRussian,
        WordScript.latin => S.of(context).labelEnglish,
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.word,
              textAlign: TextAlign.center,
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (showIpa && card.ipa.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              card.ipa,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          const SizedBox(height: 20),
          IconButton.filledTonal(
            tooltip: S.of(context).pronounce,
            iconSize: 28,
            onPressed: () => context.read<TtsService>().speak(card.word),
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// BACK: translations + example + editable mnemonic
// ---------------------------------------------------------------------------

class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.card});
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();

    return _CardSurface(
      label: S.of(context).labelMeaning,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                card.primaryTranslation.isEmpty ? '—' : card.primaryTranslation,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (settings.showSecondary &&
                  card.secondaryTranslation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  card.secondaryTranslation,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (card.example.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '“${card.example}”',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (settings.showMnemonic) MnemonicField(card: card),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline, auto-saving mnemonic / keyword field on the back of the card.
/// Saves 600 ms after typing stops, on Enter, and when the card leaves.
class MnemonicField extends StatefulWidget {
  const MnemonicField({super.key, required this.card});
  final Flashcard card;

  @override
  State<MnemonicField> createState() => _MnemonicFieldState();
}

class _MnemonicFieldState extends State<MnemonicField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.card.mnemonic);
  late final FocusNode _focus = FocusNode(debugLabel: 'mnemonic');
  late LibraryProvider _deck;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deck = context.read<LibraryProvider>();
  }

  @override
  void didUpdateWidget(covariant MnemonicField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different card (or an external edit) — refresh unless user is typing.
    if (!_focus.hasFocus && widget.card.mnemonic != _controller.text) {
      _controller.text = widget.card.mnemonic;
    }
  }

  void _scheduleSave(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  void _save() {
    _debounce?.cancel();
    _deck.updateMnemonic(widget.card.id, _controller.text);
  }

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      final id = widget.card.id;
      final text = _controller.text;
      final deck = _deck;
      // Defer: the widget tree is locked during dispose.
      Future.microtask(() => deck.updateMnemonic(id, text));
    }
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      onChanged: _scheduleSave,
      onSubmitted: (_) {
        _save();
        _focus.unfocus();
      },
      onTapOutside: (_) {
        if (_focus.hasFocus) {
          _save();
          _focus.unfocus();
        }
      },
      textInputAction: TextInputAction.done,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
        hintText: S.of(context).mnemonicHint,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
