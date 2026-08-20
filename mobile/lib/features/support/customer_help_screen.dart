import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/support/complaints_controller.dart';
import 'package:fixnow_mobile/features/support/complaint_list_screen.dart';
import 'package:fixnow_mobile/features/support/submit_complaint_screen.dart';

class CustomerHelpScreen extends StatelessWidget {
  const CustomerHelpScreen({required this.controller, super.key});

  final ComplaintsController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FixPageHeader(
            eyebrow: 'FixNow care',
            title: 'Help & Support',
            description: 'Clear guidance when you need a hand.',
          ),
          const SizedBox(height: AppSpacing.xxl),

          FixEmergencyBanner(
            title: 'Immediate Danger?',
            subtitle:
                'For gas leaks, fire, or medical emergencies, contact local authorities immediately.',
            onCallNow: () {
              // Note: Production would dial local emergency services e.g., 112 / 911
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling emergency services...')),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),

          const FixSectionHeader(title: 'Support Requests'),
          const SizedBox(height: AppSpacing.lg),

          FixCard(
            semanticLabel: 'Support requests options',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('My Support Cases'),
                  subtitle: const Text(
                    'View updates on your previous requests',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ComplaintListScreen(controller: controller),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_comment_rounded),
                  title: const Text('Submit a Request'),
                  subtitle: const Text(
                    'Report an issue or get help from our team',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SubmitComplaintScreen(
                          controller: controller,
                          targetRole: 'PLATFORM',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
          const FixSectionHeader(title: 'Contact Us'),
          const SizedBox(height: AppSpacing.lg),

          FixCard(
            semanticLabel: 'Contact us options',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Email Support'),
                  subtitle: const Text('support@fixnow.test'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening email client...')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: const Text('Call Us'),
                  subtitle: const Text('+91 800 349 6691'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calling support...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          const FixSectionHeader(
            title: 'Quick answers',
            subtitle: 'Helpful information for common booking questions',
          ),
          const SizedBox(height: AppSpacing.lg),
          const FixCard(
            tone: FixCardTone.secondary,
            semanticLabel: 'Frequently asked questions',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SupportAnswer(
                  icon: Icons.route_outlined,
                  title: 'How do I track a provider?',
                  description:
                      'Open an active booking to see each service stage and live location when it is shared.',
                ),
                SizedBox(height: AppSpacing.lg),
                _SupportAnswer(
                  icon: Icons.lock_outline_rounded,
                  title: 'When should I share my OTP?',
                  description:
                      'Share your service-start code only after the professional has arrived.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportAnswer extends StatelessWidget {
  const _SupportAnswer({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary, size: 22),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.textOnSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textOnSurfaceSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
