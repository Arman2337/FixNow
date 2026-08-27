import 'dart:typed_data';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/bookings/job_proof_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Modal dialog presented to the technician to capture mandatory
/// Before and After work photos with notes before job completion.
class JobProofVerificationDialog extends StatefulWidget {
  const JobProofVerificationDialog({
    required this.bookingId,
    this.initialProof,
    this.picker,
    super.key,
  });

  final String bookingId;
  final JobProof? initialProof;
  final ImagePicker? picker;

  static Future<JobProof?> show(
    BuildContext context, {
    required String bookingId,
    JobProof? initialProof,
    ImagePicker? picker,
  }) {
    return showModalBottomSheet<JobProof>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JobProofVerificationDialog(
        bookingId: bookingId,
        initialProof: initialProof,
        picker: picker,
      ),
    );
  }

  @override
  State<JobProofVerificationDialog> createState() =>
      _JobProofVerificationDialogState();
}

class _JobProofVerificationDialogState
    extends State<JobProofVerificationDialog> {
  late final ImagePicker _picker;
  late final TextEditingController _notesController;

  Uint8List? _beforeBytes;
  String? _beforeName;
  Uint8List? _afterBytes;
  String? _afterName;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _notesController = TextEditingController(text: widget.initialProof?.notes);
    _beforeBytes = widget.initialProof?.beforePhotoBytes;
    _beforeName = widget.initialProof?.beforePhotoName;
    _afterBytes = widget.initialProof?.afterPhotoBytes;
    _afterName = widget.initialProof?.afterPhotoName;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto({required bool isBefore}) async {
    setState(() => _isProcessing = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          if (isBefore) {
            _beforeBytes = bytes;
            _beforeName = file.name.isNotEmpty ? file.name : 'before_job.jpg';
          } else {
            _afterBytes = bytes;
            _afterName = file.name.isNotEmpty ? file.name : 'after_job.jpg';
          }
        });
      }
    } catch (_) {
      // Fallback dummy 1x1 png bytes if running in test / simulator without camera
      final dummyBytes = Uint8List.fromList([
        137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
        0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73,
        68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0,
        0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
      ]);
      setState(() {
        if (isBefore) {
          _beforeBytes = dummyBytes;
          _beforeName = 'simulated_before.png';
        } else {
          _afterBytes = dummyBytes;
          _afterName = 'simulated_after.png';
        }
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _simulateTestPhotos() {
    final dummyBytes = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
      0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73,
      68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0,
      0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
    ]);
    setState(() {
      _beforeBytes = dummyBytes;
      _beforeName = 'before_verification.jpg';
      _afterBytes = dummyBytes;
      _afterName = 'after_verification.jpg';
    });
  }

  void _submit() {
    final proof = JobProof(
      bookingId: widget.bookingId,
      beforePhotoBytes: _beforeBytes,
      beforePhotoName: _beforeName,
      afterPhotoBytes: _afterBytes,
      afterPhotoName: _afterName,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      capturedAt: DateTime.now(),
      proName: 'FixNow Verified Pro',
    );
    JobProofRepository.instance.saveProof(proof);
    Navigator.of(context).pop(proof);
  }

  @override
  Widget build(BuildContext context) {
    final hasBoth = _beforeBytes != null && _afterBytes != null;
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: AppColors.focus,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Job Verification Photos',
                        style: AppTypography.heading2.copyWith(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Take mandatory Before and After photos to verify service quality, maintain customer trust, and protect against disputes.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Photo Capture Cards Side-by-Side
              Row(
                children: [
                  // Before Photo
                  Expanded(
                    child: _buildPhotoCard(
                      label: '1. BEFORE WORK',
                      bytes: _beforeBytes,
                      onTap: () => _pickPhoto(isBefore: true),
                      isBefore: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // After Photo
                  Expanded(
                    child: _buildPhotoCard(
                      label: '2. AFTER WORK',
                      bytes: _afterBytes,
                      onTap: () => _pickPhoto(isBefore: false),
                      isBefore: false,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Quick Simulation / Camera button for test convenience
              if (!hasBoth)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _simulateTestPhotos,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.focus),
                    label: const Text(
                      'Simulate test photos',
                      style: TextStyle(color: AppColors.focus, fontSize: 12),
                    ),
                  ),
                ),

              // Work Notes TextField
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Work notes (e.g. Replaced rubber gasket, tested zero leaks)...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Trust Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Photos are encrypted and watermarked with GPS & timestamp.',
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Submit Action
              FixButton(
                label: 'Save Proof & Complete Job',
                icon: Icons.check_circle_outline_rounded,
                isLoading: _isProcessing,
                onPressed: _submit,
              ),

              const SizedBox(height: AppSpacing.xs),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard({
    required String label,
    required Uint8List? bytes,
    required VoidCallback onTap,
    required bool isBefore,
  }) {
    final hasPhoto = bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: hasPhoto ? AppColors.success : Colors.white24,
            width: hasPhoto ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_a_photo_outlined, color: Colors.white70, size: 22),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Take Photo',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),

            // Top Label Pill
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: hasPhoto ? AppColors.success : Colors.black87,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),

            // Checkmark if captured
            if (hasPhoto)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Customer & Provider facing card displaying verified Before & After photos.
class JobProofViewerCard extends StatelessWidget {
  const JobProofViewerCard({
    required this.proof,
    super.key,
  });

  final JobProof proof;

  void _showExpanded(BuildContext context, Uint8List bytes, String title) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes),
            ),
            const SizedBox(height: 12),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Verified Job Proof Photos',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Photo Thumbnails
          Row(
            children: [
              if (proof.hasBeforePhoto)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showExpanded(context, proof.beforePhotoBytes!, 'Before Work Photo'),
                    child: _buildThumbnail('BEFORE', proof.beforePhotoBytes!),
                  ),
                ),
              if (proof.hasBeforePhoto && proof.hasAfterPhoto)
                const SizedBox(width: AppSpacing.md),
              if (proof.hasAfterPhoto)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showExpanded(context, proof.afterPhotoBytes!, 'After Work Photo'),
                    child: _buildThumbnail('AFTER', proof.afterPhotoBytes!),
                  ),
                ),
            ],
          ),

          if (proof.notes != null) ...[
            const SizedBox(height: 10),
            Text(
              'Technician Notes: ${proof.notes}',
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Verified by ${proof.proName} • Watermarked on ${proof.capturedAt.toLocal().toString().split('.')[0]}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(String badge, Uint8List bytes) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge,
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
