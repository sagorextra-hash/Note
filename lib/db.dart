import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

typedef M = Map<String, Object?>;

class Db {
  Db._();
  static final Db i = Db._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'khata.db');
    return openDatabase(path, version: 1, onCreate: (d, v) async {
      await d.execute(
          'CREATE TABLE tx(id INTEGER PRIMARY KEY AUTOINCREMENT, book INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, category TEXT, method TEXT, note TEXT, date INTEGER NOT NULL)');
      await d.execute(
          'CREATE TABLE party(id INTEGER PRIMARY KEY AUTOINCREMENT, book INTEGER NOT NULL, name TEXT NOT NULL, phone TEXT)');
      await d.execute(
          'CREATE TABLE ledger(id INTEGER PRIMARY KEY AUTOINCREMENT, party_id INTEGER NOT NULL, type TEXT NOT NULL, amount REAL NOT NULL, note TEXT, date INTEGER NOT NULL)');
    });
  }

  (String, List<Object?>) _w(int book, int? from, int? to, [String? type]) {
    final c = <String>['book=?'];
    final a = <Object?>[book];
    if (from != null) {
      c.add('date>=?');
      a.add(from);
    }
    if (to != null) {
      c.add('date<?');
      a.add(to);
    }
    if (type != null) {
      c.add('type=?');
      a.add(type);
    }
    return (c.join(' AND '), a);
  }

  // ---------- আয়-ব্যয় ----------
  Future<int> insertTx(M m) async => (await db).insert('tx', m);

  Future<void> updateTx(int id, M m) async =>
      (await db).update('tx', m, where: 'id=?', whereArgs: [id]);

  Future<void> deleteTx(int id) async =>
      (await db).delete('tx', where: 'id=?', whereArgs: [id]);

  Future<List<M>> txList(int book,
      {int? from, int? to, String? type, int? limit}) async {
    final d = await db;
    final (w, a) = _w(book, from, to, type);
    return d.query('tx',
        where: w, whereArgs: a, orderBy: 'date DESC, id DESC', limit: limit);
  }

  Future<Map<String, double>> totals(int book, {int? from, int? to}) async {
    final d = await db;
    final (w, a) = _w(book, from, to);
    final r = await d.rawQuery(
        'SELECT type, SUM(amount) AS s FROM tx WHERE $w GROUP BY type', a);
    final m = <String, double>{'income': 0.0, 'expense': 0.0};
    for (final x in r) {
      m[x['type'] as String] = ((x['s'] as num?) ?? 0).toDouble();
    }
    return m;
  }

  Future<List<M>> catTotals(int book, String type, {int? from, int? to}) async {
    final d = await db;
    final (w, a) = _w(book, from, to, type);
    return d.rawQuery(
        'SELECT category, SUM(amount) AS s FROM tx WHERE $w GROUP BY category ORDER BY s DESC',
        a);
  }

  // ---------- পার্টি ----------
  Future<int> insertParty(M m) async => (await db).insert('party', m);

  Future<void> updateParty(int id, M m) async =>
      (await db).update('party', m, where: 'id=?', whereArgs: [id]);

  Future<void> deleteParty(int id) async {
    final d = await db;
    await d.delete('ledger', where: 'party_id=?', whereArgs: [id]);
    await d.delete('party', where: 'id=?', whereArgs: [id]);
  }

  Future<M?> partyById(int id) async {
    final r = await (await db).query('party', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<List<M>> partiesWithBal(int book) async {
    final d = await db;
    return d.rawQuery(
        "SELECT p.id, p.book, p.name, p.phone, COALESCE(SUM(CASE WHEN l.type='gave' THEN l.amount ELSE -l.amount END),0) AS bal FROM party p LEFT JOIN ledger l ON l.party_id=p.id WHERE p.book=? GROUP BY p.id ORDER BY p.name COLLATE NOCASE",
        [book]);
  }

  // ---------- লেজার ----------
  Future<int> insertLedger(M m) async => (await db).insert('ledger', m);

  Future<void> deleteLedger(int id) async =>
      (await db).delete('ledger', where: 'id=?', whereArgs: [id]);

  Future<List<M>> ledgerList(int partyId) async => (await db).query('ledger',
      where: 'party_id=?', whereArgs: [partyId], orderBy: 'date DESC, id DESC');

  // ---------- ব্যাকআপ ----------
  Future<String> exportJson() async {
    final d = await db;
    return jsonEncode({
      'app': 'khata',
      'version': 1,
      'tx': await d.query('tx'),
      'party': await d.query('party'),
      'ledger': await d.query('ledger'),
    });
  }

  Future<void> importJson(String s) async {
    final m = jsonDecode(s) as Map<String, dynamic>;
    if (m['app'] != 'khata') {
      throw const FormatException('ব্যাকআপ সঠিক নয়');
    }
    final d = await db;
    await d.transaction((t) async {
      await t.delete('tx');
      await t.delete('party');
      await t.delete('ledger');
      for (final k in ['tx', 'party', 'ledger']) {
        for (final r in (m[k] as List)) {
          await t.insert(k, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }
}
