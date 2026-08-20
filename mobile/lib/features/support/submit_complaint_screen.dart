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

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
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
      appBar: AppBar(title: const Text('File a complaint')),
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
                  if (widget.controller.submitError != null) ...[
                    Text(
                      widget.controller.submitError!,
                      style: const TextStyle(color: Colors.red),
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
