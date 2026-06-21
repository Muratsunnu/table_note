import 'package:flutter/foundation.dart';
import '../models/tally_model.dart';
import '../services/storage_service.dart';

class TallyTemplateProvider extends ChangeNotifier {
  List<TallyTemplateModel> _templates = [];
  bool _isLoading = false;

  List<TallyTemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  bool get hasTemplates => _templates.isNotEmpty;

  TallyTemplateProvider() {
    _load();
  }

  Future<void> _load() async {
    _isLoading = true;
    notifyListeners();
    _templates = await StorageService.loadTallyTemplates();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _save() async {
    await StorageService.saveTallyTemplates(_templates);
  }

  Future<bool> createTemplate(TallyTemplateModel template) async {
    try {
      _templates.add(template);
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Çetele şablonu oluşturma hatası: $e');
      return false;
    }
  }

  Future<bool> updateTemplate(int index, TallyTemplateModel template) async {
    if (index < 0 || index >= _templates.length) return false;
    try {
      _templates[index] = template;
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Çetele şablonu güncelleme hatası: $e');
      return false;
    }
  }

  Future<bool> deleteTemplate(int index) async {
    if (index < 0 || index >= _templates.length) return false;
    try {
      _templates.removeAt(index);
      await _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Çetele şablonu silme hatası: $e');
      return false;
    }
  }
}
