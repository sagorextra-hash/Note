import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KhataApp());
}

class KhataApp extends StatelessWidget {
  const KhataApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'হিসাব খাতা',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF00695C),
      ),
      home: const Root(),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});
  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  bool loading = true;
  bool locked = false;
  DateTime? pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      locked = (p.getString('pin') ?? '').isNotEmpty;
      loading = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) async {
    if (s == AppLifecycleState.paused) {
      pausedAt = DateTime.now();
    }
    if (s == AppLifecycleState.resumed && pausedAt != null) {
      final away = DateTime.now().difference(pausedAt!);
      pausedAt = null;
      if (away.inSeconds > 30) {
        final p = await SharedPreferences.getInstance();
        if ((p.getString('pin') ?? '').isNotEmpty && mounted) {
          setState(() => locked = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (locked) {
      return LockScreen(onUnlock: () => setState(() => locked = false));
    }
    return const HomeShell();
  }
}
