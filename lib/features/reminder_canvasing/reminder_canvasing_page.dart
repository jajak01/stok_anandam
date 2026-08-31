import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';

/// Halaman daftar Reminder dari database Portal (eksternal).
/// Menu khusus ADMIN & MANAGER.
class ReminderCanvasingPage extends StatefulWidget {
  const ReminderCanvasingPage({super.key});

  @override
  State<ReminderCanvasingPage> createState() => _ReminderCanvasingPageState();
}

class _ReminderCanvasingPageState extends State<ReminderCanvasingPage> {
  List<Map<String, Object?>> _reminders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = (await getIt<Dio>().get<Object>('/api/v1/reminders')).data;
      List<Map<String, Object?>> list = [];
      if (data is Map && data['data'] is List) {
        list = (data['data'] as List)
            .whereType<Map>()
            .map((e) => Map<String, Object?>.from(e))
            .toList();
      }
      if (mounted) {
        setState(() {
          _reminders = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('ReminderCanvasing load error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      currentRoute: AppRoutes.reminderCanvasing,
      userName: getIt<CurrentUserStore>().displayName,
      userRole: getIt<CurrentUserStore>().userRole,
      onNavigate: (route) => context.go(route),
      onLogout: () {
        getIt<TokenStorage>().clear();
        getIt<CurrentUserStore>().clear();
        context.go(AppRoutes.login);
      },
      title: 'Reminder Canvasing',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('${_reminders.length} Reminder',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        IconButton.filledTonal(
          onPressed: _loading ? null : _load,
          icon: Icon(_loading ? Icons.hourglass_top : Icons.refresh),
          tooltip: 'Muat ulang',
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
            const SizedBox(height: 8),
            const Text('Gagal memuat data reminder'),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (_reminders.isEmpty) {
      return const Center(child: Text('Belum ada data reminder.'));
    }
    return _buildTable(context);
  }
Widget _buildTable(BuildContext context) {
    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: _reminders.length,
      itemBuilder: (context, i) {
        final r = _reminders[i];
        final nama = r['namaInstansi']?.toString() ?? '—';
        final kategori = r['kategori']?.toString();
        final kabupaten = r['kabupaten']?.toString();
        final lastLabel = r['lastCanvasAtLabel']?.toString() ?? '—';
        final days = (r['daysNotVisited'] as num?)?.toInt() ?? 0;
        final interval = (r['intervalDays'] as num?)?.toInt() ?? 0;
        final overdue = (r['overdueDays'] as num?)?.toInt() ?? 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold)),
                          if ((kategori != null && kategori.isNotEmpty) ||
                              (kabupaten != null && kabupaten.isNotEmpty))
                            Text(
                              [
                                if (kategori != null && kategori.isNotEmpty)
                                  kategori,
                                if (kabupaten != null && kabupaten.isNotEmpty)
                                  kabupaten,
                              ].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    if (overdue > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Terlambat',
                            style: TextStyle(
                                color: Colors.red.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow(theme, Icons.history, 'Terakhir dikunjungi',
                    lastLabel),
                _infoRow(theme, Icons.event_busy, 'Tidak dikunjungi',
                    '$days hari'),
                _infoRow(theme, Icons.update, 'Interval', '$interval hari'),
                if (overdue > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Sudah melewati $overdue hari dari batas.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}