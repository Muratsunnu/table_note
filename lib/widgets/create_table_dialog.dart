import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/services/formula_service.dart';
import '../providers/table_provider.dart';
import '../providers/template_provider.dart';
import '../theme/app_theme.dart';

class CreateTableDialog extends StatefulWidget {
  const CreateTableDialog({Key? key}) : super(key: key);

  @override
  State<CreateTableDialog> createState() => _CreateTableDialogState();
}

class _CreateTableDialogState extends State<CreateTableDialog>
    with SingleTickerProviderStateMixin {
  final _tableNameController = TextEditingController();
  final List<ColumnModel> _columns = [ColumnModel(name: '')];

  // Controller listeleri
  final List<TextEditingController> _columnControllers = [];
  final List<TextEditingController> _autoFillControllers = [];
  final List<TextEditingController> _constantValueControllers = [];
  final List<TextEditingController> _formulaControllers = [];
  final List<bool> _showAutoFill = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllersForColumn(_columns[0]);
  }

  void _initializeControllersForColumn(ColumnModel col) {
    _columnControllers.add(TextEditingController(text: col.name));
    _autoFillControllers.add(TextEditingController(text: col.autoFillOptions.join(', ')));
    _constantValueControllers.add(TextEditingController(
      text: col.constantValue?.toString() ?? '',
    ));
    _formulaControllers.add(TextEditingController(text: col.formula ?? ''));
    _showAutoFill.add(col.autoFillOptions.isNotEmpty);
  }

  @override
  void dispose() {
    _tableNameController.dispose();
    _tabController.dispose();
    for (var c in _columnControllers) c.dispose();
    for (var c in _autoFillControllers) c.dispose();
    for (var c in _constantValueControllers) c.dispose();
    for (var c in _formulaControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildManualCreateTab(),
                  _buildTemplateTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.darkBlue, AppTheme.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Yeni Tablo Oluştur',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryBlue,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primaryBlue,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Manuel Oluştur'),
                Tab(text: 'Şablondan Oluştur'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tablo adı
          TextField(
            controller: _tableNameController,
            decoration: InputDecoration(
              labelText: 'Tablo Adı',
              hintText: 'Örn: Sefer Kayıtları',
              prefixIcon: const Icon(Icons.table_chart_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // Sütunlar başlığı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.lightBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.view_column_rounded, size: 18, color: AppTheme.primaryBlue),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sütunlar',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('Yardım'),
                onPressed: _showHelpDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sütun kartları
          ..._buildColumnWidgets(),

          const SizedBox(height: 16),

          // Alt butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Sütun Ekle'),
                  onPressed: _addColumn,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Tablo Oluştur'),
                  onPressed: _createTable,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildColumnWidgets() {
    return _columns.asMap().entries.map((entry) {
      final index = entry.key;
      final column = entry.value;

      // Controller senkronizasyonu
      while (_columnControllers.length <= index) {
        _initializeControllersForColumn(ColumnModel(name: ''));
      }

      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sütun adı ve silme butonu
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _columnControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Sütun ${index + 1}',
                        hintText: 'Sütun adı',
                        border: const OutlineInputBorder(),
                        prefixIcon: _getColumnTypeIcon(column.columnType),
                      ),
                      onChanged: (value) {
                        setState(() => column.name = value);
                      },
                    ),
                  ),
                  if (_columns.length > 1) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _removeColumn(index),
                      tooltip: 'Sütunu Sil',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Sütun tipi seçimi
              _buildColumnTypeSelector(index, column),

              // Tipe göre ek ayarlar
              _buildColumnTypeSettings(index, column),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _getColumnTypeIcon(ColumnType type) {
    switch (type) {
      case ColumnType.normal:
        return const Icon(Icons.edit, color: Colors.blue);
      case ColumnType.constant:
        return const Icon(Icons.pin, color: Colors.orange);
      case ColumnType.formula:
        return const Icon(Icons.functions, color: Colors.purple);
      case ColumnType.date:
        return const Icon(Icons.calendar_today, color: Colors.teal);
      case ColumnType.time:
        return const Icon(Icons.access_time, color: Colors.indigo);
      case ColumnType.autoNumber:
        return const Icon(Icons.format_list_numbered, color: Colors.brown);
    }
  }

  Widget _buildColumnTypeSelector(int index, ColumnModel column) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sütun Tipi:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.normal,
                label: 'Normal',
                icon: Icons.edit,
                color: Colors.blue,
                tooltip: 'Manuel veri girişi',
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.constant,
                label: 'Sabit Değer',
                icon: Icons.pin,
                color: Colors.orange,
                tooltip: 'Varsayılan değer gelir',
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.formula,
                label: 'Formül',
                icon: Icons.functions,
                color: Colors.purple,
                tooltip: 'Otomatik hesaplanır',
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.date,
                label: 'Tarih',
                icon: Icons.calendar_today,
                color: Colors.teal,
                tooltip: 'Bugünün tarihi otomatik gelir',
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.time,
                label: 'Saat',
                icon: Icons.access_time,
                color: Colors.indigo,
                tooltip: 'Şu anki saat otomatik gelir',
              ),
              _buildTypeChip(
                index: index,
                column: column,
                type: ColumnType.autoNumber,
                label: 'Sıra No',
                icon: Icons.format_list_numbered,
                color: Colors.brown,
                tooltip: 'Otomatik artan numara',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required int index,
    required ColumnModel column,
    required ColumnType type,
    required String label,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    final isSelected = column.columnType == type;

    return Tooltip(
      message: tooltip,
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selectedColor: color,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              column.columnType = type;
              // Tip değişince ilgili alanları temizle
              if (type == ColumnType.normal) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = false;
              } else if (type == ColumnType.constant) {
                column.formula = null;
                column.isNumeric = true;
              } else if (type == ColumnType.formula) {
                column.constantValue = null;
                column.isNumeric = true;
              } else if (type == ColumnType.date || type == ColumnType.time) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = false;
              } else if (type == ColumnType.autoNumber) {
                column.constantValue = null;
                column.formula = null;
                column.isNumeric = true; // Sayısal olarak işaretliyoruz
              }
            });
          }
        },
      ),
    );
  }

  Widget _buildColumnTypeSettings(int index, ColumnModel column) {
    switch (column.columnType) {
      case ColumnType.normal:
        return _buildNormalColumnSettings(index, column);
      case ColumnType.constant:
        return _buildConstantColumnSettings(index, column);
      case ColumnType.formula:
        return _buildFormulaColumnSettings(index, column);
      case ColumnType.date:
        return _buildDateColumnSettings(column);
      case ColumnType.time:
        return _buildTimeColumnSettings(column);
      case ColumnType.autoNumber:
        return _buildAutoNumberColumnSettings(column);
    }
  }

  Widget _buildNormalColumnSettings(int index, ColumnModel column) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Sayısal checkbox
        CheckboxListTile(
          title: const Text('Sayısal Sütun'),
          subtitle: const Text('Bu sütundaki değerler toplanabilir'),
          value: column.isNumeric,
          onChanged: (value) {
            setState(() => column.isNumeric = value ?? false);
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),

        // Otomatik doldurma seçenekleri
        if (column.autoFillOptions.isNotEmpty || _showAutoFill[index]) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _autoFillControllers[index],
            decoration: InputDecoration(
              labelText: 'Hızlı Seçim Listesi',
              hintText: 'Virgülle ayırın (örn: İstanbul, Ankara)',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.list),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    column.autoFillOptions.clear();
                    _autoFillControllers[index].clear();
                    _showAutoFill[index] = false;
                  });
                },
              ),
            ),
            onChanged: (value) {
              column.autoFillOptions = value
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
            },
          ),
        ] else ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.list, size: 18),
            label: const Text('Hızlı Seçim Listesi Ekle'),
            onPressed: () => setState(() => _showAutoFill[index] = true),
          ),
        ],
      ],
    );
  }

  Widget _buildConstantColumnSettings(int index, ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu değer tüm satırlara varsayılan olarak gelir. Satır bazında değiştirilebilir.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _constantValueControllers[index],
                decoration: const InputDecoration(
                  labelText: 'Varsayılan Değer',
                  hintText: 'Örn: 0.2',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  column.constantValue = double.tryParse(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaColumnSettings(int index, ColumnModel column) {
    // Formülde kullanılabilecek sütunlar (kendisi hariç, sadece dolu isimli olanlar)
    final availableColumns = _columns
        .asMap()
        .entries
        .where((e) => e.key != index && e.value.name.trim().isNotEmpty)
        .map((e) => e.value)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu sütun diğer sütunlardan otomatik hesaplanır.',
                      style: TextStyle(fontSize: 12, color: Colors.purple[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Formül girişi
              TextField(
                controller: _formulaControllers[index],
                decoration: InputDecoration(
                  labelText: 'Formül',
                  hintText: 'Örn: {Kg}*{Birim Fiyat}',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.functions),
                  helperText: 'İşlemler: + - * / % (yüzde)',
                  helperMaxLines: 2,
                ),
                onChanged: (value) {
                  column.formula = value;
                },
              ),
              const SizedBox(height: 12),

              // Kullanılabilir sütunlar
              if (availableColumns.isNotEmpty) ...[
                const Text(
                  'Sütun eklemek için tıklayın:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availableColumns.map((col) {
                    return ActionChip(
                      avatar: Icon(
                        col.isEffectivelyNumeric ? Icons.numbers : Icons.text_fields,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      label: Text(
                        col.name, 
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      backgroundColor: AppTheme.lightBlue,
                      side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                      onPressed: () {
                        final currentText = _formulaControllers[index].text;
                        _formulaControllers[index].text = '$currentText{${col.name}}';
                        column.formula = _formulaControllers[index].text;
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],

              // İşlem butonları
              const Text(
                'İşlem ekle:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildOperatorChip(index, column, '+', 'Toplama'),
                  _buildOperatorChip(index, column, '-', 'Çıkarma'),
                  _buildOperatorChip(index, column, '*', 'Çarpma'),
                  _buildOperatorChip(index, column, '/', 'Bölme'),
                  _buildOperatorChip(index, column, '%', 'Yüzde'),
                  _buildOperatorChip(index, column, '(', 'Parantez Aç'),
                  _buildOperatorChip(index, column, ')', 'Parantez Kapat'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorChip(int index, ColumnModel column, String op, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: ActionChip(
        label: Text(
          op,
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
            color: AppTheme.formula,
          ),
        ),
        backgroundColor: AppTheme.formulaLight,
        side: BorderSide(color: AppTheme.formula.withOpacity(0.3)),
        onPressed: () {
          final currentText = _formulaControllers[index].text;
          _formulaControllers[index].text = '$currentText$op';
          column.formula = _formulaControllers[index].text;
        },
      ),
    );
  }

  Widget _buildDateColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.teal[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.teal[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Otomatik Tarih',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yeni kayıt eklerken bugünün tarihi otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Örnek: ${_getCurrentDateFormatted()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.teal[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time, color: Colors.indigo[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Otomatik Saat',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Yeni kayıt eklerken şu anki saat otomatik gelir.\nİsterseniz değiştirebilirsiniz.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.indigo[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.indigo[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Örnek: ${_getCurrentTimeFormatted()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutoNumberColumnSettings(ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.brown[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.format_list_numbered, color: Colors.brown[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Otomatik Sıra Numarası',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.brown[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Her yeni kayıt için otomatik artan numara atanır.\n1, 2, 3, 4... şeklinde devam eder.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.brown[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.brown[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Örnek: 1, 2, 3, 4...',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.brown[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _addColumn() {
    setState(() {
      final newColumn = ColumnModel(name: '');
      _columns.add(newColumn);
      _initializeControllersForColumn(newColumn);
    });
  }

  void _removeColumn(int index) {
    setState(() {
      _columns.removeAt(index);
      _columnControllers[index].dispose();
      _columnControllers.removeAt(index);
      _autoFillControllers[index].dispose();
      _autoFillControllers.removeAt(index);
      _constantValueControllers[index].dispose();
      _constantValueControllers.removeAt(index);
      _formulaControllers[index].dispose();
      _formulaControllers.removeAt(index);
      _showAutoFill.removeAt(index);
    });
  }

  Future<void> _createTable() async {
    // Controller'lardan verileri senkronize et
    for (int i = 0; i < _columns.length; i++) {
      _columns[i].name = _columnControllers[i].text.trim();
      _columns[i].autoFillOptions = _autoFillControllers[i]
          .text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      _columns[i].constantValue = double.tryParse(_constantValueControllers[i].text);
      _columns[i].formula = _formulaControllers[i].text.trim().isEmpty
          ? null
          : _formulaControllers[i].text.trim();
    }

    final tableName = _tableNameController.text.trim();

    // Validasyon
    if (tableName.isEmpty) {
      _showErrorSnackBar('Tablo adı boş olamaz');
      return;
    }

    final validColumns = _columns.where((col) => col.name.isNotEmpty).toList();

    if (validColumns.isEmpty) {
      _showErrorSnackBar('En az bir sütun eklemelisiniz');
      return;
    }

    // Formül validasyonu
    for (final col in validColumns) {
      if (col.isFormula && (col.formula == null || col.formula!.isEmpty)) {
        _showErrorSnackBar('${col.name} sütunu için formül girilmeli');
        return;
      }
      if (col.isConstant && col.constantValue == null) {
        _showErrorSnackBar('${col.name} sütunu için varsayılan değer girilmeli');
        return;
      }
    }

    // Tablo oluştur
    final provider = Provider.of<TableProvider>(context, listen: false);
    final success = await provider.createTable(tableName, validColumns);

    if (success) {
      Navigator.pop(context);
    } else {
      _showErrorSnackBar('Tablo oluşturulamadı');
    }
  }

  Widget _buildTemplateTab() {
    return Consumer<TemplateProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!provider.hasTemplates) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.article_outlined, size: 60, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Henüz şablon yok',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.templates.length,
          itemBuilder: (context, index) {
            final template = provider.templates[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.table_chart, color: Colors.blue[700]),
                ),
                title: Text(
                  template.templateName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${template.columns.length} sütun'),
                onTap: () => _createTableFromTemplate(template),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  void _createTableFromTemplate(TemplateModel template) {
    final tableNameController = TextEditingController(text: template.templateName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablondan Tablo Oluştur'),
        content: TextField(
          controller: tableNameController,
          decoration: const InputDecoration(
            labelText: 'Tablo Adı',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tableNameController.text.trim().isNotEmpty) {
                final tableProvider = Provider.of<TableProvider>(context, listen: false);
                final success = await tableProvider.createTable(
                  tableNameController.text.trim(),
                  template.columns.map((c) => c.copyWith()).toList(),
                );
                Navigator.pop(ctx);
                Navigator.pop(context);
                if (!success) {
                  _showErrorSnackBar('Tablo oluşturulamadı');
                }
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Sütun Tipleri'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem(
                icon: Icons.edit,
                color: Colors.blue,
                title: 'Normal Sütun',
                description: 'Manuel veri girişi yapılır. Hızlı seçim listesi eklenebilir.',
              ),
              const Divider(),
              _buildHelpItem(
                icon: Icons.pin,
                color: Colors.orange,
                title: 'Sabit Değer Sütunu',
                description:
                    'Belirlediğiniz varsayılan değer tüm satırlara otomatik gelir. İsterseniz satır bazında değiştirebilirsiniz.',
              ),
              const Divider(),
              _buildHelpItem(
                icon: Icons.functions,
                color: Colors.purple,
                title: 'Formül Sütunu',
                description:
                    'Diğer sütunlardan otomatik hesaplanır. Desteklenen işlemler:\n'
                    '• + (toplama)\n'
                    '• - (çıkarma)\n'
                    '• * (çarpma)\n'
                    '• / (bölme)\n'
                    '• % (yüzde: {Fiyat}%18 = Fiyatın %18\'i)',
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Örnek Formüller:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              _buildFormulaExample('{Kg}*{Birim Fiyat}', 'Kg ile Birim Fiyatı çarp'),
              _buildFormulaExample('{Fiyat}+{Fiyat}%18', 'Fiyat + KDV'),
              _buildFormulaExample('{Brüt}-{Dara}', 'Net ağırlık'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaExample(String formula, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              formula,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.purple[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}