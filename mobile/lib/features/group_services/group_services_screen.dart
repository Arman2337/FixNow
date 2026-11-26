import 'dart:math';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
import 'package:fixnow_mobile/features/call/call_screen.dart';
import 'package:fixnow_mobile/features/location/saved_address.dart';
import 'package:fixnow_mobile/features/payments/gateway_checkout_repository.dart';
import 'package:fixnow_mobile/features/payments/group_service_payment.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

typedef _Row = Map<String, Object?>;

String? groupInviteToken(String input) {
  final value = input.trim();
  final uri = Uri.tryParse(value);
  final segments = uri?.pathSegments ?? const <String>[];
  String? candidate;
  if (uri?.scheme == 'fixnow' &&
      uri?.host == 'group-invite' &&
      segments.length == 1) {
    candidate = segments.single;
  } else if ((uri?.scheme == 'https' || uri?.scheme == 'http') &&
      segments.length >= 2 &&
      segments[segments.length - 2] == 'group-services' &&
      segments.last == 'invite') {
    candidate = uri?.fragment;
  } else if (value == uri?.path) {
    candidate = value;
  }
  if (candidate != null && RegExp(r'^[a-f0-9]{48}$').hasMatch(candidate)) {
    return candidate;
  }
  return null;
}

String _rupees(Object? minor) =>
    '₹${((minor as int) / 100).toStringAsFixed(2)}';

int? _minorUnits(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(value)) return null;
  final parts = value.split('.');
  return int.parse(parts.first) * 100 +
      (parts.length == 2 ? int.parse(parts.last.padRight(2, '0')) : 0);
}

class GroupServicesScreen extends StatefulWidget {
  const GroupServicesScreen({
    required this.api,
    required this.accessToken,
    required this.baseUri,
    this.provider = false,
    this.inviteToken,
    this.gatewayCheckout,
    super.key,
  });

  final ApiTransport api;
  final Future<String?> Function() accessToken;
  final Uri baseUri;
  final bool provider;
  final String? inviteToken;
  final GatewayCheckoutRepository? gatewayCheckout;

  @override
  State<GroupServicesScreen> createState() => _GroupServicesScreenState();
}

class _GroupServicesScreenState extends State<GroupServicesScreen> {
  static const _path = 'group-services';
  String? _selectedId;
  bool _busy = false;
  ({
    String? categoryId,
    String area,
    String serviceAddress,
    String preferredSchedule,
    String description,
  })? _lastCreation;
  String? _creationKey;
  late Future<Object?> _content;

  @override
  void initState() {
    super.initState();
    _content = _fetch();
    final token = widget.inviteToken;
    if (token != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _join(token);
      });
    }
  }

  Future<Object?> _send(String path, {_Row? body}) async {
    final token = await widget.accessToken();
    if (token == null) {
      throw const ApiException(
        ApiFailureKind.unauthorized,
        'Sign in to access group services.',
      );
    }
    final result = await widget.api.send(
      ApiRequest(
        method: body == null ? ApiMethod.get : ApiMethod.post,
        path: path,
        body: body,
        bearerToken: token,
      ),
    );
    return result.body;
  }

  Future<Object?> _fetch() => _send(
    widget.provider
        ? '$_path/provider'
        : _selectedId == null
        ? _path
        : '$_path/$_selectedId',
  );

  Future<void> _refresh() async {
    setState(() {
      _content = _fetch();
    });
    try {
      await _content;
    } catch (_) {
      // The FutureBuilder presents the retry state.
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException ? error.message : 'Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(String? id) {
    if (!mounted) return;
    setState(() {
      _selectedId = id;
      _content = _fetch();
    });
  }

  Future<List<SavedAddress>> _loadManualAddresses() async {
    try {
      final repo = SavedAddressRepository.instance;
      if (repo.addresses.isEmpty) {
        await repo.fetchAddresses();
      }
      return repo.addresses
          .where(
            (a) =>
                a.id != 'addr-current-live' &&
                a.customTitle.trim().toLowerCase() != 'current location',
          )
          .toList(growable: false);
    } catch (_) {
      return const <SavedAddress>[];
    }
  }

  Future<void> _create() => _run(() async {
    final categories = (await _send('$_path/categories') as List).cast<_Row>();
    final savedAddresses = await _loadManualAddresses();
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No group services are available yet.')),
      );
      return;
    }
    String? categoryId;
    final areaCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final scheduleCtrl = TextEditingController();
    var description = '';
    if (savedAddresses.isNotEmpty) {
      final initial = savedAddresses.first;
      addressCtrl.text = initial.formattedFull;
      areaCtrl.text = initial.city.trim().isNotEmpty
          ? '${initial.streetArea}, ${initial.city}'
          : initial.streetArea;
    }
    final form = GlobalKey<FormState>();
    try {
      final confirmed = await _formDialog(
        'Create a service group',
        'Create group',
        form,
        [
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Service',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            isExpanded: true,
            items: [
              for (final category in categories)
                DropdownMenuItem(
                  value: category['id'] as String,
                  child: Text(category['name'] as String),
                ),
            ],
            onChanged: (value) => categoryId = value,
            validator: (value) => value == null ? 'Choose a service.' : null,
          ),
          if (savedAddresses.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Saved service address',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              isExpanded: true,
              initialValue: savedAddresses.first.id,
              items: [
                for (final addr in savedAddresses)
                  DropdownMenuItem(
                    value: addr.id,
                    child: Text(
                      '${addr.labelText}: ${addr.formattedFull}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                final picked = savedAddresses
                    .where((a) => a.id == value)
                    .firstOrNull;
                if (picked == null) return;
                addressCtrl.text = picked.formattedFull;
                areaCtrl.text = picked.city.trim().isNotEmpty
                    ? '${picked.streetArea}, ${picked.city}'
                    : picked.streetArea;
              },
            ),
          TextFormField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Service address',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              helperText:
                  'Enter flat/house number, building & street (never your live GPS).',
              helperMaxLines: 3,
            ),
            maxLength: 300,
            maxLines: 2,
            validator: (value) => (value ?? '').trim().length < 5
                ? 'Enter a complete service address (at least 5 characters).'
                : null,
          ),
          TextFormField(
            controller: areaCtrl,
            decoration: const InputDecoration(
              labelText: 'Neighbourhood or PIN code',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            maxLength: 120,
            validator: (value) => (value ?? '').trim().length < 2
                ? 'Enter at least 2 characters.'
                : null,
          ),
          TextFormField(
            controller: scheduleCtrl,
            decoration: const InputDecoration(
              labelText: 'Preferred date & time (optional)',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'e.g. Saturday 10:00 AM - 1:00 PM',
            ),
            maxLength: 120,
          ),
          _field(
            'What does each household need?',
            (value) => description = value,
            min: 3,
            max: 1000,
            hint: 'For example, one split AC cleaning per household.',
          ),
        ],
      );
      if (!confirmed || !mounted) return;
      final area = areaCtrl.text.trim();
      final serviceAddress = addressCtrl.text.trim();
      final preferredSchedule = scheduleCtrl.text.trim();
      final input = (
        categoryId: categoryId,
        area: area,
        serviceAddress: serviceAddress,
        preferredSchedule: preferredSchedule,
        description: description,
      );
      if (_lastCreation != input) {
        final random = Random.secure();
        _lastCreation = input;
        _creationKey = List.generate(
          16,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
      final result =
          await _send(
                _path,
                body: {
                  'categoryId': categoryId,
                  'requestKey': _creationKey,
                  'area': area,
                  'serviceAddress': serviceAddress,
                  if (preferredSchedule.isNotEmpty)
                    'preferredSchedule': preferredSchedule,
                  'description': description,
                },
              )
              as _Row;
      _lastCreation = null;
      _creationKey = null;
      _open(result['id'] as String);
    } finally {
      areaCtrl.dispose();
      addressCtrl.dispose();
      scheduleCtrl.dispose();
    }
  });

  Future<void> _join([String? invitation]) => _run(() async {
    var token = invitation;
    final savedAddresses = await _loadManualAddresses();
    if (!mounted) return;
    final addressCtrl = TextEditingController(
      text: savedAddresses.isNotEmpty ? savedAddresses.first.formattedFull : '',
    );
    final form = GlobalKey<FormState>();
    try {
      final confirmed = await _formDialog(
        'Join a service group',
        'Send join request',
        form,
        [
          const Text(
            'Send a join request with your household service address. Once the group maker accepts your request, you can share the invite link and track full service progress.',
          ),
          if (invitation == null)
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Invitation link or code',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              autocorrect: false,
              validator: (value) {
                token = groupInviteToken(value ?? '');
                return token == null
                    ? 'Enter a FixNow group invitation.'
                    : null;
              },
            ),
          if (savedAddresses.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Saved service address',
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              isExpanded: true,
              initialValue: savedAddresses.first.id,
              items: [
                for (final addr in savedAddresses)
                  DropdownMenuItem(
                    value: addr.id,
                    child: Text(
                      '${addr.labelText}: ${addr.formattedFull}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                final picked = savedAddresses
                    .where((a) => a.id == value)
                    .firstOrNull;
                if (picked != null) {
                  addressCtrl.text = picked.formattedFull;
                }
              },
            ),
          TextFormField(
            controller: addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Your service address',
              floatingLabelBehavior: FloatingLabelBehavior.always,
              helperText:
                  'Enter flat/house number & street for your household.',
              helperMaxLines: 3,
            ),
            maxLength: 300,
            maxLines: 2,
            validator: (value) => (value ?? '').trim().length < 5
                ? 'Enter a complete service address (at least 5 characters).'
                : null,
          ),
        ],
      );
      if (!confirmed || !mounted) return;
      final result =
          await _send(
                '$_path/join',
                body: {
                  'token': token,
                  'serviceAddress': addressCtrl.text.trim(),
                },
              )
              as _Row;
      _open(result['id'] as String);
    } finally {
      addressCtrl.dispose();
    }
  });

  Future<void> _quote(String id) => _run(() async {
    int? regular;
    int? discounted;
    var note = '';
    final form = GlobalKey<FormState>();
    final confirmed = await _formDialog(
      'Send a group quote',
      'Send quote',
      form,
      [
        const Text(
          'Enter the price for one household, including any fees. If selected, your account phone number is shared with the organizer so you can arrange the service.',
        ),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Your regular price (₹)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            regular = _minorUnits(value ?? '');
            return regular == null || regular! < 2 || regular! > 100000000
                ? 'Enter a price from ₹0.02 to ₹10,00,000.'
                : null;
          },
        ),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Discounted group price (₹)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            discounted = _minorUnits(value ?? '');
            return discounted == null ||
                    discounted! < 1 ||
                    regular == null ||
                    discounted! >= regular!
                ? 'Enter a positive price below your regular price.'
                : null;
          },
        ),
        _field(
          'What’s included and when?',
          (value) => note = value,
          min: 3,
          max: 500,
        ),
      ],
    );
    if (!confirmed || !mounted) return;
    await _send(
      '$_path/$id/quotes',
      body: {'regularMinor': regular, 'groupMinor': discounted, 'note': note},
    );
    if (mounted) await _refresh();
  });

  Future<bool> _formDialog(
    String title,
    String action,
    GlobalKey<FormState> form,
    List<Widget> fields,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          scrollable: true,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final field in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: field,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!form.currentState!.validate()) return;
                form.currentState!.save();
                Navigator.pop(dialogContext, true);
              },
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Widget _field(
    String label,
    ValueChanged<String> save, {
    required int min,
    required int max,
    String? hint,
  }) => TextFormField(
    decoration: InputDecoration(
      labelText: label,
      // A floating label sits in the field's placeholder slot until it is
      // focused, so every field looked label-less and the longer ones were
      // ellipsized ("What does each house..."). Pinned above the field the
      // label is always visible and never truncated.
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperText: hint,
      // 4 lines cut the privacy reminder mid-word ("...addresses and pho...").
      helperMaxLines: 8,
    ),
    maxLength: max,
    maxLines: max > 120 ? 3 : 1,
    validator: (value) => (value ?? '').trim().length < min
        ? 'Enter at least $min characters.'
        : null,
    onSaved: (value) => save(value!.trim()),
  );

  Future<void> _confirmChange(
    String path,
    _Row data,
    String title,
    String explanation,
    String action,
  ) => _run(() async {
    if (!await _formDialog(title, action, GlobalKey<FormState>(), [
          Text(explanation),
        ]) ||
        !mounted) {
      return;
    }
    await _send(path, body: data);
    if (mounted) await _refresh();
  });

  @override
  Widget build(BuildContext context) {
    final showingDetail = _selectedId != null;
    return PopScope(
      canPop: !showingDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && showingDetail) _open(null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.provider ? 'Group quote requests' : 'Group services',
          ),
          leading: showingDetail
              ? BackButton(onPressed: () => _open(null))
              : null,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<Object?>(
            future: _content,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Semantics(
                  liveRegion: true,
                  label: 'Loading groups',
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.pagePadding),
                    child: FixSkeletonList(count: 3),
                  ),
                );
              }
              if (snapshot.hasError) {
                return FixErrorState(
                  title: 'Group services unavailable',
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Try loading group services again.',
                  onRetry: _refresh,
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  children: [
                    if (showingDetail)
                      ..._detail(snapshot.data as _Row)
                    else
                      ..._list((snapshot.data as List).cast<_Row>()),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _list(List<_Row> groups) => [
    if (!widget.provider) ...[
      const Text(
        'Invite neighbours who need the same service and compare per-household group prices.',
      ),
      const SizedBox(height: AppSpacing.md),
      FilledButton.icon(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Create a service group'),
      ),
      OutlinedButton(
        onPressed: _busy ? null : _join,
        child: const Text('Join with an invitation'),
      ),
    ],
    if (groups.isEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: FixCard(
          child: Column(
            children: [
              Icon(
                widget.provider ? Icons.request_page_rounded : Icons.groups_2,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.provider
                    ? 'No group requests yet'
                    : 'No service groups yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.provider
                    ? 'Group quote requests from households in your trade '
                          'will appear here.'
                    : 'Invite neighbours into one shared request so a single '
                          'provider can quote for the whole street.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    for (final group in groups)
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: FixCard(
          child: widget.provider
              ? _providerRequest(group)
              : ListTile(
                  title: Text(group['service'] as String),
                  subtitle: Text(
                    '${group['area']} · ${group['memberCount']} households\n${_status(group)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _open(group['id'] as String),
                ),
        ),
      ),
  ];

  String _status(_Row group) {
    if (group['membershipStatus'] == 'pending') {
      return 'Pending approval';
    }
    final serviceStatus = group['serviceStatus']?.toString();
    return switch (serviceStatus) {
      'COMPLETED' => 'Completed',
      'IN_PROGRESS' => 'Service in progress',
      'SCHEDULED' => 'Service scheduled',
      'PROVIDER_SELECTED' => 'Provider selected',
      'COLLECTING_QUOTES' => 'Collecting quotes',
      'INVITING' => 'Inviting members',
      _ => group['selectedQuoteId'] != null
          ? 'Provider selected'
          : group['requestedAt'] != null
          ? 'Collecting quotes'
          : 'Inviting members',
    };
  }

  Widget _statusTimeline(String serviceStatus, _Row group) {
    final activeCode = switch (serviceStatus) {
      'COMPLETED' ||
      'IN_PROGRESS' ||
      'SCHEDULED' ||
      'PROVIDER_SELECTED' ||
      'COLLECTING_QUOTES' ||
      'INVITING' => serviceStatus,
      _ => group['selectedQuoteId'] != null
          ? 'PROVIDER_SELECTED'
          : group['requestedAt'] != null
          ? 'COLLECTING_QUOTES'
          : 'INVITING',
    };
    const steps = [
      ('INVITING', 'Inviting members'),
      ('COLLECTING_QUOTES', 'Collecting quotes'),
      ('PROVIDER_SELECTED', 'Provider selected'),
      ('SCHEDULED', 'Scheduled'),
      ('IN_PROGRESS', 'In progress'),
      ('COMPLETED', 'Completed'),
    ];
    final currentIdx = steps.indexWhere((s) => s.$1 == activeCode);
    return FixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service status timeline',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    i < currentIdx
                        ? Icons.check_circle_rounded
                        : i == currentIdx
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: i <= currentIdx
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    steps[i].$2,
                    style: TextStyle(
                      fontWeight: i == currentIdx
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: i <= currentIdx
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _providerRequest(_Row group) {
    final groupId = group['id'] as String;
    final quoted = group['ownQuoteId'] != null;
    final selected = group['selectedQuoteId'];
    final isSelected = quoted && selected == group['ownQuoteId'];
    final contact = group['organizerPhone'] as String?;
    final organizerName = group['organizerName'] as String? ?? 'Organizer';
    final schedule = group['preferredSchedule'] as String?;
    final serviceAddress = group['serviceAddress'] as String?;
    final ownNote = group['ownNote'] as String?;
    final ownRegularMinor = group['ownRegularMinor'];
    final serviceStatus =
        group['serviceStatus']?.toString() ??
        (selected != null ? 'PROVIDER_SELECTED' : 'COLLECTING_QUOTES');
    final members = (group['members'] as List?)?.cast<_Row>() ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                group['service'] as String,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Chip(label: Text(_status(group))),
          ],
        ),
        Text('${group['area']} · ${group['memberCount']} approved households'),
        Text('Organizer: $organizerName'),
        if (schedule != null && schedule.isNotEmpty)
          Text('Preferred schedule: $schedule'),
        const SizedBox(height: AppSpacing.sm),
        Text(group['description'] as String),
        const SizedBox(height: AppSpacing.sm),
        if (quoted) ...[
          Text(
            selected == null
                ? 'Quote sent · ${_rupees(group['ownGroupMinor'])} per household'
                : isSelected
                ? 'Your quote was selected · ${_rupees(group['ownGroupMinor'])} per household'
                : 'The group selected another quote',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (ownRegularMinor is int)
            Text('Your regular price: ${_rupees(ownRegularMinor)}'),
          if (ownNote != null && ownNote.isNotEmpty) Text('Quote note: $ownNote'),
        ] else
          FilledButton(
            onPressed: _busy ? null : () => _quote(groupId),
            child: const Text('Send a discounted quote'),
          ),
        if (isSelected) ...[
          const SizedBox(height: AppSpacing.md),
          if (serviceAddress != null && serviceAddress.isNotEmpty)
            Text('Primary service address: $serviceAddress'),
          if (contact != null && contact.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: SelectableText('Organizer phone: $contact')),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CallScreen(
                        oppositePartyName: organizerName,
                        oppositePartyRole: 'Organizer',
                        phoneNumber: contact,
                        isProvider: true,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                ),
              ],
            ),
          ],
          if (members.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Household service locations:',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            for (final m in members)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${m['displayName'] ?? 'Customer'}'
                  '${m['serviceAddress'] != null ? ' — ${m['serviceAddress']}' : ''}'
                  '${m['phone'] != null ? ' (${m['phone']})' : ''}',
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (serviceStatus == 'PROVIDER_SELECTED')
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _confirmChange(
                      '$_path/$groupId/status',
                      {'status': 'SCHEDULED'},
                      'Mark service as scheduled?',
                      'Confirm you have coordinated the visit schedule with the group organizer.',
                      'Mark scheduled',
                    ),
              child: const Text('Mark scheduled'),
            ),
          if (serviceStatus == 'PROVIDER_SELECTED' ||
              serviceStatus == 'SCHEDULED')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _confirmChange(
                        '$_path/$groupId/status',
                        {'status': 'IN_PROGRESS'},
                        'Start group service?',
                        'All approved households will see that work is now in progress.',
                        'Start service',
                      ),
                child: const Text('Start service'),
              ),
            ),
          if (serviceStatus == 'IN_PROGRESS')
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _confirmChange(
                      '$_path/$groupId/status',
                      {'status': 'COMPLETED'},
                      'Complete group service?',
                      'Marks this group service completed for all households.',
                      'Mark completed',
                    ),
              child: const Text('Mark completed'),
            ),
        ],
      ],
    );
  }

  List<Widget> _detail(_Row group) {
    final id = group['id'] as String;
    final organizer = group['organizer'] == true;
    final membershipStatus = group['membershipStatus']?.toString() ?? 'approved';
    final selected = group['selectedQuoteId'];
    final invite = group['inviteToken'] as String?;
    final contact = group['providerPhone'] as String?;
    final requested = group['requestedAt'] != null;
    final serviceAddress = group['serviceAddress'] as String?;
    final myServiceAddress = group['myServiceAddress'] as String?;
    final preferredSchedule = group['preferredSchedule'] as String?;
    final organizerName = group['organizerName'] as String? ?? 'Organizer';
    final serviceStatus = group['serviceStatus']?.toString() ?? '';
    final quotes = (group['quotes'] as List? ?? const []).cast<_Row>();
    final members = (group['members'] as List? ?? const []).cast<_Row>();
    final pendingMembers = members
        .where((m) => m['status'] == 'pending')
        .toList();
    final approvedMembers = members
        .where((m) => m['status'] == 'approved')
        .toList();
    final selectedQuote =
        quotes.where((quote) => quote['id'] == selected).firstOrNull;

    if (!organizer && membershipStatus == 'pending') {
      return [
        Text(
          group['service'] as String,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${group['area']} · ${group['memberCount']} approved households'),
        const SizedBox(height: AppSpacing.md),
        FixCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join request pending approval',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              const Text(
                'The group organizer reviews every joining request. Once accepted, you can share the group link with others and view full quotes and service progress.',
              ),
              if (myServiceAddress != null && myServiceAddress.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Your submitted service address: $myServiceAddress'),
              ],
            ],
          ),
        ),
      ];
    }

    return [
      Text(
        group['service'] as String,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text('${group['area']} · ${group['memberCount']} households'),
      Text('Organizer: $organizerName · Status: ${_status(group)}'),
      if (serviceAddress != null && serviceAddress.isNotEmpty)
        Text('Group service address: $serviceAddress'),
      if (myServiceAddress != null &&
          myServiceAddress.isNotEmpty &&
          myServiceAddress != serviceAddress)
        Text('Your service address: $myServiceAddress'),
      if (preferredSchedule != null && preferredSchedule.isNotEmpty)
        Text('Preferred schedule: $preferredSchedule'),
      const SizedBox(height: AppSpacing.md),
      Text(group['description'] as String),
      const SizedBox(height: AppSpacing.md),
      if (!requested) ...[
        if (invite != null)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final link = Uri.parse('fixnow://group-invite/$invite');
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Join my FixNow service group. Open this link on '
                            'your phone: $link\n\n'
                            'If it does not open, go to FixNow > Group '
                            'services > Join with an invitation and paste: '
                            '$invite',
                        sharePositionOrigin: box == null || !box.hasSize
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  }),
            icon: const Icon(Icons.share_outlined),
            label: const Text('Share invitation'),
          ),
        if (invite == null)
          const Text('The invitation link has expired.'),
        if (organizer)
          FilledButton(
            onPressed: _busy || (group['memberCount'] as int) < 2
                ? null
                : () => _confirmChange(
                    '$_path/$id/request',
                    const {},
                    'Request group quotes?',
                    'Joining will close so providers can quote for this group size.',
                    'Request quotes',
                  ),
            child: const Text('Request group quotes'),
          ),
        if ((group['memberCount'] as int) < 2)
          const Text('At least two approved households are needed to request quotes.'),
      ],
      if (organizer && pendingMembers.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          'Pending join requests (${pendingMembers.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final member in pendingMembers)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: FixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member['displayName'] as String? ?? 'Customer',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (member['serviceAddress'] != null)
                    Text('Address: ${member['serviceAddress']}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await _send(
                                  '$_path/$id/members/${member['customerId']}/approve',
                                  body: const {},
                                );
                                if (mounted) await _refresh();
                              }),
                        child: const Text('Accept'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await _send(
                                  '$_path/$id/members/${member['customerId']}/reject',
                                  body: const {},
                                );
                                if (mounted) await _refresh();
                              }),
                        child: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
      const SizedBox(height: AppSpacing.md),
      _statusTimeline(serviceStatus, group),
      if (approvedMembers.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          'Group members (${approvedMembers.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final member in approvedMembers)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${member['displayName'] ?? 'Customer'}${member['organizer'] == true ? ' (Organizer)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (member['serviceAddress'] != null)
                    Text('Address: ${member['serviceAddress']}'),
                ],
              ),
            ),
          ),
      ],
      if (requested) ...[
        const SizedBox(height: AppSpacing.md),
        Text('Provider quotes', style: Theme.of(context).textTheme.titleLarge),
        if (quotes.isEmpty)
          const Text(
            'Waiting for providers to send quotes. Pull down to check again.',
          ),
        if (selected != null)
          const Text(
            'Your group has chosen a provider. All approved members can track scheduling, service progress, and payments here.',
          ),
        if (contact != null) SelectableText('Selected provider phone $contact'),
        if (selectedQuote != null && widget.gatewayCheckout != null) ...[
          const SizedBox(height: AppSpacing.md),
          GroupServicePayment(
            key: ValueKey(id),
            repository: widget.gatewayCheckout!,
            groupId: id,
            amountMinor: selectedQuote['groupMinor'] as int,
          ),
        ],
        for (final quote in quotes)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: FixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote['providerName'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    quote['verified'] == true
                        ? 'Identity verified'
                        : 'Identity verification incomplete',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${_rupees(quote['groupMinor'])} per household',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Provider’s regular price ${_rupees(quote['regularMinor'])}',
                  ),
                  Text(
                    'Save ${_rupees((quote['regularMinor'] as int) - (quote['groupMinor'] as int))} per household',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(quote['note'] as String),
                  if (selected == quote['id'])
                    const Chip(label: Text('Selected quote')),
                  if (organizer && selected == null)
                    FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmChange(
                              '$_path/$id/select',
                              {'quoteId': quote['id']},
                              'Select ${quote['providerName']}?',
                              'This confirms one provider for the group at ${_rupees(quote['groupMinor'])} per household and closes quoting. Your account phone number is shared with this provider to arrange the service.',
                              'Select provider',
                            ),
                      child: const Text('Select this provider'),
                    ),
                ],
              ),
            ),
          ),
      ],
    ];
  }
}
