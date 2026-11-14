import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/network_service.dart';
import '../core/repository.dart';
import '../core/shops_service.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';
import 'network_tab.dart' show statusColor;
import 'user_detail_screen.dart';
import 'shops_tab.dart';
import 'invite_panel.dart';

/// One member of the network (an agent like Saeed or a worker): their details,
/// the people linked to them (each with their own counts, tappable to go one
/// level deeper) and every shop registered by them or anyone under them, with
/// all shop tools (links, NFC, owner password, edit, suspend).
class MemberScreen extends StatefulWidget {
  const MemberScreen({
    super.key,
    required this.network,
    required this.shops,
    required this.tenant,
    required this.member,
  });

  final NetworkService network;
  final ShopsService shops;
  final String tenant;
  final Json member;

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  List<Json> members = const [];
  List<Json> shopRows = const [];
  bool loading = true;
  String? error;

  String get id => '${widget.member['user_id']}';
  bool isSuper = false;

  @override
  void initState() {
    super.initState();
    load();
    widget.network.client.rpc('nfc_am_super_admin').then((v) {
      if (mounted) setState(() => isSuper = v == true);
    }).catchError((_) {});
  }

  /// Full details (shops, cards, permissions) for the super admin.
  Future<void> _openDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => UserDetailScreen(
          service: WorkersService(widget.network.client),
          user: {'user_id': id, 'email': _fresh['email']},
          canBan: true,
        ),
      ),
    );
    if (mounted) load();
  }

  /// Removes the member with everything they created; asks about their team.
  Future<void> _deleteMember() async {
    final hasTeam = _children(id).isNotEmpty;
    var withTeam = false;
    if (hasTeam) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('لهذا الحساب أشخاص تابعون له')),
          content: Text(tr('هل تحذف فريقه أيضاً مع كل ما أنشؤوه؟ إن اخترت «أبقِهم» ينتقلون إلى المسؤول الذي فوقه.')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('أبقِهم'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('احذف الفريق أيضاً')),
            ),
          ],
        ),
      );
      if (choice == null) return;
      withTeam = choice;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(trf('حذف {0} نهائياً؟', [_fresh['name']])),
        content: Text(tr('سيُحذف الحساب ولن يستطيع الدخول للتطبيق، وتُحذف معه محلاته وزبائنها وبطاقاته ومساحات عمله. لا يمكن التراجع.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('إلغاء'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('حذف')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.network.purge(id, withTeam: withTeam);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('تم حذف الحساب وكل ما أنشأه.'))));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppColors.danger));
      }
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([widget.network.members(), widget.network.shops()]);
      if (!mounted) return;
      setState(() {
        members = r[0];
        shopRows = r[1];
      });
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Json> _children(String parent) =>
      members.where((m) => '${m['parent_id']}' == parent).toList();

  /// Ids of [root] and everyone below it.
  Set<String> _subtree(String root) {
    final out = <String>{root};
    final queue = [root];
    while (queue.isNotEmpty) {
      for (final c in _children(queue.removeLast())) {
        if (out.add('${c['user_id']}')) queue.add('${c['user_id']}');
      }
    }
    return out;
  }

  int _shopCount(Set<String> ids) =>
      shopRows.where((s) => ids.contains('${s['created_by']}')).length;

  int _customerCount(Set<String> ids) => shopRows
      .where((s) => ids.contains('${s['created_by']}'))
      .fold(0, (sum, s) => sum + ((s['customers'] as num?)?.toInt() ?? 0));

  Json get _fresh =>
      members.firstWhere((m) => '${m['user_id']}' == id, orElse: () => widget.member);

  void _open(Json m) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => MemberScreen(
        network: widget.network,
        shops: widget.shops,
        tenant: widget.tenant,
        member: m,
      ),
    ),
  );

  Widget _stat(String value, String label, IconData icon) => Expanded(
    child: Column(
      children: [
        Icon(icon, size: 18, color: AppColors.primarySoft),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ],
    ),
  );

  Widget _header() {
    final m = _fresh;
    final status = '${m['status']}';
    final color = statusColor(status);
    final subtree = _subtree(id);
    final paidUntil = DateTime.tryParse('${m['paid_until'] ?? ''}');
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.18),
                child: Icon(m['role'] == 'agent' ? Icons.hub_rounded : Icons.person_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${m['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    SelectableText('${m['email']}', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(m['role'] == 'agent' ? tr('وكيل') : tr('عامل')),
              Pill(
                status == 'paid' && paidUntil != null
                    ? trf('مدفوع حتى {0}', [shortDate(paidUntil)])
                    : status == 'expired' && paidUntil != null
                    ? trf('انتهى {0}', [shortDate(paidUntil)])
                    : statusLabel(status),
                color: color,
              ),
              if (m['active'] != true) Pill(tr('موقوف'), color: AppColors.danger),
              if ('${m['parent_name'] ?? ''}'.isNotEmpty) Pill(trf('تابع لـ {0}', [m['parent_name']]), color: AppColors.muted),
              Pill(trf('آخر دخول: {0}', [relativeTime(DateTime.tryParse('${m['last_sign_in'] ?? ''}'))]), color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${_children(id).length}', tr('مرتبطون به مباشرة'), Icons.people_alt_rounded),
              _stat('${subtree.length - 1}', tr('كل شبكته'), Icons.account_tree_rounded),
              _stat('${_shopCount(subtree)}', tr('المحلات'), Icons.storefront_rounded),
              _stat('${_customerCount(subtree)}', tr('الزبائن'), Icons.loyalty_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _memberTile(Json m) {
    final sub = _subtree('${m['user_id']}');
    final color = statusColor('${m['status']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: 0.6)),
          ),
          leading: Icon(m['role'] == 'agent' ? Icons.hub_outlined : Icons.person_outline, color: color),
          title: Text('${m['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(
            [
              m['role'] == 'agent' ? tr('وكيل') : tr('عامل'),
              trf('{0} مرتبط', [sub.length - 1]),
              trf('{0} محل', [_shopCount(sub)]),
              trf('{0} زبون', [_customerCount(sub)]),
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5),
          ),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => _open(m),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = _children(id);
    final subtree = _subtree(id);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${_fresh['name']}'),
          actions: [
            if (isSuper)
              IconButton(
                tooltip: tr('الصلاحيات والتفاصيل'),
                onPressed: _openDetails,
                icon: const Icon(Icons.admin_panel_settings_rounded),
              ),
            IconButton(
              tooltip: tr('حذف الحساب نهائياً'),
              onPressed: loading ? null : _deleteMember,
              icon: const Icon(Icons.person_remove_rounded, color: AppColors.danger),
            ),
            IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.sync_rounded)),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: trf('المرتبطون ({0})', [subtree.length - 1])),
              Tab(text: trf('المحلات ({0})', [_shopCount(subtree)])),
            ],
          ),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text(error!, style: const TextStyle(color: AppColors.danger)))
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
                      children: [
                        _header(),
                        const SizedBox(height: 12),
                        SecurityPanel(network: widget.network, userId: id, name: '${_fresh['name']}'),
                        const SizedBox(height: 16),
                        SectionTitle(tr('الأشخاص المرتبطون به')),
                        if (children.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(tr('لا يوجد أشخاص مرتبطون به بعد.'), style: const TextStyle(color: AppColors.muted)),
                          ),
                        for (final c in children) _memberTile(c),
                      ],
                    ),
                  ),
                  ShopsTab(
                    service: widget.shops,
                    network: widget.network,
                    tenant: widget.tenant,
                    seeAll: true,
                    onlyCreators: subtree,
                    allowCreate: false,
                  ),
                ],
              ),
      ),
    );
  }
}
