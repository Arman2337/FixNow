import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_card.dart';
import 'package:fixnow_mobile/features/location/location_consent_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:fixnow_mobile/features/services/service_discovery_controller.dart';
import 'package:flutter/material.dart';

class ServiceDiscoveryScreen extends StatefulWidget {
  const ServiceDiscoveryScreen({
    required this.controller,
    required this.locationController,
    super.key,
  });
  final ServiceDiscoveryController controller;
  final LocationConsentController locationController;

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
          Semantics(
            header: true,
            child: Text(
              'Find a service',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Browse trusted help by category.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          LocationConsentCard(controller: widget.locationController),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            child: Text(
              'Services',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._content(context),
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
          for (final category in widget.controller.categories) ...[
            _CategoryCard(category: category),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      };
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});
  final ServiceCategory category;

  @override
  Widget build(BuildContext context) => FixCard(
    semanticLabel: '${category.name} service category',
    child: Row(
      children: [
        const Icon(Icons.home_repair_service_outlined),
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
                Text(description),
              ],
            ],
          ),
        ),
      ],
    ),
  );
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
