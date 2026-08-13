import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/location/location_consent_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:flutter/material.dart';

class ServiceDiscoveryScreen extends StatefulWidget {
  const ServiceDiscoveryScreen({
    required this.controller,
    required this.locationController,
    this.onCategorySelected,
    super.key,
  });
  final ServiceDiscoveryController controller;
  final LocationConsentController locationController;
  final ValueChanged<ServiceCategory>? onCategorySelected;

  @override
  State<ServiceDiscoveryScreen> createState() => _ServiceDiscoveryScreenState();
}

class _ServiceDiscoveryScreenState extends State<ServiceDiscoveryScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => RefreshIndicator(
      onRefresh: widget.controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        children: [
          if (widget.controller.status == DiscoveryStatus.ready ||
              widget.controller.status == DiscoveryStatus.initial ||
              widget.controller.status == DiscoveryStatus.loading) ...[
            const FixBrandMark(compact: true),
            const SizedBox(height: AppSpacing.xxl),
          ],
          const FixPageHeader(
            eyebrow: 'Professional help is minutes away',
            title: 'What can we fix today?',
            description: 'Choose a trusted service and describe what happened.',
          ),
          const SizedBox(height: AppSpacing.xl),
          const FixCard(
            tone: FixCardTone.elevated,
            semanticLabel: 'Verified professional matching',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: AppColors.verified),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trusted local professionals',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Requests are offered only to eligible providers. Assignment happens after acceptance.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.controller.status == DiscoveryStatus.offline ||
              widget.controller.status == DiscoveryStatus.error ||
              widget.controller.status == DiscoveryStatus.empty) ...[
            const SizedBox(height: AppSpacing.xl),
            ..._content(context),
            const SizedBox(height: AppSpacing.xl),
          ],
          LocationConsentCard(controller: widget.locationController),
          if (widget.controller.status == DiscoveryStatus.ready ||
              widget.controller.status == DiscoveryStatus.initial ||
              widget.controller.status == DiscoveryStatus.loading) ...[
            const SizedBox(height: AppSpacing.xxl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'Popular services',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                Text(
                  'Verified categories',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ..._content(context),
          ],
        ],
      ),
    ),
  );

  List<Widget> _content(BuildContext context) =>
      switch (widget.controller.status) {
        DiscoveryStatus.initial || DiscoveryStatus.loading => const [
          Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading services',
            ),
          ),
        ],
        DiscoveryStatus.empty => [
          _DiscoveryMessage(
            title: 'No services available',
            message: 'Services will appear here when they become available.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.offline => [
          _DiscoveryMessage(
            title: 'You are offline',
            message: 'Check your connection, then try again.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.error => [
          _DiscoveryMessage(
            title: 'Services unavailable',
            message: 'We could not load services. Try again.',
            onRetry: widget.controller.load,
          ),
        ],
        DiscoveryStatus.ready => [
          _CategoryList(
            categories: widget.controller.categories,
            onSelected: widget.onCategorySelected,
          ),
        ],
      };
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories, required this.onSelected});
  final List<ServiceCategory> categories;
  final ValueChanged<ServiceCategory>? onSelected;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (var index = 0; index < categories.length; index += 1) ...[
          _CategoryRow(
            category: categories[index],
            onTap: onSelected == null
                ? null
                : () => onSelected!(categories[index]),
          ),
          if (index < categories.length - 1)
            const Divider(height: 1, indent: 64),
        ],
      ],
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onTap});
  final ServiceCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: '${category.name} service category',
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.inputBorder,
                ),
                child: Icon(
                  _categoryIcon(category.iconName),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (category.description case final description?) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    ),
  );

  static IconData _categoryIcon(String? value) => switch (value) {
    'plumbing' => Icons.plumbing_outlined,
    'electrical_services' => Icons.electrical_services_outlined,
    'ac_unit' => Icons.ac_unit_outlined,
    'key' => Icons.key_outlined,
    _ => Icons.home_repair_service_outlined,
  };
}

class _DiscoveryMessage extends StatelessWidget {
  const _DiscoveryMessage({
    required this.title,
    required this.message,
    required this.onRetry,
  });
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FixCard(
    semanticLabel: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(message),
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
