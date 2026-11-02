import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'utils.dart';

// ======================= সাধারণ হেল্পার =======================

Future<bool> confirmDlg(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('না')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('হ্যাঁ')),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  const StatCard(this.title, this.value, this.color, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Flexible(child: Text(title, style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class TxTile extends StatelessWidget {
  final M t;
  final VoidCallback? onTap;
  const TxTile(this.t, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final inc = t['type'] == 'income';
    final color = inc ? kGreen : kRed;
    final note = (t['note'] as String?) ?? '';
    final method = (t['method'] as String?) ?? '';
    final amt = (t['amount'] as num).toDouble();
    final parts = <String>[
      fmtMs(t['date'] as int),
      if (method.isNotEmpty) method,
      if (note.isNotEmpty) note,
    ];
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(30),
        child: Icon(inc ? Icons.south_west : Icons.north_east, color: color),
      ),
      title: Text((t['category'] as String?) ?? ''),
      subtitle: Text(parts.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text('${inc ? '+' : '-'}${money(amt)}',
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15)),
    );
  }
}

// ======================= লক স্ক্রিন =======================

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  const LockScreen({super.key, required this.onUnlock});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final c = TextEditingController();
  bool err = false;

  Future<void> _check(String v) async {
    final e = toEn(v);
    if (e.length == 4) {
      final p = await SharedPreferences.getInstance();
      if (e == p.getString('pin')) {
        widget.onUnlock();
      } else {
        c.clear();
        setState(() => err = true);
      }
    } else if (err) {
      setState(() => err = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 64),
            const SizedBox(height: 16),
            const Text('পিন দিন', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: TextField(
                controller: c,
                autofocus: true,
                obscureText: true,
                maxLength: 4,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 28, letterSpacing: 8),
                decoration: InputDecoration(
                    counterText: '', errorText: err ? 'ভুল পিন' : null),
                onChanged: _check,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ======================= হোম শেল =======================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  static const _pages = <Widget>[Dashboard(), TxScreen(), PartiesScreen(), ReportScreen()];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(app.book == 0 ? 'ব্যবসার খাতা' : 'ব্যক্তিগত খাতা'),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('ব্যবসা'), icon: Icon(Icons.store)),
                    ButtonSegment(value: 1, label: Text('ব্যক্তিগত'), icon: Icon(Icons.person)),
                  ],
                  selected: {app.book},
                  onSelectionChanged: (s) => app.setBook(s.first),
                ),
              ),
            ),
          ),
          body: _pages[tab],
          floatingActionButton: tab == 2
              ? FloatingActionButton.extended(
                  onPressed: () => showPartyDialog(context),
                  icon: const Icon(Icons.person_add),
                  label: const Text('নতুন পার্টি'),
                )
              : tab < 2
                  ? FloatingActionButton.extended(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AddTxScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('নতুন এন্ট্রি'),
                    )
                  : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard), label: 'ড্যাশবোর্ড'),
              NavigationDestination(icon: Icon(Icons.receipt_long), label: 'আয়-ব্যয়'),
              NavigationDestination(icon: Icon(Icons.people), label: 'দেনা-পাওনা'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'রিপোর্ট'),
            ],
          ),
        );
      },
    );
  }
}

// ======================= ড্যাশবোর্ড =======================

class Dashboard extends StatelessWidget {
  const Dashboard({super.key});

  Future<Map<String, dynamic>> _load() async {
    final td = rangeFor(0);
    final today = await Db.i.totals(app.book, from: td.from, to: td.to);
    final all = await Db.i.totals(app.book);
    final parties = await Db.i.partiesWithBal(app.book);
    double recv = 0, pay = 0;
    for (final p in parties) {
      final b = (p['bal'] as num).toDouble();
      if (b > 0) {
        recv += b;
      } else if (b < 0) {
        pay -= b;
      }
    }
    final recent = await Db.i.txList(app.book, limit: 6);
    return {'today': today, 'all': all, 'recv': recv, 'pay': pay, 'recent': recent};
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final today = d['today'] as Map<String, double>;
          final all = d['all'] as Map<String, double>;
          final recent = d['recent'] as List<M>;
          final bal = all['income']! - all['expense']!;
          final cs = Theme.of(context).colorScheme;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('বর্তমান ব্যালেন্স'),
                    const SizedBox(height: 6),
                    Text(money(bal),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
              Row(children: [
                Expanded(child: StatCard('আজকের আয়', money(today['income']!), kGreen, Icons.south_west)),
                Expanded(child: StatCard('আজকের ব্যয়', money(today['expense']!), kRed, Icons.north_east)),
              ]),
              Row(children: [
                Expanded(child: StatCard('মোট পাওনা', money(d['recv'] as double), kGreen, Icons.call_received)),
                Expanded(child: StatCard('মোট দেনা', money(d['pay'] as double), kRed, Icons.call_made)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kGreen),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddTxScreen(initialType: 'income'))),
                    icon: const Icon(Icons.add),
                    label: const Text('আয়'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kRed),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AddTxScreen(initialType: 'expense'))),
                    icon: const Icon(Icons.remove),
                    label: const Text('ব্যয়'),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('সাম্প্রতিক এন্ট্রি',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('এখনো কোনো এন্ট্রি নেই')),
                ),
              for (final t in recent)
                TxTile(t,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddTxScreen(tx: t)))),
            ],
          );
        },
      ),
    );
  }
}

// ======================= আয়-ব্যয় তালিকা =======================

class TxScreen extends StatefulWidget {
  const TxScreen({super.key});
  @override
  State<TxScreen> createState() => _TxScreenState();
}

class _TxScreenState extends State<TxScreen> {
  String? filter;

  Widget _chip(String label, String? v) => ChoiceChip(
        label: Text(label),
        selected: filter == v,
        onSelected: (_) => setState(() => filter = v),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            _chip('সব', null),
            const SizedBox(width: 8),
            _chip('আয়', 'income'),
            const SizedBox(width: 8),
            _chip('ব্যয়', 'expense'),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<M>>(
            future: Db.i.txList(app.book, type: filter),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final list = snap.data!;
              if (list.isEmpty) return const Center(child: Text('কোনো এন্ট্রি নেই'));
              final items = <Widget>[];
              int? lastDay;
              for (final t in list) {
                final dt = DateTime.fromMillisecondsSinceEpoch(t['date'] as int);
                final day = dt.year * 10000 + dt.month * 100 + dt.day;
                if (day != lastDay) {
                  lastDay = day;
                  items.add(Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(fmtDate(dt),
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  ));
                }
                items.add(TxTile(t,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AddTxScreen(tx: t)))));
              }
              return ListView(padding: const EdgeInsets.only(bottom: 100), children: items);
            },
          ),
        ),
      ]),
    );
  }
}

// ======================= এন্ট্রি যোগ/সম্পাদনা =======================

class AddTxScreen extends StatefulWidget {
  final M? tx;
  final String initialType;
  const AddTxScreen({super.key, this.tx, this.initialType = 'expense'});
  @override
  State<AddTxScreen> createState() => _AddTxState();
}

class _AddTxState extends State<AddTxScreen> {
  late String type;
  String? cat;
  String method = 'ক্যাশ';
  late DateTime date;
  late int book;
  final amountC = TextEditingController();
  final noteC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.tx;
    if (t != null) {
      type = t['type'] as String;
      cat = t['category'] as String?;
      method = (t['method'] as String?) ?? 'ক্যাশ';
      date = DateTime.fromMillisecondsSinceEpoch(t['date'] as int);
      book = t['book'] as int;
      final a = (t['amount'] as num).toDouble();
      amountC.text = a == a.roundToDouble() ? a.toInt().toString() : a.toString();
      noteC.text = (t['note'] as String?) ?? '';
    } else {
      type = widget.initialType;
      date = DateTime.now();
      book = app.book;
    }
  }

  Future<void> _save() async {
    final amt = double.tryParse(toEn(amountC.text.trim()));
    if (amt == null || amt <= 0) {
      toast(context, 'সঠিক পরিমাণ লিখুন');
      return;
    }
    final m = <String, Object?>{
      'book': book,
      'type': type,
      'amount': amt,
      'category': cat ?? 'অন্যান্য',
      'method': method,
      'note': noteC.text.trim(),
      'date': date.millisecondsSinceEpoch,
    };
    if (widget.tx == null) {
      await Db.i.insertTx(m);
    } else {
      await Db.i.updateTx(widget.tx!['id'] as int, m);
    }
    app.changed();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (await confirmDlg(context, 'এই এন্ট্রি মুছে ফেলবেন?')) {
      await Db.i.deleteTx(widget.tx!['id'] as int);
      app.changed();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = List<String>.from(categoriesFor(book, type));
    if (cat != null && !cats.contains(cat)) cats.add(cat!);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tx == null ? 'নতুন এন্ট্রি' : 'এন্ট্রি সম্পাদনা'),
        actions: [
          if (widget.tx != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'income', label: Text('আয়')),
            ButtonSegment(value: 'expense', label: Text('ব্যয়')),
          ],
          selected: {type},
          onSelectionChanged: (s) => setState(() {
            type = s.first;
            cat = null;
          }),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: amountC,
          autofocus: widget.tx == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              labelText: 'পরিমাণ', prefixText: '৳ ', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        const Text('ক্যাটাগরি', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final c in cats)
              ChoiceChip(
                label: Text(c),
                selected: cat == c,
                onSelected: (_) => setState(() => cat = c),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('পেমেন্ট মাধ্যম', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in paymentMethods)
              ChoiceChip(
                label: Text(m),
                selected: method == m,
                onSelected: (_) => setState(() => method = m),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(fmtDate(date)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => date = d);
          },
        ),
        TextField(
          controller: noteC,
          decoration: const InputDecoration(
              labelText: 'নোট (ঐচ্ছিক)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _save,
          child: const Text('সংরক্ষণ করুন', style: TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}

// ======================= পার্টি তালিকা =======================

Future<void> showPartyDialog(BuildContext context, {M? party}) async {
  final nameC = TextEditingController(text: (party?['name'] as String?) ?? '');
  final phoneC = TextEditingController(text: (party?['phone'] as String?) ?? '');
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(party == null ? 'নতুন পার্টি' : 'পার্টি সম্পাদনা'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: nameC,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'নাম'),
        ),
        TextField(
          controller: phoneC,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'ফোন (ঐচ্ছিক)'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        FilledButton(
          onPressed: () async {
            final n = nameC.text.trim();
            if (n.isEmpty) return;
            final m = <String, Object?>{'name': n, 'phone': phoneC.text.trim()};
            if (party == null) {
              await Db.i.insertParty({'book': app.book, ...m});
            } else {
              await Db.i.updateParty(party['id'] as int, m);
            }
            app.changed();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('সংরক্ষণ'),
        ),
      ],
    ),
  );
}

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});
  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => FutureBuilder<List<M>>(
        future: Db.i.partiesWithBal(app.book),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          double recv = 0, pay = 0;
          for (final p in all) {
            final b = (p['bal'] as num).toDouble();
            if (b > 0) {
              recv += b;
            } else if (b < 0) {
              pay -= b;
            }
          }
          final list = all
              .where((p) => (p['name'] as String).toLowerCase().contains(q.toLowerCase()))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                Expanded(child: StatCard('আমি পাব', money(recv), kGreen, Icons.call_received)),
                Expanded(child: StatCard('আমি দেব', money(pay), kRed, Icons.call_made)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: TextField(
                onChanged: (v) => setState(() => q = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'পার্টি খুঁজুন',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('কোনো পার্টি নেই। নিচের বাটনে চাপ দিয়ে যোগ করুন'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final p = list[i];
                        final b = (p['bal'] as num).toDouble();
                        final name = p['name'] as String;
                        final phone = (p['phone'] as String?) ?? '';
                        return ListTile(
                          leading: CircleAvatar(child: Text(name.characters.first)),
                          title: Text(name),
                          subtitle: phone.isEmpty ? null : Text(bn(phone)),
                          trailing: Text(
                            b > 0
                                ? 'পাব ${money(b)}'
                                : b < 0
                                    ? 'দেব ${money(-b)}'
                                    : 'হিসাব সমান',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: b > 0 ? kGreen : (b < 0 ? kRed : Colors.grey)),
                          ),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PartyScreen(partyId: p['id'] as int))),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

// ======================= পার্টির খাতা =======================

class PartyScreen extends StatelessWidget {
  final int partyId;
  const PartyScreen({super.key, required this.partyId});

  Future<Map<String, dynamic>> _load() async {
    final p = await Db.i.partyById(partyId);
    final e = await Db.i.ledgerList(partyId);
    return {'p': p, 'e': e};
  }

  double _bal(List<M> e) {
    double b = 0;
    for (final x in e) {
      final a = (x['amount'] as num).toDouble();
      b += x['type'] == 'gave' ? a : -a;
    }
    return b;
  }

  String _statement(String name, List<M> e) {
    final b = _bal(e);
    final lines = StringBuffer();
    lines.writeln('হিসাব বিবরণী: $name');
    lines.writeln('তারিখ: ${fmtDate(DateTime.now())}');
    lines.writeln('------------------');
    for (final x in e.reversed) {
      final a = (x['amount'] as num).toDouble();
      final note = (x['note'] as String?) ?? '';
      lines.writeln(
          '${fmtMs(x['date'] as int)} | ${x['type'] == 'gave' ? 'দিয়েছি' : 'পেয়েছি'} | ${money(a)}${note.isEmpty ? '' : ' | $note'}');
    }
    lines.writeln('------------------');
    lines.writeln(b > 0
        ? 'মোট বাকি: আপনার কাছে আমি পাব ${money(b)}'
        : b < 0
            ? 'মোট বাকি: আপনাকে আমি দেব ${money(-b)}'
            : 'হিসাব সমান');
    return lines.toString();
  }

  Future<void> _add(BuildContext context, String type, M p) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LedgerEntryScreen(
                partyId: partyId,
                partyName: p['name'] as String,
                book: p['book'] as int,
                type: type)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return Scaffold(
                appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
          }
          final p = snap.data!['p'] as M?;
          final e = snap.data!['e'] as List<M>;
          if (p == null) return Scaffold(appBar: AppBar(), body: const SizedBox());
          final name = p['name'] as String;
          final b = _bal(e);
          return Scaffold(
            appBar: AppBar(
              title: Text(name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => Share.share(_statement(name, e)),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await showPartyDialog(context, party: p);
                    } else if (v == 'del') {
                      if (await confirmDlg(context, '"$name" এবং তার সব হিসাব মুছে ফেলবেন?')) {
                        await Db.i.deleteParty(partyId);
                        app.changed();
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('সম্পাদনা')),
                    PopupMenuItem(value: 'del', child: Text('মুছে ফেলুন')),
                  ],
                ),
              ],
            ),
            body: Column(children: [
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        b > 0 ? 'আপনি পাবেন' : (b < 0 ? 'আপনি দেবেন' : 'হিসাব সমান'),
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(money(b.abs()),
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: b > 0 ? kGreen : (b < 0 ? kRed : Colors.grey))),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: e.isEmpty
                    ? const Center(child: Text('এখনো কোনো লেনদেন নেই'))
                    : ListView.builder(
                        itemCount: e.length,
                        itemBuilder: (context, i) {
                          final x = e[i];
                          final gave = x['type'] == 'gave';
                          final note = (x['note'] as String?) ?? '';
                          final color = gave ? kRed : kGreen;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withAlpha(30),
                              child: Icon(gave ? Icons.north_east : Icons.south_west,
                                  color: color),
                            ),
                            title: Text(gave ? 'দিলাম' : 'পেলাম'),
                            subtitle: Text(
                                '${fmtMs(x['date'] as int)}${note.isEmpty ? '' : ' • $note'}'),
                            trailing: Text(money((x['amount'] as num).toDouble()),
                                style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            onLongPress: () async {
                              if (await confirmDlg(context, 'এই লেনদেন মুছে ফেলবেন?')) {
                                await Db.i.deleteLedger(x['id'] as int);
                                app.changed();
                              }
                            },
                          );
                        },
                      ),
              ),
            ]),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: kRed, minimumSize: const Size.fromHeight(52)),
                      onPressed: () => _add(context, 'gave', p),
                      child: const Text('দিলাম', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: kGreen, minimumSize: const Size.fromHeight(52)),
                      onPressed: () => _add(context, 'got', p),
                      child: const Text('পেলাম', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LedgerEntryScreen extends StatefulWidget {
  final int partyId;
  final String partyName;
  final int book;
  final String type; // gave | got
  const LedgerEntryScreen(
      {super.key,
      required this.partyId,
      required this.partyName,
      required this.book,
      required this.type});
  @override
  State<LedgerEntryScreen> createState() => _LedgerEntryState();
}

class _LedgerEntryState extends State<LedgerEntryScreen> {
  final amountC = TextEditingController();
  final noteC = TextEditingController();
  DateTime date = DateTime.now();
  bool cash = true;

  Future<void> _save() async {
    final amt = double.tryParse(toEn(amountC.text.trim()));
    if (amt == null || amt <= 0) {
      toast(context, 'সঠিক পরিমাণ লিখুন');
      return;
    }
    final note = noteC.text.trim();
    await Db.i.insertLedger({
      'party_id': widget.partyId,
      'type': widget.type,
      'amount': amt,
      'note': note,
      'date': date.millisecondsSinceEpoch,
    });
    if (cash) {
      await Db.i.insertTx({
        'book': widget.book,
        'type': widget.type == 'gave' ? 'expense' : 'income',
        'amount': amt,
        'category': 'দেনা-পাওনা',
        'method': 'ক্যাশ',
        'note': [widget.partyName, note].where((s) => s.isNotEmpty).join(' - '),
        'date': date.millisecondsSinceEpoch,
      });
    }
    app.changed();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final gave = widget.type == 'gave';
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partyName} - ${gave ? 'দিলাম' : 'পেলাম'}'),
        backgroundColor: (gave ? kRed : kGreen).withAlpha(40),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
          controller: amountC,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
              labelText: 'পরিমাণ', prefixText: '৳ ', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: noteC,
          decoration: const InputDecoration(
              labelText: 'নোট (ঐচ্ছিক)', border: OutlineInputBorder()),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: Text(fmtDate(date)),
          trailing: const Icon(Icons.edit),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setState(() => date = d);
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: cash,
          onChanged: (v) => setState(() => cash = v),
          title: const Text('আয়-ব্যয় খাতায়ও যোগ করুন'),
          subtitle: Text(gave
              ? 'নগদ টাকা দিলে ব্যয় হিসেবে যোগ হবে'
              : 'নগদ টাকা পেলে আয় হিসেবে যোগ হবে'),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: gave ? kRed : kGreen,
              minimumSize: const Size.fromHeight(52)),
          onPressed: _save,
          child: const Text('সংরক্ষণ করুন', style: TextStyle(fontSize: 16)),
        ),
      ]),
    );
  }
}

// ======================= রিপোর্ট =======================

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportState();
}

class _ReportState extends State<ReportScreen> {
  int idx = 1;

  Future<Map<String, dynamic>> _load() async {
    final r = rangeFor(idx);
    final t = await Db.i.totals(app.book, from: r.from, to: r.to);
    final ce = await Db.i.catTotals(app.book, 'expense', from: r.from, to: r.to);
    final ci = await Db.i.catTotals(app.book, 'income', from: r.from, to: r.to);
    return {'t': t, 'ce': ce, 'ci': ci};
  }

  Widget _cats(String title, List<M> rows, double total, Color color) {
    if (rows.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text((r['category'] as String?) ?? ''),
              Text(
                  '${money((r['s'] as num).toDouble())}  (${bn((total > 0 ? (r['s'] as num) / total * 100 : 0).toStringAsFixed(0))}%)'),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: total > 0 ? ((r['s'] as num) / total).toDouble() : 0,
              color: color,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snap) {
          final chips = Wrap(spacing: 8, children: [
            for (int i = 0; i < rangeLabels.length; i++)
              ChoiceChip(
                label: Text(rangeLabels[i]),
                selected: idx == i,
                onSelected: (_) => setState(() => idx = i),
              ),
          ]);
          if (!snap.hasData) {
            return ListView(padding: const EdgeInsets.all(16), children: [
              chips,
              const SizedBox(height: 40),
              const Center(child: CircularProgressIndicator()),
            ]);
          }
          final t = snap.data!['t'] as Map<String, double>;
          final ce = snap.data!['ce'] as List<M>;
          final ci = snap.data!['ci'] as List<M>;
          final inc = t['income']!;
          final exp = t['expense']!;
          final net = inc - exp;
          return ListView(padding: const EdgeInsets.all(16), children: [
            chips,
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatCard('মোট আয়', money(inc), kGreen, Icons.south_west)),
              Expanded(child: StatCard('মোট ব্যয়', money(exp), kRed, Icons.north_east)),
            ]),
            StatCard(net >= 0 ? 'লাভ / সঞ্চয়' : 'ঘাটতি', money(net),
                net >= 0 ? kGreen : kRed, Icons.account_balance_wallet),
            _cats('ব্যয়ের ক্যাটাগরি', ce, exp, kRed),
            _cats('আয়ের ক্যাটাগরি', ci, inc, kGreen),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                final b = StringBuffer();
                b.writeln('${app.book == 0 ? 'ব্যবসার' : 'ব্যক্তিগত'} রিপোর্ট (${rangeLabels[idx]})');
                b.writeln('মোট আয়: ${money(inc)}');
                b.writeln('মোট ব্যয়: ${money(exp)}');
                b.writeln('${net >= 0 ? 'লাভ/সঞ্চয়' : 'ঘাটতি'}: ${money(net)}');
                if (ce.isNotEmpty) {
                  b.writeln('\nব্যয়:');
                  for (final r in ce) {
                    b.writeln('- ${r['category']}: ${money((r['s'] as num).toDouble())}');
                  }
                }
                if (ci.isNotEmpty) {
                  b.writeln('\nআয়:');
                  for (final r in ci) {
                    b.writeln('- ${r['category']}: ${money((r['s'] as num).toDouble())}');
                  }
                }
                Share.share(b.toString());
              },
              icon: const Icon(Icons.share),
              label: const Text('রিপোর্ট শেয়ার করুন'),
            ),
          ]);
        },
      ),
    );
  }
}

// ======================= সেটিংস =======================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  bool hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => hasPin = (p.getString('pin') ?? '').isNotEmpty);
  }

  Future<void> _setPin() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('৪ সংখ্যার পিন দিন'),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          maxLength: 4,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('ঠিক আছে')),
        ],
      ),
    );
    if (v == null || !mounted) return;
    final e = toEn(v);
    if (RegExp(r'^\d{4}$').hasMatch(e)) {
      final p = await SharedPreferences.getInstance();
      await p.setString('pin', e);
      await _load();
      if (mounted) toast(context, 'পিন চালু হয়েছে');
    } else {
      toast(context, 'ঠিক ৪টি সংখ্যা দিন');
    }
  }

  Future<void> _removePin() async {
    if (await confirmDlg(context, 'পিন বন্ধ করবেন?')) {
      final p = await SharedPreferences.getInstance();
      await p.remove('pin');
      await _load();
    }
  }

  Future<void> _restore() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ব্যাকআপ রিস্টোর'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('সতর্কতা: বর্তমান সব ডেটা মুছে ব্যাকআপের ডেটা বসবে।',
              style: TextStyle(color: kRed)),
          const SizedBox(height: 8),
          TextField(
            controller: c,
            maxLines: 5,
            decoration: const InputDecoration(
                hintText: 'ব্যাকআপ টেক্সট এখানে পেস্ট করুন', border: OutlineInputBorder()),
          ),
          TextButton.icon(
            onPressed: () async {
              final d = await Clipboard.getData('text/plain');
              c.text = d?.text ?? '';
            },
            icon: const Icon(Icons.paste),
            label: const Text('ক্লিপবোর্ড থেকে পেস্ট'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('রিস্টোর')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Db.i.importJson(c.text.trim());
      app.changed();
      if (mounted) toast(context, 'রিস্টোর সম্পন্ন');
    } catch (_) {
      if (mounted) toast(context, 'ব্যাকআপ টেক্সট সঠিক নয়');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.lock),
          title: Text(hasPin ? 'পিন বদলান' : 'পিন লক চালু করুন'),
          subtitle: const Text('অ্যাপ খুলতে পিন লাগবে'),
          onTap: _setPin,
        ),
        if (hasPin)
          ListTile(
            leading: const Icon(Icons.lock_open),
            title: const Text('পিন বন্ধ করুন'),
            onTap: _removePin,
          ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.backup),
          title: const Text('ব্যাকআপ শেয়ার করুন'),
          subtitle: const Text('WhatsApp / ইমেইল / Drive-এ নিজেকে পাঠিয়ে রাখুন'),
          onTap: () async {
            final s = await Db.i.exportJson();
            await Share.share(s, subject: 'হিসাব খাতা ব্যাকআপ');
          },
        ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('ব্যাকআপ কপি করুন'),
          onTap: () async {
            final s = await Db.i.exportJson();
            await Clipboard.setData(ClipboardData(text: s));
            if (context.mounted) toast(context, 'ব্যাকআপ কপি হয়েছে');
          },
        ),
        ListTile(
          leading: const Icon(Icons.restore),
          title: const Text('ব্যাকআপ রিস্টোর করুন'),
          onTap: _restore,
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('হিসাব খাতা'),
          subtitle: Text('সংস্করণ ১.০ • সব ডেটা আপনার ফোনেই থাকে, ইন্টারনেট লাগে না'),
        ),
      ]),
    );
  }
}
