import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Katılım kodu, her rakamı kendi hücresinde.
///
/// Kodu veren kişi de alan kişi de aynı şeyi görür: biri okur, öbürü yazar.
/// Rakamların ayrı durması telefonda tek tek söylemeyi ve saymayı
/// kolaylaştırır.
class JoinCodeCells extends StatelessWidget {
  const JoinCodeCells({
    super.key,
    required this.code,
    this.activeIndex,
    this.hasError = false,
  });

  static const length = 6;

  final String code;

  /// Sıradaki rakamın yazılacağı hücre; yalnızca kod girilirken işaretlenir.
  final int? activeIndex;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final line = hasError ? colors.error : theme.dividerColor;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: line),
      ),
      child: SizedBox(
        height: 64,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < length; index++) ...[
              if (index > 0)
                VerticalDivider(width: 1, thickness: 1, color: line),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // Seçili hücrenin işareti, hesap formundaki etkin satırla
                    // aynı dil: ana renkte bir çizgi.
                    border: Border(
                      bottom: BorderSide(
                        width: 3,
                        color: index == activeIndex
                            ? colors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    index < code.length ? code[index] : '',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yazılan ya da yapıştırılan metinden katılım kodunu çıkarır.
///
/// Kod çoğunlukla bir mesajın içinde gelir ("… paylaşımına katıl. Katılım
/// kodu: 463404"). Yalnızca rakamları süzmek yetmez: tablonun adında rakam
/// varsa ("test2") o da koda karışırdı. Metinde kendi başına duran altı
/// haneli bir sayı varsa kod odur.
class JoinCodeFormatter extends TextInputFormatter {
  const JoinCodeFormatter();

  static final _standalone = RegExp(r'(?<!\d)\d{6}(?!\d)');

  static String extract(String text) {
    String? pasted;
    if (text.length > JoinCodeCells.length) {
      final matches = _standalone.allMatches(text);
      if (matches.isNotEmpty) pasted = matches.last.group(0);
    }
    final digits = pasted ?? text.replaceAll(RegExp(r'\D'), '');
    return digits.length > JoinCodeCells.length
        ? digits.substring(0, JoinCodeCells.length)
        : digits;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final code = extract(newValue.text);
    return TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
  }
}

/// Kodun yazıldığı alan: görünen şey hücrelerdir, klavyeyi ve yapıştırmayı
/// üstlerindeki görünmez yazı alanı taşır.
class JoinCodeInput extends StatefulWidget {
  const JoinCodeInput({
    super.key,
    required this.controller,
    required this.semanticLabel,
    this.enabled = true,
    this.hasError = false,
    this.onChanged,
    this.onCompleted,
    this.fieldKey = const ValueKey('join-code'),
    this.autofillHints,
  });

  final TextEditingController controller;

  /// Görünmez yazı alanının anahtarı; aynı hücreler e-posta kodunda da kullanılır.
  final Key fieldKey;

  /// E-postayla gelen kodu klavyenin önerebilmesi için.
  final Iterable<String>? autofillHints;
  final String semanticLabel;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  /// Altıncı rakam yazıldığında çağrılır.
  final ValueChanged<String>? onCompleted;

  @override
  State<JoinCodeInput> createState() => _JoinCodeInputState();
}

class _JoinCodeInputState extends State<JoinCodeInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(JoinCodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Stack(
      children: [
        ExcludeSemantics(
          child: JoinCodeCells(
            code: code,
            hasError: widget.hasError,
            activeIndex: _focusNode.hasFocus && widget.enabled
                ? code.length.clamp(0, JoinCodeCells.length - 1)
                : null,
          ),
        ),
        Positioned.fill(
          child: Semantics(
            label: widget.semanticLabel,
            // Yazı görünmez; seçim rengi ve tutamaçları da görünmesin.
            child: TextSelectionTheme(
              data: const TextSelectionThemeData(
                selectionColor: Colors.transparent,
                selectionHandleColor: Colors.transparent,
              ),
              child: TextField(
                key: widget.fieldKey,
                autofillHints: widget.autofillHints,
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                showCursor: false,
                expands: true,
                maxLines: null,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: const [JoinCodeFormatter()],
                style: const TextStyle(color: Colors.transparent),
                decoration: const InputDecoration(
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
                onChanged: (value) {
                  widget.onChanged?.call(value);
                  if (value.length == JoinCodeCells.length) {
                    widget.onCompleted?.call(value);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
