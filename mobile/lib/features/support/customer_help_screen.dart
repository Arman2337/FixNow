import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/support/complaints_controller.dart';
import 'package:fixnow_mobile/features/support/complaint_list_screen.dart';
import 'package:fixnow_mobile/features/support/submit_complaint_screen.dart';

class CustomerHelpScreen extends StatelessWidget {
  const CustomerHelpScreen({
    required this.controller,
    super.key,
  });

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
            subtitle: 'For gas leaks, fire, or medical emergencies, contact local authorities immediately.',
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
                  subtitle: const Text('View updates on your previous requests'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ComplaintListScreen(
                          controller: controller,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_comment_rounded),
                  title: const Text('Submit a Request'),
                  subtitle: const Text('Report an issue or get help from our team'),
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
        ],
      ),
    );
  }
}
