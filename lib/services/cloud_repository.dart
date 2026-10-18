import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shared_row_operation.dart';
import '../models/shared_tally_operation.dart';
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
/// Kodun sunucudaki karsiligi. Katilim olusturmaz; arayuzun kodu, sifreyi ve
/// adi sirayla sorabilmesi icin.
class SharedTablePeek {
  final String tableName;
  final String kind;
  final bool requiresPassword;
  final bool passwordOk;

  const SharedTablePeek({
    required this.tableName,
    required this.kind,
    required this.requiresPassword,
    required this.passwordOk,
  });

  factory SharedTablePeek.fromJson(Map<String, dynamic> json) =>
      SharedTablePeek(
        tableName: json['tableName']?.toString() ?? '',
        kind: json['kind']?.toString() ?? 'table',
        requiresPassword: json['requiresPassword'] == true,
        passwordOk: json['passwordOk'] == true,
      );
}

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
    'table_owner_required',
    'member_not_found',
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

  /// 'viewer' ya da 'editor'.
  final String role;
  final DateTime joinedAt;

  /// Sahibin yanitini bekleyen bir duzenleme yetkisi talebi var mi.
  final bool editRequestOpen;

  const SharedTableMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.editRequestOpen = false,
  });

  bool get canEdit => role == 'editor';

  factory SharedTableMember.fromJson(Map<String, dynamic> json) =>
      SharedTableMember(
        userId: json['user_id'].toString(),
        displayName: json['display_name']?.toString(),
        // Bilinmeyen deger yetki vermez.
        role: json['role']?.toString() == 'editor' ? 'editor' : 'viewer',
        editRequestOpen: json['edit_request_open'] == true,
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
/// Bu cihazdaki kisinin bir ortak tablodaki yetkisi.
class SharedAccess {
  /// 'owner', 'editor', 'viewer'; artik uye degilse null.
  final String? role;

  /// Goruntuleyen kisinin yanit bekleyen bir talebi var mi.
  final bool editRequested;

  /// Yalnizca sahip icin: yanit bekleyen talep sayisi.
  final int pendingRequests;

  const SharedAccess({
    this.role,
    this.editRequested = false,
    this.pendingRequests = 0,
  });

  factory SharedAccess.fromJson(Map<String, dynamic> json) => SharedAccess(
    role: json['role']?.toString(),
    editRequested: json['editRequested'] == true,
    pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
  );
}

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

/// Sunucunun uygulamadigi bir cetele ogesi ve kayittaki hali.
class SharedTallyConflict {
  final String itemId;

  /// 'changed' baskasi ayni ogenin ayni gununu degistirdi, 'deleted' ogeyi
  /// sildi.
  final String reason;
  final TallyItemModel? current;

  const SharedTallyConflict({
    required this.itemId,
    required this.reason,
    this.current,
  });

  factory SharedTallyConflict.fromJson(Map<String, dynamic> json) =>
      SharedTallyConflict(
        itemId: json['itemId'].toString(),
        reason: json['reason']?.toString() ?? 'changed',
        current: json['current'] == null
            ? null
            : TallyItemModel.fromJson(
                Map<String, dynamic>.from(json['current'] as Map),
              ),
      );
}

/// Cetele oge gonderiminin sonucu.
class SharedTallySyncResult {
  final int revision;
  final List<String> applied;
  final List<SharedTallyConflict> conflicts;
  final Map<String, dynamic>? payload;

  const SharedTallySyncResult({
    required this.revision,
    required this.applied,
    required this.conflicts,
    this.payload,
  });

  bool get hasConflicts => conflicts.isNotEmpty;

  factory SharedTallySyncResult.fromJson(
    Map<String, dynamic> json,
  ) => SharedTallySyncResult(
    revision: (json['revision'] as num?)?.toInt() ?? 0,
    applied: [
      for (final id in (json['applied'] as List? ?? const [])) id.toString(),
    ],
    conflicts: [
      for (final item in (json['conflicts'] as List? ?? const []))
        SharedTallyConflict.fromJson(Map<String, dynamic>.from(item as Map)),
    ],
    payload: json['payload'] == null
        ? null
        : Map<String, dynamic>.from(json['payload'] as Map),
  );
}

/// Ortak tablonun sunucudaki son hali.
class SharedTableSnapshot {
  final int revision;
  final Map<String, dynamic> payload;

  /// Sunucudaki son degisiklik ani. Paylasim kapaliyken yuk, surum artmadan
  /// degisebilir; surumle birlikte buna da bakilir.
  final String? updatedAt;

  const SharedTableSnapshot({
    required this.revision,
    required this.payload,
    this.updatedAt,
  });
}

/// Tablonun yalnizca surum bilgisi: yuku indirmeden degisip degismedigini
/// anlamak icin.
class SharedTableVersion {
  final int revision;
  final String? updatedAt;

  const SharedTableVersion({required this.revision, this.updatedAt});
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
  /// Kodu (ve verilmisse sifreyi) dogrular, katilim olusturmaz.
  Future<SharedTablePeek> peekSharedTable({
    required String code,
    String? password,
  }) async {
    try {
      final result = await _client.rpc(
        'peek_shared_table',
        params: {
          'plain_code': code.trim(),
          'plain_password': (password == null || password.isEmpty)
              ? null
              : password,
        },
      );
      return SharedTablePeek.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

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
      // Rol ve talep bilgisini de doner; eski 'shared_table_members' yalnizca
      // ad ve tarihi veriyordu.
      'shared_table_member_roles',
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
        .select('payload, revision, updated_at')
        .eq('id', tableId)
        .maybeSingle();
    if (row == null) return null;
    final payload = row['payload'];
    if (payload is! Map) return null;
    return SharedTableSnapshot(
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      payload: Map<String, dynamic>.from(payload),
      updatedAt: row['updated_at']?.toString(),
    );
  }

  /// Yalnizca surum ve son degisiklik ani. Birkac yuz baytlik bir yanit;
  /// tablonun tamami ancak bu degismisse indirilir.
  Future<SharedTableVersion?> fetchSharedTableVersion(String tableId) async {
    final row = await _client
        .from('cloud_tables')
        .select('revision, updated_at')
        .eq('id', tableId)
        .maybeSingle();
    if (row == null) return null;
    return SharedTableVersion(
      revision: (row['revision'] as num?)?.toInt() ?? 0,
      updatedAt: row['updated_at']?.toString(),
    );
  }

  /// Ortak tablonun sunucudaki surumunu canli izler.
  ///
  /// Yayin satirin tamamini tasiyor ama buradan yalnizca surum numarasi
  /// okunuyor; icerigi fetchSharedTable ile almak, indirmenin tek bir
  /// yoldan gecmesini sagliyor. O yolda "bekleyen degisiklik varsa
  /// dokunma" korumasi var ve onu atlamak veri kaybi olurdu.
  /// Canli yayin baglantisi koptuktan sonra yeniden kuruldugunda yayinlanan
  /// deger: arada kacirilmis bir degisiklik olabilir, surum bilinmiyor.
  static const int revisionUnknown = -1;

  /// Tablonun surumu her degistiginde yeni surumu yayinlar.
  ///
  /// Bildirim YALNIZCA surum numarasini tasir. Eskiden satirin tamami
  /// geliyordu: her kayitta tabloyu acik tutan her cihaz butun tabloyu bir
  /// kez bildirimin icinde, bir kez de ardindan indirerek aliyordu. Ucretsiz
  /// planda tek mesaj en fazla 256 KB olabildigi icin buyuk bir tablonun
  /// bildirimi sigmayabiliyordu da.
  Stream<int> watchSharedTableRevision(String tableId) {
    final SupabaseClient client = _client;
    late final StreamController<int> controller;
    RealtimeChannel? channel;
    var subscribedOnce = false;
    controller = StreamController<int>(
      onListen: () {
        channel = client
            .channel('cloud-table-revision:$tableId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'cloud_tables',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: tableId,
              ),
              select: const ['revision'],
              callback: (payload) {
                final revision =
                    (payload.newRecord['revision'] as num?)?.toInt() ?? 0;
                if (!controller.isClosed) controller.add(revision);
              },
            )
            .subscribe((status, error) {
              if (controller.isClosed) return;
              if (status == RealtimeSubscribeStatus.subscribed) {
                // Ilk baglantida tablo zaten bir kez soruluyor. Sonrakiler
                // kopup yeniden kurulmus baglantidir.
                if (subscribedOnce) controller.add(revisionUnknown);
                subscribedOnce = true;
              } else if (error != null) {
                controller.addError(error);
              }
            });
      },
      onCancel: () async {
        final open = channel;
        channel = null;
        if (open != null) await client.removeChannel(open);
      },
    );
    return controller.stream;
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

  /// Tablo sutunlarini degistirir. Yalnizca sahip cagirabilir.
  ///
  /// Satirlar gonderilmez: sunucu mevcut satirlarin boyunu kendisi ayarlar.
  /// Istemcinin elindeki yuku butun halinde yazmak daha kolay olurdu ama o
  /// sirada katilan birinin kaydettigi satir, sahibin eski kopyasinda
  /// bulunmadigi icin silinirdi.
  Future<SharedRowSyncResult> applySharedTableColumns({
    required String tableId,
    required String name,
    required List<Map<String, dynamic>> columns,
  }) async {
    try {
      final result = await _client.rpc(
        'apply_shared_table_columns',
        params: {
          'target_table_id': tableId,
          'new_name': name,
          'new_columns': columns,
        },
      );
      return SharedRowSyncResult.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Cetele yapisini degistirir: durumlar, tarih araligi, ad. Ogelere
  /// dokunulmaz, cunku isaretler gun anahtariyla saklaniyor.
  Future<SharedRowSyncResult> applySharedTallyStructure({
    required String tallyId,
    required String name,
    required List<Map<String, dynamic>> statuses,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final result = await _client.rpc(
        'apply_shared_tally_structure',
        params: {
          'target_table_id': tallyId,
          'new_name': name,
          'new_statuses': statuses,
          'new_start': startDate,
          'new_end': endDate,
        },
      );
      return SharedRowSyncResult.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  Future<SharedTallySyncResult> applySharedTallyItems(
    String tallyId,
    List<SharedTallyOperation> operations,
  ) async {
    try {
      final result = await _client.rpc(
        'apply_shared_tally_items',
        params: {
          'target_table_id': tallyId,
          'operations': operations.map((op) => op.toJson()).toList(),
        },
      );
      return SharedTallySyncResult.fromJson(_resultMap(result));
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
  /// Tablonun katilim kodu. Yalnizca sahibine doner; kod hic uretilmediyse
  /// ya da bu degisiklikten once uretildiyse null.
  Future<String?> sharedTableJoinCode(String tableId) async {
    try {
      final result = await _client.rpc(
        'shared_table_join_code',
        params: {'target_table_id': tableId},
      );
      final code = result?.toString().trim();
      return (code == null || code.isEmpty) ? null : code;
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  Future<String> rotateSharedTableCode(String tableId) async {
    try {
      final result = await _client.rpc(
        'rotate_shared_table_join_code',
        params: {'target_table_id': tableId},
      );
      return result.toString();
    } on PostgrestException catch (error) {
      // Sunucunun soylediği neden (Premium yok, sahibi degilsin) kullaniciya
      // "bir seyler ters gitti" diye degil kendi adiyla gitsin.
      throw SharedTableException(error.message);
    }
  }

  /// Tabloyu ya da ceteleyi tek adimda paylasima acar ve katilim kodunu
  /// doner. Tablo ekranindaki "Paylas" dugmesi bunu cagirir.
  ///
  /// Kod, buluttaki satirin uzerinde durur; satir yoksa uretilecek yer de
  /// yoktur. Eskiden kullanicinin once Ayarlar > Bulut Yedekleme'den tum
  /// tablolarini yedeklemesi, sonra listeden bu tabloyu bulup paylasmasi
  /// gerekiyordu. Burada yalnizca bu tablo yuklenir.
  ///
  /// Tablo zaten paylasimdaysa kodu yenilenmez: yeni kod eskisini gecersiz
  /// kilar ve kodu daha once almis kisileri bosa dusururdu.
  Future<String> startSharing({
    TableModel? table,
    TallyTableModel? tally,
  }) async {
    assert((table == null) != (tally == null));
    final id = table?.id ?? tally!.id;
    try {
      await backupTables([?table], [?tally]);
    } on PostgrestException catch (error) {
      // Sunucu, Premium'u olmayan hesabin buluta yazmasini burada durdurur
      // ('owner_premium_required'). Neden, kod uretme adimina varmadan
      // kaybolmasin.
      throw SharedTableException(error.message);
    }
    return await sharedTableJoinCode(id) ?? await rotateSharedTableCode(id);
  }

  /// Bu cihazdaki kisinin tablodaki yetkisi. Sahip icin bekleyen talep
  /// sayisini da tasir.
  Future<SharedAccess> sharedTableAccess(String tableId) async {
    try {
      final result = await _client.rpc(
        'shared_table_access',
        params: {'target_table_id': tableId},
      );
      return SharedAccess.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Goruntuleyen kisi duzenleme yetkisi ister. Karari tablo sahibi verir.
  Future<SharedAccess> requestSharedEditAccess(String tableId) async {
    try {
      final result = await _client.rpc(
        'request_shared_edit_access',
        params: {'target_table_id': tableId},
      );
      return SharedAccess.fromJson(_resultMap(result));
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Sahip bir uyenin rolunu belirler: 'viewer' ya da 'editor'. Ayni rolu
  /// yeniden vermek, o uyenin acik talebini kapatir (reddetmek budur).
  Future<void> setSharedMemberRole(
    String tableId,
    String memberUserId,
    String role,
  ) async {
    try {
      await _client.rpc(
        'set_shared_member_role',
        params: {
          'target_table_id': tableId,
          'member_user_id': memberUserId,
          'new_role': role,
        },
      );
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
  }

  /// Katilinan tablodan ayrilir: sunucudaki uyelik silinir. Zaten uye
  /// olmayan icin sessizce basarilidir.
  Future<void> leaveSharedTable(String tableId) async {
    try {
      await _client.rpc(
        'leave_shared_table',
        params: {'target_table_id': tableId},
      );
    } on PostgrestException catch (error) {
      throw SharedTableException(error.message);
    }
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
