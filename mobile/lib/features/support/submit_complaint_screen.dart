import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/design_system/fix_components.dart';
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
      appBar: AppBar(title: const Text('File a Complaint')),
      body: FixPageFrame(
        child: ListenableBuilder(
          listenable: widget.controller,
        builder: (context, _) {
          final isSubmitting =
              widget.controller.submitStatus == SubmitComplaintStatus.submitting;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (widget.controller.submitError != null) ...[
                  Text(
                    widget.controller.submitError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                const Text(
                  'Please provide details about your issue. Our trust and safety team will review this shortly.',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (val) {
                          setState(() {
                            _selectedCategory = val;
                          });
                        },
                  validator: (val) => val == null ? 'Please select a category' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
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
                const SizedBox(height: AppSpacing.xl),
                FixButton(
                  label: 'Submit Complaint',
                  isLoading: isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    ));
  }
}
