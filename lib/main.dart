import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n.dart';
import 'screens/account.dart';
import 'screens/provider.dart';
import 'screens/requests.dart';
import 'screens/services.dart';
import 'state.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const ShabekinApp()));
  state.init();
}

class ShabekinApp extends StatefulWidget {
  const ShabekinApp({super.key});
  @override
  State<ShabekinApp> createState() => _ShabekinAppState();
}

class _ShabekinAppState extends State<ShabekinApp> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AppState>().sync();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppState>().sync();
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shabekin',
      theme: buildTheme(),
      locale: Locale(s.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: s.ready ? const HomeShell() : const _Splash(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kGreen,
        body: Center(child: Image.asset('assets/logo.png', width: 220)),
      );
}

class _Tab {
  final IconData icon;
  final String label;
  final Widget page;
  _Tab(this.icon, this.label, this.page);
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final tabs = <_Tab>[
      _Tab(Icons.local_shipping_outlined, 'tab_services', const ServicesScreen()),
      _Tab(Icons.receipt_long_outlined, 'tab_requests', const RequestsScreen()),
      if (s.isProvider) _Tab(Icons.work_outline, 'tab_provider', const ProviderScreen()),
      _Tab(Icons.person_outline, 'tab_account', const AccountScreen()),
    ];
    final idx = s.tab.clamp(0, tabs.length - 1);
    return Scaffold(
      body: IndexedStack(index: idx, children: tabs.map((t) => t.page).toList()),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: s.setTab,
        destinations: tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: context.tr(t.label))).toList(),
      ),
    );
  }
}
