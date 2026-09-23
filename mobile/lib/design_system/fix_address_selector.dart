import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/app_typography.dart';
import 'package:fixnow_mobile/design_system/fix_button.dart';
import 'package:fixnow_mobile/features/location/live_location_service.dart';
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
  bool _userManuallySelected = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedAddress =
        widget.initialAddress ??
        SavedAddressRepository.instance.defaultAddress ??
        (SavedAddressRepository.instance.addresses.isNotEmpty
            ? SavedAddressRepository.instance.addresses.first
            : const SavedAddress(
                id: 'empty',
                label: AddressLabel.other,
                customTitle: 'No Saved Addresses',
                flatBuilding: 'Tap + Add New to save an address.',
                streetArea: '',
                latitude: 0.0,
                longitude: 0.0,
              ));
    SavedAddressRepository.instance.addListener(_onRepoChanged);
  }

  void _onRepoChanged() {
    if (!mounted) return;
    final all = SavedAddressRepository.instance.addresses;
    final def = SavedAddressRepository.instance.defaultAddress ?? all.first;
    if (!_userManuallySelected ||
        !all.any((a) => a.id == _selectedAddress.id)) {
      _selectedAddress = def;
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
    _userManuallySelected = true;
    setState(() => _selectedAddress = address);
    widget.onAddressSelected(address);
  }

  Future<void> _detectAndUseLiveLocation() async {
    setState(() => _isLocating = true);
    final live = await LiveLocationService.detectAndSaveLiveAddress();
    if (mounted) {
      setState(() => _isLocating = false);
      if (live != null) {
        _userManuallySelected = false;
        _select(live);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected live GPS address: ${live.formattedSnippet}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not access live GPS location. Please check location permissions.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderDefault),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Service Address',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.my_location_rounded,
                            size: 10,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'GPS ±3m',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openAddModal,
                child: const Text(
                  '+ Add New',
                  style: TextStyle(
                    color: AppColors.primary,
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
                InkWell(
                  onTap: _isLocating ? null : _detectAndUseLiveLocation,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.focus.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.focus),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLocating)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.focus,
                            ),
                          )
                        else
                          const Icon(
                            Icons.my_location_rounded,
                            size: 13,
                            color: AppColors.focus,
                          ),
                        const SizedBox(width: 4),
                        const Text(
                          'Use Live GPS',
                          style: TextStyle(
                            color: AppColors.focus,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                for (final addr in addresses) ...[
                  _buildAddressChip(addr),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: _openAddModal,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'New Address',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
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

          // Detailed Selected Address Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.borderDefault),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedAddress.icon,
                    color: AppColors.primary,
                    size: 16,
                  ),
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
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          if (_selectedAddress.isDefault) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'DEFAULT',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedAddress.formattedFull,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
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
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              addr.icon,
              color: isSelected ? Colors.white : AppColors.textSecondary,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              addr.customTitle,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
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
  const AddEditAddressModalSheet({super.key, this.initialAddress});

  final SavedAddress? initialAddress;

  static Future<SavedAddress?> show(
    BuildContext context, {
    SavedAddress? address,
  }) {
    return showModalBottomSheet<SavedAddress>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AddEditAddressModalSheet(initialAddress: address),
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
  bool _isAutoFilling = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAddress;
    _label = a?.label ?? AddressLabel.home;
    _titleController = TextEditingController(text: a?.customTitle ?? 'Home');
    _flatController = TextEditingController(text: a?.flatBuilding ?? '');
    _streetController = TextEditingController(text: a?.streetArea ?? '');
    _landmarkController = TextEditingController(text: a?.landmark ?? '');
    _cityController = TextEditingController(text: a?.city ?? 'Bengaluru');
    _pincodeController = TextEditingController(text: a?.postalCode ?? '560034');
    _isDefault = a?.isDefault ?? false;
    _latitude = a?.latitude;
    _longitude = a?.longitude;
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

  Future<void> _fillFromLiveGps() async {
    setState(() => _isAutoFilling = true);
    final live = await LiveLocationService.detectAndSaveLiveAddress();
    if (mounted) {
      setState(() => _isAutoFilling = false);
      if (live != null) {
        setState(() {
          _latitude = live.latitude;
          _longitude = live.longitude;
          if (live.flatBuilding.isNotEmpty &&
              live.flatBuilding != 'Current Location') {
            _flatController.text = live.flatBuilding;
          } else if (_flatController.text.isEmpty) {
            _flatController.text = 'Current Location';
          }
          _streetController.text = live.streetArea;
          _cityController.text = live.city;
          if (live.postalCode.isNotEmpty) {
            _pincodeController.text = live.postalCode;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-filled from live GPS: ${live.formattedSnippet}'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access live GPS location.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final address = SavedAddress(
      id: widget.initialAddress?.id ??
          'addr-${DateTime.now().millisecondsSinceEpoch}',
      label: _label,
      customTitle: _titleController.text.trim(),
      flatBuilding: _flatController.text.trim(),
      streetArea: _streetController.text.trim(),
      landmark: _landmarkController.text.trim().isNotEmpty
          ? _landmarkController.text.trim()
          : null,
      city: _cityController.text.trim(),
      postalCode: _pincodeController.text.trim(),
      latitude: _latitude ?? widget.initialAddress?.latitude ?? 12.9352,
      longitude: _longitude ?? widget.initialAddress?.longitude ?? 77.6245,
      isDefault: _isDefault,
    );

    await SavedAddressRepository.instance.saveAddress(address);
    Navigator.of(context).pop(address);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderDefault)),
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
                        color: AppColors.borderDefault,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.initialAddress == null
                            ? 'Add New Address'
                            : 'Edit Address',
                        style: FixNowTypography.heading2.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Label selector chips
                  Row(
                    children: [
                      _buildLabelChoice(
                        AddressLabel.home,
                        'Home',
                        Icons.home_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildLabelChoice(
                        AddressLabel.work,
                        'Work',
                        Icons.work_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildLabelChoice(
                        AddressLabel.other,
                        'Other',
                        Icons.location_on_rounded,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Quick live GPS auto-fill
                  InkWell(
                    onTap: _isAutoFilling ? null : _fillFromLiveGps,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.focus.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                        border: Border.all(
                          color: AppColors.focus.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isAutoFilling)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.focus,
                              ),
                            )
                          else
                            const Icon(
                              Icons.my_location_rounded,
                              color: AppColors.focus,
                              size: 15,
                            ),
                          const SizedBox(width: 6),
                          const Text(
                            'Fill from current GPS location',
                            style: TextStyle(
                              color: AppColors.focus,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Flat/Building
                  TextFormField(
                    controller: _flatController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration(
                      'Flat, House No., Building Name *',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter building / flat details'
                        : null,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Street/Area
                  TextFormField(
                    controller: _streetController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration('Street, Area, Colony *'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter street / area'
                        : null,
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  // Landmark
                  TextFormField(
                    controller: _landmarkController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: _inputDecoration('Landmark (Optional)'),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration('City *'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter city'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _pincodeController,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          decoration: _inputDecoration('Pincode *'),
                          validator: (v) => (v == null || v.trim().length < 6)
                              ? '6-digit pincode'
                              : null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Default switch wrapped in Material
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Save as default service address',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      value: _isDefault,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _isDefault = val),
                    ),
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
            if (_titleController.text == 'Home' ||
                _titleController.text == 'Work' ||
                _titleController.text == 'Other') {
              _titleController.text = text;
            }
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderDefault,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
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
      hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      filled: true,
      fillColor: AppColors.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}
