import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'requests.dart';

class ProviderScreen extends StatelessWidget {
  const ProviderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    if (!s.approvedProvider) {
      final rejected = s.providerStatus == 'rejected';
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('tab_provider'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(rejected ? Icons.block : Icons.hourglass_top, size: 52, color: rejected ? Colors.red.shade700 : kGold),
              const SizedBox(height: 14),
              Text(context.tr(rejected ? 'prov_rejected' : 'prov_pending'), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () async {
                  try {
                    await s.refreshUser();
                  } catch (e) {
                    if (context.mounted) snack(context, errText(e));
                  }
                },
                child: Text(context.tr('refresh')),
              ),
            ]),
          ),
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('tab_provider')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: kGold,
            tabs: [Tab(text: context.tr('open_requests')), Tab(text: context.tr('my_offers')), Tab(text: context.tr('vehicles'))],
          ),
        ),
        body: const TabBarView(children: [_OpenRequests(), _MyOffers(), _Vehicles()]),
      ),
    );
  }
}

class _OpenRequests extends StatelessWidget {
  const _OpenRequests();
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return DataView<List<Json>>(
      load: () => s.api.providerRequests(),
      builder: (c, list, reload) {
        if (list.isEmpty) return EmptyView(c.tr('nothing'));
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c2, i) {
            final r = list[i];
            final sent = r['my_offer_id'] != null;
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('#${r['id']}  ${s.localized(r['service_name'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  if (sent) Text(c2.tr('offer_sent'), style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                ]),
                if (routeText(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(routeText(r))),
                if (fmtDate(r['service_date'] as String?).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtDate(r['service_date'] as String?), style: const TextStyle(color: Colors.black54))),
                if ((r['quantity'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${c2.tr('quantity')}: ${r['quantity']}', style: const TextStyle(color: Colors.black54))),
                if ((r['details'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r['details'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis)),
                const SizedBox(height: 10),
                FilledButton(onPressed: () => showOfferSheet(c2, r), child: Text(c2.tr(sent ? 'edit_offer' : 'send_offer'))),
              ]),
            );
          },
        );
      },
    );
  }
}

Future<void> showOfferSheet(BuildContext context, Json req) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (b) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(b).viewInsets.bottom + 16),
      child: _OfferForm(req: req),
    ),
  );
}

class _OfferForm extends StatefulWidget {
  final Json req;
  const _OfferForm({required this.req});
  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _amount = TextEditingController();
  final _msg = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    final amt = _amount.text.trim().replaceAll(',', '.');
    if (double.tryParse(amt) == null || double.parse(amt) <= 0) {
      snack(context, context.tr('required'));
      return;
    }
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    final msgr = ScaffoldMessenger.of(context);
    final done = context.tr('offer_sent');
    setState(() => _busy = true);
    try {
      await s.api.sendOffer(widget.req['id'] as int, amt, _msg.text.trim());
      s.bump();
      nav.pop();
      msgr.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('#${widget.req['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 12),
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.tr('price_kwd'))),
      const SizedBox(height: 12),
      TextField(controller: _msg, maxLines: 3, decoration: InputDecoration(labelText: context.tr('message_opt'))),
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _busy ? null : _send,
        child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('send_offer')),
      ),
    ]);
  }
}

class _MyOffers extends StatelessWidget {
  const _MyOffers();
  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return DataView<List<Json>>(
      load: () => s.api.providerOffers(),
      builder: (c, list, reload) {
        if (list.isEmpty) return EmptyView(c.tr('nothing'));
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (c2, i) {
            final o = list[i];
            final r = o['request'] == null ? null : Map<String, dynamic>.from(o['request'] as Map);
            return Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(r == null ? '#${o['request_id']}' : '#${r['id']}  ${s.localized(r['service_name'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  StatusChip(o['status'] as String),
                ]),
                if (r != null && routeText(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(routeText(r))),
                const SizedBox(height: 6),
                Text(fmtMoney(o['amount'], o['currency']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (r != null && o['status'] == 'accepted' && r['customer_phone'] != null) ...[
                  const SizedBox(height: 8),
                  Text('${c2.tr('customer')}: ${r['customer_name'] ?? ''}'),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(onPressed: () => openUrl('tel:${r['customer_phone']}'), icon: const Icon(Icons.call), label: Text('${c2.tr('call')}  ${r['customer_phone']}')),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

class _Vehicles extends StatelessWidget {
  const _Vehicles();

  Future<void> _add(BuildContext context) async {
    final s = context.read<AppState>();
    final name = TextEditingController();
    final model = TextEditingController();
    final plate = TextEditingController();
    final cap = TextEditingController();
    final mine = ((s.user?['provider_services'] as List?) ?? []).map((e) => e.toString()).toList();
    final opts = s.services.where((x) => mine.contains(x['key'])).toList();
    String? svc = opts.isNotEmpty ? opts.first['key'] as String : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d2, setD) => AlertDialog(
          title: Text(context.tr('add_vehicle')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: context.tr('vehicle_name'))),
              const SizedBox(height: 10),
              TextField(controller: model, decoration: InputDecoration(labelText: context.tr('model'))),
              const SizedBox(height: 10),
              TextField(controller: plate, decoration: InputDecoration(labelText: context.tr('plate'))),
              const SizedBox(height: 10),
              TextField(controller: cap, decoration: InputDecoration(labelText: context.tr('capacity'))),
              if (opts.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: svc,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: context.tr('service')),
                  items: [for (final o in opts) DropdownMenuItem(value: o['key'] as String, child: Text(s.localized(o['name'])))],
                  onChanged: (v) => setD(() => svc = v),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await s.api.addVehicle({'name': name.text.trim(), 'model': model.text.trim(), 'plate': plate.text.trim(), 'capacity': cap.text.trim(), 'service_key': svc ?? ''});
      s.bump();
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGold,
        foregroundColor: kGreen,
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: Text(context.tr('add_vehicle')),
      ),
      body: DataView<List<Json>>(
        load: () => s.api.vehicles(),
        builder: (c, list, reload) {
          if (list.isEmpty) return EmptyView(c.tr('nothing'));
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (c2, i) {
              final v = list[i];
              final line = [v['model'], v['plate'], v['capacity']].where((x) => (x ?? '').toString().isNotEmpty).join('  •  ');
              return Panel(
                child: Row(children: [
                  const Icon(Icons.local_shipping, color: kGreen),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((v['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (line.isNotEmpty) Text(line, style: const TextStyle(color: Colors.black54)),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class ProviderRegisterScreen extends StatefulWidget {
  const ProviderRegisterScreen({super.key});
  @override
  State<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends State<ProviderRegisterScreen> {
  final _key = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _crNo = TextEditingController();
  final _other = TextEditingController();
  final Set<String> _sel = {};
  String? _crPath, _crName, _licPath, _licName;
  bool _busy = false;

  Future<void> _pick(bool cr) async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (r == null || r.files.isEmpty || r.files.single.path == null) return;
    final f = r.files.single;
    setState(() {
      if (cr) {
        _crPath = f.path;
        _crName = f.name;
      } else {
        _licPath = f.path;
        _licName = f.name;
      }
    });
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    if (_sel.isEmpty) return snack(context, context.tr('pick_service'));
    if (_crPath == null || _licPath == null) return snack(context, context.tr('files_needed'));
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await s.providerRegister({
        'company': _company.text.trim(),
        'contact': _contact.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'password': _pass.text,
        'cr_number': _crNo.text.trim(),
        'services': _sel.join(','),
        'service_other': _other.text.trim(),
      }, {
        'cr_file': _crPath!,
        'license_file': _licPath!,
      });
      s.setTab(2);
      nav.pop(true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _filePick(String label, String? name, bool cr) => OutlinedButton.icon(
        onPressed: () => _pick(cr),
        icon: Icon(name == null ? Icons.upload_file : Icons.check_circle, color: name == null ? null : Colors.green.shade700),
        label: Text(name ?? label, overflow: TextOverflow.ellipsis),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    String? req(String? v) => (v == null || v.trim().isEmpty) ? context.tr('required') : null;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('as_provider'))),
      body: SafeArea(
        child: Form(
          key: _key,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(controller: _company, decoration: InputDecoration(labelText: context.tr('company')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _contact, decoration: InputDecoration(labelText: context.tr('contact'))),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('phone')), validator: req),
            const SizedBox(height: 12),
            TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: context.tr('email')), validator: req),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(labelText: context.tr('password')),
              validator: (v) => (v == null || v.length < 10) ? (s.lang == 'en' ? 'At least 10 characters' : '10 أحرف على الأقل') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _crNo, decoration: InputDecoration(labelText: context.tr('cr_number'))),
            const SizedBox(height: 16),
            Text(context.tr('services_offered'), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final sv in s.services)
                FilterChip(
                  label: Text(s.localized(sv['name'])),
                  selected: _sel.contains(sv['key']),
                  onSelected: (v) => setState(() => v ? _sel.add(sv['key'] as String) : _sel.remove(sv['key'])),
                ),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _other, decoration: InputDecoration(labelText: context.tr('service_other'))),
            const SizedBox(height: 16),
            _filePick(context.tr('cr_file'), _crName, true),
            const SizedBox(height: 8),
            _filePick(context.tr('lic_file'), _licName, false),
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('docs_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey))),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('register')),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (s.privacyUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.privacyUrl), child: Text(context.tr('privacy'))),
              if (s.termsUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.termsUrl), child: Text(context.tr('terms'))),
            ]),
          ]),
        ),
      ),
    );
  }
}
