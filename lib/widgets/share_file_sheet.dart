import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/ux_localizations.dart';
import '../providers/subscription_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';
import 'ledger.dart';
import 'premium_features.dart';
import 'premium_gate.dart';

/// Paylaşım kâğıdında ne gönderileceğine dair yapılan seçim.
class ExportChoice {
  const ExportChoice({this.filtered = false, this.query = '', this.range});

  /// Yalnızca [query] ile bulunanlar; değilse tamamı.
  final bool filtered;

  /// Kâğıdın arama kutusuna yazılan.
  final String query;

  /// Çetelede seçilen günler; null ise çetelenin bütün aralığı.
  final DateTimeRange? range;
}

/// Kâğıttaki aramanın sonucu: kaç kayıt tuttu, hangileri, aramanın altında
/// ne yazsın.
class ShareMatch {
  const ShareMatch(this.count, {this.note, this.preview = const []});

  /// Kâğıtta kaç kaydın kendisi gösterilir; gerisi sayıyla söylenir.
  static const previewLimit = 5;

  final int count;

  /// "Yalnızca “yükleme” sütununda aranıyor".
  final String? note;

  /// Bulunanların ilk birkaçı, tek satırlık özetle: dosyaya ne gireceği
  /// gönderilmeden görünsün.
  final List<String> preview;
}

/// Paylaşılabilecek bir dosya türü ve onu üreten işlem.
class ShareFileFormat {
  const ShareFileFormat({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.create,
  });

  /// "PDF", "CSV".
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  /// Seçilen kısmın dosyasını oluşturur ve yolunu döner.
  final Future<String> Function(ExportChoice choice) create;
}

/// Tabloyu ya da çeteleyi dosya olarak paylaşma kâğıdı.
///
/// Eskiden üst çubukta bir indirme düğmesi vardı: tür seçilir, dosya
/// oluşturulur, sonra ayrı bir adımda "paylaş" ya da "cihaza kaydet"
/// denirdi. Çoğu kişi dosyayı cihazına indirmek değil birine göndermek
/// istiyor; bu yüzden türe dokunmak doğrudan paylaşım penceresini açar.
/// Cihaza kaydetmek isteyen de oradan yapar ("Dosyalara kaydet", Drive):
/// ayrı bir kaydet düğmesi iPhone'da dosyayı kullanıcının göremediği
/// uygulama klasörüne bırakıyordu.
///
/// Bir kısmını göndermek Premium'dur: kâğıdın kendi arama kutusuna yazılır,
/// bulunanlar gider; çetelede günler de seçilir. Patron bütün çalışanların
/// değil, yalnızca birinin ayını gönderebilir. Seçenek ücretsiz kullanıcıya
/// da kilitli olarak görünür: çoğu kişi böyle bir şey olduğunu ancak burada
/// fark eder. Ücretsiz kullanıcı tamamını gönderir.
class ShareFileSheet extends StatefulWidget {
  const ShareFileSheet({
    super.key,
    required this.name,
    required this.summary,
    required this.icon,
    required this.formats,
    this.total = 0,
    this.match,
    this.initialQuery = '',
    this.searchHint,
    this.searchHelper,
    this.period,
    this.shareFile = ExportService.shareFile,
  });

  final String name;

  /// Adın altındaki tek satır: kaç kayıt, kaç sütun.
  final String summary;
  final IconData icon;
  final List<ShareFileFormat> formats;

  /// Tamamındaki kayıt sayısı; "Tamamı" satırında yazar.
  final int total;

  /// Yazılan aramanın sonucu; aranacak söz yoksa null. Verilmezse bir
  /// kısmını gönderme seçeneği hiç çıkmaz.
  final ShareMatch? Function(String query)? match;

  /// Ekranda açık olan arama: kutu bununla dolu gelir.
  final String initialQuery;
  final String? searchHint;

  /// Kutu boşken altında yazan ipucu.
  final String? searchHelper;

  /// Çetelenin tarih aralığı; verilirse günler seçilebilir.
  final DateTimeRange? period;

  @visibleForTesting
  final Future<bool> Function(String path, String subject, {Rect? origin})
  shareFile;

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String summary,
    required IconData icon,
    required List<ShareFileFormat> formats,
    int total = 0,
    ShareMatch? Function(String query)? match,
    String initialQuery = '',
    String? searchHint,
    String? searchHelper,
    DateTimeRange? period,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => ShareFileSheet(
      name: name,
      summary: summary,
      icon: icon,
      formats: formats,
      total: total,
      match: match,
      initialQuery: initialQuery,
      searchHint: searchHint,
      searchHelper: searchHelper,
      period: period,
    ),
  );

  @override
  State<ShareFileSheet> createState() => _ShareFileSheetState();
}

/// Kâğıdın adımları: ne gönderileceği seçilir, bir kısmıysa aranır, sonra
/// dosya türü seçilip paylaşılır.
enum _Step { pick, search, share }

class _ShareFileSheetState extends State<ShareFileSheet> {
  /// Dosyası hazırlanan tür; hazırlık sürerken öteki satırlar bekler.
  ShareFileFormat? _working;
  bool _failed = false;

  /// Arama verilmeyen kâğıtta seçilecek bir şey yoktur; doğrudan paylaşılır.
  late _Step _step = widget.match == null ? _Step.share : _Step.pick;

  /// "Bir kısmı" seçilip devam edildi mi.
  bool _some = false;
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  late ShareMatch? _match = widget.match?.call(widget.initialQuery);
  DateTimeRange? _range;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String query) =>
      setState(() => _match = widget.match?.call(query));

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _failed = false;
    });
  }

  Future<String?> _create(ShareFileFormat format, ExportChoice choice) async {
    setState(() {
      _working = format;
      _failed = false;
    });
    try {
      return await format.create(choice);
    } catch (error) {
      debugPrint('Dosya oluşturulamadı: $error');
      if (mounted) setState(() => _failed = true);
      return null;
    }
  }

  Future<void> _share(
    ShareFileFormat format,
    ExportChoice choice,
    BuildContext rowContext,
  ) async {
    // iPad'de paylaşım penceresi bir noktaya bağlanmak zorunda; konum,
    // dosya hazırlanırken satır yerinden oynamadan önce alınır.
    final box = rowContext.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    final navigator = Navigator.of(context);
    final path = await _create(format, choice);
    if (path == null) {
      if (mounted) setState(() => _working = null);
      return;
    }
    var shared = false;
    try {
      shared = await widget.shareFile(
        path,
        '${widget.name} - ${format.label}',
        origin: origin,
      );
    } catch (error) {
      debugPrint('Paylaşım açılamadı: $error');
      if (mounted) setState(() => _failed = true);
    }
    if (!mounted) return;
    setState(() => _working = null);
    // Gönderildiyse kâğıdın işi bitti. Paylaşım penceresi kapatıldıysa
    // kâğıt açık kalır: başka bir tür seçilebilir.
    if (shared) navigator.pop();
  }

  Future<void> _pickDates(DateTimeRange period) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: period.start,
      lastDate: period.end,
      initialDateRange: _range ?? period,
    );
    if (picked != null && mounted) setState(() => _range = picked);
  }

  /// 1. adım: tamamı mı, bir kısmı mı.
  Widget _pickStep(AppLocalizations loc, bool premium) => Column(
    key: const ValueKey('export-step-pick'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionTitle(loc.exportWhat),
      LedgerCard(
        children: [
          _OptionRow(
            key: const ValueKey('export-all'),
            icon: Icons.table_rows_rounded,
            title: loc.exportAll,
            trailing: loc.nRecords(widget.total),
            onTap: () {
              _some = false;
              _go(_Step.share);
            },
          ),
          _OptionRow(
            key: const ValueKey('export-some'),
            icon: Icons.filter_alt_rounded,
            locked: !premium,
            title: loc.exportSome,
            subtitle: loc.exportSomeHint,
            onTap: premium
                ? () => _go(_Step.search)
                : () => showPremiumFeatureSheet(context, PremiumFeature.export),
          ),
        ],
      ),
    ],
  );

  /// 2. adım (bir kısmı): aranır, bulunanlar görülür, devam edilir.
  Widget _searchStep(AppLocalizations loc) {
    final query = _query.text.trim();
    final match = _match;
    final count = match?.count ?? 0;
    final String? helper;
    final String? error;
    if (query.isNotEmpty && match != null && count == 0) {
      helper = null;
      error = loc.noMatchingRecord(query);
    } else {
      helper = match?.note ?? (query.isEmpty ? widget.searchHelper : null);
      error = null;
    }
    return Column(
      key: const ValueKey('export-step-search'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepBack(
          key: const ValueKey('export-back'),
          title: loc.exportSome,
          onTap: () => _go(_Step.pick),
        ),
        // Kutu hep aynı yerde kalır: önizleme çıkıp kaybolurken kutu
        // yeniden kurulursa imleç ve klavye gider.
        TextField(
          key: const ValueKey('export-query'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _search,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.searchHint,
            helperText: helper,
            helperMaxLines: 2,
            errorText: error,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: loc.clear,
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _query.clear();
                      _search('');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        // Düğme kutunun hemen altında: klavye açıkken de görünür. Bulunan
        // kayıtlar onun altında listelenir.
        FilledButton(
          key: const ValueKey('export-continue'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: count == 0
              ? null
              : () {
                  _some = true;
                  _go(_Step.share);
                },
          child: Text(
            count == 0
                ? loc.exportContinue
                : '${loc.exportContinue} · ${loc.nRecords(count)}',
          ),
        ),
        if (count > 0 && match!.preview.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MatchPreview(
            lines: match.preview,
            more: count - match.preview.length,
          ),
        ],
      ],
    );
  }

  /// Son adım: seçimin özeti ve dosya türleri.
  Widget _shareStep(
    AppLocalizations loc,
    ColorScheme colors,
    bool premium,
    ExportChoice choice,
  ) {
    final busy = _working != null;
    final period = widget.period;
    final searchable = widget.match != null;
    return Column(
      key: const ValueKey('export-step-share'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searchable || period != null) ...[
          _SectionTitle(loc.exportWhat),
          LedgerCard(
            children: [
              if (searchable)
                _SummaryRow(
                  key: const ValueKey('export-summary'),
                  icon: choice.filtered
                      ? Icons.filter_alt_rounded
                      : Icons.table_rows_rounded,
                  title: choice.filtered ? loc.exportSome : loc.exportAll,
                  subtitle: choice.filtered ? _query.text.trim() : null,
                  trailing: loc.nRecords(
                    choice.filtered ? (_match?.count ?? 0) : widget.total,
                  ),
                  onChange: busy ? null : () => _go(_Step.pick),
                ),
              if (period != null)
                _DatesRow(
                  key: const ValueKey('export-dates'),
                  range: choice.range ?? period,
                  locked: !premium,
                  onTap: busy
                      ? null
                      : premium
                      ? () => _pickDates(period)
                      : () => showPremiumFeatureSheet(
                          context,
                          PremiumFeature.export,
                        ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        _SectionTitle(loc.shareAsFile),
        LedgerCard(
          children: [
            for (final format in widget.formats)
              _FormatRow(
                key: ValueKey('share-file-${format.label}'),
                format: format,
                working: identical(_working, format),
                enabled: !busy,
                onShare: (rowContext) => _share(format, choice, rowContext),
              ),
          ],
        ),
        if (_failed) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              loc.exportFailed,
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // Premium bu kâğıt açıkken alınabilir; seçimler o an açılır.
    final premium = context.select<SubscriptionProvider, bool>(
      (subscription) => subscription.isPremium,
    );
    final choice = ExportChoice(
      filtered: premium && _some && widget.match != null,
      query: _query.text,
      range: premium ? _range : null,
    );
    final Widget step = switch (_step) {
      _Step.pick => _pickStep(loc, premium),
      _Step.search => _searchStep(loc),
      _Step.share => _shareStep(loc, colors, premium, choice),
    };
    final first = _step == _Step.pick || widget.match == null;
    // Geri tuşu kâğıdı kapatmadan önce bir önceki adıma döner.
    return PopScope(
      canPop: first || _working != null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _go(_step == _Step.share && _some ? _Step.search : _Step.pick);
      },
      child: SingleChildScrollView(
        // Arama kutusu açıkken klavye kâğıdın altını örtmesin.
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(widget.icon, color: colors.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        widget.summary,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: step,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bulunan kayıtların ilk birkaçı: dosyaya ne gireceği gönderilmeden görünür.
class _MatchPreview extends StatelessWidget {
  const _MatchPreview({required this.lines, required this.more});

  final List<String> lines;
  final int more;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('export-preview'),
      padding: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var index = 0; index < lines.length; index++) ...[
              if (index > 0)
                Divider(height: 1, thickness: 1, color: colors.outlineVariant),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  lines[index],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: colors.onSurface),
                ),
              ),
            ],
            if (more > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 9),
                child: Text(
                  loc.exportMore(more),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

/// 1. adımdaki seçenek: dokununca bir sonraki adıma geçer. Premium
/// olmayanda "bir kısmı" işaretinde kilit durur; dokununca Premium anlatılır.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.locked = false,
  });

  final IconData icon;
  final bool locked;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: colors.primary),
              child: PremiumFeatureIcon(icon: icon, locked: locked),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Arama adımının başı: dokununca seçeneklere döner.
class _StepBack extends StatelessWidget {
  const _StepBack({super.key, required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: loc.backButtonTooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Son adımda seçimin özeti: ne gidiyor, kaç kayıt. "Değiştir" ilk adıma
/// döner.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    super.key,
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onChange,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String trailing;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  subtitle == null ? trailing : '$subtitle · $trailing',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('export-change'),
            onPressed: onChange,
            child: Text(loc.exportChange),
          ),
        ],
      ),
    );
  }
}

/// Çetelede gönderilecek günler.
class _DatesRow extends StatelessWidget {
  const _DatesRow({
    super.key,
    required this.range,
    required this.locked,
    required this.onTap,
  });

  final DateTimeRange range;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            IconTheme.merge(
              data: IconThemeData(color: colors.onSurfaceVariant),
              child: PremiumFeatureIcon(
                icon: Icons.date_range_rounded,
                locked: locked,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.exportDates,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    '${material.formatCompactDate(range.start)} – '
                    '${material.formatCompactDate(range.end)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Bir dosya türü: satıra dokunmak paylaşır.
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    super.key,
    required this.format,
    required this.working,
    required this.enabled,
    required this.onShare,
  });

  final ShareFileFormat format;
  final bool working;
  final bool enabled;
  final void Function(BuildContext rowContext) onShare;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? () => onShare(context) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.tintedSurface(context, format.color),
              ),
              child: working
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.readableAccent(context, format.color),
                      ),
                    )
                  : Icon(
                      format.icon,
                      size: 20,
                      color: AppTheme.readableAccent(context, format.color),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  Text(
                    working ? loc.creatingFile : format.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Ayrı bir düğme değil: satırın tamamı paylaşır, ikon bunu
            // gösterir. iPhone'da ve Android'de kendi paylaş işareti çıkar.
            Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.adaptive.share,
                color: enabled ? colors.onSurfaceVariant : colors.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
