import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'l10n.dart';
import 'state.dart';
import 'theme.dart';

String errText(Object e) => e is ApiException ? e.message : e.toString();

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> openUrl(String u) async {
  if (u.isEmpty) return;
  try {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Future<void> openInApp(String u) async {
  if (u.isEmpty) return;
  try {
    await launchUrl(Uri.parse(u), mode: LaunchMode.inAppBrowserView);
  } catch (_) {
    await openUrl(u);
  }
}

String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  var s = iso.replaceFirst('T', ' ');
  if (s.length > 16) s = s.substring(0, 16);
  if (s.endsWith(' 00:00')) s = s.substring(0, 10);
  return s;
}

String fmtMoney(dynamic v, [dynamic cur]) {
  if (v == null) return '';
  final n = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
  return '${n.toStringAsFixed(3)} ${cur ?? 'KWD'}';
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: box);
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'confirmed':
      case 'accepted':
      case 'approved':
      case 'completed':
        c = Colors.green.shade700;
        break;
      case 'cancelled':
      case 'rejected':
        c = Colors.red.shade700;
        break;
      case 'quoted':
        c = Colors.orange.shade800;
        break;
      default:
        c = kGreen;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(context.status(status), style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(context.tr('retry'))),
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String text;
  const EmptyView(this.text, {super.key});
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      );
}

/// Loads data, reloads whenever AppState.dataVersion changes, supports pull-to-refresh.
class DataView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function()) builder;
  const DataView({super.key, required this.load, required this.builder});
  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  T? _data;
  Object? _err;
  bool _loading = true;
  int _ver = -1;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<AppState>().dataVersion;
    if (v != _ver) {
      _ver = v;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
    if (_data == null && _loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) return ErrorView(message: errText(_err ?? ''), onRetry: _load);
    return RefreshIndicator(onRefresh: _load, child: widget.builder(context, _data as T, _load));
  }
}

class LoginPrompt extends StatelessWidget {
  final String text;
  final VoidCallback onLogin;
  const LoginPrompt({super.key, required this.text, required this.onLogin});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 48, color: kGreen),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onLogin, child: Text(context.tr('login'))),
          ]),
        ),
      );
}
