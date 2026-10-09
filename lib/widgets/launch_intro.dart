import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Açılış animasyonu: boş tablo belirir, beyaz kareler yukarıdan düşerek
/// logodaki T'yi kurar, sonra perde açılıp uygulama görünür.
///
/// Telefonun kendi açılış ekranı yalnızca düz mavidir; bu perde aynı maviyle
/// başladığı için geçiş fark edilmez. Uygulama perdenin arkasında çoktan
/// hazırdır: animasyon yüklemeyi bekletmez, yalnızca üstünü örter.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Kapalıysa perde hiç çizilmez (testler ve widget'tan hızlı açılış).
  final bool enabled;

  static const duration = Duration(milliseconds: 1400);

  /// Telefonun açılış ekranıyla aynı renk (res/values/colors.xml).
  static const background = Color(0xFF2563EB);

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  // Yalnızca animasyon oynatılacaksa kurulur.
  AnimationController? _controller;
  late bool _visible = widget.enabled;

  @override
  void initState() {
    super.initState();
    if (!_visible) return;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: LaunchIntro.duration,
    );
    // İlk kare uygulamanın kendisini kurar ve ağırdır; animasyon ondan sonra
    // başlar ki kareleri takılmadan aksın.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Hareketi azalt açıksa animasyon oynatılmaz.
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _visible = false);
        return;
      }
      controller.forward().whenComplete(() {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          // Perde kapalıyken arkadaki görünmeyen düğmelere dokunulmaz.
          AbsorbPointer(
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.light,
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('launch-intro'),
                  painter: _IntroPainter(_controller!),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bütün sahneyi tek tuvalde çizer; animasyon boyunca hiçbir widget yeniden
/// kurulmaz, yalnızca bu tuval boyanır.
class _IntroPainter extends CustomPainter {
  _IntroPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  // Logonun ölçüleri (tool/generate_logo.py): hücre 176, aralık 40, köşe 46.
  static const double _grid = 120;
  static const double _cell = _grid * 176 / 608;
  static const double _step = _grid * 216 / 608;
  static const double _corner = _grid * 46 / 608;
  static const double _ghost = 0.28;

  // Zaman çizelgesi, milisaniye.
  static const double _total = 1400;
  static const double _ghostIn = 240;
  static const double _dropTime = 420;
  static const double _dropDistance = 180;
  static const double _fadeStart = 1180;

  /// T'nin kareleri, düşme sırasıyla: önce gövde alttan yukarı, sonra üst sıra.
  static const _drops = <(int row, int column, double start)>[
    (2, 1, 120),
    (1, 1, 250),
    (0, 0, 420),
    (0, 1, 510),
    (0, 2, 600),
  ];

  /// Yavaşlayarak iner, yerini birkaç piksel geçip geri oturur. Taşma
  /// hücreler arasındaki boşluktan küçük tutulur ki alttaki kareye binmesin.
  static double _settle(double t) {
    const back = 0.8;
    final u = t - 1;
    return 1 + (back + 1) * u * u * u + back * u * u;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress.value * _total;
    // Sonda bütün perde birlikte solar ve uygulama görünür.
    final curtain =
        1 - ((time - _fadeStart) / (_total - _fadeStart)).clamp(0.0, 1.0);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = LaunchIntro.background.withValues(alpha: curtain),
    );

    final origin = Offset((size.width - _grid) / 2, (size.height - _grid) / 2);
    void cell(int row, int column, double opacity, [double lift = 0]) {
      if (opacity <= 0) return;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            origin.dx + column * _step,
            origin.dy + row * _step - lift,
            _cell,
            _cell,
          ),
          const Radius.circular(_corner),
        ),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }

    // Boş tablo: dokuz soluk hücre.
    final ghost = _ghost * (time / _ghostIn).clamp(0.0, 1.0) * curtain;
    for (var row = 0; row < 3; row++) {
      for (var column = 0; column < 3; column++) {
        cell(row, column, ghost);
      }
    }

    // Beyaz kareler yerlerine düşer.
    for (final (row, column, start) in _drops) {
      final local = ((time - start) / _dropTime).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final landed = _settle(local);
      cell(
        row,
        column,
        (local / 0.35).clamp(0.0, 1.0) * curtain,
        _dropDistance * (1 - landed),
      );
    }
  }

  @override
  bool shouldRepaint(_IntroPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
