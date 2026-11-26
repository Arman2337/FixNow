import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_page_frame.dart';
import 'package:flutter/material.dart';

import 'complaints_controller.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({
    super.key,
    required this.controller,
    this.bookingId,
    required this.targetRole,
    this.targetId,
  });

  final ComplaintsController controller;

  final String? bookingId;
  final String targetRole;
  final String? targetId;

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<String> _categories = [
    'Unprofessional Behavior',
    'No Show',
    'Payment Issue',
    'Service Quality',
    'Safety Concern',
    'Other',
  ];
  String? _selectedCategory;

  /// True once the user has pressed Submit at least once.
  ///
  /// Validators only run after that, so nobody is told "Please select a
  /// category" while they are still reading the form; from then on each field
  /// re-validates as it changes, so an error clears the moment the field
  /// becomes valid instead of staying red under a filled-in value.
  bool _submitted = false;

  void _revalidate() {
    if (_submitted) _formKey.currentState?.validate();
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    _submitted = true;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;

    final result = await widget.controller.submitComplaint(
      bookingId: widget.bookingId,
      targetRole: widget.targetRole,
      targetId: widget.targetId,
      category: _selectedCategory!,
      description: _descriptionController.text,
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint submitted successfully')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'File a Complaint',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: FixPageFrame(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final isSubmitting =
                widget.controller.submitStatus ==
                SubmitComplaintStatus.submitting;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: [
                  // Server failures only. Field problems are reported under
                  // their own field, so a form that simply fails validation
                  // never also gets a second block of red text at the top -
                  // that pairing is what read as one error rendered twice.
                  if (widget.controller.submitStatus ==
                          SubmitComplaintStatus.error &&
                      widget.controller.submitError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.dangerSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.danger),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              "We couldn't send your complaint. Your answers "
                              'are still here - please try again.',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const FixPageHeader(
                    eyebrow: 'TRUST & SAFETY',
                    title: 'File a complaint',
                    description:
                        'Tell us what happened so our team can review the booking and help with the next step.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FixCard(
                    tone: FixCardTone.secondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Complaint details',
                          style: TextStyle(
                            color: AppColors.textOnSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Include what happened, when it happened, and what resolution you need.',
                          style: TextStyle(
                            color: AppColors.textOnSurfaceSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Category',
                          style: TextStyle(
                            color: AppColors.textOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedCategory,
                          dropdownColor: AppColors.surfacePrimary,
                          style: const TextStyle(color: AppColors.inputText),
                          iconEnabledColor: AppColors.inputIcon,
                          decoration: const InputDecoration(
                            hintText: 'Select a category',
                          ),
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.inputText,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: isSubmitting
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedCategory = val;
                                  });
                                  _revalidate();
                                },
                          validator: (val) =>
                              val == null ? 'Please select a category' : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: AppColors.textOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _descriptionController,
                          style: const TextStyle(color: AppColors.inputText),
                          cursorColor: AppColors.primary,
                          onChanged: (_) => _revalidate(),
                          decoration: const InputDecoration(
                            hintText:
                                'Describe what happened, when it happened, and what you need from us.',
                          ),
                          maxLines: 5,
                          enabled: !isSubmitting,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please provide a description';
                            }
                            if (val.trim().length < 10) {
                              return 'Description is too short';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FixButton(
                    label: 'Submit Complaint',
                    isLoading: isSubmitting,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const FixCard(
                    semanticLabel: 'Emergency safety guidance',
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.accentGold,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'For immediate danger, contact local authorities or emergency services. FixNow support is not an emergency response service.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
