import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';

import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/features/provider/provider_controller.dart';
import 'package:fixnow_mobile/features/provider/provider_models.dart';
import 'package:fixnow_mobile/features/provider/provider_setup_screen.dart';
import 'package:fixnow_mobile/notifications/push_enrollment.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({
    required this.controller,
    required this.onSignOut,
    this.onSupportCases,
    this.pushController,
    super.key,
  });
  final ProviderController controller;
  final VoidCallback onSignOut;
  final VoidCallback? onSupportCases;
  final PushEnrollmentController? pushController;

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  bool _emergencyOnCall = true;
  double? _sliderRadius;
  String? _uploadingDocType;
  bool _isSubmitting = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // We can't access widget.controller directly here easily if it hasn't loaded,
    // but the listenable builder handles it. We will populate in build if empty.
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _uploadDoc(String type) async {
    setState(() => _uploadingDocType = '${type}_file');
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          await widget.controller.uploadDocument(
            type: type,
            name: file.name,
            contentType: file.extension == 'pdf'
                ? 'application/pdf'
                : 'image/jpeg',
            bytes: file.bytes!,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingDocType = null);
    }
  }

  Future<void> _uploadDocCamera(String type) async {
    setState(() => _uploadingDocType = '${type}_camera');
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        final bytes = await image.readAsBytes();
        await widget.controller.uploadDocument(
          type: type,
          name: image.name,
          contentType: 'image/jpeg',
          bytes: bytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingDocType = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final profile = widget.controller.profile;
          if (profile != null) {
            if (_nameController.text.isEmpty &&
                profile.displayName.isNotEmpty) {
              _nameController.text = profile.displayName;
            }
            if (_bioController.text.isEmpty && profile.bio != null) {
              _bioController.text = profile.bio!;
            }
          }
          if (widget.controller.state == ProviderLoadState.loading) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                semanticsLabel: 'Loading provider setup',
              ),
            );
          }
          if (widget.controller.state == ProviderLoadState.failure) {
            return FixErrorState(
              title: 'Provider setup unavailable',
              message: widget.controller.errorMessage!,
              onRetry: () => widget.controller.load(verified: false),
            );
          }

          final status =
              widget.controller.application?.status ??
              ProviderApplicationStatus.unverified;
          final isVerified = status == ProviderApplicationStatus.approved;
          final isUnderReview = status == ProviderApplicationStatus.underReview;

          final profileComplete =
              widget.controller.profile != null || isVerified;
          final skillsComplete =
              widget.controller.skills.isNotEmpty || isVerified;

          final reviewedDocuments = widget.controller.documents
              .where((d) => d.status.toUpperCase() == 'APPROVED')
              .length;
          final documentsComplete =
              widget.controller.documents.length >= 4 ||
              reviewedDocuments > 0 ||
              isVerified;

          final completedSteps = [
            profileComplete,
            skillsComplete,
            documentsComplete,
            isVerified || isUnderReview,
          ].where((c) => c).length;

          final progressPercent = completedSteps * 25;
          final currentStepNum = completedSteps == 4 ? 4 : completedSteps + 1;

          final currentRadius =
              _sliderRadius ??
              widget.controller.profile?.serviceRadiusKm ??
              12.0;

          return CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.surface.withValues(alpha: 0.8),
                flexibleSpace: FlexibleSpaceBar(
                  background: ClipRect(
                    child: BackdropFilter(
                      filter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.0),
                        BlendMode.dst,
                      ),
                    ),
                  ),
                ),
                elevation: 0,
                titleSpacing: AppSpacing.pagePadding,
                title: Row(
                  children: [
                    const Icon(
                      Icons.handyman_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'FixNow',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Activity Rewards',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    onPressed: widget.onSignOut,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Partner Sub-Header
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.verified,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'FIXNOW PRO NETWORK',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Partner Verification',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.help_outline_rounded,
                              color: AppColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Multi-Step Onboarding Stepper Header
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Step $currentStepNum of 4',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '•',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'KYC & Trade Documents',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$progressPercent% Complete',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              _StepperSegment(isComplete: profileComplete),
                              const SizedBox(width: 6),
                              _StepperSegment(isComplete: skillsComplete),
                              const SizedBox(width: 6),
                              _StepperSegment(
                                isComplete: documentsComplete,
                                isActive: skillsComplete && !documentsComplete,
                              ),
                              const SizedBox(width: 6),
                              _StepperSegment(
                                isComplete: isVerified || isUnderReview,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StepIcon(
                                label: '1. Bio Info',
                                isComplete: profileComplete,
                              ),
                              _StepIcon(
                                label: '2. Trade Skills',
                                isComplete: skillsComplete,
                              ),
                              _StepIcon(
                                label: '3. KYC Audit',
                                isComplete: documentsComplete,
                                isActive: skillsComplete && !documentsComplete,
                              ),
                              _StepIcon(
                                label: '4. Police Check',
                                isComplete: isVerified || isUnderReview,
                                isDimmed: !documentsComplete,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Real-time Audit Status Center
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.verified_user_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Document Upload & Audit Status',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${isVerified ? 4 : reviewedDocuments} of 4 Verified',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Aadhaar Card
                    Builder(
                      builder: (context) {
                        final doc = _getDoc('aadhaar');
                        if (doc == null) {
                          return _ActionDocumentCard(
                            icon: Icons.fingerprint_rounded,
                            title: 'Aadhaar Card (Front & Back)',
                            subtitle: 'Required for Identity Verification',
                            onUpload: () => _uploadDoc('aadhaar'),
                            onCamera: () => _uploadDocCamera('aadhaar'),
                            isUploadingFile:
                                _uploadingDocType == 'aadhaar_file',
                            isUploadingCamera:
                                _uploadingDocType == 'aadhaar_camera',
                          );
                        }
                        return _DocumentCard(
                          icon: Icons.fingerprint_rounded,
                          title: 'Aadhaar Card (Front & Back)',
                          docId:
                              'ID: ${doc.id.length > 8 ? doc.id.substring(0, 8).toUpperCase() : doc.id}',
                          status: doc.status.toUpperCase(),
                          subLabel: 'File Size',
                          subIcon: Icons.folder_zip_rounded,
                          subValue:
                              '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          isVerified: doc.status.toUpperCase() == 'APPROVED',
                          isPending: doc.status.toUpperCase() != 'APPROVED',
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // PAN Card
                    Builder(
                      builder: (context) {
                        final doc = _getDoc('pan');
                        if (doc == null) {
                          return _ActionDocumentCard(
                            icon: Icons.credit_card_rounded,
                            title: 'PAN Card (Business / Personal)',
                            subtitle: 'Required for Tax Compliance',
                            onUpload: () => _uploadDoc('pan'),
                            onCamera: () => _uploadDocCamera('pan'),
                            isUploadingFile: _uploadingDocType == 'pan_file',
                            isUploadingCamera:
                                _uploadingDocType == 'pan_camera',
                          );
                        }
                        return _DocumentCard(
                          icon: Icons.credit_card_rounded,
                          title: 'PAN Card (Business / Personal)',
                          docId:
                              'ID: ${doc.id.length > 8 ? doc.id.substring(0, 8).toUpperCase() : doc.id}',
                          status: doc.status.toUpperCase(),
                          subLabel: 'File Size',
                          subIcon: Icons.folder_zip_rounded,
                          subValue:
                              '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          isVerified: doc.status.toUpperCase() == 'APPROVED',
                          isPending: doc.status.toUpperCase() != 'APPROVED',
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Trade Competency Certificate
                    Builder(
                      builder: (context) {
                        final doc = _getDoc('trade');
                        if (doc == null) {
                          return _ActionDocumentCard(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Trade Competency Certificate',
                            subtitle: 'Required for Skill Verification',
                            onUpload: () => _uploadDoc('trade'),
                            onCamera: () => _uploadDocCamera('trade'),
                            isUploadingFile: _uploadingDocType == 'trade_file',
                            isUploadingCamera:
                                _uploadingDocType == 'trade_camera',
                          );
                        }
                        return _DocumentCard(
                          icon: Icons.workspace_premium_rounded,
                          title: 'Trade Competency Certificate',
                          docId:
                              'ID: ${doc.id.length > 8 ? doc.id.substring(0, 8).toUpperCase() : doc.id}',
                          status: doc.status.toUpperCase(),
                          subLabel: 'File Size',
                          subIcon: Icons.folder_zip_rounded,
                          subValue:
                              '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          isVerified: doc.status.toUpperCase() == 'APPROVED',
                          isPending: doc.status.toUpperCase() != 'APPROVED',
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Police Clearance Certificate (PCC)
                    Builder(
                      builder: (context) {
                        final doc = _getDoc('police');
                        if (doc == null) {
                          return _ActionDocumentCard(
                            icon: Icons.security_rounded,
                            title: 'Police Clearance Certificate',
                            subtitle:
                                'Required for Instant Emergency Dispatches',
                            onUpload: () => _uploadDoc('police'),
                            onCamera: () => _uploadDocCamera('police'),
                            isUploadingFile: _uploadingDocType == 'police_file',
                            isUploadingCamera:
                                _uploadingDocType == 'police_camera',
                          );
                        }
                        return _DocumentCard(
                          icon: Icons.security_rounded,
                          title: 'Police Clearance Certificate',
                          docId:
                              'ID: ${doc.id.length > 8 ? doc.id.substring(0, 8).toUpperCase() : doc.id}',
                          status: doc.status.toUpperCase(),
                          subLabel: 'File Size',
                          subIcon: Icons.folder_zip_rounded,
                          subValue:
                              '${(doc.sizeBytes / 1024).toStringAsFixed(1)} KB',
                          isVerified: doc.status.toUpperCase() == 'APPROVED',
                          isPending: doc.status.toUpperCase() != 'APPROVED',
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Profile Info
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Profile Information',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _bioController,
                            decoration: const InputDecoration(
                              labelText: 'Bio',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FixButton(
                              label: 'Save Profile',
                              onPressed: () {
                                final current = widget.controller.profile;
                                widget.controller.saveProfile(
                                  ProviderProfile(
                                    displayName: _nameController.text,
                                    bio: _bioController.text,
                                    serviceRadiusKm:
                                        current?.serviceRadiusKm ??
                                        _sliderRadius ??
                                        12.0,
                                    baseLatitude: current?.baseLatitude ?? 0.0,
                                    baseLongitude:
                                        current?.baseLongitude ?? 0.0,
                                    stats: current?.stats,
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile saved successfully'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Work Profile & Service Range Configuration
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Icon(
                                    Icons.tune_rounded,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Work Profile & Range Setup',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.settings_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Active Trade Badge Card
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.handyman_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Services & Skills',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          for (final skill in widget.controller.skills)
                                            Chip(
                                              label: Text(
                                                skill.categoryName ?? 'Unknown',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.onAccentGold,
                                                ),
                                              ),
                                              backgroundColor: AppColors.accentGold,
                                              deleteIconColor: AppColors.onAccentGold,
                                              onDeleted: () {
                                                widget.controller.removeSkill(skill.id).then((_) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skill removed')));
                                                }).catchError((e) {
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove skill')));
                                                });
                                              },
                                            ),
                                          if (widget.controller.categories.any((cat) => !widget.controller.skills.any((s) => s.categoryId == cat['id'])))
                                            Theme(
                                              data: Theme.of(context).copyWith(
                                                canvasColor: AppColors.surfaceElevated,
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  isDense: true,
                                                  hint: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      border: Border.all(color: AppColors.primary),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.add, size: 14, color: AppColors.primary),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Add Skill',
                                                          style: TextStyle(
                                                            color: AppColors.primary,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  icon: const SizedBox.shrink(),
                                                  items: widget.controller.categories
                                                      .where((cat) => !widget.controller.skills.any((s) => s.categoryId == cat['id']))
                                                      .map(
                                                        (cat) => DropdownMenuItem<String>(
                                                          value: cat['id'] as String,
                                                          child: Text(
                                                            cat['name'] as String? ?? 'Unknown',
                                                            style: const TextStyle(
                                                              fontSize: 13,
                                                              color: AppColors.textPrimary,
                                                            ),
                                                          ),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      widget.controller.addSkill(val).then((_) {
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skill added')));
                                                      }).catchError((e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add skill')));
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    '4+ Yrs Exp',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Range Slider Module
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Dispatch Coverage Radius',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${currentRadius.toInt()} km',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor:
                                  AppColors.surfaceContainerHighest,
                              thumbColor: AppColors.primary,
                              trackHeight: 8,
                            ),
                            child: Slider(
                              value: currentRadius,
                              min: 3,
                              max: 30,
                              onChanged: (val) {
                                setState(() {
                                  _sliderRadius = val;
                                });
                              },
                              onChangeEnd: (val) {
                                final current = widget.controller.profile;
                                widget.controller.saveProfile(
                                  ProviderProfile(
                                    displayName: _nameController.text.isNotEmpty
                                        ? _nameController.text
                                        : (current?.displayName ??
                                              'New Provider'),
                                    bio: _bioController.text.isNotEmpty
                                        ? _bioController.text
                                        : current?.bio,
                                    serviceRadiusKm: val,
                                    baseLatitude: current?.baseLatitude ?? 0.0,
                                    baseLongitude:
                                        current?.baseLongitude ?? 0.0,
                                    stats: current?.stats,
                                  ),
                                );
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                '3 km (Local)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '15 km',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                '30 km (Metropolitan)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.pin_drop_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(
                                      text: 'Covers: ',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              'Selected radius around your base location',
                                          style: TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Emergency On-Call Toggle Switch
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF825100,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.bolt_rounded,
                                    color: Color(0xFF825100),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Emergency On-Call Duty',
                                            style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '1.5x Pay',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Receive high-priority immediate hazard alerts (Gas leaks, power breaks, burst lines).',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _emergencyOnCall,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: AppColors.primary,
                                  onChanged: (val) =>
                                      setState(() => _emergencyOnCall = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Trust Verification Operations Banner
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.policy_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'FixNow Trust & Safety Assurance',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text.rich(
                                  TextSpan(
                                    text:
                                        'Your documents are currently being audited by FixNow Trust Operations. Approval turnaround: ',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '24 hours',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text:
                                            '. Upon approval, your partner dashboard unlocks job broadcasts.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Actions
                    FixButton(
                      label: isVerified
                          ? 'Verified'
                          : (isUnderReview
                                ? 'Under Review'
                                : (_isSubmitting
                                      ? 'Submitting...'
                                      : 'Submit for Final Review')),
                      icon: isVerified
                          ? Icons.check_circle_rounded
                          : (isUnderReview
                                ? Icons.hourglass_top_rounded
                                : Icons.arrow_forward_rounded),
                      isLoading: _isSubmitting,
                      onPressed: (isVerified || isUnderReview || _isSubmitting)
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              try {
                                await widget.controller.submitApplication();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Application could not be submitted. Try again.',
                                      ),
                                    ),
                                  );
                                }
                              }

                              if (mounted) {
                                setState(() => _isSubmitting = false);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: FixButton(
                            label: 'Save Updates',
                            variant: FixButtonVariant.primary,
                            onPressed: () {
                              final current = widget.controller.profile;
                              widget.controller.saveProfile(
                                ProviderProfile(
                                  displayName: _nameController.text,
                                  bio: _bioController.text,
                                  serviceRadiusKm: current?.serviceRadiusKm ?? _sliderRadius ?? 12.0,
                                  baseLatitude: current?.baseLatitude ?? 0.0,
                                  baseLongitude: current?.baseLongitude ?? 0.0,
                                  stats: current?.stats,
                                ),
                              ).then((_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Updates saved successfully')),
                                );
                              }).catchError((e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to save updates')),
                                );
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FixButton(
                            label: 'Sign Out',
                            variant: FixButtonVariant.secondary,
                            onPressed: widget.onSignOut,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  bool _isDocVerified(String type, List<ProviderDocument> docs) {
    return docs.any(
      (d) =>
          d.type.toLowerCase().contains(type) &&
          d.status.toUpperCase() == 'APPROVED',
    );
  }

  ProviderDocument? _getDoc(String type) {
    try {
      return widget.controller.documents.firstWhere(
        (d) => d.type.toLowerCase().contains(type),
      );
    } catch (_) {
      return null;
    }
  }
}

class _StepperSegment extends StatelessWidget {
  const _StepperSegment({required this.isComplete, this.isActive = false});
  final bool isComplete;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: isComplete || isActive
                  ? AppColors.primary
                  : AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (isActive)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  color: AppColors.primaryFixedDim.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.label,
    required this.isComplete,
    this.isActive = false,
    this.isDimmed = false,
  });
  final String label;
  final bool isComplete;
  final bool isActive;
  final bool isDimmed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDimmed ? 0.6 : 1.0,
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (isComplete
                        ? AppColors.primary
                        : AppColors.surfaceContainer),
              border: isActive
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      width: 2,
                    )
                  : null,
            ),
            child: Icon(
              Icons.check_rounded,
              color: isActive
                  ? AppColors.primary
                  : (isComplete ? Colors.white : AppColors.textSecondary),
              size: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : AppColors.textPrimary,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.docId,
    required this.status,
    required this.subLabel,
    this.subIcon,
    required this.subValue,
    this.isVerified = false,
    this.isPending = false,
  });

  final IconData icon;
  final String title;
  final String docId;
  final String status;
  final String subLabel;
  final IconData? subIcon;
  final String subValue;
  final bool isVerified;
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final statusColor = isPending ? const Color(0xFF825100) : AppColors.primary;
    final statusBg = isPending
        ? const Color(0xFFffddb8)
        : AppColors.primary.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isPending
                      ? statusColor.withValues(alpha: 0.1)
                      : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isPending ? statusColor : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      docId,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    if (!isPending) ...[
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (isPending) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (subIcon != null) ...[
                      Icon(
                        subIcon,
                        color: isPending
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      subLabel,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (isPending)
                  Text(
                    subValue,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    subValue,
                    style: TextStyle(
                      color: isVerified
                          ? AppColors.textSecondary
                          : AppColors.primary,
                      fontSize: 10,
                      fontWeight: isVerified
                          ? FontWeight.w500
                          : FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDocumentCard extends StatelessWidget {
  const _ActionDocumentCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onUpload,
    this.onCamera,
    this.isUploadingFile = false,
    this.isUploadingCamera = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onUpload;
  final VoidCallback? onCamera;
  final bool isUploadingFile;
  final bool isUploadingCamera;

  bool get isUploading => isUploadingFile || isUploadingCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.textSecondary, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'REQUIRED',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isUploading ? null : onCamera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isUploadingCamera)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.photo_camera_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isUploadingCamera ? 'Scanning...' : 'Scan Camera',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: isUploading ? null : onUpload,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isUploadingFile)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(
                            Icons.upload_file_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          isUploadingFile ? 'Uploading...' : 'Attach PDF',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
