import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/i18n.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import 'link_writer_screen.dart';
import 'qr_screen.dart';

typedef _Json = Map<String, dynamic>;

String _base() {
  var b = AppConfig.profileBase.trim();
  while (b.endsWith('/')) {
    b = b.substring(0, b.length - 1);
  }
  return b;
}

String tagUrl(String code) => '${_base()}/k/$code';
String _pretty(String code) => code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;

List<_Json> _list(dynamic res) =>
    (res is List ? res : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

String _date(dynamic iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _typeLabel(_Json t) {
  if (t['status'] == 'blank') return tr('فارغة — تنتظر التفعيل');
  if (t['kind'] == 'card') return tr('💳 بطاقة أعمال');
  switch ('${t['link_type'] ?? ''}') {
    case 'google_review':
      return tr('⭐ تقييم Google');
    case 'instagram':
      return '📸 Instagram';
    case 'whatsapp':
      return '💬 WhatsApp';
    case 'tiktok':
      return '🎵 TikTok';
    case 'facebook':
      return '📘 Facebook';
    default:
      return tr('🌐 رابط');
  }
}

/// Super admin: batches of programmable codes (tapmaroc.com/k/CODE) to print
/// as QR and write on NFC cards. A buyer activates a blank code with their
/// own password and chooses what it opens (business card, Google review…).
class TagsScreen extends StatefulWidget {
  const TagsScreen({super.key, required this.repo});

  final Repository repo;

  @override
  State<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends State<TagsScreen> {
  List<_Json> batches = const [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await widget.repo.client.rpc('nfc_tag_batches');
      if (mounted) setState(() => batches = _list(res));
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> create() async {
    final count = TextEditingController(text: '20');
    final label = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('دفعة رموز جديدة')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: count,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('عدد الرموز (1 إلى 500)')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: label,
              decoration: InputDecoration(labelText: tr('اسم الدفعة (مثلاً: بطاقات سوداء نوفمبر)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('إنشاء'))),
        ],
      ),
    );
    if (ok != true) return;
    final n = int.tryParse(count.text.trim()) ?? 0;
    if (n < 1 || n > 500) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('العدد بين 1 و500'))));
      return;
    }
    try {
      final res = await widget.repo.client.rpc('nfc_tag_batch_create', params: {'how_many': n, 'label': label.text.trim()});
      await load();
      if (!mounted) return;
      final batch = res is Map ? '${res['batch']}' : '';
      if (batch.isNotEmpty) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BatchScreen(repo: widget.repo, batch: batch)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('بطاقات قابلة للبرمجة')),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: tr('تحديث'))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: create,
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('دفعة جديدة')),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(16)),
              child: Text(
                tr('أنشئ دفعة رموز، اطبعها QR أو اكتبها على بطاقات NFC وبِعها. أول من يمسح الرمز يفعّله بكلمة مرور خاصة به ويختار ما يفتحه: بطاقة أعمال، تقييم Google، Instagram، واتساب أو أي رابط.'),
                style: const TextStyle(height: 1.5),
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Padding(padding: const EdgeInsets.all(20), child: Text(error!, style: const TextStyle(color: AppColors.danger)))
            else if (batches.isEmpty)
              Padding(padding: const EdgeInsets.all(30), child: Center(child: Text(tr('لا توجد دفعات بعد. اضغط «دفعة جديدة».'))))
            else
              for (final b in batches)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.qr_code_2_rounded)),
                    title: Text('${b['batch']}'),
                    subtitle: Text(trf('{0} رمز · {1} مفعّل · {2} فارغ · {3} مسحة · {4}',
                        [b['total'], b['active'], b['blank'], b['scans'] ?? 0, _date(b['created_at'])])),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BatchScreen(repo: widget.repo, batch: '${b['batch']}')));
                      load();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _BatchScreen extends StatefulWidget {
  const _BatchScreen({required this.repo, required this.batch});

  final Repository repo;
  final String batch;

  @override
  State<_BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<_BatchScreen> {
  List<_Json> tags = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final res = await widget.repo.client.rpc('nfc_tag_list', params: {'batch_name': widget.batch});
      if (mounted) setState(() => tags = _list(res));
    } catch (e) {
      if (mounted) _snack('$e', bad: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String text, {bool bad = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: bad ? AppColors.danger : null));

  Future<void> _copyAll() async {
    final text = tags.map((t) => tagUrl('${t['code']}')).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _snack(trf('نُسخت {0} روابط — أرسلها للمطبعة.', [tags.length]));
  }

  Future<void> _admin(_Json t, String action) async {
    final code = '${t['code']}';
    if (action == 'reset' || action == 'disable') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(action == 'reset' ? tr('إرجاع الرمز فارغاً؟') : tr('إيقاف الرمز؟')),
          content: Text(action == 'reset'
              ? tr('سيُمحى كل ما برمجه صاحبه (وبطاقة الأعمال إن وجدت)، ويصبح الرمز جديداً يمكن تفعيله من جديد.')
              : tr('من يمسح الرمز سيرى أنه موقوف، حتى تعيد تفعيله.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('تأكيد')),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final res = await widget.repo.client.rpc('nfc_tag_admin', params: {'code': code, 'action': action});
      if (!mounted) return;
      if (action == 'new_password' && res is Map && res['password'] != null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('كلمة المرور الجديدة')),
            content: SelectableText('${res['password']}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
            actions: [
              TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: '${res['password']}')), child: Text(tr('نسخ'))),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(tr('تم'))),
            ],
          ),
        );
      } else {
        _snack(tr('تم ✓'));
      }
      load();
    } catch (e) {
      if (mounted) _snack('$e', bad: true);
    }
  }

  Future<void> _open(_Json t) async {
    final code = '${t['code']}';
    final url = tagUrl(code);
    final status = '${t['status']}';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(_pretty(code), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2)),
                subtitle: Text([
                  _typeLabel(t),
                  if ('${t['owner'] ?? ''}'.isNotEmpty) '${t['owner']}',
                  if ('${t['contact'] ?? ''}'.isNotEmpty) '${t['contact']}',
                  if (t['url'] != null) '${t['url']}',
                  trf('{0} مسحة', [t['scans'] ?? 0]),
                ].join('\n')),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text(tr('نسخ الرابط')),
                subtitle: Text(url, textDirection: TextDirection.ltr),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: url));
                  Navigator.pop(context);
                  _snack(tr('تم النسخ ✓'));
                },
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_rounded),
                title: Text(tr('رمز QR للطباعة')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(this.context).push(MaterialPageRoute(
                    builder: (_) => QrScreen(url: url, title: _pretty(code), business: 'TapMaroc', slug: code),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.nfc_rounded),
                title: Text(tr('كتابة الرابط على بطاقة NFC')),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(this.context).push(MaterialPageRoute(
                    builder: (_) => LinkWriterScreen(repo: widget.repo, initialUrl: url, title: _pretty(code)),
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(tr('فتح')),
                onTap: () {
                  Navigator.pop(context);
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
              ),
              if (status == 'active')
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: Text(tr('كلمة مرور جديدة لصاحبها')),
                  onTap: () {
                    Navigator.pop(context);
                    _admin(t, 'new_password');
                  },
                ),
              ListTile(
                leading: Icon(status == 'disabled' ? Icons.play_circle_rounded : Icons.pause_circle_rounded,
                    color: status == 'disabled' ? AppColors.success : AppColors.warning),
                title: Text(status == 'disabled' ? tr('إعادة تفعيل الرمز') : tr('إيقاف الرمز')),
                onTap: () {
                  Navigator.pop(context);
                  _admin(t, status == 'disabled' ? 'enable' : 'disable');
                },
              ),
              if (status != 'blank')
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: AppColors.danger),
                  title: Text(tr('إرجاعه فارغاً'), style: const TextStyle(color: AppColors.danger)),
                  onTap: () {
                    Navigator.pop(context);
                    _admin(t, 'reset');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String s) => s == 'active' ? AppColors.success : s == 'disabled' ? AppColors.danger : AppColors.muted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch),
        actions: [
          IconButton(onPressed: tags.isEmpty ? null : _copyAll, icon: const Icon(Icons.copy_all_rounded), tooltip: tr('نسخ كل الروابط')),
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: tr('تحديث')),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: tags.length,
                itemBuilder: (_, i) {
                  final t = tags[i];
                  final s = '${t['status']}';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      onTap: () => _open(t),
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(s).withValues(alpha: 0.18),
                        child: Icon(s == 'active' ? Icons.check_rounded : s == 'disabled' ? Icons.block_rounded : Icons.circle_outlined,
                            color: _statusColor(s)),
                      ),
                      title: Text(_pretty('${t['code']}'),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      subtitle: Text([_typeLabel(t), if ('${t['owner'] ?? ''}'.isNotEmpty) '${t['owner']}', trf('{0} مسحة', [t['scans'] ?? 0])].join(' · ')),
                      trailing: const Icon(Icons.more_vert_rounded),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
