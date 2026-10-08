import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Formu bir tablo gibi çizen parçalar: tek çerçeveli kart, etiket ve değer
/// sütunlu satırlar, kartın içinde tam genişlikte notlar.
///
/// Uygulamanın işi tablo olduğu için bilgi girilen ekranlar da (hesap,
/// tabloya katılma) aynı dille konuşur.

/// Tablo hücresine oturan yazı alanının süsü: hücrenin çerçevesi tablonun
/// çizgileridir, alanın kendi çerçevesi ve dolgusu olmaz.
InputDecoration ledgerInputDecoration(BuildContext context, {String? hint}) {
  final colors = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: .7)),
    filled: false,
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    // Alt boşluğun kalanı hücrede: hata yazısı çıktığında alt çizgiye
    // yapışmasın diye.
    contentPadding: const EdgeInsets.fromLTRB(14, 18, 8, 6),
    errorMaxLines: 3,
  );
}

/// Satırları ince çizgilerle ayrılmış tek çerçeveli kart.
class LedgerCard extends StatelessWidget {
  final List<Widget> children;
  const LedgerCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: theme.dividerColor),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Bir tablo satırı: solda etiket hücresi, sağda yazılan değer.
class LedgerField extends StatefulWidget {
  final String label;
  final Widget Function(FocusNode focusNode) builder;
  final Widget? trailing;

  /// Satır kısa süreliğine öne çıkarılır: değeri az önce başka bir yoldan
  /// (örneğin konuşarak) dolduruldu.
  final bool highlighted;
  const LedgerField({
    super.key,
    required this.label,
    required this.builder,
    this.trailing,
    this.highlighted = false,
  });

  @override
  State<LedgerField> createState() => _LedgerFieldState();
}

class _LedgerFieldState extends State<LedgerField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _focusNode.hasFocus;
    // Etiket sütunu büyük yazı ayarında bir miktar genişler, ama değere
    // yer bırakacak kadar.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: widget.highlighted
            ? AppTheme.tintedSurface(context, theme.colorScheme.primary)
            : theme.colorScheme.surface.withValues(alpha: 0),
        // Seçili hücrenin işareti: üzerinde çalışılan satır.
        border: Border(
          left: BorderSide(
            width: 3,
            color: active ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focusNode.requestFocus,
              child: SizedBox(
                width: 108 * scale,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 19, 8, 12),
                  child: ExcludeSemantics(
                    child: Text(
                      widget.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _focusNode.requestFocus,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: widget.builder(_focusNode),
                ),
              ),
            ),
            if (widget.trailing != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: widget.trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum LedgerNoteTone { info, success, error }

/// Tablonun içinde tam genişlikte bir not satırı: hata, bilgi, uyarı.
class LedgerNote extends StatelessWidget {
  final String text;
  final LedgerNoteTone tone;
  final Widget? action;
  const LedgerNote(
    this.text, {
    super.key,
    this.tone = LedgerNoteTone.info,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, accent, icon) = switch (tone) {
      LedgerNoteTone.error => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
        theme.colorScheme.onErrorContainer,
        Icons.error_outline_rounded,
      ),
      LedgerNoteTone.success => (
        AppTheme.tintedSurface(context, AppTheme.success),
        theme.colorScheme.onSurface,
        AppTheme.readableAccent(context, AppTheme.success),
        Icons.check_circle_outline_rounded,
      ),
      LedgerNoteTone.info => (
        AppTheme.tintedSurface(context, theme.colorScheme.primary),
        theme.colorScheme.onSurface,
        theme.colorScheme.primary,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: ColoredBox(
        color: background,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, action == null ? 14 : 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: foreground,
                      ),
                    ),
                    ?action,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
