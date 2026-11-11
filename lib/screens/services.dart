import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (s.services.isEmpty) {
      return Scaffold(body: SafeArea(child: ErrorView(message: s.bootError ?? context.tr('load_failed'), onRetry: s.loadConfig)));
    }
    final hero = (s.config['hero'] as String?) ?? '';
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: s.loadConfig,
        child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          SliverToBoxAdapter(
            child: Container(
              height: 230,
              decoration: const BoxDecoration(color: kGreen),
              child: Stack(fit: StackFit.expand, children: [
                if (hero.isNotEmpty)
                  Image.network(hero, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                Container(color: kGreen.withOpacity(0.72)),
                SafeArea(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Image.asset('assets/logo.png', height: 64),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(context.tr('hero_sub'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          if (s.notice != null && s.localized(s.notice).trim().isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0x33FFBD35), borderRadius: BorderRadius.circular(12), border: Border.all(color: kGold)),
                child: Row(children: [
                  const Icon(Icons.campaign_outlined, color: kGreen),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s.localized(s.notice))),
                ]),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.92),
              delegate: SliverChildBuilderDelegate(
                (c, i) => _ServiceCard(service: s.services[i]),
                childCount: s.services.length,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Json service;
  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    final img = (service['image'] as String?) ?? '';
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () async {
        if (await ensureLogin(context) && context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => RequestFormScreen(service: service)));
        }
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: img.isEmpty
                ? Container(color: Colors.grey.shade200)
                : Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.local_shipping, color: Colors.grey))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(s.localized(service['name']), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

class RequestFormScreen extends StatefulWidget {
  final Json service;
  const RequestFormScreen({super.key, required this.service});
  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _origin = TextEditingController();
  final _dest = TextEditingController();
  final _qty = TextEditingController();
  final _details = TextEditingController();
  DateTime? _date;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().user;
    _name = TextEditingController(text: (u?['name'] ?? '').toString());
    _phone = TextEditingController(text: (u?['phone'] ?? '').toString());
  }

  String _p2(int n) => n.toString().padLeft(2, '0');
  String _iso(DateTime d) => '${d.year}-${_p2(d.month)}-${_p2(d.day)} ${_p2(d.hour)}:${_p2(d.minute)}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: now, firstDate: now, lastDate: now.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (!mounted) return;
    setState(() => _date = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0));
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final okText = context.tr('req_sent');
    setState(() => _busy = true);
    try {
      await s.api.createRequest({
        'service_key': widget.service['key'],
        'customer_name': _name.text.trim(),
        'customer_phone': _phone.text.trim(),
        'origin': _origin.text.trim(),
        'destination': _dest.text.trim(),
        'service_date': _date == null ? '' : _iso(_date!),
        'quantity': _qty.text.trim(),
        'details': _details.text.trim(),
      });
      s.bump();
      s.setTab(1);
      nav.pop();
      msgr.showSnackBar(SnackBar(content: Text(okText)));
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    return Scaffold(
      appBar: AppBar(title: Text(s.localized(widget.service['name']))),
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _name, decoration: InputDecoration(labelText: context.tr('name')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('phone')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _origin, decoration: InputDecoration(labelText: context.tr('from_loc')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _dest, decoration: InputDecoration(labelText: context.tr('to_loc'))),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(labelText: context.tr('date_time'), suffixIcon: const Icon(Icons.event)),
                child: Text(_date == null ? '' : _iso(_date!)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _qty, decoration: InputDecoration(labelText: context.tr('quantity'))),
            const SizedBox(height: 12),
            TextFormField(controller: _details, maxLines: 4, decoration: InputDecoration(labelText: context.tr('details'))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('submit_req')),
            ),
          ]),
        ),
      ),
    );
  }
}
