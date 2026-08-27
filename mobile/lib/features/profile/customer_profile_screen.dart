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
    this.onSignOut,
    this.onSupportCases,
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
    widget.controller.load();
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
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FixPageHeader(
            eyebrow: 'Your account',
            title: 'Profile',
            description: 'Only your display name is collected here.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          const FixCard(
            tone: FixCardTone.elevated,
            semanticLabel: 'Customer account summary',
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(Icons.person_rounded, color: AppColors.primary),
                ),
                SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FixNow customer',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text('Your service history and account stay private.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.controller.status == ProfileViewStatus.loading)
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Loading profile',
              ),
            )
          else if (_failed)
            _ProfileFailure(
              status: widget.controller.status,
              onRetry: widget.controller.load,
            )
          else
            FixCard(
              semanticLabel: 'Customer profile form',
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Personal details',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.textOnSurface),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Display name',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textOnSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.lg),
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
                      const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.lg),
          const _SavedAddressesSection(),
          if (widget.pushController != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PushSettingsCard(controller: widget.pushController!),
          ],
          if (widget.onSupportCases != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Support Cases',
              icon: Icons.support_agent_outlined,
              variant: FixButtonVariant.secondary,
              onPressed: widget.onSupportCases,
            ),
          ],
          if (widget.onSignOut != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FixButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              variant: FixButtonVariant.secondary,
              onPressed: widget.onSignOut,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          const FixCard(
            semanticLabel: 'Profile privacy information',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip_outlined),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Your location is not part of your profile and is never saved by this screen.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

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
        return FixCard(
          semanticLabel: 'Saved addresses',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_city_rounded, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Saved addresses',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textOnSurface,
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
              const SizedBox(height: AppSpacing.md),
              for (final addr in addresses) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(addr.icon, color: AppColors.focus, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  addr.customTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                if (addr.isDefault) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'DEFAULT',
                                      style: TextStyle(color: AppColors.success, fontSize: 8, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              addr.formattedFull,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (!addr.isDefault)
                                  InkWell(
                                    onTap: () => SavedAddressRepository.instance.setDefault(addr.id),
                                    child: const Text(
                                      'Set as default',
                                      style: TextStyle(color: AppColors.focus, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                if (!addr.isDefault) const SizedBox(width: 14),
                                InkWell(
                                  onTap: () => SavedAddressRepository.instance.deleteAddress(addr.id),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
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
