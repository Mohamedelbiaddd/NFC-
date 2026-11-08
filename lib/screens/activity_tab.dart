import 'package:flutter/material.dart';

import '../core/labels.dart';
import '../core/repository.dart';
import '../core/theme.dart';
import '../core/workers_service.dart';

/// Monitoring screen: who did what, how much, and when.
class ActivityTab extends StatefulWidget {
  const ActivityTab({
    super.key,
    required this.service,
    required this.tenant,
    this.currentUserId,
  });

  final WorkersService service;
  final String tenant;
  final String? currentUserId;

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  List<Json> members = const [];
  List<Json> feed = const [];
  String? filter;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tenant != widget.tenant) {
      members = const [];
      feed = const [];
      filter = null;
      load();
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        widget.service.overview(widget.tenant),
        widget.service.activity(widget.tenant, limit: 200),
      ]);
      if (!mounted) return;
      setState(() {
        members = results[0];
        feed = results[1];
      });
    } catch (e) {
      if (mounted) setState(() => error = userError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Json> get visibleFeed => filter == null
      ? feed
      : feed.where((row) => row['actor_id'] == filter).toList();

  String _name(Json member) {
    final display = member['display_name'];
    if (display is String && display.trim().isNotEmpty) return display.trim();
    final username = member['username'];
    if (username is String && username.isNotEmpty) return username;
    final email = '${member['email'] ?? ''}';
    return email.split('@').first;
  }

  DateTime? _time(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;

  @override
  Widget build(BuildContext context) {
    if (loading && members.isEmpty && feed.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'تعذّر تحميل المتابعة',
        text: error!,
        action: FilledButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionTitle('إنجاز كل مستخدم'),
          ...members.map(_memberCard),
          const SizedBox(height: 20),
          SectionTitle(
            'سجل النشاط',
            trailing: DropdownButton<String?>(
              value: filter,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(16),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('الكل'),
                ),
                ...members.map(
                  (m) => DropdownMenuItem<String?>(
                    value: '${m['user_id']}',
                    child: Text(_name(m), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => filter = value),
            ),
          ),
          if (visibleFeed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'لا يوجد نشاط مسجّل بعد. سيظهر كل ما يقوم به المستخدمون هنا.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else
            ...visibleFeed.map(_feedRow),
        ],
      ),
    );
  }

  Widget _memberCard(Json member) {
    final role = '${member['role'] ?? ''}';
    final username = '${member['username'] ?? ''}';
    final created = member['profiles_created'];
    final written = member['cards_written'];
    final locked = member['cards_locked'];
    final actions = member['actions'];
    final last = _time(member['last_active']);
    final name = _name(member);
    final isMe = member['user_id'] == widget.currentUserId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SurfaceCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: roleColor(role).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: roleColor(role).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.isEmpty ? '?' : name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: roleColor(role),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            const Pill('أنت', color: AppColors.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (username.isNotEmpty) '@$username',
                          roleLabel(role),
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Pill(roleLabel(role), color: roleColor(role)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _metric('أضاف', '$created', AppColors.success),
                _metric('كتب بطاقة', '$written', AppColors.primarySoft),
                _metric('مشاهدات', '${member['scans'] ?? 0}', AppColors.accent),
                _metric('نشاطات', '$actions', AppColors.warning),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    last == null
                        ? 'لا نشاط بعد'
                        : 'آخر نشاط ${relativeTime(last)} · ${shortDate(last)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                if (locked > 0)
                  Pill('$locked مقفلة', color: AppColors.muted),
                if (member['banned_until'] is String &&
                    DateTime.tryParse('${member['banned_until']}')?.isAfter(
                          DateTime.now(),
                        ) ==
                        true)
                  const Pill('محظور', color: AppColors.danger),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    ),
  );

  Widget _feedRow(Json row) {
    final action = '${row['action'] ?? ''}';
    final subject = '${row['subject'] ?? ''}';
    final actor = '${row['actor'] ?? 'مستخدم'}';
    final time = _time(row['created_at']);
    final color = actionColor(action);
    final actorId = row['actor_id'];
    final who = filter == null
        ? (actorId == widget.currentUserId ? 'أنت' : actor)
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(actionIcon(action), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      if (who != null) who,
                      actionLabel(action),
                      if (subject.isNotEmpty) '· $subject',
                    ].join(' '),
                    style: const TextStyle(fontSize: 13.5, height: 1.4),
                  ),
                  Text(
                    relativeTime(time),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (time != null)
              Text(
                shortDate(time).split(' ').first,
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}
