import 'package:flutter/material.dart';
import 'package:fixnow_mobile/design_system/app_colors.dart';
import 'package:fixnow_mobile/design_system/app_radius.dart';
import 'package:fixnow_mobile/design_system/app_spacing.dart';
import 'package:fixnow_mobile/features/chat/chat_controller.dart';
import 'package:fixnow_mobile/features/chat/chat_message.dart';

class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({
    super.key,
    required this.controller,
    this.providerName = 'Verified Professional',
    this.onCallPressed,
  });

  final ChatController controller;
  final String providerName;
  final VoidCallback? onCallPressed;

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _quickResponses = [
    '🚪 Buzz code is #',
    '📍 At the front gate',
    '🅿️ Park in driveway',
    '🔔 Ring the doorbell',
    '⏱️ 5 minutes away',
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
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
      _scrollToBottom();
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
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primarySoft,
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundSecondary,
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
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.focus,
                        size: 14,
                      ),
                    ],
                  ),
                  Text(
                    'Booking #$bookingShortId',
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
        actions: [
          if (widget.onCallPressed != null)
            IconButton(
              icon: const Icon(
                Icons.phone_outlined,
                color: AppColors.accentGold,
              ),
              tooltip: 'Call Pro',
              onPressed: widget.onCallPressed,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Shield Notice Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.backgroundSecondary.withValues(alpha: 0.5),
              child: Row(
                children: const [
                  Icon(
                    Icons.shield_outlined,
                    color: AppColors.focus,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Phone numbers are hidden to protect your privacy.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Read-Only Notice Bar if service is completed
            if (!controller.canSend)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                  : controller.errorMessage != null && controller.messages.isEmpty
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
                                return _ChatBubble(message: message);
                              },
                            ),
            ),

            // 1-Tap Quick Responses
            if (controller.canSend)
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: _quickResponses.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final chipText = _quickResponses[index];
                    return ActionChip(
                      backgroundColor: AppColors.backgroundSecondary,
                      side: const BorderSide(color: AppColors.borderStrong),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      label: Text(
                        chipText,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                      onPressed: () {
                        if (chipText.endsWith('#')) {
                          _textController.text = chipText;
                          _textController.selection = TextSelection.fromPosition(
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

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.backgroundSecondary,
                border: Border(
                  top: BorderSide(color: Color(0xFF1E293B)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderStrong),
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
                              ? 'Message your professional...'
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: isMe
              ? null
              : Border.all(color: const Color(0xFF263353), width: 1),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.messageText,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt.toLocal()),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.readAt != null
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 13,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
