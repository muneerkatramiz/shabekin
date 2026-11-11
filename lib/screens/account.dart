import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auth.dart';
import 'provider.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _delete(BuildContext context) async {
    final s = context.read<AppState>();
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('delete_account')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.tr('delete_q')),
          const SizedBox(height: 12),
          TextField(controller: c, obscureText: true, decoration: InputDecoration(labelText: context.tr('password'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.tr('delete_account'), style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await s.deleteAccount(c.text);
    } catch (e) {
      if (context.mounted) snack(context, errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('tab_account'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (u == null) ...[
          Panel(
            child: Column(children: [
              const Icon(Icons.account_circle_outlined, size: 56, color: kGreen),
              const SizedBox(height: 10),
              FilledButton(onPressed: () => ensureLogin(context), child: Text(context.tr('login'))),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                child: Text(context.tr('register')),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderRegisterScreen())),
                child: Text(context.tr('as_provider')),
              ),
            ]),
          ),
        ] else ...[
          Panel(
            child: Row(children: [
              const CircleAvatar(radius: 26, backgroundColor: kGreen, child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((u['name'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text((u['email'] ?? '').toString(), style: const TextStyle(color: Colors.black54)),
                  if ((u['phone'] ?? '').toString().isNotEmpty) Text((u['phone']).toString(), style: const TextStyle(color: Colors.black54)),
                ]),
              ),
              if (s.isProvider) StatusChip((s.providerStatus ?? 'pending')),
            ]),
          ),
          const SizedBox(height: 12),
          if (!s.isProvider)
            Panel(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderRegisterScreen())),
              child: Row(children: [
                const Icon(Icons.local_shipping_outlined, color: kGreen),
                const SizedBox(width: 12),
                Expanded(child: Text(context.tr('as_provider'), style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right),
              ]),
            ),
        ],
        const SizedBox(height: 12),
        Panel(
          child: Row(children: [
            const Icon(Icons.language, color: kGreen),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('language'), style: const TextStyle(fontWeight: FontWeight.w700))),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [ButtonSegment(value: 'ar', label: Text('العربية')), ButtonSegment(value: 'en', label: Text('English'))],
              selected: {s.lang},
              onSelectionChanged: (v) => s.setLang(v.first),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final pg in s.pages) ...[
              ListTile(leading: const Icon(Icons.article_outlined), title: Text((pg['title'] ?? '').toString()), onTap: () => openInApp((pg['url'] ?? '').toString())),
              const Divider(height: 1),
            ],
            if (s.privacyUrl.isNotEmpty) ListTile(leading: const Icon(Icons.privacy_tip_outlined), title: Text(context.tr('privacy')), onTap: () => openInApp(s.privacyUrl)),
            if (s.termsUrl.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.description_outlined), title: Text(context.tr('terms')), onTap: () => openInApp(s.termsUrl)),
            ],
            if (s.supportEmail.isNotEmpty) ...[
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.mail_outline), title: Text(context.tr('support')), onTap: () => openUrl('mailto:${s.supportEmail}')),
            ],
          ]),
        ),
        if (u != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: () => s.logout(), icon: const Icon(Icons.logout), label: Text(context.tr('logout'))),
          TextButton(onPressed: () => _delete(context), child: Text(context.tr('delete_account'), style: TextStyle(color: Colors.red.shade700))),
        ],
      ]),
    );
  }
}
