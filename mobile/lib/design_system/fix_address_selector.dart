import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:flutter/material.dart';

/// Card presented on ServiceRequestScreen allowing 1-tap saved address selection.
class SavedAddressSelectorCard extends StatefulWidget {
  const SavedAddressSelectorCard({
    required this.onAddressSelected,
    this.initialAddress,
    super.key,
  });

  final ValueChanged<SavedAddress> onAddressSelected;
  final SavedAddress? initialAddress;

  @override
  State<SavedAddressSelectorCard> createState() =>
      _SavedAddressSelectorCardState();
}

class _SavedAddressSelectorCardState extends State<SavedAddressSelectorCard> {
  late SavedAddress _selectedAddress;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.initialAddress ??
        SavedAddressRepository.instance.defaultAddress ??
        SavedAddressRepository.instance.addresses.first;
    SavedAddressRepository.instance.addListener(_onRepoChanged);
  }

  void _onRepoChanged() {
    if (!mounted) return;
    final all = SavedAddressRepository.instance.addresses;
    if (all.isEmpty) return;
    if (!all.any((a) => a.id == _selectedAddress.id)) {
      _selectedAddress = SavedAddressRepository.instance.defaultAddress ?? all.first;
      widget.onAddressSelected(_selectedAddress);
    }
    setState(() {});
  }

  @override
  void dispose() {
    SavedAddressRepository.instance.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _select(SavedAddress address) {
    setState(() => _selectedAddress = address);
    widget.onAddressSelected(address);
  }

  void _openAddModal() async {
    final newAddress = await AddEditAddressModalSheet.show(context);
    if (newAddress != null && mounted) {
      _select(newAddress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = SavedAddressRepository.instance.addresses;

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.focus, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Service Address',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _openAddModal,
                child: const Text(
                  '+ Add New',
                  style: TextStyle(
                    color: AppColors.focus,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Horizontal Address Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final addr in addresses) ...[
                  _buildAddressChip(addr),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: _openAddModal,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: Colors.white70),
                        SizedBox(width: 4),
                        Text(
                          'New Address',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Detailed Selected Address Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_selectedAddress.icon, color: AppColors.focus, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _selectedAddress.customTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (_selectedAddress.isDefault) ...[
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
                      const SizedBox(height: 3),
                      Text(
                        _selectedAddress.formattedFull,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressChip(SavedAddress addr) {
    final isSelected = addr.id == _selectedAddress.id;
    return InkWell(
      onTap: () => _select(addr),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(addr.icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              addr.customTitle,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Bottom Sheet for adding or editing an address
class AddEditAddressModalSheet extends StatefulWidget {
  const AddEditAddressModalSheet({this.existingAddress, super.key});

  final SavedAddress? existingAddress;

  static Future<SavedAddress?> show(BuildContext context, {SavedAddress? existing}) {
    return showModalBottomSheet<SavedAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditAddressModalSheet(existingAddress: existing),
    );
  }

  @override
  State<AddEditAddressModalSheet> createState() =>
      _AddEditAddressModalSheetState();
}

class _AddEditAddressModalSheetState extends State<AddEditAddressModalSheet> {
  final _formKey = GlobalKey<FormState>();
  late AddressLabel _label;
  late TextEditingController _titleController;
  late TextEditingController _flatController;
  late TextEditingController _streetController;
  late TextEditingController _landmarkController;
  late TextEditingController _cityController;
  late TextEditingController _pincodeController;
  bool _isDefault = false;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _label = a?.label ?? AddressLabel.home;
    _titleController = TextEditingController(text: a?.customTitle ?? 'Home');
    _flatController = TextEditingController(text: a?.flatBuilding ?? '');
    _streetController = TextEditingController(text: a?.streetArea ?? '');
    _landmarkController = TextEditingController(text: a?.landmark ?? '');
    _cityController = TextEditingController(text: a?.city ?? 'Bengaluru');
    _pincodeController = TextEditingController(text: a?.postalCode ?? '560034');
    _isDefault = a?.isDefault ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _flatController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final address = SavedAddress(
      id: widget.existingAddress?.id ?? 'addr-${DateTime.now().millisecondsSinceEpoch}',
      label: _label,
      customTitle: _titleController.text.trim(),
      flatBuilding: _flatController.text.trim(),
      streetArea: _streetController.text.trim(),
      landmark: _landmarkController.text.trim().isNotEmpty ? _landmarkController.text.trim() : null,
      city: _cityController.text.trim(),
      postalCode: _pincodeController.text.trim(),
      latitude: widget.existingAddress?.latitude ?? 12.9352,
      longitude: widget.existingAddress?.longitude ?? 77.6245,
      isDefault: _isDefault,
    );

    SavedAddressRepository.instance.saveAddress(address);
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingAddress == null ? 'Add New Address' : 'Edit Address',
                      style: AppTypography.heading2.copyWith(color: Colors.white, fontSize: 18),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Label selector chips
                Row(
                  children: [
                    _buildLabelChoice(AddressLabel.home, 'Home', Icons.home_rounded),
                    const SizedBox(width: 8),
                    _buildLabelChoice(AddressLabel.work, 'Work', Icons.work_rounded),
                    const SizedBox(width: 8),
                    _buildLabelChoice(AddressLabel.other, 'Other', Icons.location_on_rounded),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Flat/Building
                TextFormField(
                  controller: _flatController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Flat, House No., Building Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter building / flat details' : null,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Street/Area
                TextFormField(
                  controller: _streetController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Street, Area, Colony *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter street / area' : null,
                ),

                const SizedBox(height: AppSpacing.sm),

                // Landmark
                TextFormField(
                  controller: _landmarkController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: _inputDecoration('Landmark (Optional)'),
                ),

                const SizedBox(height: AppSpacing.sm),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _inputDecoration('City *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter city' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _pincodeController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _inputDecoration('Pincode *'),
                        validator: (v) => (v == null || v.trim().length < 6) ? '6-digit pincode' : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // Default switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save as default service address', style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _isDefault,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) => setState(() => _isDefault = val),
                ),

                const SizedBox(height: AppSpacing.md),

                FixButton(
                  label: 'Save Address',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelChoice(AddressLabel label, String text, IconData icon) {
    final isSelected = _label == label;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _label = label;
            if (_titleController.text == 'Home' || _titleController.text == 'Work' || _titleController.text == 'Other') {
              _titleController.text = text;
            }
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.white12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.focus : Colors.white70, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? AppColors.focus : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      filled: true,
      fillColor: AppColors.surfaceElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
