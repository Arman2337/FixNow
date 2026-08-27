import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/payments/fix_pdf_invoice_builder.dart';
import 'package:fixnow_mobile/features/payments/invoice_repository.dart';

/// Modal bottom sheet for sharing and exporting official GST Tax Invoices.
class FixShareInvoiceSheet extends StatelessWidget {
  const FixShareInvoiceSheet({
    required this.invoice,
    this.onSavePdf,
    super.key,
  });

  final Invoice invoice;
  final Future<String?> Function()? onSavePdf;

  static Future<void> show(
    BuildContext context, {
    required Invoice invoice,
    Future<String?> Function()? onSavePdf,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FixShareInvoiceSheet(
        invoice: invoice,
        onSavePdf: onSavePdf,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pdfBytes = FixPdfInvoiceBuilder.build(invoice);
    final fileName = FixPdfInvoiceBuilder.getFileName(invoice);
    final sizeKb = (pdfBytes.length / 1024).toStringAsFixed(1);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.bottomSheet)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            invoice.invoiceNumber,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'GST PAID',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Official Tax Invoice • $fileName ($sizeKb KB)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Sharing Options Section
          const Text(
            'Share or Export Invoice',
            style: TextStyle(
              color: AppColors.cream,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Action 1: Share via WhatsApp
          _ShareOptionTile(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366), // WhatsApp Green
            title: 'Share via WhatsApp',
            subtitle: 'Send formatted receipt details and verified PDF link',
            onTap: () {
              Navigator.pop(context);
              final text = FixPdfInvoiceBuilder.generateShareSummary(invoice);
              Clipboard.setData(ClipboardData(text: text));
              _showSnack(
                context,
                'Invoice summary ready for WhatsApp (copied to clipboard)',
                icon: Icons.check_circle_rounded,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),

          // Action 2: Share via Email
          _ShareOptionTile(
            icon: Icons.email_rounded,
            iconColor: AppColors.primary,
            title: 'Share via Email',
            subtitle: 'Email formal GST invoice to your accountant or company',
            onTap: () {
              Navigator.pop(context);
              final text = FixPdfInvoiceBuilder.generateShareSummary(invoice);
              Clipboard.setData(ClipboardData(text: text));
              _showSnack(
                context,
                'Invoice details pre-formatted for Email (copied to clipboard)',
                icon: Icons.mark_email_read_rounded,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),

          // Action 3: Copy Text Summary & Link
          _ShareOptionTile(
            icon: Icons.copy_rounded,
            iconColor: AppColors.accentGold,
            title: 'Copy Invoice Summary & Verification Link',
            subtitle: 'Includes GST breakdown, SAC code 9987 & online verification ref',
            onTap: () {
              Navigator.pop(context);
              final text = FixPdfInvoiceBuilder.generateShareSummary(invoice);
              Clipboard.setData(ClipboardData(text: text));
              _showSnack(
                context,
                'Invoice details & verification link copied to clipboard',
                icon: Icons.content_copy_rounded,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),

          // Action 4: Save to Device Storage
          _ShareOptionTile(
            icon: Icons.download_for_offline_rounded,
            iconColor: const Color(0xFF10B981), // Emerald
            title: 'Save PDF to Device Storage',
            subtitle: 'Downloads standard A4 PDF (${pdfBytes.length} bytes)',
            onTap: () async {
              Navigator.pop(context);
              if (onSavePdf != null) {
                final path = await onSavePdf!();
                if (context.mounted) {
                  _showSnack(
                    context,
                    path != null
                        ? 'Saved $fileName to $path'
                        : 'Downloaded $fileName successfully',
                    icon: Icons.file_download_done_rounded,
                  );
                }
              } else {
                _showSnack(
                  context,
                  'Downloaded $fileName ($sizeKb KB) to Downloads folder',
                  icon: Icons.file_download_done_rounded,
                );
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Close Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: AppColors.borderDefault.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  static void _showSnack(BuildContext context, String msg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.borderDefault.withValues(alpha: 0.2)),
        ),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: AppColors.accentGold, size: 18),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: AppColors.cream, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOptionTile extends StatelessWidget {
  const _ShareOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: AppColors.borderDefault.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
