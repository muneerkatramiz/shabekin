import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'provider.dart';

Future<bool> ensureLogin(BuildContext context) async {
  if (context.read<AppState>().loggedIn) return true;
  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok == true;
}

String? _req(BuildContext c, String? v) => (v == null || v.trim().isEmpty) ? c.tr('required') : null;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final s = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await s.login(_email.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: _email.text);
    final api = context.read<AppState>().api;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('forgot')),
        content: TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: context.tr('email'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: Text(context.tr('send'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.forgot(c.text.trim());
      if (mounted) snack(context, context.tr('forgot_sent'));
    } catch (e) {
      if (mounted) snack(context, errText(e));
    }
  }

  Future<void> _go(Widget page) async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page));
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('login'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(16)),
            child: Image.asset('assets/logo.png', height: 70),
          ),
          const SizedBox(height: 20),
          Form(
            key: _key,
            child: Column(children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: context.tr('email')),
                validator: (v) => _req(context, v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(labelText: context.tr('password')),
                validator: (v) => _req(context, v),
                onFieldSubmitted: (_) => _submit(),
              ),
            ]),
          ),
          Align(alignment: AlignmentDirectional.centerStart, child: TextButton(onPressed: _forgot, child: Text(context.tr('forgot')))),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('login')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => _go(const RegisterScreen()), child: Text(context.tr('register'))),
          TextButton(onPressed: () => _go(const ProviderRegisterScreen()), child: Text(context.tr('as_provider'))),
        ]),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _key = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final s = context.read<AppState>();
    setState(() => _busy = true);
    try {
      await s.register({'name': _name.text.trim(), 'phone': _phone.text.trim(), 'email': _email.text.trim(), 'password': _pass.text});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) snack(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('register'))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Form(
            key: _key,
            child: Column(children: [
              TextFormField(controller: _name, decoration: InputDecoration(labelText: context.tr('name')), validator: (v) => _req(context, v)),
              const SizedBox(height: 12),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('phone')), validator: (v) => _req(context, v)),
              const SizedBox(height: 12),
              TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: context.tr('email')), validator: (v) => _req(context, v)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(labelText: context.tr('password')),
                validator: (v) => (v == null || v.length < 8) ? (s.lang == 'en' ? 'At least 8 characters' : '8 أحرف على الأقل') : null,
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(context.tr('register')),
          ),
          const SizedBox(height: 12),
          Text(context.tr('agree'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (s.privacyUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.privacyUrl), child: Text(context.tr('privacy'))),
            if (s.termsUrl.isNotEmpty) TextButton(onPressed: () => openInApp(s.termsUrl), child: Text(context.tr('terms'))),
          ]),
        ]),
      ),
    );
  }
}
