import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_note/models/tabel_model.dart';
import 'package:table_note/services/formula_service.dart';
import '../providers/table_provider.dart';
import '../theme/app_theme.dart';

class AddRowDialog extends StatefulWidget {
  const AddRowDialog({Key? key}) : super(key: key);

  @override
  State<AddRowDialog> createState() => _AddRowDialogState();
}

class _AddRowDialogState extends State<AddRowDialog> {
  List<TextEditingController> _controllers = [];
  late List<ColumnModel> _columns;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TableProvider>(context, listen: false);
    _columns = provider.currentTable!.columns;
    
    // Mevcut satır sayısı (sıra no için)
    final currentRowCount = provider.currentTable!.rows.length;

    // Her sütun için controller oluştur
    for (int i = 0; i < _columns.length; i++) {
      final col = _columns[i];
      final controller = TextEditingController();

      // Sabit değer sütunu ise varsayılan değeri ata
      if (col.isConstant && col.constantValue != null) {
        controller.text = _formatNumber(col.constantValue!);
      }
      // Tarih sütunu ise bugünün tarihini ata
      else if (col.isDate) {
        controller.text = _getCurrentDateFormatted();
      }
      // Saat sütunu ise şu anki saati ata
      else if (col.isTime) {
        controller.text = _getCurrentTimeFormatted();
      }
      // Otomatik sıra numarası
      else if (col.isAutoNumber) {
        controller.text = (currentRowCount + 1).toString();
      }

      _controllers.add(controller);
    }

    // İlk formül hesaplaması
    _recalculateFormulas();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Formülleri yeniden hesapla
  // Birden fazla geçiş yaparak bağımlı formülleri doğru hesapla
  void _recalculateFormulas() {
    // Formül sütunu sayısı kadar geçiş yap (en kötü durumda zincir uzunluğu)
    final formulaCount = _columns.where((c) => c.isFormula).length;
    
    for (int pass = 0; pass < formulaCount; pass++) {
      // Her geçişte güncel rowData'yı al
      final rowData = _controllers.map((c) => c.text).toList();
      
      for (int i = 0; i < _columns.length; i++) {
        final col = _columns[i];
        if (col.isFormula && col.formula != null) {
          final result = FormulaService.calculate(col.formula!, rowData, _columns);
          if (result != null) {
            _controllers[i].text = _formatNumber(result);
          }
        }
      }
    }
  }

  String _formatNumber(double value) {
    // Tam sayı ise ondalık gösterme
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    // 2 ondalık basamak
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add_rounded, color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Yeni Kayıt Ekle',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _columns.asMap().entries.map((entry) {
              final colIndex = entry.key;
              final column = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _buildInputField(colIndex, column),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Ekle'),
          onPressed: _addRow,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(int colIndex, ColumnModel column) {
    // Formül sütunu - sadece okunur
    if (column.isFormula) {
      return _buildFormulaField(colIndex, column);
    }

    // Sabit değer sütunu - düzenlenebilir ama varsayılan gelir
    if (column.isConstant) {
      return _buildConstantField(colIndex, column);
    }

    // Tarih sütunu
    if (column.isDate) {
      return _buildDateField(colIndex, column);
    }

    // Saat sütunu
    if (column.isTime) {
      return _buildTimeField(colIndex, column);
    }

    // Otomatik sıra numarası
    if (column.isAutoNumber) {
      return _buildAutoNumberField(colIndex, column);
    }

    // Normal sütun
    return _buildNormalField(colIndex, column);
  }

  Widget _buildNormalField(int colIndex, ColumnModel column) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controllers[colIndex],
          decoration: InputDecoration(
            labelText: column.name,
            border: const OutlineInputBorder(),
            prefixIcon: Icon(
              column.isNumeric ? Icons.numbers : Icons.text_fields,
              color: column.isNumeric ? Colors.green : Colors.blue,
            ),
            suffixIcon: column.autoFillOptions.isNotEmpty
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: 'Hızlı Seç',
                    onSelected: (value) {
                      _controllers[colIndex].text = value;
                      _recalculateFormulas();
                      setState(() {});
                    },
                    itemBuilder: (context) {
                      return column.autoFillOptions.map((option) {
                        return PopupMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList();
                    },
                  )
                : null,
          ),
          keyboardType: column.isNumeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          onChanged: (value) {
            _recalculateFormulas();
            setState(() {});
          },
        ),

        // Hızlı seçim chip'leri
        if (column.autoFillOptions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: column.autoFillOptions.map((option) {
              final isSelected = _controllers[colIndex].text == option;
              return GestureDetector(
                onTap: () {
                  _controllers[colIndex].text = option;
                  _recalculateFormulas();
                  setState(() {});
                },
                child: Chip(
                  label: Text(
                    option, 
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  backgroundColor: isSelected ? AppTheme.lightBlue : AppTheme.background,
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildConstantField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.pin, color: Colors.orange),
        suffixIcon: Tooltip(
          message: 'Varsayılan: ${_formatNumber(column.constantValue ?? 0)}',
          child: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: () {
              _controllers[colIndex].text = _formatNumber(column.constantValue ?? 0);
              _recalculateFormulas();
              setState(() {});
            },
          ),
        ),
        helperText: 'Varsayılan: ${_formatNumber(column.constantValue ?? 0)}',
        helperStyle: TextStyle(color: Colors.orange[700]),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (value) {
        _recalculateFormulas();
        setState(() {});
      },
    );
  }

  Widget _buildFormulaField(int colIndex, ColumnModel column) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.functions, color: Colors.purple[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  column.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controllers[colIndex].text.isEmpty
                      ? 'Hesaplanıyor...'
                      : _controllers[colIndex].text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[900],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Formül: ${FormulaService.formatFormula(column.formula ?? '')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.purple[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Otomatik',
              style: TextStyle(
                fontSize: 11,
                color: Colors.purple[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today, color: Colors.teal),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.today, color: Colors.teal),
              onPressed: () {
                _controllers[colIndex].text = _getCurrentDateFormatted();
                setState(() {});
              },
              tooltip: 'Bugün',
            ),
            IconButton(
              icon: const Icon(Icons.edit_calendar, color: Colors.teal),
              onPressed: () => _selectDate(colIndex),
              tooltip: 'Tarih Seç',
            ),
          ],
        ),
        helperText: 'Bugünün tarihi otomatik geldi',
        helperStyle: TextStyle(color: Colors.teal[600]),
      ),
      readOnly: true,
      onTap: () => _selectDate(colIndex),
    );
  }

  Widget _buildTimeField(int colIndex, ColumnModel column) {
    return TextField(
      controller: _controllers[colIndex],
      decoration: InputDecoration(
        labelText: column.name,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.access_time, color: Colors.indigo),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.update, color: Colors.indigo),
              onPressed: () {
                _controllers[colIndex].text = _getCurrentTimeFormatted();
                setState(() {});
              },
              tooltip: 'Şu an',
            ),
            IconButton(
              icon: const Icon(Icons.more_time, color: Colors.indigo),
              onPressed: () => _selectTime(colIndex),
              tooltip: 'Saat Seç',
            ),
          ],
        ),
        helperText: 'Şu anki saat otomatik geldi',
        helperStyle: TextStyle(color: Colors.indigo[600]),
      ),
      readOnly: true,
      onTap: () => _selectTime(colIndex),
    );
  }

  Widget _buildAutoNumberField(int colIndex, ColumnModel column) {
    return Container(
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
                  column.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _controllers[colIndex].text,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[900],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.brown[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Otomatik',
              style: TextStyle(
                fontSize: 11,
                color: Colors.brown[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(int colIndex) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      _controllers[colIndex].text = 
          '${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}';
      setState(() {});
    }
  }

  Future<void> _selectTime(int colIndex) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _controllers[colIndex].text = 
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  String _getCurrentDateFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
  }

  String _getCurrentTimeFormatted() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _addRow() async {
    // Son kez formülleri hesapla
    _recalculateFormulas();

    final provider = Provider.of<TableProvider>(context, listen: false);
    final rowData = _controllers.map((controller) => controller.text.trim()).toList();

    final success = await provider.addRow(rowData);

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt eklenemedi')),
      );
    }
  }
}