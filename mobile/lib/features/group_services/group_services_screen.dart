import 'dart:math';

import 'package:fixnow_mobile/api/api_client.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/design_system/fix_card.dart';
import 'package:fixnow_mobile/design_system/fix_state_views.dart';
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
  ({String? categoryId, String area, String description})? _lastCreation;
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
    setState(() => _content = _fetch());
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

  Future<void> _create() => _run(() async {
    final categories = (await _send('$_path/categories') as List).cast<_Row>();
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No group services are available yet.')),
      );
      return;
    }
    String? categoryId;
    var area = '';
    var description = '';
    final form = GlobalKey<FormState>();
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
        _field(
          'Neighbourhood or PIN code',
          (value) => area = value,
          min: 2,
          max: 120,
        ),
        _field(
          'What does each household need?',
          (value) => description = value,
          min: 3,
          max: 1000,
          hint:
              'For example, one split AC cleaning per household. Keep addresses and phone numbers private.',
        ),
      ],
    );
    if (!confirmed || !mounted) return;
    final input = (
      categoryId: categoryId,
      area: area,
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
                'description': description,
              },
            )
            as _Row;
    _lastCreation = null;
    _creationKey = null;
    _open(result['id'] as String);
  });

  Future<void> _join([String? invitation]) => _run(() async {
    var token = invitation;
    final form = GlobalKey<FormState>();
    final confirmed = await _formDialog(
      'Join a service group',
      'Join group',
      form,
      [
        const Text(
          'Joining adds your household to this request. The organizer chooses the provider.',
        ),
        if (invitation == null)
          TextFormField(
            decoration: const InputDecoration(labelText: 'Invitation link'),
            autocorrect: false,
            validator: (value) {
              token = groupInviteToken(value ?? '');
              return token == null ? 'Enter a FixNow group invitation.' : null;
            },
          ),
      ],
    );
    if (!confirmed || !mounted) return;
    final result = await _send('$_path/join', body: {'token': token}) as _Row;
    _open(result['id'] as String);
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

  String _status(_Row group) => group['selectedQuoteId'] != null
      ? 'Provider selected'
      : group['requestedAt'] != null
      ? 'Collecting quotes'
      : 'Inviting members';

  Widget _providerRequest(_Row group) {
    final quoted = group['ownQuoteId'] != null;
    final selected = group['selectedQuoteId'];
    final contact = group['organizerPhone'] as String?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group['service'] as String,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text('${group['area']} · ${group['memberCount']} households'),
        const SizedBox(height: AppSpacing.sm),
        Text(group['description'] as String),
        const SizedBox(height: AppSpacing.sm),
        if (quoted)
          Text(
            selected == null
                ? 'Quote sent · ${_rupees(group['ownGroupMinor'])} per household'
                : selected == group['ownQuoteId']
                ? 'Your quote was selected'
                : 'The group selected another quote',
          )
        else
          FilledButton(
            onPressed: _busy ? null : () => _quote(group['id'] as String),
            child: const Text('Send a discounted quote'),
          ),
        if (contact != null) SelectableText('Organizer phone $contact'),
      ],
    );
  }

  List<Widget> _detail(_Row group) {
    final id = group['id'] as String;
    final organizer = group['organizer'] == true;
    final selected = group['selectedQuoteId'];
    final invite = group['inviteToken'] as String?;
    final contact = group['providerPhone'] as String?;
    final requested = group['requestedAt'] != null;
    final quotes = (group['quotes'] as List).cast<_Row>();
    final selectedQuote = quotes.where((quote) => quote['id'] == selected).firstOrNull;
    return [
      Text(
        group['service'] as String,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text('${group['area']} · ${group['memberCount']} households'),
      Text(_status(group)),
      const SizedBox(height: AppSpacing.md),
      Text(group['description'] as String),
      const SizedBox(height: AppSpacing.md),
      if (!requested) ...[
        if (invite != null)
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    // No raw API host, and no token printed as a bare URL.
                    // The app already understands
                    // `fixnow://group-invite/<token>`, and `groupInviteToken`
                    // also accepts a pasted code, so this shares a deep link
                    // first and a code second without exposing the
                    // deployment's internal address.
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
        if (organizer && invite == null)
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
          const Text('At least two households are needed to request quotes.'),
      ] else ...[
        Text('Provider quotes', style: Theme.of(context).textTheme.titleLarge),
        if (quotes.isEmpty)
          const Text(
            'Waiting for providers to send quotes. Pull down to check again.',
          ),
        if (selected != null)
          const Text(
            'Your group has chosen a provider. The organizer coordinates scheduling with the provider.',
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
