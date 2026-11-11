import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api.dart';
import '../l10n.dart';
import '../state.dart';
import '../widgets.dart';
import 'auth.dart';

const _openStatuses = ['new', 'reviewing', 'waiting_provider', 'quoted'];

String routeText(Json r) {
  final o = (r['origin'] ?? '').toString();
  final d = (r['destination'] ?? '').toString();
  if (o.isNotEmpty && d.isNotEmpty) return '$o  →  $d';
  return o.isNotEmpty ? o : d;
}

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('tab_requests'))),
      body: !s.loggedIn
          ? LoginPrompt(text: context.tr('login_needed'), onLogin: () => ensureLogin(context))
          : DataView<List<Json>>(
              load: () => context.read<AppState>().api.requests(),
              builder: (c, list, reload) {
                if (list.isEmpty) return EmptyView(c.tr('no_requests'));
                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c2, i) {
                    final r = list[i];
                    final offers = (r['offers_count'] ?? 0) as int;
                    return Panel(
                      onTap: () => Navigator.push(c2, MaterialPageRoute(builder: (_) => RequestDetailScreen(id: r['id'] as int))),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('#${r['id']}  ${s.localized(r['service_name'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (routeText(r).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(routeText(r), style: const TextStyle(color: Colors.black54))),
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(fmtDate(r['created_at'] as String?), style: const TextStyle(color: Colors.black38, fontSize: 12))),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          StatusChip(r['status'] as String),
                          if (offers > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c2.tr('offers')}: $offers', style: const TextStyle(fontSize: 12))),
                        ]),
                      ]),
                    );
                  },
                );
              },
            ),
    );
  }
}

class RequestDetailScreen extends StatelessWidget {
  final int id;
  const RequestDetailScreen({super.key, required this.id});

  Future<bool> _confirm(BuildContext context, String text) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('no'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.tr('yes'))),
        ],
      ),
    );
    return r == true;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('tab_requests')} #$id')),
      body: DataView<Json>(
        load: () => context.read<AppState>().api.request(id),
        builder: (c, data, reload) {
          final r = Map<String, dynamic>.from(data['request'] as Map);
          final offers = ((data['offers'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final open = _openStatuses.contains(r['status']);
          return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s.localized(r['service_name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                  StatusChip(r['status'] as String),
                ]),
                const SizedBox(height: 10),
                if (routeText(r).isNotEmpty) Text(routeText(r)),
                if (fmtDate(r['service_date'] as String?).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(fmtDate(r['service_date'] as String?))),
                if ((r['quantity'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${c.tr('quantity')}: ${r['quantity']}')),
                if ((r['details'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(r['details'].toString(), style: const TextStyle(color: Colors.black87))),
              ]),
            ),
            const SizedBox(height: 18),
            Text(c.tr('offers'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            if (offers.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(c.tr('no_offers'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
            for (final o in offers)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text((o['company'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700))),
                      StatusChip(o['status'] as String),
                    ]),
                    const SizedBox(height: 6),
                    Text(fmtMoney(o['amount'], o['currency']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    if ((o['message'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(o['message'].toString())),
                    if (o['provider_phone'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(onPressed: () => openUrl('tel:${o['provider_phone']}'), icon: const Icon(Icons.call), label: Text('${c.tr('call')}  ${o['provider_phone']}')),
                      ),
                    if (open && o['status'] == 'pending')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: FilledButton(
                          onPressed: () async {
                            final st = c.read<AppState>();
                            if (!await _confirm(c, c.tr('accept_q'))) return;
                            try {
                              await st.api.acceptOffer(o['id'] as int);
                              st.bump();
                            } catch (e) {
                              if (c.mounted) snack(c, errText(e));
                            }
                          },
                          child: Text(c.tr('accept')),
                        ),
                      ),
                  ]),
                ),
              ),
            if (open) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  final st = c.read<AppState>();
                  if (!await _confirm(c, c.tr('cancel_q'))) return;
                  try {
                    await st.api.cancelRequest(id);
                    st.bump();
                  } catch (e) {
                    if (c.mounted) snack(c, errText(e));
                  }
                },
                child: Text(c.tr('cancel_req'), style: TextStyle(color: Colors.red.shade700)),
              ),
            ],
          ]);
        },
      ),
    );
  }
}
