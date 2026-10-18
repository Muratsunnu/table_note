import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../l10n/app_localizations.dart';
import '../models/overview_grid.dart';
import '../theme/app_theme.dart';

/// Yakınlaştırma hesapları; widget'tan ayrı ki test edilebilsin.
class OverviewViewport {
  /// Tamamını gösteren ölçek. Küçük tablolar büyütülmez.
  static double fitScale(Size viewport, Size content) {
    if (content.width <= 0 || content.height <= 0) return 1;
    return math.min(
      1.0,
      math.min(
        viewport.width / content.width,
        viewport.height / content.height,
      ),
    );
  }

  /// En fazla doğal boyutun dört katı; çok büyük tablolarda sığdırmanın
  /// dört katı, ki uzaklaştırılmış hâlden de anlamlı yakınlaşılabilsin.
  static double maxScale(Size viewport, Size content) =>
      math.max(4.0, fitScale(viewport, content) * 4);

  // dart format off
  static Matrix4 matrix(double scale, Offset translation) => Matrix4(
    scale, 0, 0, 0,
    0, scale, 0, 0,
    0, 0, 1, 0,
    translation.dx, translation.dy, 0, 1,
  );
  // dart format on

  static double scaleOf(Matrix4 matrix) => matrix.storage[0];
  static Offset translationOf(Matrix4 matrix) =>
      Offset(matrix.storage[12], matrix.storage[13]);

  /// Görünümden büyük içerik kenarlarından taşmaz; küçüğü sol üste yaslanır.
  static Offset clampTranslation(
    Offset translation,
    double scale,
    Size viewport,
    Size content,
  ) {
    double axis(double value, double view, double size) {
      final scaled = size * scale;
      if (scaled <= view) return 0;
      return value.clamp(view - scaled, 0.0);
    }

    return Offset(
      axis(translation.dx, viewport.width, content.width),
      axis(translation.dy, viewport.height, content.height),
    );
  }

  /// [focal] noktasının altındaki içerik yerinde kalacak şekilde ölçekler.
  static Matrix4 zoomAt(
    Offset focal,
    Matrix4 current,
    double target,
    Size viewport,
    Size content,
  ) {
    final contentPoint = (focal - translationOf(current)) / scaleOf(current);
    return matrix(
      target,
      clampTranslation(
        focal - contentPoint * target,
        target,
        viewport,
        content,
      ),
    );
  }

  /// İki parmak hareketinin ara karesi. Hareket başladığında parmakların
  /// altındaki içerik noktası, parmaklar nereye giderse oraya taşınır; tek
  /// parmakta ölçek 1 kaldığı için bu düz kaydırmadır.
  static Matrix4 gesture({
    required Matrix4 start,
    required Offset startFocal,
    required Offset focal,
    required double scaleChange,
    required Size viewport,
    required Size content,
  }) {
    final startScale = scaleOf(start);
    final scale = (startScale * scaleChange).clamp(
      fitScale(viewport, content),
      maxScale(viewport, content),
    );
    final contentPoint = (startFocal - translationOf(start)) / startScale;
    return matrix(
      scale,
      clampTranslation(focal - contentPoint * scale, scale, viewport, content),
    );
  }

  /// Dik tutulan telefonda geniş bir tablo, yan çevrilince belirgin büyüyorsa.
  static bool suggestsLandscape(Size viewport, Size content) {
    if (viewport.width >= viewport.height) return false;
    final portrait = fitScale(viewport, content);
    final landscape = fitScale(Size(viewport.height, viewport.width), content);
    return landscape >= portrait * 1.4;
  }

  /// Sabit sütunlar ekranın en fazla bu kadarını kaplar; çok yakınlaşınca
  /// ekranı kaplamasınlar diye sabitlenmez, tabloyla birlikte kayarlar.
  static const double maxPinnedWidth = 0.45;
  static const double maxPinnedHeight = 0.3;

  static bool pinsColumns(double frozenWidth, double scale, Size viewport) =>
      frozenWidth > 0 && frozenWidth * scale <= viewport.width * maxPinnedWidth;

  static bool pinsHeader(double headerHeight, double scale, Size viewport) =>
      headerHeight * scale <= viewport.height * maxPinnedHeight;

  /// Sabit başlık ve sütunun ekrandaki yeri: içerikle gelir, ekrandan çıkmaz.
  static Offset stickyOrigin(Offset translation) =>
      Offset(math.max(translation.dx, 0), math.max(translation.dy, 0));
}

/// Tablonun ya da çetelenin tamamını gösteren, salt okunur tam ekran pencere.
/// İki parmakla yakınlaşır, sürükleyerek gezinir; çift dokunuş yakınlaşır ya
/// da tamamına döner. Başlık satırı ve soldaki sütunlar kaydırmada sabit kalır.
class GridOverviewScreen extends StatefulWidget {
  /// Hareketlerin alındığı ve tablonun çizildiği alan.
  static const canvasKey = Key('grid-overview-canvas');

  final OverviewGrid grid;

  /// Testlerin görünümü okuyabilmesi için; uygulamada verilmez.
  @visibleForTesting
  final TransformationController? controller;

  const GridOverviewScreen({super.key, required this.grid, this.controller});

  static Future<void> open(BuildContext context, OverviewGrid grid) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => GridOverviewScreen(grid: grid),
        ),
      );

  @override
  State<GridOverviewScreen> createState() => _GridOverviewScreenState();
}

class _GridOverviewScreenState extends State<GridOverviewScreen>
    with SingleTickerProviderStateMixin {
  /// Same drag as Flutter's own scrolling views, so a flick feels familiar.
  static const double _drag = 0.0000135;
  static const Duration _zoomDuration = Duration(milliseconds: 260);

  late final TransformationController _controller =
      widget.controller ?? TransformationController();
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: _zoomDuration,
  )..addListener(_onMotionTick);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
  );
  Matrix4Tween? _motionTween;
  Size? _viewport;
  bool _ready = false;
  bool _hintDismissed = false;
  _CellText? _text;

  // Gesture state: the view and the fingers when the current drag began.
  Matrix4? _gestureStart;
  Offset? _gestureFocal;
  double _gestureScale = 1;
  int _gesturePointers = 0;

  // Double tap, read from raw pointer events so it never competes with pinch.
  final _DoubleTapDetector _doubleTap = _DoubleTapDetector();

  Size get _content => Size(widget.grid.width, widget.grid.height);
  double get _fitScale => OverviewViewport.fitScale(_viewport!, _content);
  Matrix4 get _fitMatrix => OverviewViewport.matrix(_fitScale, Offset.zero);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Theme or locale changes re-resolve colours; zooming never does.
    _text?.dispose();
    _text = _CellText(widget.grid, _OverviewPalette.of(context, widget.grid));
  }

  @override
  void dispose() {
    _curve.dispose();
    _motion.dispose();
    if (widget.controller == null) _controller.dispose();
    _text?.dispose();
    super.dispose();
  }

  void _onMotionTick() {
    final tween = _motionTween;
    if (tween != null) _controller.value = tween.transform(_curve.value);
  }

  void _animateTo(Matrix4 target, {Duration duration = _zoomDuration}) {
    _motionTween = Matrix4Tween(begin: _controller.value.clone(), end: target);
    _motion.duration = duration;
    _motion.forward(from: 0);
  }

  /// The rotate hint is advice for the first look, not a permanent banner.
  void _dismissHint() {
    if (!_hintDismissed) setState(() => _hintDismissed = true);
  }

  void _onDoubleTap(Offset focal) {
    _dismissHint();
    final viewport = _viewport;
    if (viewport == null) return;
    final fit = _fitScale;
    final scale = OverviewViewport.scaleOf(_controller.value);
    // Near the whole-table view: zoom in where tapped. Otherwise go back.
    if (scale <= fit * 1.05) {
      final target = math.min(
        OverviewViewport.maxScale(viewport, _content),
        math.max(1.0, fit * 2.5),
      );
      _animateTo(
        OverviewViewport.zoomAt(
          focal,
          _controller.value,
          target,
          viewport,
          _content,
        ),
      );
    } else {
      _animateTo(_fitMatrix);
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    // A plain tap also "starts" a scale gesture, and it arrives after the
    // double tap has begun zooming. Waiting for real movement before
    // stopping anything keeps a double tap from cancelling itself.
    _gestureStart = null;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final viewport = _viewport;
    if (viewport == null) return;
    // First movement, or a finger joining or leaving: take a fresh reference
    // so the table does not jump when the focal point moves between fingers.
    if (_gestureStart == null || details.pointerCount != _gesturePointers) {
      _motion.stop();
      _dismissHint();
      _gestureStart = _controller.value.clone();
      _gestureFocal = details.localFocalPoint;
      _gestureScale = details.scale;
      _gesturePointers = details.pointerCount;
      return;
    }
    _controller.value = OverviewViewport.gesture(
      start: _gestureStart!,
      startFocal: _gestureFocal!,
      focal: details.localFocalPoint,
      scaleChange: details.scale / _gestureScale,
      viewport: viewport,
      content: _content,
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final viewport = _viewport;
    final moved = _gestureStart != null;
    _gestureStart = null;
    _gestureFocal = null;
    // Only a one-finger flick keeps gliding; a pinch stops where it is left.
    if (viewport == null || !moved || _gesturePointers > 1) return;
    final velocity = details.velocity.pixelsPerSecond;
    if (velocity.distance < kMinFlingVelocity) return;
    final start = OverviewViewport.translationOf(_controller.value);
    final end = Offset(
      FrictionSimulation(_drag, start.dx, velocity.dx).finalX,
      FrictionSimulation(_drag, start.dy, velocity.dy).finalX,
    );
    final seconds = math.log(10 / velocity.distance) / math.log(_drag);
    final scale = OverviewViewport.scaleOf(_controller.value);
    _animateTo(
      OverviewViewport.matrix(
        scale,
        OverviewViewport.clampTranslation(end, scale, viewport, _content),
      ),
      duration: Duration(milliseconds: (seconds * 1000).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.grid;
    final tr = AppLocalizations.of(context).locale.languageCode != 'en';
    final text = _text!;
    return Scaffold(
      appBar: AppBar(
        title: Text(grid.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: tr ? 'Tamamını sığdır' : 'Fit to screen',
            icon: const Icon(Icons.fit_screen_rounded),
            onPressed: _viewport == null ? null : () => _animateTo(_fitMatrix),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          if (_viewport != viewport) {
            _viewport = viewport;
            // First layout and rotations start from the whole table.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _motion.stop();
              _controller.value = _fitMatrix;
              if (!_ready) setState(() => _ready = true);
            });
          }
          final rotateHint =
              !_hintDismissed &&
              OverviewViewport.suggestsLandscape(viewport, _content);
          return Semantics(
            label: tr
                ? '${grid.title}: ${grid.rows.length} satır, '
                      '${grid.columnCount} sütun'
                : '${grid.title}: ${grid.rows.length} rows, '
                      '${grid.columnCount} columns',
            child: Opacity(
              opacity: _ready ? 1 : 0,
              child: ColoredBox(
                color: text.palette.canvas,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Listener(
                        onPointerDown: _doubleTap.down,
                        onPointerCancel: _doubleTap.cancel,
                        onPointerUp: (event) {
                          final at = _doubleTap.up(event);
                          if (at != null) _onDoubleTap(at);
                        },
                        child: GestureDetector(
                          key: GridOverviewScreen.canvasKey,
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          onScaleEnd: _onScaleEnd,
                          child: CustomPaint(
                            size: viewport,
                            painter: _GridPainter(text, _controller),
                          ),
                        ),
                      ),
                    ),
                    if (rotateHint)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16 + MediaQuery.paddingOf(context).bottom,
                        child: IgnorePointer(child: _RotateHint(tr: tr)),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Two quick taps in the same place, told apart from pinches and drags. It
/// reads raw pointer events, so unlike a gesture recogniser it never holds
/// back the first moments of a pinch.
class _DoubleTapDetector {
  Offset? _downAt;
  Duration? _downTime;
  int _pointers = 0;
  bool _multiTouch = false;
  Offset? _lastTapAt;
  Duration? _lastTapTime;

  void down(PointerDownEvent event) {
    _pointers++;
    if (_pointers > 1) _multiTouch = true;
    if (_pointers == 1) {
      _downAt = event.localPosition;
      _downTime = event.timeStamp;
    }
  }

  void cancel(PointerCancelEvent event) {
    _pointers = math.max(0, _pointers - 1);
    _forget();
  }

  /// Returns where the double tap landed, if this lift completes one.
  Offset? up(PointerUpEvent event) {
    _pointers = math.max(0, _pointers - 1);
    if (_pointers > 0) return null;
    final downAt = _downAt;
    final downTime = _downTime;
    final wasMulti = _multiTouch;
    _multiTouch = false;
    final isTap =
        !wasMulti &&
        downAt != null &&
        downTime != null &&
        (event.localPosition - downAt).distance < kTouchSlop &&
        event.timeStamp - downTime < kLongPressTimeout;
    if (!isTap) {
      _forget();
      return null;
    }
    final lastAt = _lastTapAt;
    final lastTime = _lastTapTime;
    if (lastAt != null &&
        lastTime != null &&
        event.timeStamp - lastTime < kDoubleTapTimeout &&
        (event.localPosition - lastAt).distance < kDoubleTapSlop) {
      _forget();
      return event.localPosition;
    }
    _lastTapAt = event.localPosition;
    _lastTapTime = event.timeStamp;
    return null;
  }

  void _forget() {
    _lastTapAt = null;
    _lastTapTime = null;
  }
}

class _RotateHint extends StatelessWidget {
  final bool tr;

  const _RotateHint({required this.tr});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.inverseSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.screen_rotation_rounded,
                size: 18,
                color: colors.onInverseSurface,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  tr
                      ? 'Daha büyük görmek için telefonu yan çevir'
                      : 'Turn your phone sideways to see it larger',
                  style: TextStyle(color: colors.onInverseSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewPalette {
  final Color canvas;
  final Color headerBackground;
  final Color headerText;
  final Color rowEven;
  final Color rowOdd;
  final Color bodyText;
  final Color footerBackground;
  final Color footerText;
  final Color gridLine;
  final Color edge;
  final Color highlight;
  final TextStyle baseStyle;
  final Map<int, Color> _readable;

  _OverviewPalette._({
    required this.canvas,
    required this.headerBackground,
    required this.headerText,
    required this.rowEven,
    required this.rowOdd,
    required this.bodyText,
    required this.footerBackground,
    required this.footerText,
    required this.gridLine,
    required this.edge,
    required this.highlight,
    required this.baseStyle,
    required Map<int, Color> readable,
  }) : _readable = readable;

  factory _OverviewPalette.of(BuildContext context, OverviewGrid grid) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tints = <int, Color>{};
    void collect(OverviewCell cell) {
      final tint = cell.tint;
      if (tint != null) {
        tints.putIfAbsent(
          tint.toARGB32(),
          () => AppTheme.readableAccent(context, tint),
        );
      }
    }

    grid.header.forEach(collect);
    for (final row in grid.rows) {
      row.forEach(collect);
    }
    grid.footer?.forEach(collect);

    return _OverviewPalette._(
      canvas: colors.surfaceContainerLowest,
      headerBackground: colors.primaryContainer,
      headerText: colors.onPrimaryContainer,
      rowEven: AppTheme.tableRowColor(context, 0),
      rowOdd: AppTheme.tableRowColor(context, 1),
      bodyText: colors.onSurface,
      footerBackground: colors.secondaryContainer,
      footerText: colors.onSecondaryContainer,
      gridLine: colors.outlineVariant.withValues(alpha: 0.7),
      edge: colors.outline,
      highlight: Colors.amber,
      baseStyle: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontSize: OverviewGrid.fontSize,
        height: 1.15,
      ),
      readable: tints,
    );
  }

  Color readable(Color tint) => _readable[tint.toARGB32()] ?? bodyText;
}

/// Hücre metinleri bir kez dizilir; yakınlaştırmada yalnızca yeniden çizilir.
class _CellText {
  final OverviewGrid grid;
  final _OverviewPalette palette;
  late final List<TextPainter?> _header = List.filled(grid.columnCount, null);
  late final List<List<TextPainter?>> _body = List.generate(
    grid.bodyRowCount,
    (_) => List<TextPainter?>.filled(grid.columnCount, null),
  );
  final List<bool> _headerDone;
  final List<List<bool>> _bodyDone;

  _CellText(this.grid, this.palette)
    : _headerDone = List.filled(grid.columnCount, false),
      _bodyDone = List.generate(
        grid.bodyRowCount,
        (_) => List<bool>.filled(grid.columnCount, false),
      );

  TextPainter? header(int column) {
    if (!_headerDone[column]) {
      _headerDone[column] = true;
      _header[column] = _layout(grid.header[column], column, header: true);
    }
    return _header[column];
  }

  TextPainter? body(int row, int column) {
    if (!_bodyDone[row][column]) {
      _bodyDone[row][column] = true;
      final cells = grid.bodyRow(row);
      _body[row][column] = column < cells.length
          ? _layout(cells[column], column, footer: grid.isFooter(row))
          : null;
    }
    return _body[row][column];
  }

  TextPainter? _layout(
    OverviewCell cell,
    int column, {
    bool header = false,
    bool footer = false,
  }) {
    if (cell.text.isEmpty) return null;
    final columnWidth = grid.columnWidths[column];
    final width = math.max(
      0.0,
      columnWidth - 2 * OverviewGrid.paddingFor(columnWidth),
    );
    final color = cell.tint != null
        ? palette.readable(cell.tint!)
        : header
        ? palette.headerText
        : footer
        ? palette.footerText
        : palette.bodyText;
    return TextPainter(
      text: TextSpan(
        text: cell.text,
        style: palette.baseStyle.copyWith(
          color: color,
          fontWeight: cell.strong ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (cell.align) {
        OverviewAlign.start => TextAlign.left,
        OverviewAlign.center => TextAlign.center,
        OverviewAlign.end => TextAlign.right,
      },
      textScaler: TextScaler.noScaling,
      maxLines: header ? 2 : 1,
      ellipsis: '…',
    )..layout(minWidth: width, maxWidth: width);
  }

  void dispose() {
    for (final painter in _header) {
      painter?.dispose();
    }
    for (final row in _body) {
      for (final painter in row) {
        painter?.dispose();
      }
    }
  }
}

/// Tabloyu görünümün ölçeği ve kaydırmasıyla çizer, sonra sabit başlığı ve
/// sütunu üstüne koyar. Yalnızca ekrandaki hücreler çizilir; çok
/// uzaklaşınca okunamayacak metin atlanır.
class _GridPainter extends CustomPainter {
  /// Bu ölçeğin altında metin okunamaz; yalnızca hücre renkleri çizilir.
  static const double textScaleThreshold = 0.2;

  final _CellText text;
  final TransformationController controller;

  _GridPainter(this.text, this.controller) : super(repaint: controller);

  OverviewGrid get grid => text.grid;
  _OverviewPalette get palette => text.palette;

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = controller.value;
    final scale = OverviewViewport.scaleOf(matrix);
    final translation = OverviewViewport.translationOf(matrix);
    final withText = scale >= textScaleThreshold;
    canvas.clipRect(Offset.zero & size);

    // The part of the table currently on screen, in table units.
    final rows = _rowRange(
      -translation.dy / scale,
      (size.height - translation.dy) / scale,
    );
    final columns = _columnRange(
      -translation.dx / scale,
      (size.width - translation.dx) / scale,
    );

    // The scrolling table itself.
    canvas.save();
    canvas.translate(translation.dx, translation.dy);
    canvas.scale(scale);
    _paintBody(canvas, rows, columns, withText);
    _paintHeader(canvas, columns, withText);
    canvas.restore();

    // Pinned parts on top, only once they have scrolled away from home.
    // Half a pixel of slack: the fitted view can land a hair below zero.
    final origin = OverviewViewport.stickyOrigin(translation);
    final frozen = (0, grid.frozenColumns);
    final pinColumns = OverviewViewport.pinsColumns(
      grid.frozenWidth,
      scale,
      size,
    );
    final pinHeader = OverviewViewport.pinsHeader(
      OverviewGrid.headerHeight,
      scale,
      size,
    );
    final columnsDetached = pinColumns && translation.dx < -0.5;
    final headerDetached = pinHeader && translation.dy < -0.5;
    // The pinned corner follows the header: stuck to the top only if the
    // header is pinned too, otherwise it scrolls up with it.
    final cornerY = pinHeader ? origin.dy : translation.dy;

    if (columnsDetached) {
      canvas.save();
      canvas.translate(0, translation.dy);
      canvas.scale(scale);
      _paintBody(canvas, rows, frozen, withText);
      canvas.restore();
    }
    if (headerDetached) {
      canvas.save();
      canvas.translate(translation.dx, 0);
      canvas.scale(scale);
      _paintHeader(canvas, columns, withText);
      canvas.restore();
    }
    if (columnsDetached) {
      canvas.save();
      canvas.translate(0, cornerY);
      canvas.scale(scale);
      _paintHeader(canvas, frozen, withText);
      canvas.restore();
    }

    // A firm edge shows where pinned cells end; it stops where the table does.
    final edge = Paint()
      ..color = palette.edge
      ..strokeWidth = 1;
    final tableBottom = math.min(
      size.height,
      translation.dy + grid.height * scale,
    );
    final tableRight = math.min(
      size.width,
      translation.dx + grid.width * scale,
    );
    if (columnsDetached) {
      final x = grid.frozenWidth * scale;
      canvas.drawLine(Offset(x, cornerY), Offset(x, tableBottom), edge);
    }
    if (headerDetached) {
      final y = OverviewGrid.headerHeight * scale;
      canvas.drawLine(Offset(origin.dx, y), Offset(tableRight, y), edge);
    }
  }

  (int, int) _rowRange(double top, double bottom) {
    const height = OverviewGrid.rowHeight;
    final first = ((top - OverviewGrid.headerHeight) / height).floor();
    final last = ((bottom - OverviewGrid.headerHeight) / height).ceil();
    return (
      first.clamp(0, grid.bodyRowCount),
      last.clamp(0, grid.bodyRowCount),
    );
  }

  (int, int) _columnRange(double left, double right) {
    final offsets = grid.columnOffsets;
    var first = 0;
    while (first < grid.columnCount && offsets[first + 1] <= left) {
      first++;
    }
    var last = first;
    while (last < grid.columnCount && offsets[last] < right) {
      last++;
    }
    return (first, last);
  }

  void _paintHeader(Canvas canvas, (int, int) columns, bool withText) {
    final (start, end) = columns;
    for (var c = start; c < end; c++) {
      final rect = Rect.fromLTWH(
        grid.columnOffsets[c],
        0,
        grid.columnWidths[c],
        OverviewGrid.headerHeight,
      );
      canvas.drawRect(rect, Paint()..color = palette.headerBackground);
      if (grid.highlightedColumns.contains(c)) {
        canvas.drawRect(
          rect,
          Paint()..color = palette.highlight.withValues(alpha: 0.35),
        );
      }
      _paintLines(canvas, rect);
      if (withText) _paintText(canvas, rect, text.header(c));
    }
  }

  void _paintBody(
    Canvas canvas,
    (int, int) rows,
    (int, int) columns,
    bool withText,
  ) {
    final (rowStart, rowEnd) = rows;
    final (columnStart, columnEnd) = columns;
    for (var r = rowStart; r < rowEnd; r++) {
      final footer = grid.isFooter(r);
      final background = footer
          ? palette.footerBackground
          : r.isEven
          ? palette.rowEven
          : palette.rowOdd;
      final cells = grid.bodyRow(r);
      final top = grid.bodyRowTop(r);
      for (var c = columnStart; c < columnEnd; c++) {
        final rect = Rect.fromLTWH(
          grid.columnOffsets[c],
          top,
          grid.columnWidths[c],
          OverviewGrid.rowHeight,
        );
        canvas.drawRect(rect, Paint()..color = background);
        if (!footer && grid.highlightedColumns.contains(c)) {
          canvas.drawRect(
            rect,
            Paint()..color = palette.highlight.withValues(alpha: 0.10),
          );
        }
        final tint = c < cells.length ? cells[c].tint : null;
        if (tint != null && !footer) {
          canvas.drawRect(rect, Paint()..color = tint.withValues(alpha: 0.16));
        }
        _paintLines(canvas, rect);
        if (withText) _paintText(canvas, rect, text.body(r, c));
      }
    }
  }

  void _paintLines(Canvas canvas, Rect rect) {
    final line = Paint()
      ..color = palette.gridLine
      ..strokeWidth = 0.6;
    canvas.drawLine(rect.topRight, rect.bottomRight, line);
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, line);
  }

  void _paintText(Canvas canvas, Rect rect, TextPainter? painter) {
    if (painter == null) return;
    painter.paint(
      canvas,
      Offset(
        rect.left + OverviewGrid.paddingFor(rect.width),
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.text != text || old.controller != controller;
}
