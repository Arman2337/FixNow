import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_motion.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/call/booking_call_screen.dart';
import 'package:fixnow_mobile/features/call/call_controller.dart';
import 'package:fixnow_mobile/features/call/call_repository.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';

class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({
    super.key,
    required this.controller,
    this.providerName = 'Verified Professional',
    this.callRepository,
    this.onCallPressed,
  });

  final ChatController controller;
  final String providerName;
  final CallRepository? callRepository;
  final VoidCallback? onCallPressed;

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _primed = false;
  int _watermark = 0;

  /// First index that should play the entrance animation; -1 = none.
  int _animateFrom = -1;

  List<String> get _quickResponses => widget.controller.isProvider
      ? const [
          '🛵 On my way now',
          '⏱️ 5 minutes away',
          '🚦 Stuck in traffic (+10m)',
          '📍 Arrived outside building',
          '🅿️ Where can I park?',
          '🚪 Ringing the doorbell now',
          '📞 Calling you now',
        ]
      : const [
          '🚪 Buzz code is #',
          '📍 At the front gate',
          '🅿️ Park in driveway',
          '🔔 Please ring the doorbell',
          '⏱️ Ready when you arrive',
          '📞 Call me from the gate',
        ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
    widget.controller.startPolling();
  }

  @override
  void dispose() {
    widget.controller.stopPolling();
    widget.controller.removeListener(_onControllerUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    // Track which messages are NEW so only they animate in. History renders
    // instantly; the optimistic-send replace (same count, new id) keeps the
    // window open so the in-flight entrance isn't torn down by the second
    // notifyListeners.
    final count = widget.controller.messages.length;
    if (!_primed) {
      _primed = true;
      _watermark = count;
    } else if (count > _watermark) {
      _animateFrom = _watermark;
      _watermark = count;
    } else if (count < _watermark) {
      _watermark = count;
      if (_animateFrom > count) _animateFrom = count;
    }
    setState(() {});
    _scrollToBottom(force: false);
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final pos = _scrollController.position;
        final nearBottom = (pos.maxScrollExtent - pos.pixels) < 200;
        if (force || nearBottom) {
          _scrollController.animateTo(
            pos.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = overrideText ?? _textController.text;
    if (text.trim().isEmpty) return;

    if (overrideText == null) {
      _textController.clear();
    }

    final ok = await widget.controller.send(text);
    if (ok) {
      _scrollToBottom(force: true);
    } else if (mounted && widget.controller.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.errorMessage!),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bookingShortId = controller.bookingId.length > 8
        ? controller.bookingId.substring(0, 8).toUpperCase()
        : controller.bookingId.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.surfaceContainerLowest,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.providerName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                    ],
                  ),
                  Text(
                    'Booking #$bookingShortId',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onCallPressed != null || widget.callRepository != null)
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              tooltip: 'Call Pro',
              onPressed: () {
                if (widget.onCallPressed != null) {
                  widget.onCallPressed!();
                } else if (widget.callRepository != null) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookingCallScreen(
                        controller: CallController(
                          bookingId: widget.controller.bookingId,
                          repository: widget.callRepository!,
                          realtimeClient: widget.controller.realtimeClient,
                          initialSpeakerOn: true,
                        ),
                        providerName: widget.providerName,
                      ),
                    ),
                  );
                }
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Shield Notice Bar (Stitch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.surfaceContainerLow,
              child: Row(
                children: const [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phone numbers are hidden to protect your privacy.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Read-Only Notice Bar if service is completed
            if (!controller.canSend)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                color: AppColors.accentGoldSoft,
                child: Row(
                  children: const [
                    Icon(
                      Icons.lock_clock_outlined,
                      color: AppColors.onAccentGold,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Service completed — chat history is now read-only.',
                        style: TextStyle(
                          color: AppColors.onAccentGold,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Message History Area
            Expanded(
              child: controller.isLoading && controller.messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : controller.errorMessage != null &&
                        controller.messages.isEmpty
                  ? Center(
                      child: InkWell(
                        onTap: controller.load,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.refresh_rounded,
                                color: AppColors.textSecondary,
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                controller.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : controller.messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: AppColors.textDisabled,
                            size: 44,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Coordinate arrival, buzz codes, or gate instructions.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: controller.messages.length,
                      itemBuilder: (context, index) {
                        final message = controller.messages[index];
                        final bubble = _ChatBubble(message: message);
                        final isNew =
                            _animateFrom >= 0 && index >= _animateFrom;
                        return isNew
                            ? _BubbleEntrance(isMe: message.isMe, child: bubble)
                            : bubble;
                      },
                    ),
            ),

            // 1-Tap Quick Responses (Stitch Pills)
            if (controller.canSend)
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  itemCount: _quickResponses.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final chipText = _quickResponses[index];
                    return ActionChip(
                      backgroundColor: AppColors.surfaceContainerLowest,
                      side: const BorderSide(color: AppColors.borderDefault),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      label: Text(
                        chipText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        if (chipText.endsWith('#')) {
                          _textController.text = chipText;
                          _textController.selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: chipText.length),
                              );
                        } else {
                          _sendMessage(chipText);
                        }
                      },
                    );
                  },
                ),
              ),

            // Input Bar (Stitch Dock)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                border: Border(top: BorderSide(color: AppColors.borderDefault)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderDefault),
                      ),
                      child: TextField(
                        controller: _textController,
                        enabled: controller.canSend,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: controller.canSend
                              ? (widget.controller.isProvider
                                    ? 'Message customer...'
                                    : 'Message your professional...')
                              : 'Chat is read-only',
                          hintStyle: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: controller.canSend
                          ? AppColors.primary
                          : AppColors.textDisabled,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: controller.isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                      onPressed: controller.canSend && !controller.isSending
                          ? () => _sendMessage()
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    if (message.messageText.startsWith('📞')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: const Color(0xFF263353), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.messageText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(message.createdAt.toLocal()),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  message.senderRole.isNotEmpty
                      ? message.senderRole[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.primary
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: isMe
                          ? null
                          : Border.all(
                              color: AppColors.outline.withValues(alpha: 0.08),
                              width: 1,
                            ),
                    ),
                    child: Text(
                      message.messageText,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isMe ? 0 : 4,
                      right: isMe ? 4 : 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt.toLocal()),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (!isMe && message.senderRole.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              message.senderRole,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _DeliveryTick(message: message),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slides a just-arrived bubble up and in from its sender's side. History
/// messages never pass through here — only indices above the watermark.
class _BubbleEntrance extends StatelessWidget {
  const _BubbleEntrance({required this.isMe, required this.child});

  final bool isMe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.container,
      curve: AppMotion.enterCurve,
      builder: (context, t, child) {
        final dx = isMe ? 0.16 : -0.16;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx * 60 * (1 - t), 18 * (1 - t)),
            child: Transform.scale(
              scale: 0.94 + 0.06 * t,
              alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// ✓ sent → ✓✓ delivered → gold ✓✓ read, morphing between states instead of
/// snapping. Plain icon under reduce motion (AnimatedSwitcher ignores it).
class _DeliveryTick extends StatelessWidget {
  const _DeliveryTick({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final read = message.readAt != null;
    final delivered = message.id.isNotEmpty;
    final stateKey = read ? 'read' : (delivered ? 'delivered' : 'sent');
    final icon = read || delivered
        ? Icons.done_all_rounded
        : Icons.done_rounded;
    final color = read
        ? AppColors.accentGold
        : Colors.white.withValues(alpha: 0.85);

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Icon(icon, color: color, size: 13);
    }
    return AnimatedSwitcher(
      duration: AppMotion.standard,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.celebrateCurve),
        ),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: Icon(icon, key: ValueKey(stateKey), color: color, size: 13),
    );
  }
}
