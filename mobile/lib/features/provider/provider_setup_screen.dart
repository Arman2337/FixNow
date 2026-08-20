import 'package:file_picker/file_picker.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({required this.controller, super.key});
  final ProviderController controller;
  @override
  State<ProviderSetupScreen> createState() => _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late final TextEditingController _radius;
  double? _latitude;
  double? _longitude;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _name = TextEditingController(text: profile?.displayName);
    _bio = TextEditingController(text: profile?.bio);
    _radius = TextEditingController(
      text: profile?.serviceRadiusKm.toStringAsFixed(0) ?? '10',
    );
    _latitude = profile?.baseLatitude;
    _longitude = profile?.baseLongitude;
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _busy = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required to set your service area.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'We could not use your current location. Check permission and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() ||
        _latitude == null ||
        _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set your service-area location before saving.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.controller.saveProfile(
        ProviderProfile(
          displayName: _name.text.trim(),
          bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
          serviceRadiusKm: double.parse(_radius.text),
          baseLatitude: _latitude!,
          baseLongitude: _longitude!,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile could not be saved. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) return;
    final extension = file!.extension?.toLowerCase();
    final contentType = extension == 'pdf'
        ? 'application/pdf'
        : extension == 'png'
        ? 'image/png'
        : 'image/jpeg';
    setState(() => _busy = true);
    try {
      await widget.controller.uploadDocument(
        type: type,
        name: file.name,
        contentType: contentType,
        bytes: file.bytes!,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Document upload failed. Use a PDF, JPG, or PNG under 10 MB.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Professional setup')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: FixPageFrame(
          maxWidth: 640,
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FixPageHeader(
                  eyebrow: 'YOUR BUSINESS',
                  title: 'Professional profile',
                  description:
                      'Only information required for service eligibility and coverage is collected.',
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _name,
                  style: const TextStyle(color: AppColors.inputText),
                  cursorColor: AppColors.primary,
                  decoration: const InputDecoration(
                    labelText: 'Professional display name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value?.trim().length ?? 0) < 2
                      ? 'Enter at least 2 characters.'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _bio,
                  style: const TextStyle(color: AppColors.inputText),
                  cursorColor: AppColors.primary,
                  maxLength: 1000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Professional summary',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _radius,
                  style: const TextStyle(color: AppColors.inputText),
                  cursorColor: AppColors.primary,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Service radius (km)',
                    prefixIcon: Icon(Icons.radar_rounded),
                  ),
                  validator: (value) {
                    final radius = double.tryParse(value ?? '');
                    return radius == null || radius < 1 || radius > 100
                        ? 'Enter a radius from 1 to 100 km.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                FixCard(
                  tone: FixCardTone.secondary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service-area center',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _latitude == null
                            ? 'Not set'
                            : 'Location set securely. Exact coordinates are not displayed.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FixButton(
                        label: 'Use current location',
                        icon: Icons.my_location_rounded,
                        onPressed: _busy ? null : _useLocation,
                        variant: FixButtonVariant.secondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FixButton(
                  label: 'Save professional profile',
                  icon: Icons.save_rounded,
                  onPressed: _busy ? null : _save,
                ),
                if (widget.controller.application?.status !=
                    ProviderApplicationStatus.approved) ...[
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    'Services and skills',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Skills remain unverified until an authorized reviewer verifies them.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...widget.controller.categories
                      .where(
                        (category) => !widget.controller.skills.any(
                          (skill) => skill.categoryName == category['name'],
                        ),
                      )
                      .map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: FixButton(
                            label: 'Add ${category['name']}',
                            icon: Icons.add_rounded,
                            onPressed: _busy
                                ? null
                                : () async {
                                    setState(() => _busy = true);
                                    try {
                                      await widget.controller.addSkill(
                                        category['id'] as String,
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(() => _busy = false);
                                      }
                                    }
                                  },
                            variant: FixButtonVariant.secondary,
                          ),
                        ),
                      ),
                  ...widget.controller.skills.map(
                    (skill) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: FixCard(
                        child: Row(
                          children: [
                            const Icon(Icons.build_circle_outlined),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: Text(skill.categoryName)),
                            Text(
                              skill.verified ? 'Verified' : 'Pending review',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  Text(
                    'Private documents',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'PDF, JPG, or PNG up to 10 MB. Files stay private and pass malware scanning.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final type in const [
                    'identity',
                    'license',
                    'certification',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: FixButton(
                        label:
                            'Upload ${type[0].toUpperCase()}${type.substring(1)}',
                        icon: Icons.upload_file_rounded,
                        onPressed: _busy ? null : () => _pickDocument(type),
                        variant: FixButtonVariant.secondary,
                      ),
                    ),
                  ...widget.controller.documents.map(
                    (document) => Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: FixCard(
                        child: Text(
                          '${document.type} • ${document.status} • ${(document.sizeBytes / 1024).ceil()} KB',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
