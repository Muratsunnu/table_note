import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../services/home_widget_service.dart';

class HomeWidgetHelpScreen extends StatelessWidget {
  const HomeWidgetHelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final tr = AppLocalizations.of(context).locale.languageCode != 'en';
    final service = context.watch<HomeWidgetService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr ? 'Ana ekran widget’ı' : 'Home screen widget'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            tr ? 'Tablon bir dokunuş uzağında' : 'Your table, one tap away',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            tr
                ? 'Tablo veya çeteleni seç. Kayıt sayısını ve istersen bir sütun/durum toplamını gör. + düğmesi kayıt ekleme formunu açar.'
                : 'Choose a table or tally. See its record count and an optional column/status total. The + button opens the add form.',
          ),
          const SizedBox(height: 24),
          Text('Android', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            tr
                ? 'Ana ekranda boş bir yere basılı tut → Widget’lar → Table Note. Widget’ı yerleştir, tabloyu ve özeti seç. Dişli simgesiyle seçimi değiştirebilirsin.'
                : 'Touch and hold an empty area on your home screen → Widgets → Table Note. Place the widget, then choose a table and summary. Use its settings icon to change your selection.',
          ),
          const SizedBox(height: 24),
          Text('iOS 17+', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            tr
                ? 'Ana ekranda boş bir yere basılı tut → Düzenle / Widget Ekle → Table Note. Ekledikten sonra widget’a basılı tut → Widget’ı Düzenle → Tablo ve özeti seç.'
                : 'Touch and hold your home screen → Edit / Add Widget → Table Note. After adding it, touch and hold the widget → Edit Widget → choose the table and summary.',
          ),
          const SizedBox(height: 24),
          Text(
            tr
                ? 'Birden fazla widget, farklı tablolar gösterebilir. Özetler uygulamadaki tüm kayıtları kapsar; arama filtresinden etkilenmez. Değişiklikler kaydedilince güncelleme istenir; görünme zamanını işletim sistemi belirler.'
                : 'Multiple widgets can show different tables. Summaries cover all records, regardless of the search filter. Saved changes request a refresh; the operating system controls when it appears.',
          ),
          const SizedBox(height: 16),
          Text(
            tr
                ? 'Widget’ta görünen tablo adı ve toplamlar telefonun ana ekranından okunabilir. Açık bir form varsa widget isteği, form kapatılana kadar bekler.'
                : 'The table name and totals are visible on your home screen. If a form is open, a widget request waits until you close it.',
          ),
          if (service.syncError != null) ...[
            const SizedBox(height: 16),
            Text(
              tr
                  ? 'Widget verisi aktarılamadı. Yeni uygulama sürümünün kurulu olduğundan emin ol. iOS’ta App Group yetkisi de etkin olmalı.'
                  : 'Widget data could not be shared. Install the updated app. On iOS, App Group access must also be enabled.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
