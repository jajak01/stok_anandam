import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:stok_anandam/core/auth/current_user_store.dart';
import 'package:stok_anandam/core/routing/app_router.dart';
import 'package:stok_anandam/data/models/memo.dart';
import 'package:stok_anandam/data/repositories/memo_repository.dart';
import 'package:stok_anandam/features/layout/dashboard_shell.dart';
import 'package:stok_anandam/features/memo/bloc/memo_bloc.dart';
import 'package:stok_anandam/core/auth/auth_service.dart';
import 'package:stok_anandam/features/memo/utils/memo_print_utils.dart';
import 'package:stok_anandam/features/penjadwalan/penjadwalan_page.dart';
import 'package:stok_anandam/injection.dart';
import 'package:stok_anandam/token_storage.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:stok_anandam/features/memo/widgets/status_badge.dart';
import 'package:stok_anandam/features/memo/widgets/hub_control_center.dart';
import 'package:stok_anandam/data/api_new_endpoints.dart';
import 'package:stok_anandam/core/env/app_env.dart';
import 'package:stok_anandam/features/shared/widgets/simple_barcode_scanner.dart';
import 'package:intl/intl.dart';
import 'package:stok_anandam/features/memo/widgets/memo_timeline_section.dart';
import 'package:stok_anandam/features/printer/printer_dialog.dart';

class MemoDetailPage extends StatelessWidget {
  final String id;
  const MemoDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userStore = getIt<CurrentUserStore>();
    final userRole = userStore.userRole?.toUpperCase();
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final horizontalPadding = isDesktop ? 32.0 : 16.0;

    return BlocProvider(
      create: (context) => MemoBloc(getIt())..add(LoadMemoDetail(id)),
      child: Builder(builder: (context) {
        return BlocConsumer<MemoBloc, MemoState>(
          listener: (context, state) {
            if (state is MemoOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.message), backgroundColor: Colors.green));

              // If technician finished their job, exit immediately instead of refreshing
              if (userRole == 'TEKNISI' && state.message.contains('Teknisi')) {
                context.go(AppRoutes.memo);
                return;
              }

              // Trigger auto-refresh for others
              context.read<MemoBloc>().add(LoadMemoDetail(id));
            } else if (state is MemoError) {
              // If technician loses access (meaning it transitioned out of their scope), exit silently or with generic message
              if (userRole == 'TEKNISI' &&
                  (state.error.contains('Akses') ||
                      state.error.contains('Forbidden') ||
                      state.error.contains('ditolak'))) {
                context.go(AppRoutes.memo);
                return;
              }

              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(state.error), backgroundColor: Colors.red));
            }
          },
          builder: (context, state) {
            MemoDetail? memo;
            if (state is MemoDetailLoaded) {
              memo = state.detail;
            }
            final bool isWaitingForInvoice =
                memo?.statusAkhir == MemoStatus.MENUNGGU_NOTA ||
                    memo?.statusAkhir == MemoStatus.MENUNGGU_GUDANG;

            Widget childWidget;
            if (state is MemoLoading || state is MemoInitial) {
              childWidget = const Center(child: CircularProgressIndicator());
            } else if (state is MemoDetailLoaded) {
              final memo = state.detail;
              childWidget = RefreshIndicator(
                onRefresh: () async {
                  context.read<MemoBloc>().add(LoadMemoDetail(id));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Back & Title (Desktop Only - Mobile used DashboardShell AppBar)
                      if (isDesktop) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.arrow_back_rounded,
                                      size: 24, color: Colors.black87),
                                  onPressed: () => context.go(AppRoutes.memo),
                                ),
                                const SizedBox(width: 8),
                                Text('Detail Memo',
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                    )),
                              ],
                            ),
                            Row(
                              children: [
                                if (memo.statusAkhir ==
                                        MemoStatus.MENUNGGU_NOTA ||
                                    memo.statusAkhir ==
                                        MemoStatus.MENUNGGU_GUDANG)
                                  TextButton.icon(
                                    onPressed: () {
                                      context
                                          .read<MemoBloc>()
                                          .add(RetryAutoMatchJlEvent(memo.id!));
                                    },
                                    icon: const Icon(Icons.sync_rounded,
                                        color: Colors.blue),
                                    label: const Text('Cari Ulang JL',
                                        style: TextStyle(color: Colors.blue)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                if ((userRole == 'ADMIN' ||
                                        userRole == 'MANAGER' ||
                                        userRole == 'SPV_MARKETING' ||
                                        (userRole != null &&
                                            userRole
                                                .startsWith('MARKETING'))) &&
                                    memo.statusAkhir == MemoStatus.DRAFT)
                                  TextButton.icon(
                                    onPressed: () async {
                                      await context.pushNamed(
                                        AppRoutes.memoCreate,
                                        extra: memo,
                                        queryParameters: {
                                          'type': memo.memoType
                                        },
                                      );
                                      if (context.mounted) {
                                        context
                                            .read<MemoBloc>()
                                            .add(LoadMemoDetail(memo.id!));
                                      }
                                    },
                                    icon: const Icon(Icons.edit_note_rounded,
                                        color: Colors.teal),
                                    label: const Text('Edit Memo',
                                        style: TextStyle(color: Colors.teal)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Main Content White Area
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        padding: EdgeInsets.all(isDesktop ? 32 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMemoHeaderRow(memo, theme, context),
                            const SizedBox(height: 24),
                            _buildTopInformationSection(
                                memo, isDesktop, theme, context),
                            const SizedBox(height: 32),
                            _buildDescriptionBox(memo, userRole, context),
                            const SizedBox(height: 32),
                            _buildQrSection(memo, theme, context, isDesktop),
                            const SizedBox(height: 32),
                            _buildItemListTable(memo, userRole, context),

                            const SizedBox(height: 32),
                            _buildBottomBoxes(
                                context, memo, theme, isDesktop, userRole),
                            const SizedBox(height: 24),

                            if (memo.buktiFoto != null &&
                                memo.buktiFoto!.isNotEmpty) ...[
                              const SizedBox(height: 32),
                              _buildDeliveryProofSection(memo, theme, context),
                            ],

                            // Audit Log
                            if ((userRole != null &&
                                    userRole.startsWith('MARKETING')) ||
                                userRole == 'SPV_MARKETING' ||
                                userRole == 'ADMIN' ||
                                userRole == 'MANAGER' ||
                                userRole == 'SPV_GUDANG' ||
                                userRole == 'SPV_TEKNISI') ...[
                              const SizedBox(height: 40),
                              Text('Riwayat Aktivitas',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700)),
                              const SizedBox(height: 20),
                              MemoTimelineSection(memo: memo),
                            ],

                            const SizedBox(height: 32),
                            _buildRoleActionButtons(
                                memo, userRole ?? '', context),

                            const SizedBox(height: 32),
                            _buildActionBar(memo, userRole, context, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (state is MemoError) {
              childWidget = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(state.error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<MemoBloc>().add(LoadMemoDetail(id)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              );
            } else {
              childWidget = const SizedBox();
            }

            return DashboardShell(
              currentRoute: AppRoutes.memo,
              onScan: () async {
                await context.pushNamed(AppRoutes.scanner);
                if (context.mounted) {
                  context.read<MemoBloc>().add(LoadMemoDetail(id));
                }
              },
              userName: userStore.displayName,
              userRole: userStore.userRole,
              title: 'Detail Memo',
              onNavigate: (route) => context.go(route),
              onLogout: () async {
                await getIt<AuthService>().logout();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
              },
              onRefresh: () {
                context.read<MemoBloc>().add(LoadMemoDetail(id));
              },
              onHeaderAction: isWaitingForInvoice
                  ? () =>
                      context.read<MemoBloc>().add(RetryAutoMatchJlEvent(id))
                  : null,
              headerActionLabel: 'Cari Ulang JL',
              headerActionIcon: Icons.sync_rounded,
              child: childWidget,
            );
          },
        );
      }),
    );
  }

  Widget _buildMemoHeaderRow(
      MemoDetail memo, ThemeData theme, BuildContext context) {
    final memoId = memo.nomorMemo ?? memo.id ?? '';
    final userStore = getIt<CurrentUserStore>();
    final userRole = userStore.userRole?.toUpperCase();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final showEditButton = (userRole == 'ADMIN' ||
            userRole == 'MANAGER' ||
            userRole == 'SPV_MARKETING' ||
            (userRole != null && userRole.startsWith('MARKETING'))) &&
        memo.statusAkhir == MemoStatus.DRAFT;

    final showInputJlButton = (userRole == 'NOTA' ||
            userRole == 'GUDANG' ||
            userRole == 'SPV_GUDANG' ||
            userRole == 'ADMIN' ||
            userRole == 'MANAGER') &&
        memo.statusAkhir == MemoStatus.MENUNGGU_NOTA &&
        (memo.nomorJl == null || memo.nomorJl!.isEmpty);

    if (isDesktop) {
      return Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            '#$memoId',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (memo.revisedFromNomorMemo != null &&
                            memo.revisedFromNomorMemo!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                'REV DARI: ${memo.revisedFromNomorMemo}',
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    onPressed: () =>
                        _copyToClipboard(context, memoId, 'ID Memo'),
                    tooltip: 'Salin ID Memo',
                  ),
                ],
              ),
            ),
          ),
          if (showInputJlButton)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilledButton.icon(
                onPressed: () => _showNotaInputDialog(context, memo.id!),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Input JL', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, size: 22),
            color: theme.colorScheme.primary,
            onPressed: () => _copyToClipboard(
                context, _generateMemoCopyText(memo), 'Seluruh Data Memo'),
            tooltip: 'Salin Seluruh Data Memo',
          ),
          const SizedBox(width: 8),
          StatusBadge(status: memo.statusAkhir ?? MemoStatus.DRAFT),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                '#$memoId',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            if (memo.revisedFromNomorMemo != null &&
                                memo.revisedFromNomorMemo!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    'REV DARI: ${memo.revisedFromNomorMemo}',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        onPressed: () =>
                            _copyToClipboard(context, memoId, 'ID Memo'),
                        tooltip: 'Salin ID Memo',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: memo.statusAkhir ?? MemoStatus.DRAFT),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (showInputJlButton)
                FilledButton.icon(
                  onPressed: () => _showNotaInputDialog(context, memo.id!),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Input JL', style: TextStyle(fontSize: 12)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              if (showEditButton)
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.pushNamed(
                      AppRoutes.memoCreate,
                      extra: memo,
                      queryParameters: {'type': memo.memoType},
                    );
                    if (context.mounted) {
                      context.read<MemoBloc>().add(LoadMemoDetail(memo.id!));
                    }
                  },
                  icon: const Icon(Icons.edit_note_rounded,
                      size: 16, color: Colors.teal),
                  label: const Text('Edit Memo',
                      style: TextStyle(color: Colors.teal, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.teal),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _copyToClipboard(
                    context, _generateMemoCopyText(memo), 'Seluruh Data Memo'),
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Salin Memo', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showPrinterDialog(context, memo),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Print', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    if (text.isEmpty || text == '-') return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text('$label berhasil disalin'),
          ],
        ),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildTopInformationSection(
      MemoDetail memo, bool isDesktop, ThemeData theme, BuildContext context) {
    final marketing = memo.marketingName ?? '-';
    final payment = memo.metodePembayaran ?? '-';
    final prosesKirim = memo.isDeliveryRequired;
    final prosesTeknis = memo.isTeknisRequired;

    if (isDesktop) {
      return Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Customer Section
                Expanded(
                  flex: 3,
                  child: _buildHeaderCard(
                    theme,
                    title: 'Data Pelanggan',
                    icon: Icons.person_outline_rounded,
                    children: [
                      _buildInfoCol('Pelanggan',
                          (memo.customerName ?? '-').toUpperCase(), theme,
                          onCopy: () => _copyToClipboard(
                              context,
                              (memo.customerName ?? '').toUpperCase(),
                              'Nama Pelanggan')),
                      if (memo.memoType != 'ONLINE')
                        _buildInfoCol(
                            'No HP', memo.customerPhone ?? '-', theme),
                      if (memo.memoType != 'ONLINE')
                        _buildInfoCol(
                            'Alamat Pengiriman',
                            (memo.desaKelurahan != null &&
                                    memo.desaKelurahan!.isNotEmpty)
                                ? "${memo.desaKelurahan}, ${memo.kecamatan}, ${memo.kabupatenKota}${memo.kodePos != null ? ' (${memo.kodePos})' : ''}"
                                : (memo.penjadwalanHistory.any((j) =>
                                        j.alamatLengkap != null &&
                                        j.alamatLengkap!.isNotEmpty)
                                    ? memo.penjadwalanHistory
                                        .lastWhere((j) =>
                                            j.alamatLengkap != null &&
                                            j.alamatLengkap!.isNotEmpty)
                                        .alamatLengkap!
                                    : (memo.kodePos != null &&
                                            memo.kodePos!.isNotEmpty
                                        ? memo.kodePos!
                                        : '-')),
                            theme),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 2. Order Section
                Expanded(
                  flex: 4,
                  child: _buildHeaderCard(
                    theme,
                    title: 'Detail Transaksi',
                    icon: Icons.receipt_long_outlined,
                    children: [
                      _buildInfoCol(
                          'Tanggal',
                          memo.tanggalMemo != null
                              ? _formatDate(memo.tanggalMemo!)
                              : '-',
                          theme),
                      _buildInfoCol('Marketing (PJ)', marketing, theme),
                      if (memo.creatorName != null)
                        _buildInfoCol('Dibuat Oleh', memo.creatorName!, theme),
                      _buildInfoCol('Tipe Memo', memo.memoType ?? '-', theme),
                      if (memo.badanUsaha != null && memo.memoType == 'PROJECT')
                        _buildInfoCol('Badan Usaha', memo.badanUsaha!, theme),
                      if (memo.orderIdMarketplace != null)
                        _buildInfoCol(
                            'Order ID', memo.orderIdMarketplace!, theme,
                            onCopy: () => _copyToClipboard(
                                context, memo.orderIdMarketplace!, 'Order ID')),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 3. Logistics & Billing Section
                Expanded(
                  flex: 4,
                  child: _buildHeaderCard(
                    theme,
                    title: 'Fulfillment & Pembayaran',
                    icon: Icons.local_shipping_outlined,
                    children: [
                      if (memo.opsiPengiriman != null)
                        _buildInfoCol(
                            'Fulfillment',
                            (memo.isDeliveryRequired ||
                                    memo.opsiPengiriman!
                                        .toUpperCase()
                                        .contains('DELIVERY') ||
                                    memo.opsiPengiriman!
                                        .toUpperCase()
                                        .contains('KIRIM') ||
                                    memo.opsiPengiriman!
                                        .toUpperCase()
                                        .contains('DIKIRIM') ||
                                    memo.opsiPengiriman!
                                        .toUpperCase()
                                        .contains('MARKETING') ||
                                    memo.opsiPengiriman!
                                        .toUpperCase()
                                        .contains('DRIVER'))
                                ? memo.deliveryMethodLabel
                                : 'AMBIL DI TOKO',
                            theme),
                      if (memo.memoType != 'ONLINE')
                        _buildInfoCol(
                            'Payment',
                            (memo.metodePembayaran?.toUpperCase() == 'TEMPO' &&
                                    memo.tempo != null &&
                                    memo.tempo!.isNotEmpty)
                                ? '$payment ${memo.tempo!.toLowerCase().contains('hari') ? memo.tempo : '${memo.tempo} Hari'}'
                                : payment,
                            theme),
                      if (memo.platform != null)
                        _buildInfoCol('Platform', memo.platform!, theme),
                      if (memo.nomorJl != null && memo.nomorJl!.isNotEmpty)
                        _buildInfoCol('Invoice / JL', memo.nomorJl!, theme,
                            onCopy: () => _copyToClipboard(
                                context, memo.nomorJl!, 'Invoice / JL')),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildProcessItem('Proses Kirim', prosesKirim, theme),
                          const SizedBox(width: 24),
                          _buildProcessItem(
                              'Proses Teknisi', prosesTeknis, theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (memo.resi != null || memo.ekspedisi != null) ...[
            const SizedBox(height: 16),
            _buildHeaderCard(
              theme,
              title: 'Informasi Marketplace / Ekspedisi',
              icon: Icons.hub_outlined,
              isRow: true,
              children: [
                _buildInfoCol('Resi', memo.resi ?? '-', theme,
                    onEdit: () =>
                        _showEditResiDialog(context, memo.id!, memo.resi ?? ''),
                    onCopy: () =>
                        _copyToClipboard(context, memo.resi ?? '', 'Resi')),
                if (memo.ekspedisi != null)
                  _buildInfoCol(
                      'Ekspedisi',
                      memo.memoType == 'ONLINE' && memo.subEkspedisi != null
                          ? '${memo.ekspedisi} - ${memo.subEkspedisi}'
                          : memo.ekspedisi!,
                      theme),
                if (memo.estimasiOngkir != null &&
                    memo.estimasiOngkir!.isNotEmpty)
                  _buildInfoCol('Estimasi Ongkir', memo.estimasiOngkir!, theme),
              ],
            ),
          ],
        ],
      );
    } else {
      // Mobile version
      final alamatMobile = (memo.desaKelurahan != null &&
              memo.desaKelurahan!.isNotEmpty)
          ? "${memo.desaKelurahan}, ${memo.kecamatan}, ${memo.kabupatenKota}${memo.kodePos != null ? ' (${memo.kodePos})' : ''}"
          : (memo.penjadwalanHistory.any(
                  (j) => j.alamatLengkap != null && j.alamatLengkap!.isNotEmpty)
              ? memo.penjadwalanHistory
                  .lastWhere((j) =>
                      j.alamatLengkap != null && j.alamatLengkap!.isNotEmpty)
                  .alamatLengkap!
              : (memo.kodePos != null && memo.kodePos!.isNotEmpty
                  ? memo.kodePos!
                  : '-'));

      final fulfillmentMethod = (memo.isDeliveryRequired ||
              (memo.opsiPengiriman ?? '').toUpperCase().contains('DELIVERY') ||
              (memo.opsiPengiriman ?? '').toUpperCase().contains('KIRIM') ||
              (memo.opsiPengiriman ?? '').toUpperCase().contains('DIKIRIM') ||
              (memo.opsiPengiriman ?? '').toUpperCase().contains('MARKETING') ||
              (memo.opsiPengiriman ?? '').toUpperCase().contains('DRIVER'))
          ? memo.deliveryMethodLabel
          : 'AMBIL DI TOKO';

      final processes = [
        _buildProcessItem('Proses Kirim', prosesKirim, theme),
        _buildProcessItem('Proses Teknisi', prosesTeknis, theme),
      ];

      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade100),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nama Pelanggan Besar di Atas + Copy Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    (memo.customerName ?? '-').toUpperCase(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _copyToClipboard(
                      context,
                      (memo.customerName ?? '').toUpperCase(),
                      'Nama Pelanggan'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.copy_rounded,
                        size: 16, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            if (memo.memoType != 'ONLINE') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    memo.customerPhone ?? '-',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      alamatMobile,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(thickness: 1, color: Color(0xFFF1F5F9)),
            ),

            // Info Data (Split View Layout)
            Builder(builder: (context) {
              final List<Widget> allItems = [];
              if (memo.tanggalMemo != null) {
                allItems.add(_buildIconText(Icons.calendar_today_outlined,
                    _formatDate(memo.tanggalMemo!), theme));
              }
              if (memo.opsiPengiriman != null) {
                allItems.add(_buildIconText(
                    Icons.local_shipping_outlined, fulfillmentMethod, theme));
              }
              allItems
                  .add(_buildIconText(Icons.person_outline, marketing, theme));
              if (memo.creatorName != null) {
                allItems.add(_buildIconText(
                    Icons.edit_note_outlined, memo.creatorName!, theme));
              }
              if (memo.badanUsaha != null && memo.memoType == 'PROJECT') {
                allItems.add(_buildIconText(
                    Icons.business_outlined, memo.badanUsaha!, theme));
              }
              if (memo.memoType != 'ONLINE') {
                allItems.add(_buildIconText(
                    Icons.payment_outlined,
                    (memo.metodePembayaran?.toUpperCase() == 'TEMPO' &&
                            memo.tempo != null &&
                            memo.tempo!.isNotEmpty)
                        ? '$payment ${memo.tempo!.toLowerCase().contains('hari') ? memo.tempo : '${memo.tempo} Hari'}'
                        : payment,
                    theme));
              }
              if (memo.platform != null) {
                allItems.add(_buildIconText(
                    Icons.shopping_bag_outlined, memo.platform!, theme));
              }
              if (memo.ekspedisi != null) {
                allItems.add(_buildIconText(
                    Icons.rocket_launch_outlined,
                    memo.memoType == 'ONLINE' && memo.subEkspedisi != null
                        ? '${memo.ekspedisi} - ${memo.subEkspedisi}'
                        : memo.ekspedisi!,
                    theme));
              }
              if (memo.estimasiOngkir != null &&
                  memo.estimasiOngkir!.isNotEmpty) {
                allItems.add(_buildIconText(
                    Icons.monetization_on_outlined,
                    memo.estimasiOngkir!,
                    theme));
              }
              final int mid = (allItems.length + 1) ~/ 2;
              final leftItems = allItems.sublist(0, mid);
              final rightItems = allItems.sublist(mid);

              final List<TableRow> tableRows = [];
              final int rowCount = leftItems.length > rightItems.length
                  ? leftItems.length
                  : rightItems.length;

              for (int i = 0; i < rowCount; i++) {
                final bool hasLeft = i < leftItems.length;
                final bool hasRight = i < rightItems.length;

                tableRows.add(
                  TableRow(
                    children: [
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: hasLeft
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: leftItems[i],
                              )
                            : const SizedBox.shrink(),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.fill,
                        child: Container(
                          margin: const EdgeInsets.only(left: 11, right: 12),
                          color: const Color(0xFFE2E8F0),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: hasRight
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: rightItems[i],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );

                // Add horizontal dividers
                if (i < rowCount - 1) {
                  final bool nextHasLeft = (i + 1) < leftItems.length;
                  final bool nextHasRight = (i + 1) < rightItems.length;

                  tableRows.add(
                    TableRow(
                      children: [
                        nextHasLeft
                            ? const Divider(
                                endIndent: 8, height: 1, thickness: 0.8)
                            : const SizedBox.shrink(),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.fill,
                          child: Container(
                            margin: const EdgeInsets.only(left: 11, right: 12),
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                        nextHasRight
                            ? const Divider(
                                indent: 8, height: 1, thickness: 0.8)
                            : const SizedBox.shrink(),
                      ],
                    ),
                  );
                }
              }

              return Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FixedColumnWidth(24),
                  2: FlexColumnWidth(1),
                },
                children: tableRows,
              );
            }),

            // Important Codes (Order ID, JL, Resi)
            if (memo.orderIdMarketplace != null ||
                (memo.nomorJl != null && memo.nomorJl!.isNotEmpty) ||
                memo.resi != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (memo.orderIdMarketplace != null)
                      _buildCopyableRow(
                          context,
                          'Order ID',
                          memo.orderIdMarketplace!,
                          Icons.shopping_cart_checkout),
                    if (memo.nomorJl != null && memo.nomorJl!.isNotEmpty) ...[
                      if (memo.orderIdMarketplace != null)
                        const SizedBox(height: 10),
                      _buildCopyableRow(context, 'Invoice', memo.nomorJl!,
                          Icons.receipt_long_outlined),
                    ],
                    if (memo.resi != null && memo.resi!.isNotEmpty) ...[
                      if (memo.orderIdMarketplace != null ||
                          (memo.nomorJl != null && memo.nomorJl!.isNotEmpty))
                        const SizedBox(height: 10),
                      _buildCopyableRow(context, 'Resi', memo.resi!,
                          Icons.confirmation_number_outlined,
                          onEdit: () => _showEditResiDialog(
                              context, memo.id!, memo.resi!)),
                    ],
                  ],
                ),
              ),
            ],

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(thickness: 1, color: Color(0xFFF1F5F9)),
            ),

            // Proses Kirim / Teknisi (Tetap pakai label)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: processes,
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHeaderCard(ThemeData theme,
      {required String title,
      required IconData icon,
      required List<Widget> children,
      bool isRow = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          isRow
              ? IntrinsicHeight(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: children
                        .expand((w) => [Expanded(child: w), _verticalDivider()])
                        .toList()
                      ..removeLast(),
                  ),
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: children,
                ),
        ],
      ),
    );
  }

  Widget _buildProcessItem(String label, bool isYes, ThemeData theme) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        _buildYesNoPill(isYes, theme),
      ],
    );
  }

  Widget _buildIconText(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableRow(
      BuildContext context, String label, String value, IconData icon,
      {VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onEdit != null)
            InkWell(
              onTap: onEdit,
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_outlined,
                    size: 14, color: Colors.blue),
              ),
            ),
          InkWell(
            onTap: () => _copyToClipboard(context, value, label),
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  const Icon(Icons.copy_rounded, size: 14, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, ThemeData theme,
      {VoidCallback? onEdit, VoidCallback? onCopy}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            if (onCopy != null && value != '-' && value.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 14, color: Colors.teal),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onCopy,
              ),
            if (onEdit != null) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit, size: 14, color: Colors.blue),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onEdit,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1.2,
      height: double.infinity,
      color: const Color(0xFFE2E8F0),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildYesNoPill(bool isYes, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isYes
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        border: Border.all(
            color: isYes
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isYes ? 'YA' : 'TIDAK',
        style: TextStyle(
          color: isYes ? Colors.green.shade700 : Colors.grey.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildItemListTable(
      MemoDetail memo, String? userRole, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daftar Barang',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                // Table Header
                Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                          flex: 4,
                          child: Text('Item',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary))),
                      Expanded(
                          flex: 2,
                          child: Text('Qty / Kirim',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary))),
                      Expanded(
                          flex: 3,
                          child: Text('Harga',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary))),
                      Expanded(
                          flex: 4,
                          child: Text('Subtotal',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary))),
                    ],
                  ),
                ),
                // Table Body
                ...memo.items.map((item) => Container(
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade100))),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  flex: 4,
                                  child: Text(item.namaBarang ?? '-',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600))),
                              Expanded(
                                  flex: 2,
                                  child: Text(
                                      '${item.qty} / ${item.qtyShipped}',
                                      style: theme.textTheme.bodyMedium)),
                              Expanded(
                                  flex: 3,
                                  child: Text(_formatRupiah(item.hargaSatuan),
                                      style: theme.textTheme.bodyMedium)),
                              Expanded(
                                  flex: 4,
                                  child: Text(_formatRupiah(item.subtotal),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold))),
                            ],
                          ),
                          if (item.catatanGudang != null &&
                              item.catatanGudang!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 14, color: Colors.amber.shade800),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Catatan: ${item.catatanGudang}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                  if (userRole == 'GUDANG' ||
                                      userRole == 'SPV_GUDANG' ||
                                      userRole == 'ADMIN' ||
                                      userRole == 'MANAGER')
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 14, color: Colors.blue),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _showEditNoteDialog(
                                          context,
                                          memo.id!,
                                          item.id!,
                                          item.catatanGudang ?? ''),
                                    ),
                                ],
                              ),
                            ),
                          ] else if (userRole == 'GUDANG' ||
                              userRole == 'SPV_GUDANG' ||
                              userRole == 'ADMIN' ||
                              userRole == 'MANAGER') ...[
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () => _showEditNoteDialog(context,
                                  memo.id!, item.id!, item.catatanGudang ?? ''),
                              icon: const Icon(Icons.add_comment_outlined,
                                  size: 14),
                              label: const Text('Tambah Catatan',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          ],
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBoxes(BuildContext context, MemoDetail memo,
      ThemeData theme, bool isDesktop, String? userRole) {
    bool butuhKirim = memo.isDeliveryRequired && memo.memoType != 'ONLINE';

    final scheduleLogisticsTypes = [
      'PENGIRIMAN',
      'PENGAMBILAN',
      'DROP_OFF_EKSPEDISI'
    ];
    final jadwalKirim = memo.penjadwalanHistory
        .where((j) => scheduleLogisticsTypes.contains(j.tipeTugas))
        .toList();
    final latestKirim = jadwalKirim.isNotEmpty ? jadwalKirim.last : null;

    bool adaJadwalKirim = latestKirim != null;
    String kirimOleh = latestKirim?.personelName != null
        ? "${latestKirim!.personelName} (${latestKirim.personelRole ?? 'Driver'})"
        : (latestKirim?.personelId != null
            ? "ID: ${latestKirim?.personelId}"
            : "-");
    String kirimTanggal = latestKirim?.tanggalJadwal ?? "-";
    String kirimJam = latestKirim?.estimasiWaktu ?? "-";

    bool butuhTeknis = memo.isTeknisRequired;

    final jadwalTeknis =
        memo.penjadwalanHistory.where((j) => j.tipeTugas == 'TEKNISI').toList();
    final latestTeknis = jadwalTeknis.isNotEmpty ? jadwalTeknis.last : null;

    bool adaJadwalTeknis = latestTeknis != null;

    String teknisOleh = latestTeknis?.personelName != null
        ? "${latestTeknis!.personelName} (${latestTeknis.personelRole ?? 'Teknisi'})"
        : (latestTeknis?.personelId != null
            ? "ID: ${latestTeknis?.personelId}"
            : "-");
    String teknisTanggal = latestTeknis?.tanggalJadwal ?? "-";
    String teknisJam = latestTeknis?.estimasiWaktu ?? "-";

    Color bgKirim = theme.colorScheme.surface;
    Color borderKirim = Colors.grey.shade200;

    if (adaJadwalKirim) {
      if (latestKirim.statusJadwal == 'DIJADWALKAN') {
        bgKirim = Colors.green.withValues(alpha: 0.05);
        borderKirim = Colors.green.withValues(alpha: 0.2);
      } else {
        bgKirim = Colors.red.withValues(alpha: 0.05);
        borderKirim = Colors.red.withValues(alpha: 0.2);
      }
    }

    Color bgTeknis = theme.colorScheme.surface;
    Color borderTeknis = Colors.grey.shade200;

    if (adaJadwalTeknis) {
      if (latestTeknis.statusJadwal == 'DIJADWALKAN') {
        bgTeknis = Colors.green.withValues(alpha: 0.05);
        borderTeknis = Colors.green.withValues(alpha: 0.2);
      } else {
        bgTeknis = Colors.red.withValues(alpha: 0.05);
        borderTeknis = Colors.red.withValues(alpha: 0.2);
      }
    }

    final scheduleWidgets = [
      _buildScheduleBox(
          context: context,
          memo: memo,
          title: 'Penjadwalan Teknisi',
          isRequired: butuhTeknis,
          hasJadwal: adaJadwalTeknis,
          oleh: teknisOleh,
          tanggal: teknisTanggal,
          jam: teknisJam,
          bgColor: bgTeknis,
          borderColor: borderTeknis,
          tipe: TipeJadwal.teknisi,
          theme: theme,
          userRole: userRole),
      const SizedBox(width: 16),
      _buildScheduleBox(
          context: context,
          memo: memo,
          title: 'Penjadwalan Kirim',
          isRequired: butuhKirim,
          hasJadwal: adaJadwalKirim,
          oleh: kirimOleh,
          tanggal: kirimTanggal,
          jam: kirimJam,
          bgColor: bgKirim,
          borderColor: borderKirim,
          tipe: TipeJadwal.kirim,
          theme: theme,
          userRole: userRole),
    ];

    final totalBox = Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            isDesktop ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Item',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(
                    '${memo.totalQty.toString().replaceAll(RegExp(r'\.0$'), '')} Pcs',
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total Penjualan',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(_formatRupiah(memo.totalHarga),
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (isDesktop) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Expanded(child: scheduleWidgets[0]),
                  const SizedBox(width: 16),
                  Expanded(child: scheduleWidgets[2]),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: totalBox),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          scheduleWidgets[0],
          const SizedBox(height: 12),
          scheduleWidgets[2],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: totalBox),
        ],
      );
    }
  }

  Widget _buildScheduleBox({
    required BuildContext context,
    required MemoDetail memo,
    required String title,
    required bool isRequired,
    required bool hasJadwal,
    String? oleh,
    String? tanggal,
    String? jam,
    required Color bgColor,
    required Color borderColor,
    required TipeJadwal tipe,
    required ThemeData theme,
    String? userRole,
  }) {
    final bool canSchedule = isRequired ||
        userRole == 'GUDANG' ||
        userRole == 'SPV_GUDANG' ||
        userRole == 'ADMIN' ||
        userRole == 'MANAGER' ||
        (userRole != null && userRole.startsWith('MARKETING'));

    final double activeOpacity = canSchedule ? 1.0 : 0.4;

    return InkWell(
        onTap: !canSchedule
            ? null
            : () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PenjadwalanPage(
                      memoId: memo.id!,
                      memo: memo,
                      tipe: tipe,
                    ),
                  ),
                );

                if (result == true && context.mounted) {
                  context.read<MemoBloc>().add(LoadMemoDetail(memo.id!));
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor.withValues(alpha: activeOpacity * bgColor.a),
            border: Border.all(
                color: borderColor.withValues(
                    alpha: activeOpacity * borderColor.a)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                      tipe == TipeJadwal.kirim
                          ? Icons.local_shipping_outlined
                          : Icons.build_outlined,
                      size: 16,
                      color: theme.colorScheme.primary
                          .withValues(alpha: activeOpacity)),
                  const SizedBox(width: 8),
                  Text(title,
                      style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: activeOpacity))),
                ],
              ),
              const SizedBox(height: 12),
              if (hasJadwal) ...[
                _buildSmallInfo('Oleh', oleh ?? '-', opacity: activeOpacity),
                const SizedBox(height: 4),
                _buildSmallInfo('Tanggal', tanggal ?? '-',
                    opacity: activeOpacity),
                const SizedBox(height: 4),
                _buildSmallInfo('Jam', jam ?? '-', opacity: activeOpacity),
              ] else ...[
                Text(isRequired ? 'Belum Dijadwalkan' : 'Tidak Diperlukan',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.withValues(alpha: activeOpacity))),
              ]
            ],
          ),
        ));
  }

  Widget _buildSmallInfo(String label, String value, {double opacity = 1.0}) {
    return Row(
      children: [
        Text('$label: ',
            style: TextStyle(
                fontSize: 11, color: Colors.grey.withValues(alpha: opacity))),
        Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: opacity < 1.0
                        ? Colors.black.withValues(alpha: opacity)
                        : null))),
      ],
    );
  }

  Widget _buildDescriptionBox(
      MemoDetail memo, String? userRole, BuildContext context) {
    final theme = Theme.of(context);
    if (memo.deskripsi == null || memo.deskripsi!.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Deskripsi / Catatan Tambahan',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
            border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            memo.deskripsi!,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryProofSection(
      MemoDetail memo, ThemeData theme, BuildContext context) {
    String photoUrl = '';
    if (memo.buktiFotoUrl != null && memo.buktiFotoUrl!.isNotEmpty) {
      photoUrl = memo.buktiFotoUrl!.startsWith('http')
          ? memo.buktiFotoUrl!
          : '$apiBaseUrl${memo.buktiFotoUrl!.startsWith('/') ? '' : '/'}${memo.buktiFotoUrl}';
    } else if (memo.buktiFoto != null && memo.buktiFoto!.isNotEmpty) {
      photoUrl = memo.buktiFoto!.startsWith('http')
          ? memo.buktiFoto!
          : '$apiBaseUrl/uploads/${memo.buktiFoto}';
    }
    final token = getIt<TokenStorage>().token;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bukti Pengiriman',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _showFullScreenImage(context, photoUrl),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.network(
                        photoUrl,
                        headers: {
                          if (token != null && token.isNotEmpty)
                            'Authorization': 'Bearer $token',
                        },
                        width: double.infinity,
                        height: 250,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 250,
                            color: Colors.grey.shade100,
                            child: const Center(
                                child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            color: Colors.grey.shade100,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_outlined,
                                    size: 48, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('Gagal memuat gambar',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text('Tap untuk perbesar',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Foto bukti pengiriman terverifikasi',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final token = getIt<TokenStorage>().token;
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  headers: {
                    if (token != null && token.isNotEmpty)
                      'Authorization': 'Bearer $token',
                  },
                  fit: BoxFit.contain,
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBar(MemoDetail memo, String? userRole,
      BuildContext context, ThemeData theme) {
    userRole = userRole?.toUpperCase();
    final bool isAdmin = userRole == 'ADMIN' || userRole == 'MANAGER';
    final bool isMarketing =
        (userRole != null && userRole.startsWith('MARKETING')) ||
            userRole == 'SPV_MARKETING';

    // Logic for Finalize (Draft -> Waiting Warehouse)
    bool canFinalize =
        (isAdmin || isMarketing) && memo.statusAkhir == MemoStatus.DRAFT;

    if (!canFinalize) return const SizedBox();

    final bool isMobile = MediaQuery.of(context).size.width < 720;

    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showForceCompleteDialog(context, memo.id!),
                      icon: const Icon(Icons.gavel_rounded),
                      label: const Text('SELESAIKAN PAKSA (ADMIN)'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (canFinalize)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (memo.isDeliveryRequired) {
                        final hasKirim = memo.penjadwalanHistory
                            .any((j) => j.tipeTugas == 'PENGIRIMAN');
                        if (!hasKirim) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Gagal: Pengiriman wajib dijadwalkan terlebih dahulu')));
                          return;
                        }
                      }
                      /* Removed mandatory technician scheduling check per user request */
                      context.read<MemoBloc>().add(FinalizeMemoEvent(memo.id!));
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Buat & Kirim ke Gudang'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showForceCompleteDialog(context, memo.id!),
                    icon: const Icon(Icons.gavel_rounded),
                    label: const Text('SELESAIKAN PAKSA (ADMIN)'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                const Spacer(),
                if (canFinalize)
                  ElevatedButton.icon(
                    onPressed: () {
                      if (memo.isDeliveryRequired &&
                          memo.memoType != 'ONLINE') {
                        final hasKirim = memo.penjadwalanHistory
                            .any((j) => j.tipeTugas == 'PENGIRIMAN');
                        if (!hasKirim) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Gagal: Pengiriman wajib dijadwalkan terlebih dahulu')));
                          return;
                        }
                      }
                      /* Removed mandatory technician scheduling check per user request */
                      context.read<MemoBloc>().add(FinalizeMemoEvent(memo.id!));
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Buat & Kirim ke Gudang'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 18, horizontal: 32),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
              ],
            ),
    );
  }

  Widget _buildRoleActionButtons(
      MemoDetail memo, String userRole, BuildContext context) {
    final status = memo.statusAkhir;
    final id = memo.id!;
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- GUDANG / ADMIN / MANAGER (ACC/Reject Pending) ---
          if ((userRole == 'GUDANG' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'SPV_GUDANG') &&
              (status == MemoStatus.MENUNGGU_PERSETUJUAN ||
                  status == MemoStatus.PENDING))
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 450) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => context
                          .read<MemoBloc>()
                          .add(ApproveMemoEvent(id.toString())),
                      icon: const Icon(Icons.check),
                      label: const Text('ACC (Setujui)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => context
                          .read<MemoBloc>()
                          .add(RejectMemoEvent(id.toString())),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak PENDING'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context
                          .read<MemoBloc>()
                          .add(RejectMemoEvent(id.toString())),
                      icon: const Icon(Icons.close),
                      label: const Text('Tolak PENDING'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context
                          .read<MemoBloc>()
                          .add(ApproveMemoEvent(id.toString())),
                      icon: const Icon(Icons.check),
                      label: const Text('ACC (Setujui)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              );
            }),

          // --- POST-APPROVAL ACTIONS (Continue / Finish) ---
          if (((userRole.startsWith('MARKETING')) ||
                  userRole == 'SPV_MARKETING' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER') &&
              status == MemoStatus.DISETUJUI)
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 500) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showContinueTypePicker(context, memo),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Lanjutkan Buat Memo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _showFinishPendingConfirmation(
                          context, id.toString()),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Selesai (Hanya PENDING)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showFinishPendingConfirmation(
                          context, id.toString()),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Selesai (Hanya PENDING)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        side: BorderSide(color: Colors.green.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showContinueTypePicker(context, memo),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Lanjutkan Buat Memo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              );
            }),

          if ((userRole == 'GUDANG' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'SPV_GUDANG' ||
                  userRole == 'SPV_MARKETING') &&
              status == MemoStatus.MENUNGGU_GUDANG)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showConfirmDialog(
                      context: context,
                      title: 'Konfirmasi Barang Selesai?',
                      message:
                          'Tandai proses warehouse (label/nota/picking) telah selesai?',
                      icon: Icons.check_circle_rounded,
                      confirmColor: Colors.green,
                      onConfirm: () {
                        context
                            .read<MemoBloc>()
                            .add(FinishGudangProcessEvent(id.toString()));
                      },
                    );
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Konfirmasi Barang Selesai'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showReportIssueDialog(context, id.toString()),
                  icon: const Icon(Icons.report_problem_rounded),
                  label: const Text('Laporkan Kendala Barang'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

          // --- PICKUP CONFIRMATION (Admin/Marketing/Manager) ---
          if (status == MemoStatus.MENUNGGU_KONFIRMASI_PICKUP)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Builder(builder: (ctx) {
                  final currentUser = getIt<CurrentUserStore>().username;
                  final role = userRole.toUpperCase();
                  final isOwner = memo.marketingUsername == currentUser;
                  final isAdminOrSpv =
                      role == 'ADMIN' || role == 'MANAGER' || role == 'SPV_MARKETING';
                  final isMarketing =
                      role.startsWith('MARKETING_') || role == 'MARKETING';

                  if (isOwner || isAdminOrSpv || isMarketing) {
                    return ElevatedButton.icon(
                      onPressed: () {
                        _showConfirmDialog(
                          context: context,
                          title: 'Konfirmasi Selesai Pickup?',
                          message:
                              'Apakah Anda yakin proses serah terima barang ini sudah benar dan selesai?',
                          icon: Icons.verified_user_rounded,
                          confirmColor: Colors.deepPurple,
                          onConfirm: () {
                            context
                                .read<MemoBloc>()
                                .add(ConfirmPickupFinalEvent(id.toString()));
                          },
                        );
                      },
                      icon: const Icon(Icons.verified_user_rounded),
                      label: const Text('Konfirmasi Selesai Pickup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    );
                  }
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Menunggu konfirmasi penyelesaian oleh Admin atau Marketing terkait.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),

          // --- NOTA / INVOICE FINISH (Visible for MENUNGGU_NOTA only, jika JL belum diisi) ---
          // Button di atas sudah tersedia di header - ini fallback jika tidak di atas
          if ((userRole == 'NOTA' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'GUDANG' ||
                  userRole == 'SPV_GUDANG') &&
              status == MemoStatus.MENUNGGU_NOTA &&
              (memo.nomorJl == null || memo.nomorJl!.isEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: () => _showNotaInputDialog(context, memo.id!),
                icon: const Icon(Icons.receipt_long_rounded),
                label: const Text('Input JL & Lanjutkan ke Buffer Zone'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
              ),
            ),

          // --- HUB: BUFFER ZONE (READY) ---
          if ((userRole == 'GUDANG' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'SPV_GUDANG') &&
              (status == MemoStatus.MENUNGGU_PENGIRIMAN ||
                  status == MemoStatus.MENUNGGU_TEKNISI ||
                  status == MemoStatus.BUFFER_ZONE))
            HubControlCenter(
              onAssignment: memo.memoType == 'ONLINE'
                  ? null
                  : () => _showAssignmentDialog(context, memo),
              onPickup: () => _showPickupRouteDialog(context, id.toString()),
              onPartialShipment: memo.memoType == 'ONLINE'
                  ? null
                  : () => _showPartialShipmentDialog(context, memo),
            ),

          // --- MARKETING / MANAGER SCAN QR: AMBIL DI TOKO ---
          if ((userRole.startsWith('MARKETING')) ||
              userRole == 'SPV_MARKETING' ||
              userRole == 'ADMIN' ||
              userRole == 'MANAGER')
            if (status == MemoStatus.BUFFER_ZONE)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showPickupRouteDialog(context, id.toString()),
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Selesaikan Pesanan (Ambil di Toko)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),

          // --- ROUTING: MENUNGGU_PENGIRIMAN ---
          if ((userRole == 'GUDANG' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'DELIVERY' ||
                  (userRole.startsWith('MARKETING')) ||
                  userRole == 'SPV_MARKETING') &&
              status == MemoStatus.MENUNGGU_PENGIRIMAN)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (userRole == 'DELIVERY' ||
                    userRole == 'ADMIN' ||
                    userRole == 'MANAGER' ||
                    (userRole.startsWith('MARKETING')))
                  ElevatedButton.icon(
                    onPressed: () {
                      _showConfirmDialog(
                        context: context,
                        title: 'Mulai Pengiriman?',
                        message:
                            'Driver akan mulai proses pengiriman stok ke pelanggan.',
                        icon: Icons.local_shipping_rounded,
                        confirmColor: Colors.orange,
                        onConfirm: () {
                          context.read<MemoBloc>().add(UpdateMemoStatusEvent(
                              id.toString(),
                              MemoStatus.DALAM_PENGIRIMAN,
                              "Driver mulai pengiriman"));
                        },
                      );
                    },
                    icon: const Icon(Icons.local_shipping_rounded),
                    label: const Text('Mulai Pengiriman'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showPickupRouteDialog(
                      context, id.toString(),
                      isReRouting: true),
                  icon: const Icon(Icons.store_rounded),
                  label: const Text('BATAL KIRIM & AMBIL DI TOKO'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

          if (status == MemoStatus.KENDALA_BARANG)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "MENUNGGU TINDAKAN: Memo ini telah ditandai memiliki kendala barang. Menunggu revisi atau instruksi dari bagian Marketing.",
                      style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // --- TEKNISI ---
          if ((userRole == 'TEKNISI' ||
                  userRole == 'SPV_TEKNISI' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER') &&
              status == MemoStatus.MENUNGGU_TEKNISI)
            ElevatedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Mulai Proses Teknisi?',
                  message: 'Teknisi akan mulai memproses memo ini.',
                  icon: Icons.build_rounded,
                  confirmColor: Colors.orange,
                  onConfirm: () {
                    context.read<MemoBloc>().add(UpdateMemoStatusEvent(
                        id.toString(),
                        MemoStatus.PROSES_TEKNISI,
                        "Teknisi mulai memproses"));
                  },
                );
              },
              icon: const Icon(Icons.build_rounded),
              label: const Text('Mulai Proses Teknisi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          if ((userRole == 'TEKNISI' ||
                  userRole == 'SPV_TEKNISI' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER') &&
              status == MemoStatus.PROSES_TEKNISI)
            ElevatedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Selesai Proses Teknisi?',
                  message:
                      'Apakah Anda yakin pekerjaan teknisi sudah benar-benar selesai?',
                  icon: Icons.check_circle_rounded,
                  confirmColor: Colors.green,
                  onConfirm: () {
                    context
                        .read<MemoBloc>()
                        .add(FinishTechnicianProcessEvent(id.toString()));
                  },
                );
              },
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Selesai Proses Teknisi (Masuk Buffer Zone)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

          // --- DALAM PENGIRIMAN ---
          if ((userRole == 'DELIVERY' ||
                  userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  userRole == 'GUDANG' ||
                  userRole == 'SPV_GUDANG' ||
                  (userRole.startsWith('MARKETING')) ||
                  userRole == 'SPV_MARKETING') &&
              status == MemoStatus.DALAM_PENGIRIMAN)
            ElevatedButton.icon(
              onPressed: () => _showDeliveryProofDialog(context, id.toString()),
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Selesai Pengiriman'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(height: 12),

          // --- ONLINE SPECIFIC: BUFFER_ZONE -> SUDAH DIKIRIM (Bukti Foto Opsional) ---
          if ((userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  (userRole.startsWith('MARKETING')) ||
                  userRole == 'SPV_MARKETING') &&
              status == MemoStatus.BUFFER_ZONE &&
              memo.memoType == 'ONLINE')
            ElevatedButton.icon(
              onPressed: () =>
                  _showOnlineDeliveryProofDialog(context, id.toString()),
              icon: const Icon(Icons.local_shipping_rounded),
              label: const Text('Tandai Sudah Dikirim'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(height: 12),

          if ((userRole == 'ADMIN' ||
                  userRole == 'MANAGER' ||
                  (userRole.startsWith('MARKETING')) ||
                  userRole == 'SPV_MARKETING') &&
              (status == MemoStatus.DITERIMA_USER ||
                  (status == MemoStatus.BUFFER_ZONE &&
                      memo.memoType != 'ONLINE') ||
                  status == MemoStatus.TERKIRIM_SEBAGIAN))
            ElevatedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Tandai Selesai Akhir?',
                  message:
                      'Tindakan ini akan menutup memo secara permanen dan tidak dapat dibatalkan.',
                  icon: Icons.verified_rounded,
                  confirmColor: const Color(0xFF0F172A),
                  onConfirm: () {
                    context
                        .read<MemoBloc>()
                        .add(CompleteMemoEvent(id.toString()));
                  },
                );
              },
              icon: const Icon(Icons.verified_rounded),
              label: const Text('Tandai Selesai (Selesai Akhir)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(height: 12),

          // --- CANCEL BUTTON (Visible for roles except GUDANG, DELIVERY, TEKNISI, NOTA) ---
          if (!(userRole == 'GUDANG' ||
                  userRole == 'SPV_GUDANG' ||
                  userRole == 'DELIVERY' ||
                  userRole == 'TEKNISI' ||
                  userRole == 'SPV_TEKNISI' ||
                  userRole == 'NOTA') &&
              status != MemoStatus.SELESAI &&
              status != MemoStatus.DIBATALKAN &&
              status != MemoStatus.DITOLAK)
            OutlinedButton.icon(
              onPressed: () {
                _showConfirmDialog(
                  context: context,
                  title: 'Batalkan Memo?',
                  message:
                      'Apakah Anda yakin ingin membatalkan memo ini secara permanen? Stok yang dibooking akan dilepaskan.',
                  icon: Icons.cancel_outlined,
                  confirmColor: Colors.red,
                  onConfirm: () {
                    context.read<MemoBloc>().add(UpdateMemoStatusEvent(
                        id.toString(),
                        MemoStatus.DIBATALKAN,
                        "Dibatalkan oleh $userRole"));
                  },
                );
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Batalkan Memo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  void _showNotaInputDialog(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    final controller = TextEditingController(text: 'JL-YGY-');
    final noteController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.receipt_long_rounded, color: Colors.blue, size: 28),
              SizedBox(width: 12),
              Text('Input Nomor JL / Invoice'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Masukkan nomor JL untuk memo ini. Format wajib diawali dengan 'JL-'. Contoh: JL-YGY-0009146",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'Nomor JL',
                  hintText: 'JL-XXX-XXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: const Icon(Icons.numbers_rounded),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final jl = controller.text.trim();
                if (jl.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text('Nomor JL tidak boleh kosong!',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  return;
                }
                if (!jl.toUpperCase().startsWith("JL-")) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  "Format JL tidak valid! Wajib diawali 'JL-'",
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                      backgroundColor: Colors.orange.shade800,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                memoBloc.add(FinishInvoicingProcessEvent(
                  memoId,
                  nomorJl: jl,
                  keteranganLog: noteController.text,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Selesai & Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Icon(icon, color: confirmColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[600], fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Ya, Lanjutkan',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditNoteDialog(
      BuildContext context, String memoId, int itemId, String currentNote) {
    final memoBloc = context.read<MemoBloc>();
    final controller = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Icon(Icons.edit_note,
                  color: Theme.of(context).primaryColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Edit Catatan Item',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Tambahkan detail atau instruksi khusus untuk item ini.",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Contoh: Kurang 3 barang karena rusak...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Batal',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<MemoBloc>().add(
                    UpdateItemCatatanEvent(itemId, controller.text, memoId));
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan Perubahan',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showContinueTypePicker(BuildContext context, MemoDetail memo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih Tipe Memo Lanjutan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildContinueButton(
                  context, memo, 'BIASA', Colors.blue, Icons.article),
              const SizedBox(height: 12),
              _buildContinueButton(
                  context, memo, 'ONLINE', Colors.orange, Icons.shopping_cart),
              const SizedBox(height: 12),
              _buildContinueButton(
                  context, memo, 'PROJECT', Colors.purple, Icons.assignment),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(BuildContext context, MemoDetail memo,
      String type, Color color, IconData icon) {
    final String memoId = memo.id!;
    return ElevatedButton.icon(
      onPressed: () async {
        Navigator.pop(context);
        await context.pushNamed(
          AppRoutes.memoCreate,
          extra: memo,
          queryParameters: {
            'type': type,
            'continuationId': memoId,
          },
        );
        if (context.mounted) {
          context.read<MemoBloc>().add(LoadMemoDetail(memoId));
        }
      },
      icon: Icon(icon, color: Colors.white),
      label: Text('Lanjutkan sebagai $type'),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFinishPendingConfirmation(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          title: const Text('Konfirmasi Selesai'),
          content: const Text(
              'Apakah Anda yakin ingin menyelesaikan booking ini tanpa melanjutkan ke memo lain? Status akan berubah menjadi SELESAI.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                memoBloc.add(FinishPendingMemoEvent(memoId));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Ya, Selesaikan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSection(
      MemoDetail memo, ThemeData theme, BuildContext context, bool isDesktop) {
    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: memo.id ?? 'N/A',
                version: QrVersions.auto,
                size: 100.0,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QR Code Memo',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scan untuk mempercepat pencarian data di gudang atau pengiriman.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: memo.statusAkhir == MemoStatus.DRAFT
                            ? null
                            : () => MemoPrintUtils.printFullMemo(memo),
                        icon: const Icon(Icons.description_rounded, size: 16),
                        label: const Text('Cetak Memo Lengkap'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: memo.statusAkhir == MemoStatus.DRAFT
                            ? null
                            : () => MemoPrintUtils.printMemoLabels([memo]),
                        icon: const Icon(Icons.label_rounded, size: 16),
                        label: const Text('Cetak Label'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      if (memo.memoType == 'BIASA' ||
                          memo.memoType == 'DISTRIBUSI')
                        ElevatedButton.icon(
                          onPressed: memo.statusAkhir == MemoStatus.DRAFT
                              ? null
                              : () =>
                                  MemoPrintUtils.printShippingAddresses([memo]),
                          icon: const Icon(Icons.local_shipping_rounded,
                              size: 16),
                          label: const Text('Cetak Alamat'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      if (memo.memoType == 'DISTRIBUSI')
                        ElevatedButton.icon(
                          onPressed: memo.statusAkhir == MemoStatus.DRAFT
                              ? null
                              : () => _showPostInvoicePreview(context, memo),
                          icon: const Icon(Icons.preview_rounded, size: 16),
                          label: const Text('Preview Post Invoice'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile View (Optimized)
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: memo.id ?? 'N/A',
                  version: QrVersions.auto,
                  size: 80.0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Code Memo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scan untuk mempercepat pencarian data di gudang atau pengiriman.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: memo.statusAkhir == MemoStatus.DRAFT
                          ? null
                          : () => MemoPrintUtils.printFullMemo(memo),
                      icon: const Icon(Icons.description_rounded, size: 16),
                      label: const Text('Cetak'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: memo.statusAkhir == MemoStatus.DRAFT
                          ? null
                          : () => MemoPrintUtils.printMemoLabels([memo]),
                      icon: const Icon(Icons.label_rounded, size: 16),
                      label: const Text('Label'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: theme.colorScheme.primary),
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (memo.memoType == 'BIASA' ||
                  memo.memoType == 'DISTRIBUSI') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: memo.statusAkhir == MemoStatus.DRAFT
                        ? null
                        : () => MemoPrintUtils.printShippingAddresses([memo]),
                    icon: const Icon(Icons.local_shipping_rounded, size: 16),
                    label: const Text('Cetak Alamat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
              if (memo.memoType == 'DISTRIBUSI') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: memo.statusAkhir == MemoStatus.DRAFT
                        ? null
                        : () => _showPostInvoicePreview(context, memo),
                    icon: const Icon(Icons.preview_rounded, size: 16),
                    label: const Text('Preview Post Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignmentDialog(BuildContext context, MemoDetail memo) async {
    final theme = Theme.of(context);
    final repository = getIt<MemoRepository>();
    final memoBloc = context.read<MemoBloc>();

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final List<UserAccount> drivers =
          await repository.getUsersByRole('DELIVERY');
      await repository.getUsersByRole('TEKNISI');

      // Fetch all users and filter for marketing-related roles
      final List<UserAccount> allUsers = await repository.getAllUsers();
      final List<UserAccount> marketings = allUsers.where((u) {
        final role = u.role.toUpperCase();
        return role.contains('MARKETING');
      }).toList();

      if (!context.mounted) return;
      Navigator.pop(context); // Remove loading

      // Pre-fill from history if available
      int? selectedDriverId;
      int? selectedTeknisiId;
      int? selectedMarketingId;
      DateTime selectedDate = DateTime.now();
      String? selectedTime;

      // Address Controllers for Dialog
      final TextEditingController kodeposController =
          TextEditingController(text: memo.kodePos);
      final TextEditingController desaController =
          TextEditingController(text: memo.desaKelurahan);
      final TextEditingController kecamatanController =
          TextEditingController(text: memo.kecamatan);
      final TextEditingController kabupatenController =
          TextEditingController(text: memo.kabupatenKota);

      final lastP = memo.penjadwalanHistory.isNotEmpty
          ? memo.penjadwalanHistory.last
          : null;
      if (lastP != null) {
        if (lastP.tipeTugas == 'PENGIRIMAN' ||
            lastP.tipeTugas == 'PENGAMBILAN' ||
            lastP.tipeTugas == 'DROP_OFF_EKSPEDISI') {
          // If the last assigned person was marketing, pre-fill marketing dropdown
          if (lastP.personelRole?.toUpperCase().contains('MARKETING') ??
              false) {
            selectedMarketingId = lastP.personelId;
          } else {
            selectedDriverId = lastP.personelId;
          }
        } else if (lastP.tipeTugas == 'TEKNISI') {
          selectedTeknisiId = lastP.personelId;
        }
        selectedTime = lastP.estimasiWaktu;

        if (lastP.tanggalJadwal != null && lastP.tanggalJadwal!.isNotEmpty) {
          try {
            final parts = lastP.tanggalJadwal!.split('-');
            if (parts.length == 3) {
              selectedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]),
                  int.parse(parts[0]));
            }
          } catch (_) {}
        }
      }

      showDialog(
        context: context,
        builder: (ctx) => BlocProvider.value(
            value: memoBloc,
            child: StatefulBuilder(
              builder: (context, setState) {
                memo.penjadwalanHistory.any((p) =>
                    p.tipeTugas == 'TEKNISI' && p.statusJadwal == 'SELESAI');

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(Icons.assignment_ind, color: theme.primaryColor),
                      const SizedBox(width: 12),
                      const Text('Penugasan Personel'),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Tentukan personel dan alamat untuk melanjutkan proses ini.",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        if (memo.isDeliveryRequired == true &&
                            (memo.statusAkhir == MemoStatus.BUFFER_ZONE ||
                                memo.statusAkhir ==
                                    MemoStatus.MENUNGGU_PENGIRIMAN ||
                                memo.statusAkhir ==
                                    MemoStatus.MENUNGGU_GUDANG)) ...[
                          const Text('Jalur Pengiriman:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDriverId,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              hintText: 'Pilih Driver (Delivery)',
                              prefixIcon:
                                  const Icon(Icons.local_shipping, size: 20),
                            ),
                            items: drivers
                                .map((u) => DropdownMenuItem(
                                    value: u.id, child: Text(u.nama)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              selectedDriverId = v;
                              if (v != null) selectedMarketingId = null;
                            }),
                          ),
                          const SizedBox(height: 12),
                          const Center(
                              child: Text('— ATAU —',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey))),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: selectedMarketingId,
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              hintText: 'Pilih Marketing (Kirim Sendiri)',
                              prefixIcon: const Icon(Icons.person_pin_outlined,
                                  size: 20),
                            ),
                            items: marketings
                                .map((u) => DropdownMenuItem(
                                    value: u.id, child: Text(u.nama)))
                                .toList(),
                            onChanged: (v) => setState(() {
                              selectedMarketingId = v;
                              if (v != null) selectedDriverId = null;
                            }),
                          ),
                          const SizedBox(height: 20),
                          const SizedBox(height: 20),
                        ],
                        const Text('Tanggal & Waktu Rencana:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 7)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 90)),
                                  );
                                  if (picked != null) {
                                    setState(() => selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(_formatDate(selectedDate),
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: InkWell(
                                onTap: () async {
                                  final TimeOfDay? picked =
                                      await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime != null
                                        ? TimeOfDay(
                                            hour: int.parse(
                                                selectedTime!.split(':')[0]),
                                            minute: int.parse(
                                                selectedTime!.split(':')[1]))
                                        : TimeOfDay.now(),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      selectedTime =
                                          "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey[400]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(selectedTime ?? "Waktu",
                                          style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Stage-aware Validation:
                        if (memo.isDeliveryRequired == true &&
                            memo.statusAkhir != MemoStatus.MENUNGGU_TEKNISI &&
                            selectedDriverId == null &&
                            selectedMarketingId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Pilih Driver atau Marketing pengirim")));
                          return;
                        }

                        if (selectedTime == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "Pilih estimasi waktu terlebih dahulu")));
                          return;
                        }

                        Navigator.pop(ctx);
                        context.read<MemoBloc>().add(ConfirmDeliveryRouteEvent(
                              memo.id!,
                              driverId: selectedDriverId,
                              teknisiId: selectedTeknisiId,
                              marketingId: selectedMarketingId,
                              tanggalJadwal:
                                  "${selectedDate.day.toString().padLeft(2, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.year}",
                              estimasiWaktu: selectedTime,
                            ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Konfirmasi & Lanjutkan'),
                    ),
                  ],
                );
              },
            )),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Gagal mengambil data: $e")));
      }
    }
  }

  void _showReportIssueDialog(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.report_problem_rounded, color: Colors.red),
              SizedBox(width: 12),
              Text('Laporkan Kendala Fisik'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Jelaskan kendala fisik yang ditemukan (misal: barang pecah, stok tidak ada). Memo akan tertunda sampai ada revisi dari marketing.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Masukkan alasan kendala...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isEmpty) return;
                memoBloc.add(ReportPhysicalIssueEvent(memoId, controller.text));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Laporkan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showForceCompleteDialog(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.red),
              SizedBox(width: 12),
              Text('Selesaikan Paksa (Admin)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "PERINGATAN: Tindakan ini akan menutup memo secara paksa tanpa validasi normal. Wajib menyertakan alasan audit.",
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.red,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Alasan penyelesaian paksa...",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.feedback_outlined, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Alasan penyelesaian paksa wajib diisi!',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                  return;
                }
                memoBloc.add(
                    ForceCompleteMemoEvent(memoId, controller.text.trim()));
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, foregroundColor: Colors.white),
              child: const Text("Gavel: Selesaikan"),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickupRouteDialog(BuildContext context, String memoId,
      {bool isReRouting = false}) {
    final memoBloc = context.read<MemoBloc>();
    XFile? pickedFile;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider.value(
        value: memoBloc,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.person_pin_circle_rounded,
                    color: Colors.green.shade700),
                const SizedBox(width: 12),
                Text(isReRouting
                    ? 'Batal Kirim & Pickup'
                    : 'Serah Terima Pickup'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Tahap 1: Validasi QR Code\nTahap 2: Foto Serah Terima",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Buka scanner
                        final result =
                            await context.pushNamed(AppRoutes.scanner);
                        if (result == memoId) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("QR Valid: Cocok"),
                                  backgroundColor: Colors.green));
                        } else if (result != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("QR Tidak Cocok!"),
                                  backgroundColor: Colors.red));
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text("Scan QR Memo"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey),
                    ),
                    const SizedBox(height: 16),
                    const Divider(thickness: 1.2, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        XFile? photo;
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) {
                          final ImagePicker picker = ImagePicker();
                          photo = await picker.pickImage(
                              source: ImageSource.gallery);
                        } else {
                          photo =
                              await context.pushNamed<XFile>(AppRoutes.camera);
                        }
                        if (photo != null) setState(() => pickedFile = photo);
                      },
                      child: Container(
                        height: 150,
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: pickedFile == null
                                  ? Colors.orange
                                  : Colors.green,
                              width: 2),
                        ),
                        child: pickedFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      size: 40, color: Colors.grey),
                                  Text("Foto Serah Terima Pelanggan",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(pickedFile!.path),
                                    fit: BoxFit.cover),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text("Batal")),
              ElevatedButton(
                onPressed: () {
                  if (pickedFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Wajib mengambil foto serah terima!',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }
                  memoBloc.add(ConfirmPickupRouteEvent(memoId, pickedFile!));
                  Navigator.pop(dialogCtx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white),
                child: const Text("Selesaikan Pickup"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  String _formatDateTime(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  String _formatNumber(num value) {
    if (value is int || value == value.roundToDouble()) {
      return value.toInt().toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
          );
    } else {
      List<String> parts = value.toString().split('.');
      String intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      return '$intPart,${parts[1]}';
    }
  }

  String _formatRupiah(num v) => "Rp. ${_formatNumber(v)}";

  /// Dialog khusus ONLINE: wajib foto bukti sebelum tandai selesai/dikirim
  void _showOnlineDeliveryProofDialog(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile;
    final TextEditingController resiController = TextEditingController();
    final TextEditingController catatanController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider.value(
        value: memoBloc,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: Colors.blue),
                SizedBox(width: 12),
                Text('Bukti Pengiriman Online'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Upload bukti input Resi untuk Audit Log (Opsional)',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: resiController,
                      decoration: InputDecoration(
                        labelText: 'Nomor Resi / ID Pengiriman (Opsional)',
                        hintText: 'Misal: GK12345678 atau JNE-xxx',
                        prefixIcon:
                            const Icon(Icons.confirmation_number_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          onPressed: () async {
                            final scanned = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SimpleBarcodeScanner(
                                  title: 'Scan Nomor Resi',
                                ),
                              ),
                            );
                            if (scanned != null) {
                              resiController.text = scanned;
                            }
                          },
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Bukti Foto (Opsional):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        XFile? photo;
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) {
                          photo = await picker.pickImage(
                              source: ImageSource.gallery);
                        } else {
                          photo =
                              await context.pushNamed<XFile>(AppRoutes.camera);
                        }
                        if (photo != null) setState(() => pickedFile = photo);
                      },
                      child: Container(
                        height: 180,
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: pickedFile == null
                                ? Colors.grey.shade300
                                : Colors.green.shade300,
                            width: 2,
                          ),
                        ),
                        child: pickedFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate_rounded,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    (Platform.isWindows ||
                                            Platform.isLinux ||
                                            Platform.isMacOS)
                                        ? 'Pilih Foto Bukti'
                                        : 'Buka Kamera',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Text('(Opsional)',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 11)),
                                ],
                              )
                            : Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(File(pickedFile!.path),
                                        fit: BoxFit.cover,
                                        width: double.maxFinite,
                                        height: 180),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () =>
                                          setState(() => pickedFile = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: catatanController,
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Misal: Diterima driver Gojek atas nama Budi',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _showConfirmDialog(
                    context: context,
                    title: 'Konfirmasi Pengiriman?',
                    message:
                        'Memo ini akan ditandai Menunggu Pengiriman. Pastikan data sudah benar.',
                    icon: Icons.local_shipping_rounded,
                    confirmColor: Colors.blue,
                    onConfirm: () {
                      final catatanText = catatanController.text.trim();
                      final resiText = resiController.text.trim();

                      // Catatan ditambahkan info jika ada/tiada foto bukti
                      final defaultCatatan = pickedFile != null
                          ? "Ditandai sudah dikirim oleh Marketing (Menunggu Pengiriman - dengan bukti foto)"
                          : "Ditandai sudah dikirim oleh Marketing (Menunggu Pengiriman)";

                      final finalCatatan =
                          catatanText.isNotEmpty ? catatanText : defaultCatatan;

                      // Kirim event gabungan untuk update resi, foto bukti, dan status secara sekuensial dalam satu loading state
                      context.read<MemoBloc>().add(UpdateMemoResiAndStatusEvent(
                            memoId,
                            resiText,
                            MemoStatus.MENUNGGU_PENGIRIMAN,
                            finalCatatan,
                            photo: pickedFile,
                          ));

                      Navigator.pop(dialogCtx);
                    },
                  );
                },
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Konfirmasi Dikirim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeliveryProofDialog(BuildContext context, String memoId) {
    final memoBloc = context.read<MemoBloc>();
    final ImagePicker picker = ImagePicker();
    XFile? pickedFile;
    final TextEditingController catatanController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider.value(
        value: memoBloc,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt_rounded, color: Colors.blue),
                SizedBox(width: 12),
                Text('Bukti Pengiriman'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ambil foto bukti pengiriman. Wajib menggunakan kamera (tidak boleh dari galeri/file).',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () async {
                        XFile? photo;
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) {
                          photo = await picker.pickImage(
                              source: ImageSource.gallery);
                        } else {
                          // Navigate to Custom Camera Screen
                          photo =
                              await context.pushNamed<XFile>(AppRoutes.camera);
                        }

                        if (photo != null) {
                          setState(() => pickedFile = photo);
                        }
                      },
                      child: Container(
                        height: 200,
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: pickedFile == null
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.grey[300]!,
                              width: 2),
                        ),
                        child: pickedFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_rounded,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                      (Platform.isWindows ||
                                              Platform.isLinux ||
                                              Platform.isMacOS)
                                          ? 'Pilih File (Dev Mode)'
                                          : 'Buka Kamera',
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      (Platform.isWindows ||
                                              Platform.isLinux ||
                                              Platform.isMacOS)
                                          ? '(Di HP Wajib Kamera)'
                                          : '(Wajib Foto Kamera)',
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 10)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(pickedFile!.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: catatanController,
                      decoration: InputDecoration(
                        labelText: 'Catatan (Opsional)',
                        hintText: 'Misal: Diterima oleh Satpam',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (pickedFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.camera_enhance_rounded,
                                color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Wajib mengambil foto bukti pengiriman!',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }
                  _showConfirmDialog(
                    context: context,
                    title: 'Kirim Bukti Foto?',
                    message: 'Apakah Anda yakin foto bukti sudah sesuai?',
                    icon: Icons.camera_alt_rounded,
                    confirmColor: Colors.green,
                    onConfirm: () {
                      context.read<MemoBloc>().add(
                            FinishDeliveryProcessEvent(
                              id: memoId,
                              photo: pickedFile!,
                              catatan: catatanController.text,
                            ),
                          );
                      Navigator.pop(dialogCtx);
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Kirim Bukti'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPartialShipmentDialog(BuildContext context, MemoDetail memo) {
    final memoBloc = context.read<MemoBloc>();
    final controllers = <int, TextEditingController>{};
    XFile? pickedFile;

    // Initialize controllers for items that have remaining qty
    for (var item in memo.items) {
      if (item.qtyRemaining > 0) {
        controllers[item.id!] = TextEditingController();
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: memoBloc,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.playlist_add_check_circle_rounded,
                    color: Colors.blueGrey),
                SizedBox(width: 12),
                Text('Konfirmasi Kirim Sebagian'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masukkan jumlah barang yang dikirim saat ini.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              for (var item in memo.items) {
                                if (item.qtyRemaining > 0 &&
                                    controllers.containsKey(item.id)) {
                                  // Set ke sisa qty maksimal
                                  controllers[item.id!]!.text =
                                      item.qtyRemaining.toInt().toString();
                                }
                              }
                            });
                          },
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Kirim Semua Sisa'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueGrey.shade700,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (var controller in controllers.values) {
                                controller.clear();
                              }
                            });
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...memo.items
                        .where((item) => item.qtyRemaining > 0)
                        .map((item) {
                      final controller = controllers[item.id!]!;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.namaBarang ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                'Total: ${item.qty} | Sudah Terkirim: ${item.qtyShipped} | Sisa: ${item.qtyRemaining}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.blueGrey[600])),
                            const SizedBox(height: 12),
                            TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Jumlah Kirim Sekarang',
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                suffixText: 'Unit',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    const Text('Bukti Foto (Wajib):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        XFile? photo;
                        if (Platform.isWindows ||
                            Platform.isLinux ||
                            Platform.isMacOS) {
                          final ImagePicker picker = ImagePicker();
                          photo = await picker.pickImage(
                              source: ImageSource.gallery);
                        } else {
                          photo =
                              await context.pushNamed<XFile>(AppRoutes.camera);
                        }
                        if (photo != null) setState(() => pickedFile = photo);
                      },
                      child: Container(
                        height: 150,
                        width: double.maxFinite,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: pickedFile == null
                                  ? Colors.red.withValues(alpha: 0.3)
                                  : Colors.grey[300]!,
                              width: 2),
                        ),
                        child: pickedFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_rounded,
                                      size: 40, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text('Ambil Foto Bukti',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(File(pickedFile!.path),
                                    fit: BoxFit.cover),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final List<Map<String, dynamic>> itemsToShip = [];
                  String? errorMessage;

                  for (var item in memo.items) {
                    if (item.qtyRemaining <= 0) continue;
                    final input = controllers[item.id!]?.text ?? '';
                    if (input.isEmpty) continue;

                    final qtyInput = int.tryParse(input);
                    if (qtyInput == null || qtyInput <= 0) {
                      errorMessage =
                          "Jumlah kirim untuk ${item.namaBarang} tidak valid";
                      break;
                    }

                    if (qtyInput > item.qtyRemaining) {
                      errorMessage =
                          "Jumlah kirim untuk ${item.namaBarang} melebihi sisa (${item.qtyRemaining})";
                      break;
                    }

                    itemsToShip.add({
                      'itemId': item.id,
                      'qtyDikirimSaatIni': qtyInput,
                    });
                  }

                  if (errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.white),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(errorMessage,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }

                  if (itemsToShip.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Minimal satu item harus diisi jumlah kirimnya!',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                        backgroundColor: Colors.orange.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }

                  if (pickedFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.camera_alt_rounded, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'Wajib mengambil foto bukti pengiriman sebagian!',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500))),
                          ],
                        ),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                    return;
                  }

                  _showConfirmDialog(
                    context: context,
                    title: 'Konfirmasi Pengiriman?',
                    message: 'Apakah data barang yang dikirim sudah benar?',
                    icon: Icons.playlist_add_check_circle_rounded,
                    confirmColor: Colors.blueGrey,
                    onConfirm: () {
                      memoBloc.add(KonfirmasiKirimEvent(
                        memo.id!,
                        itemsToShip,
                        photo: pickedFile!,
                      ));
                      Navigator.pop(ctx);
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Konfirmasi & Kirim'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditResiDialog(
      BuildContext context, String memoId, String currentResi) {
    final memoBloc = context.read<MemoBloc>();
    final controller = TextEditingController(text: currentResi);
    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: memoBloc,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Colors.blue),
              SizedBox(width: 12),
              Text('Edit Nomor Resi'),
            ],
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Nomor Resi',
              hintText: 'Masukkan nomor resi baru',
              prefixIcon: const Icon(Icons.confirmation_number_outlined),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                onPressed: () async {
                  final scanned = await Navigator.push<String>(
                    dialogCtx,
                    MaterialPageRoute(
                      builder: (_) => const SimpleBarcodeScanner(
                        title: 'Scan Nomor Resi',
                      ),
                    ),
                  );
                  if (scanned != null) {
                    controller.text = scanned;
                  }
                },
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child:
                  Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
            ),
            ElevatedButton(
              onPressed: () {
                final newResi = controller.text.trim();

                // Alert jika resi sudah ada tapi coba dikosongkan
                if (currentResi.isNotEmpty && newResi.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Nomor resi yang sudah ada tidak boleh dikosongkan kembali!',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                memoBloc.add(UpdateMemoResiEvent(memoId, newResi));
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostInvoicePreview(BuildContext context, MemoDetail memo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 600, // Slightly wider for better visibility
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Container(
                color: Colors.teal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Preview Post Invoice',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    primaryColor: Colors.teal,
                    appBarTheme:
                        const AppBarTheme(backgroundColor: Colors.teal),
                    colorScheme:
                        ColorScheme.fromSwatch(primarySwatch: Colors.teal),
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  child: PdfPreview(
                    build: (format) =>
                        MemoPrintUtils.generatePostInvoicePdf(memo, format),
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    canDebug: false,
                    allowPrinting: true,
                    allowSharing: true,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'Invoice_${memo.nomorMemo}.pdf',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrinterDialog(BuildContext context, MemoDetail memo) {
    PrinterDialog.show(context, memo);
  }

  String _generateMemoCopyText(MemoDetail memo) {
    final DateFormat formatter = DateFormat('dd MMMM yyyy');
    final String formattedDate =
        memo.tanggalMemo != null ? formatter.format(memo.tanggalMemo!) : '-';

    String formatRp(num value) {
      return "Rp ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}";
    }

    final buffer = StringBuffer();
    buffer.writeln("*Tanggal:* $formattedDate");
    buffer
        .writeln("*Pelanggan:* ${(memo.customerName ?? 'Umum').toUpperCase()}");
    buffer.writeln("*No. HP:* ${memo.customerPhone ?? '-'}");

    final alamat = (memo.desaKelurahan != null &&
            memo.desaKelurahan!.isNotEmpty)
        ? "${memo.desaKelurahan}, ${memo.kecamatan}, ${memo.kabupatenKota}${memo.kodePos != null ? ' (${memo.kodePos})' : ''}"
        : (memo.penjadwalanHistory.any(
                (j) => j.alamatLengkap != null && j.alamatLengkap!.isNotEmpty)
            ? memo.penjadwalanHistory
                .lastWhere((j) =>
                    j.alamatLengkap != null && j.alamatLengkap!.isNotEmpty)
                .alamatLengkap!
            : (memo.kodePos != null && memo.kodePos!.isNotEmpty
                ? memo.kodePos!
                : '-'));
    buffer.writeln("*Alamat Pengiriman:* $alamat");

    final fulfillmentMethod = (memo.isDeliveryRequired ||
            (memo.opsiPengiriman ?? '').toUpperCase().contains('DELIVERY') ||
            (memo.opsiPengiriman ?? '').toUpperCase().contains('KIRIM') ||
            (memo.opsiPengiriman ?? '').toUpperCase().contains('DIKIRIM') ||
            (memo.opsiPengiriman ?? '').toUpperCase().contains('MARKETING') ||
            (memo.opsiPengiriman ?? '').toUpperCase().contains('DRIVER'))
        ? memo.deliveryMethodLabel
        : 'AMBIL DI TOKO';
    buffer.writeln("*Fulfillment:* $fulfillmentMethod");
    buffer.writeln("");

    final String tempoText = memo.tempo != null
        ? (memo.tempo!.toLowerCase().contains('hari')
            ? memo.tempo!
            : "${memo.tempo} Hari")
        : "";
    final paymentInfo = (memo.metodePembayaran?.toUpperCase() == 'TEMPO' &&
            tempoText.isNotEmpty)
        ? "${memo.metodePembayaran} $tempoText"
        : (memo.metodePembayaran ?? '-');
    buffer.writeln("*Metode Pembayaran:* $paymentInfo");

    final platform = memo.platform;
    if (platform != null && platform.isNotEmpty) {
      buffer.writeln("*Platform:* $platform");
    }
    buffer.writeln("");

    buffer.writeln("*DAFTAR BARANG*");
    for (int i = 0; i < memo.items.length; i++) {
      final item = memo.items[i];
      buffer.writeln("${i + 1}. *${item.namaBarang ?? '-'}*");
      buffer.writeln(
          "   Qty: ${item.qty} Pcs  |  Harga: ${formatRp(item.hargaSatuan)}  |  Subtotal: ${formatRp(item.subtotal)}");
    }
    buffer.writeln("");

    buffer.writeln("━━━━━━━━━━━━━━━━━━━━━━━━━━");
    buffer.writeln(
        "*TOTAL ITEM:* ${memo.totalQty.toString().replaceAll(RegExp(r'\.0$'), '')} Pcs");
    buffer.writeln("*TOTAL PENJUALAN:* ${formatRp(memo.totalHarga)}");

    return buffer.toString();
  }
}
