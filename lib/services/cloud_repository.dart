import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shared_row_operation.dart';
import '../models/tabel_model.dart';
import '../models/tally_model.dart';
import 'supabase_service.dart';

class CloudEntry {
  final String id;
  final String ownerId;
  final String kind;
  final String name;
  final Map<String, dynamic> payload;
  final DateTime updatedAt;
  final int revision;
  final bool collaborationEnabled;

  const CloudEntry({
    required this.id,
    required this.ownerId,
    required this.kind,
    required this.name,
    required this.payload,
    required this.updatedAt,
    required this.revision,
    required this.collaborationEnabled,
  });

  factory CloudEntry.fromJson(Map<String, dynamic> json) => CloudEntry(
    id: json['id'].toString(),
    ownerId: json['owner_id'].toString(),
    kind: json['table_kind'].toString(),
    name: json['name'].toString(),
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    updatedAt: DateTime.parse(json['updated_at'].toString()),
    revision: (json['revision'] as num?)?.toInt() ?? 1,
    collaborationEnabled: json['collaboration_enabled'] == true,
  );
}

/// Katilim denemesinin sonucu. Sahip kendi tablosunun koduyla girerse ad
/// istenmez ve [displayName] null doner.
class SharedTableJoin {
  final String tableId;
  final String? displayName;

  const SharedTableJoin({required this.tableId, this.displayName});
}

/// Sunucunun verdigi kod. Mesaj degil kod tasiyoruz ki kullaniciya gosterilen
/// metin uygulamanin diline uysun.
class SharedTableException implements Exception {
  final String code;

  const SharedTableException(this.code);

  /// Sunucunun bildigi kodlardan biri mi, yoksa beklenmeyen bir hata mi.
  bool get isKnown => const {
    'authentication_required',
    'invalid_table_code',
    'invalid_table_password',
    'owner_premium_required',
    'invalid_display_name',
    'display_name_taken',
    'too_many_attempts',
    'table_not_found',
    'password_too_short',
    'shared_table_needs_upgrade',
    'shared_table_locked_by_other',
    'shared_table_edit_access_required',
    'shared_table_revision_conflict',
  }.contains(code);

  @override
  String toString() => 'SharedTableException($code)';
}

class SharedTableMember {
  final String userId;
  final String? displayName;
  final String role;
  final DateTime joinedAt;

  const SharedTableMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  factory SharedTableMember.fromJson(Map<String, dynamic> json) =>
      SharedTableMember(
        userId: json['user_id'].toString(),
        displayName: json['display_name']?.toString(),
        role: json['role']?.toString() ?? 'editor',
        // Sunucu UTC gonderir; yerel saate cevrilmezse kullanici saatleri
        // kendi diliminden kaymis gorur.
        joinedAt:
            (DateTime.tryParse(json['joined_at']?.toString() ?? '') ??
                    DateTime.now())
                .toLocal(),
      );
}

/// Gunluk satiri. Ad, kaydin atildigi andaki addir; kisi sonra adini
/// degistirse de gecmis oldugu gibi kalir.
class TableActivityEntry {
  final int id;

  /// Kaydi atan kisinin kimligi. Ad yerine kimlige bakmak gerekir: sahibin
  /// profilinde ad olmayabilir ve sunucu o zaman 'bilinmeyen' yazar.
  final String? actorId;
  final String actorName;
  final String action;
  final String? rowId;
  final String? columnName;
  final String? oldValue;
  final String? newValue;
  final DateTime createdAt;

  const TableActivityEntry({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.rowId,
    required this.columnName,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
  });

  factory TableActivityEntry.fromJson(Map<String, dynamic> json) =>
      TableActivityEntry(
        id: (json['id'] as num?)?.toInt() ?? 0,
        actorId: json['actor_id']?.toString(),
        actorName: json['actor_name']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        rowId: json['row_id']?.toString(),
        columnName: json['column_name']?.toString(),
        oldValue: json['old_value']?.toString(),
        newValue: json['new_value']?.toString(),
        createdAt:
            (DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                    DateTime.now())
                .toLocal(),
      );
}

/// Ortak tablonun sunucudaki son hali.
class SharedTableSnapshot {
  final int revision;
  final Map<String, dynamic> payload;

  const SharedTableSnapshot({required this.revision, required this.payload});
}

/// Satir gonderiminin sonucu. Uygulananlar kuyruktan duser; cakisanlar
/// kullanici karar verene kadar bekler.
class SharedRowSyncResult {
  final int revision;
  final List<String> applied;
  final List<SharedRowConflict> conflicts;
  final Map<String, dynamic>? payload;

  const SharedRowSyncResult({
    required this.revision,
    required this.applied,
    required this.conflicts,
    this.payload,
  });

  bool get hasConflicts => conflicts.isNotEmpty;

  factory SharedRowSyncResult.fromJson(Map<String, dynamic> json) =>
      SharedRowSyncResult(
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        applied: [
          for (final id in (json['applied'] as List? ?? const []))
            id.toString(),
        ],
        conflicts: [
          for (final item in (json['conflicts'] as List? ?? const []))
            SharedRowConflict.fromJson(Map<String, dynamic>.from(item as Map)),
        ],
        payload: json['payload'] == null
            ? null
            : Map<String, dynamic>.from(json['payload'] as Map),
      );
}

/// Sunucunun uygulamadigi bir satir ve kayittaki hali.
class SharedRowConflict {
  final String rowId;

  /// 'changed' baskasi ayni satiri degistirdi, 'deleted' satiri sildi.
  final String reason;
  final List<String>? current;

  const SharedRowConflict({
    required this.rowId,
    required this.reason,
    this.current,
  });

  factory SharedRowConflict.fromJson(Map<String, dynamic> json) =>
      SharedRowConflict(
        rowId: json['rowId'].toString(),
        reason: json['reason']?.toString() ?? 'changed',
        current: json['current'] == null
            ? null
            : List<String>.from(
                (json['current'] as List).map((cell) => cell.toString()),
              ),
      );
}

class CloudRepository {
  dynamic get _client {
    final client = SupabaseService.client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Bulut işlemleri için giriş yapılmalı.');
    }
    return client;
  }

  Future<List<CloudEntry>> list() async {
    final rows = await _client
        .from('cloud_tables')
        .select(
          'id, owner_id, table_kind, name, payload, updated_at, '
          'revision, collaboration_enabled',
        )
        .order('updated_at', ascending: false);
    return (rows as List)
        .map((row) => CloudEntry.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> backupTables(
    List<TableModel> tables,
    List<TallyTableModel> tallies,
  ) async {
    final userId = _client.auth.currentUser!.id;
    final rows = <Map<String, dynamic>>[
      ...tables.map(
        (table) => {
          'id': table.id,
          'owner_id': userId,
          'table_kind': 'table',
          'name': table.tableName,
          'payload': table.toJson(),
          'schema_version': 2,
        },
      ),
      ...tallies.map(
        (table) => {
          'id': table.id,
          'owner_id': userId,
          'table_kind': 'tally',
          'name': table.tableName,
          'payload': table.toJson(),
          'schema_version': 2,
        },
      ),
    ];
    if (rows.isEmpty) return;

    // Ortak calisma acik tablolar kilitli RPC disinda yazilamaz. Genel yedekleme
    // akisi bu tablolari atlar; onlar "Tabloyu guncelle" akisi ile kaydedilir.
    final visibleRows = await _client
        .from('cloud_tables')
        .select('id, owner_id, collaboration_enabled');
    final blockedIds = (visibleRows as List)
        .map((row) => Map<String, dynamic>.from(row))
        .where(
          (row) =>
              row['owner_id']?.toString() != userId ||
              row['collaboration_enabled'] == true,
        )
        .map((row) => row['id'].toString())
        .toSet();
    final writableRows = rows
        .where((row) => !blockedIds.contains(row['id']))
        .toList();
    if (writableRows.isEmpty) return;
    await _client.from('cloud_tables').upsert(writableRows, onConflict: 'id');
  }

  Future<String> createShareCode(String tableId) async {
    final result = await _client.rpc(
      'create_share_invite',
      params: {
        'target_table_id': tableId,
        'valid_for': '7 days',
        'allowed_uses': 1,
      },
    );
    return result.toString();
  }

  /// Kodla (ve varsa sifreyle) tabloya katilir. Katilan kisinin Premium
  /// almasi gerekmez; sart tabloyu paylasan kisidedir.
  Future<SharedTableJoin> joinSharedTable({
    required String code,
    String? password,
    String? displayName,
  }) async {
    try {
      final result = await _client.rpc(
        'join_shared_table',
        params: {
          'plain_code': code.trim(),
          'plain_password': password?.trim().isEmpty == true
              ? null
              : password?.trim(),
          'display_name': displayName?.trim(),
        },
      );
      final map = _resultMap(result);
      return SharedTableJoin(
        tableId: map['tableId'].toString(),
        displayName: map['displayName']?.toString(),
      );
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Koda istege bagli sifre koyar; bos deger sifreyi kaldirir. Yalnizca
  /// tablo sahibi cagirabilir, dogrulama veritabaninda yapilir.
  Future<void> setSharedTablePassword(String tableId, String? password) async {
    try {
      await _client.rpc(
        'set_shared_table_password',
        params: {
          'target_table_id': tableId,
          'plain_password': password?.trim().isEmpty == true
              ? null
              : password?.trim(),
        },
      );
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Tablonun uyeleri. Sunucu yalnizca tablo sahibine liste dondurur.
  Future<List<SharedTableMember>> sharedTableMembers(String tableId) async {
    final result = await _client.rpc(
      'shared_table_members',
      params: {'target_table_id': tableId},
    );
    if (result is! List) return const [];
    return result
        .map(
          (row) =>
              SharedTableMember.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Degisiklik gunlugu, en yenisi basta. Sunucu bu tabloyu yalnizca sahibine
  /// okutur; baskasi cagirirsa bos liste doner.
  /// Ortak tablonun sunucudaki son halini indirir.
  ///
  /// list() butun tablolari cektigi icin tek bir tabloyu tazelemek adina
  /// israfti; burada yalnizca gereken iki alan isteniyor.
  Future<SharedTableSnapshot?> fetchSharedTable(String tableId) async {
    final row = await _client
        .from('cloud_tables')
        .select('payload, revision')
        .eq('id', tableId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is! Map) return null;
    return SharedTableSnapshot(
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      payload: Map<String, dynamic>.from(payload),
    );
  }

  /// Ortak tablonun sunucudaki surumunu canli izler.
  ///
  /// Yayin satirin tamamini tasiyor ama buradan yalnizca surum numarasi
  /// okunuyor; icerigi fetchSharedTable ile almak, indirmenin tek bir
  /// yoldan gecmesini sagliyor. O yolda "bekleyen degisiklik varsa
  /// dokunma" korumasi var ve onu atlamak veri kaybi olurdu.
  Stream<int> watchSharedTableRevision(String tableId) {
    final dynamic raw = _client
        .from('cloud_tables')
        .stream(primaryKey: ['id'])
        .eq('id', tableId);
    return (raw as Stream<List<Map<String, dynamic>>>).map((rows) {
      if (rows.isEmpty) return 0;
      return (rows.first['revision'] as num?)?.toInt() ?? 0;
    });
  }

  Future<List<TableActivityEntry>> tableActivity(
    String tableId, {
    int limit = 200,
  }) async {
    final rows = await _client
        .from('table_activity')
        .select()
        .eq('table_id', tableId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map(
          (row) => TableActivityEntry.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Bekleyen satir degisikliklerini birlestirerek gonderir. Kilit gerekmez:
  /// farkli satirlara dokunan iki kisi birbirini beklemez.
  Future<SharedRowSyncResult> applySharedTableRows(
    String tableId,
    List<SharedRowOperation> operations,
  ) async {
    try {
      final result = await _client.rpc(
        'apply_shared_table_rows',
        params: {
          'target_table_id': tableId,
          'operations': operations.map((op) => op.toJson()).toList(),
        },
      );
      return SharedRowSyncResult.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  Future<void> claimShareCode(String code) async {
    await _client.rpc(
      'claim_share_invite',
      params: {'plain_token': code.trim()},
    );
  }

  /// Ortak calismayi acar veya mevcut katilim kodunu yeniler.
  /// Kod sunucuda yalnizca hash olarak tutuldugu icin sadece bu cagri sonucunda
  /// gosterilebilir.
  Future<String> rotateSharedTableCode(String tableId) async {
    final result = await _client.rpc(
      'rotate_shared_table_join_code',
      params: {'target_table_id': tableId},
    );
    return result.toString();
  }

  Future<void> disableSharedTableCollaboration(String tableId) async {
    await _client.rpc(
      'disable_shared_table_collaboration',
      params: {'target_table_id': tableId},
    );
  }

  Map<String, dynamic> _resultMap(dynamic result) {
    if (result is Map) return Map<String, dynamic>.from(result);
    if (result is List && result.isNotEmpty && result.first is Map) {
      return Map<String, dynamic>.from(result.first as Map);
    }
    throw StateError('Supabase ortak tablo yaniti gecersiz.');
  }
}
