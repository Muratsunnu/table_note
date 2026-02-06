import 'package:flutter/foundation.dart';
import 'package:table_note/models/tabel_model.dart';

import '../services/storage_service.dart';

class TemplateProvider extends ChangeNotifier {
  List<TemplateModel> _templates = [];
  bool _isLoading = false;

  List<TemplateModel> get templates => _templates;
  bool get isLoading => _isLoading;
  bool get hasTemplates => _templates.isNotEmpty;

  TemplateProvider() {
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    _isLoading = true;
    notifyListeners();
    
    _templates = await StorageService.loadTemplates();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveTemplates() async {
    await StorageService.saveTemplates(_templates);
  }

  // Template oluştur
  Future<bool> createTemplate(String templateName, List<ColumnModel> columns) async {
    try {
      final newTemplate = TemplateModel(
        templateName: templateName.trim(),
        columns: columns,
      );
      
      _templates.add(newTemplate);
      await _saveTemplates();
      notifyListeners();
      return true;
    } catch (e) {
      print('Template oluşturulurken hata: $e');
      return false;
    }
  }

  // Template sil
  Future<bool> deleteTemplate(int templateIndex) async {
    try {
      if (templateIndex >= 0 && templateIndex < _templates.length) {
        _templates.removeAt(templateIndex);
        await _saveTemplates();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Template silinirken hata: $e');
      return false;
    }
  }

  // Template güncelle
  Future<bool> updateTemplate(int templateIndex, String newName, List<ColumnModel> newColumns) async {
    try {
      if (templateIndex >= 0 && templateIndex < _templates.length) {
        _templates[templateIndex] = TemplateModel(
          templateName: newName.trim(),
          columns: newColumns,
        );
        await _saveTemplates();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Template güncellenirken hata: $e');
      return false;
    }
  }
}