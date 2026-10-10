import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Yan çevrilmiş telefon gibi yüksekliği dar ekran. Bu durumda sekmeler ve
/// kayıt ekleme düğmesi yana alınır, başlıklar tek satıra iner; kalan
/// yükseklik tabloya kalır.
bool isCompactHeight(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 480;

/// Çocuğuna en az [minHeight] verir; yer daha azsa taşan kısmı keser.
/// Klavye açılıp tabloya neredeyse hiç yer kalmadığında taşma hatası yerine
/// tablonun üst kısmı görünür.
class MinHeightClip extends StatelessWidget {
  const MinHeightClip({
    super.key,
    required this.minHeight,
    required this.child,
  });

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = math.max(minHeight, constraints.maxHeight);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: height,
            maxHeight: height,
            child: child,
          ),
        );
      },
    );
  }
}
