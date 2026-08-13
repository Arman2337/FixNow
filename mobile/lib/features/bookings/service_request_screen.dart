import 'dart:async';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/bookings/booking_controller.dart';
import 'package:fixnow_mobile/features/services/service_category.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ServiceRequestScreen extends StatefulWidget {
  const ServiceRequestScreen({
    required this.category,
    required this.controller,
    super.key,
  });
  final ServiceCategory category;
  final BookingController controller;

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationFailure(
          'Turn on Location Services to request nearby help.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _LocationFailure(
          'Location access is needed to match providers near you.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      await widget.controller.create(
        serviceCategoryId: widget.category.id,
        description: _details.text,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on _LocationFailure catch (error) {
      setState(() => _error = error.message);
    } on TimeoutException {
      setState(
        () => _error =
            'We could not get your location. Move to an open area and try again.',
      );
    } on ApiException catch (error) {
      setState(
        () => _error = error.kind == ApiFailureKind.offline
            ? 'You are offline. Reconnect and try again.'
            : 'We could not create the request. Try again.',
      );
    } catch (_) {
      setState(() => _error = 'We could not create the request. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Request service'), centerTitle: false),
    body: SafeArea(
      child: FixPageFrame(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            FixPageHeader(
              eyebrow: 'Request details',
              title: widget.category.name,
              description:
                  widget.category.description ??
                  'Tell us what needs attention and we will match a verified provider nearby.',
            ),
            const SizedBox(height: AppSpacing.xl),
            FixCard(
              semanticLabel: 'How matching works',
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Your request is shared only with eligible providers. A provider is assigned after they accept it.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _details,
                enabled: !_submitting,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What needs fixing?',
                  hintText:
                      'Describe the issue, where it is, and anything the provider should know.',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value?.trim().length ?? 0) < 10
                    ? 'Add at least 10 characters so the provider can prepare.'
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Row(
              children: [
                Icon(Icons.location_on_outlined, size: 20),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Your current location is captured only when you submit.',
                  ),
                ),
              ],
            ),
            if (_error case final message?) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FixButton(
              label: 'Find a verified provider',
              icon: Icons.arrow_forward_rounded,
              onPressed: _submit,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    ),
  );
}

class _LocationFailure implements Exception {
  const _LocationFailure(this.message);
  final String message;
}
