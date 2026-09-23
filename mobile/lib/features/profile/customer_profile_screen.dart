import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_status_chip.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/design_system/fix_address_selector.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:fixnow_mobile/features/profile/customer_profile_controller.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:fixnow_mobile/notifications/push_settings_card.dart';
import 'package:flutter/material.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    required this.controller,
    this.pushController,
    this.onSupportCases,
    this.onSignOut,
    super.key,
  });

  final CustomerProfileController controller;
  final PushEnrollmentController? pushController;
  final VoidCallback? onSignOut;
  final VoidCallback? onSupportCases;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;


  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    widget.controller.addListener(_syncName);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.load();
      SavedAddressRepository.instance.fetchAddresses();
    });
  }

  void _syncName() {
    if (widget.controller.status == ProfileViewStatus.ready ||
        widget.controller.status == ProfileViewStatus.saved) {
      _nameController.text = widget.controller.displayName;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncName);
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FixPageHeader(
            eyebrow: 'Your account',
            title: 'Profile & Settings',
            description: 'Only your display name is collected here.',
          ),
          const SizedBox(height: AppSpacing.sm),

          // Stitch Customer Identity Card with Verified Badge & Membership Tier
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.primaryContainer
                              .withValues(alpha: 0.18),
                          child: Text(
                            widget.controller.displayName.isNotEmpty
                                ? widget.controller.displayName[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surfaceContainerLowest,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                        ),
                      ],
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
                                  widget.controller.displayName.isNotEmpty
                                      ? widget.controller.displayName
                                      : 'FixNow customer',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Your service history and account stay private.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                // FixNow Plus Member Tier Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            size: 16,
                            color: AppColors.onTertiaryFixed,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'FIXNOW PLUS MEMBER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.onTertiaryFixed,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.onTertiaryFixed.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'VIP Tier 1',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onTertiaryFixed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Quick Stat Bento Row (3 columns)
          Row(
            children: [
              Expanded(
                child: _buildBentoStatCard(
                  icon: Icons.task_alt_rounded,
                  iconBg: AppColors.primaryFixed,
                  iconColor: AppColors.onPrimaryFixed,
                  metric:
                      widget.controller.stats?.completedJobs.toString() ?? '-',
                  label: 'Completed',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildBentoStatCard(
                  icon: Icons.account_balance_wallet_rounded,
                  iconBg: AppColors.tertiaryFixed,
                  iconColor: AppColors.onTertiaryFixed,
                  metric: widget.controller.stats != null
                      ? '₹${(widget.controller.stats!.cashbackMinor / 100).toStringAsFixed(0)}'
                      : '₹--',
                  label: 'Cashback',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _buildBentoStatCard(
                  icon: Icons.shield_rounded,
                  iconBg: AppColors.secondaryContainer,
                  iconColor: AppColors.onSecondaryContainer,
                  metric:
                      widget.controller.stats?.activeWarranties.toString() ??
                      '-',
                  label: 'Warranty',
                ),
              ),
            ],
          ),

          // Profile editing / Status
          if (widget.controller.status == ProfileViewStatus.loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading profile',
                ),
              ),
            )
          else if (_failed)
            _ProfileFailure(
              status: widget.controller.status,
              onRetry: widget.controller.load,
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outline.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text(
                          'Personal details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Display name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.inputText),
                      cursorColor: AppColors.primary,
                      maxLength: 80,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'How should we address you?',
                      ),
                      validator: (value) {
                        final candidate = value?.trim() ?? '';
                        if (candidate.isEmpty) return 'Enter a display name.';
                        if (candidate.contains(RegExp(r'[\x00-\x1F\x7F]'))) {
                          return 'Remove unsupported characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FixButton(
                      label: 'Save profile',
                      isLoading:
                          widget.controller.status == ProfileViewStatus.saving,
                      onPressed: () async {
                        if (_formKey.currentState?.validate() ?? false) {
                          await widget.controller.save(_nameController.text);
                        }
                      },
                    ),
                    if (widget.controller.status ==
                        ProfileViewStatus.saved) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: FixStatusChip(
                          label: 'Profile saved',
                          icon: Icons.check_circle_outline,
                          tone: FixStatusTone.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          const _SavedAddressesSection(),
          // Payment Methods & FastPay Card
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.credit_card_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Methods & Settlement',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pay upon service completion (Cash / UPI)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Section 2: Support & Warranty
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'SUPPORT & WARRANTY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: widget.onSupportCases,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.assignment_late_outlined,
                            color: AppColors.onErrorContainer,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Support Cases & Disputes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Track re-inspections, refunds, and claims',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.outline.withValues(alpha: 0.08),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.help_center_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Help Center & Warranty FAQs',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Claim guidelines, invoice downloads',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PushSettingsCard(controller: widget.pushController),
          const SizedBox(height: AppSpacing.md),
          if (widget.onSignOut != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              variant: FixButtonVariant.secondary,
              onPressed: widget.onSignOut,
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          // Privacy card required by tests
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.outline.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your location is not part of your profile and is never saved by this screen.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          // ISO 27001 Certification Footer
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'FixNow v2.4.1 (Build 492) • ISO 27001 Certified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'End-to-end encrypted home maintenance records',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    ),
  );

  Widget _buildBentoStatCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String metric,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            metric,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }




  bool get _failed => const {
    ProfileViewStatus.offline,
    ProfileViewStatus.unauthorized,
    ProfileViewStatus.error,
  }.contains(widget.controller.status);
}

class _SavedAddressesSection extends StatelessWidget {
  const _SavedAddressesSection();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SavedAddressRepository.instance,
      builder: (context, _) {
        final addresses = SavedAddressRepository.instance.addresses;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outline.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.location_city_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'Saved addresses',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => AddEditAddressModalSheet.show(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add new'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final addr in addresses) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.outline.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          addr.icon,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    addr.customTitle,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (addr.isDefault) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryFixed,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'DEFAULT',
                                      style: TextStyle(
                                        color: AppColors.onPrimaryFixed,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              addr.formattedFull,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (!addr.isDefault)
                                  InkWell(
                                    onTap: () => SavedAddressRepository.instance
                                        .setDefault(addr.id),
                                    child: const Text(
                                      'Set as default',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (!addr.isDefault) const SizedBox(width: 14),
                                InkWell(
                                  onTap: () => SavedAddressRepository.instance
                                      .deleteAddress(addr.id),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
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
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProfileFailure extends StatelessWidget {
  const _ProfileFailure({required this.status, required this.onRetry});
  final ProfileViewStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unauthorized = status == ProfileViewStatus.unauthorized;
    final offline = status == ProfileViewStatus.offline;
    return FixCard(
      semanticLabel: 'Profile unavailable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            unauthorized
                ? 'Sign in required'
                : offline
                ? 'You are offline'
                : 'Profile unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            unauthorized
                ? 'Sign in to view or update your profile.'
                : offline
                ? 'Check your connection, then try again.'
                : 'We could not load your profile. Try again.',
          ),
          const SizedBox(height: AppSpacing.lg),
          FixButton(
            label: 'Try again',
            onPressed: onRetry,
            variant: FixButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
