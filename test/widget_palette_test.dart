import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_note/models/home_widget_snapshot.dart';
import 'package:table_note/models/tally_model.dart';
import 'package:table_note/theme/app_theme.dart';

const _amber = 0xFFFFC107;

int _alpha(int argb) => (argb >> 24) & 0xFF;
int _rgb(int argb) => argb & 0xFFFFFF;

void main() {
  test('palet uygulamanın kendi renklerini taşır', () {
    final light = AppTheme.widgetPalette(AppTheme.theme);
    final dark = AppTheme.widgetPalette(AppTheme.darkTheme);

    // The tally paints today amber in both themes; the widget used to use blue.
    for (final palette in [light, dark]) {
      expect(_rgb(palette['todayHeader']!), _rgb(_amber));
      expect(_rgb(palette['todayCell']!), _rgb(_amber));
      // The header wash is stronger than the one behind the cells.
      expect(
        _alpha(palette['todayHeader']!),
        greaterThan(_alpha(palette['todayCell']!)),
      );
    }

    // Header, rows and text all flip with the theme, so the widget follows the
    // app's own light/dark switch rather than the system's.
    for (final key in ['background', 'header', 'onHeader', 'rowEven', 'text']) {
      expect(light[key], isNot(dark[key]), reason: key);
    }
    // Zebra rows need two distinguishable shades in both themes.
    expect(light['rowEven'], isNot(light['rowOdd']));
    expect(dark['rowEven'], isNot(dark['rowOdd']));
  });

  test('okunur mürekkep koyu ve açık temada ayrışır', () {
    const green = Color(0xFF2E7D32);
    final onLight = AppTheme.readableInk(green, dark: false);
    final onDark = AppTheme.readableInk(green, dark: true);

    expect(onLight, isNot(onDark));
    // Dark themes need the lighter variant to stay legible.
    expect(
      HSLColor.fromColor(onDark).lightness,
      greaterThan(HSLColor.fromColor(onLight).lightness),
    );
  });

  test('çetele işaretleri hem zemin hem mürekkep rengiyle gider', () {
    final data =
        jsonDecode(
              HomeWidgetSnapshot.encode(
                tables: const [],
                tallies: [
                  TallyTableModel(
                    id: 'c1',
                    tableName: 'yoklama',
                    startDate: DateTime(2026, 9, 1),
                    endDate: DateTime(2026, 9, 3),
                    statuses: [
                      TallyStatus(
                        code: 'V',
                        label: 'Var',
                        colorValue: 0xFF4CAF50,
                      ),
                    ],
                    items: [
                      TallyItemModel(name: 'Ali', entries: {'2026-09-02': 'V'}),
                    ],
                  ),
                ],
                language: 'tr',
                dark: false,
                palette: AppTheme.widgetPalette(AppTheme.theme),
              ),
            )
            as Map<String, dynamic>;

    expect(data['palette'], isNotEmpty);
    final row = (data['entries'][0]['rows'] as List).first;
    final marked = (row['colors'] as List).indexWhere((color) => color != null);
    expect(marked, greaterThan(0));
    // The raw status colour tints the cell; the ink is what the code is drawn
    // in, and the app darkens it for a light theme.
    expect(row['colors'][marked], 0xFF4CAF50);
    // This green is too light to read on a light background, so the ink must
    // differ from the tint; a colour already in range is left alone.
    expect(row['inks'][marked], isNot(0xFF4CAF50));
    expect(
      row['inks'][marked],
      AppTheme.readableInk(const Color(0xFF4CAF50), dark: false).toARGB32(),
    );
  });
}
