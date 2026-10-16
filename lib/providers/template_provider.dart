import 'package:flutter/foundation.dart';
import 'package:table_note/models/tabel_model.dart';

import '../data/example_templates.dart';
import '../services/storage_service.dart';
import '../config/plan_limits.dart';

class TemplateProvider extends ChangeNotifier {
  List<TemplateModel> _templates = [];
  bool _isLoading = false;

  /// Hazır örneklerden silinenler ve düzenlenenlerin son hali.
  Set<String> _hiddenExamples = {};
  Map<String, TemplateModel> _editedExamples = {};

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
    final examples = await StorageService.loadExampleTemplateChanges();
    _hiddenExamples = examples.hidden;
    _editedExamples = examples.edited;

    _isLoading = false;
    notifyListeners();
  }

  /// Uygulamayla gelen örneklerin kimliği "example-" ile başlar.
  static bool isExample(String id) => id.startsWith('example-');

  /// Listede görünen hazır örnekler. Düzenlenmemiş olanlar uygulamanın
  /// diliyle değişir; düzenlenen örnek kullanıcının yazdığı gibi kalır.
  /// Örnekler ücretsiz şablon sınırına sayılmaz.
  List<TemplateModel> examples(String languageCode) => [
    for (final example in exampleTemplates(languageCode))
      if (!_hiddenExamples.contains(example.id))
        _editedExamples[example.id] ?? example,
  ];

  bool get hasHiddenExamples => _hiddenExamples.isNotEmpty;

  /// Silinen örnekleri ([id] verilirse yalnızca onu) geri getirir;
  /// düzenlenmiş olanlar düzenlendiği gibi döner.
  Future<void> restoreExamples({String? id}) async {
    _hiddenExamples = id == null ? {} : ({..._hiddenExamples}..remove(id));
    notifyListeners();
    await _saveExamples();
  }

  Future<bool> _saveExamples() => StorageService.saveExampleTemplateChanges(
    hidden: _hiddenExamples,
    edited: _editedExamples,
  );

  Future<void> _saveTemplates() async {
    await StorageService.saveTemplates(_templates);
  }

  // Template oluştur
  Future<bool> createTemplate(
    String templateName,
    List<ColumnModel> columns, {
    bool isPremium = false,
  }) async {
    try {
      if (!isPremium && _templates.length >= PlanLimits.freeTemplates) {
        return false;
      }
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

  // Template sil: hazır örnek gizlenir, kullanıcının şablonu silinir.
  Future<bool> deleteTemplate(String id) async {
    try {
      if (isExample(id)) {
        _hiddenExamples = {..._hiddenExamples, id};
        notifyListeners();
        return await _saveExamples();
      }
      final index = _templates.indexWhere((template) => template.id == id);
      if (index == -1) return false;
      _templates.removeAt(index);
      await _saveTemplates();
      notifyListeners();
      return true;
    } catch (e) {
      print('Template silinirken hata: $e');
      return false;
    }
  }

  // Template güncelle: hazır örnek de kullanıcının şablonu gibi düzenlenir.
  Future<bool> updateTemplate(
    String id,
    String newName,
    List<ColumnModel> newColumns,
  ) async {
    try {
      if (isExample(id)) {
        final createdAt = _editedExamples[id]?.createdAt;
        _editedExamples = {
          ..._editedExamples,
          id: TemplateModel(
            id: id,
            templateName: newName.trim(),
            columns: newColumns,
            createdAt: createdAt,
            updatedAt: DateTime.now(),
          ),
        };
        notifyListeners();
        return await _saveExamples();
      }
      final index = _templates.indexWhere((template) => template.id == id);
      if (index == -1) return false;
      final oldTemplate = _templates[index];
      _templates[index] = TemplateModel(
        id: oldTemplate.id,
        templateName: newName.trim(),
        columns: newColumns,
        createdAt: oldTemplate.createdAt,
        updatedAt: DateTime.now(),
      );
      await _saveTemplates();
      notifyListeners();
      return true;
    } catch (e) {
      print('Template güncellenirken hata: $e');
      return false;
    }
  }
}
