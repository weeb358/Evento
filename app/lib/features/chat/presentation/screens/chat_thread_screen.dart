import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/chat_models.dart';
import '../controllers/chat_providers.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final RealtimeChannel _typingChannel;
  Timer? _typingDebounce;
  final Set<String> _typingUserIds = {};

  @override
  void initState() {
    super.initState();

    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      ref.read(chatRepositoryProvider).markRead(threadId: widget.threadId, userId: userId);
    }

    _typingChannel = ref.read(chatRepositoryProvider).typingChannel(widget.threadId);
    _typingChannel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final typingUserId = payload['user_id'] as String?;
        final isTyping = payload['is_typing'] as bool? ?? false;
        if (typingUserId == null || typingUserId == userId) return;
        setState(() {
          if (isTyping) {
            _typingUserIds.add(typingUserId);
          } else {
            _typingUserIds.remove(typingUserId);
          }
        });
      },
    );
    _typingChannel.subscribe();
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _typingChannel.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    ref.read(chatRepositoryProvider).broadcastTyping(
          channel: _typingChannel,
          userId: userId,
          isTyping: value.isNotEmpty,
        );

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      ref.read(chatRepositoryProvider).broadcastTyping(
            channel: _typingChannel,
            userId: userId,
            isTyping: false,
          );
    });
  }

  Future<void> _sendText() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    _messageController.clear();
    await ref
        .read(chatRepositoryProvider)
        .sendMessage(threadId: widget.threadId, senderId: userId, content: content);
  }

  Future<void> _sendImage() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final uploadResult = await ref.read(chatRepositoryProvider).uploadImage(
          threadId: widget.threadId,
          bytes: bytes,
          fileExt: picked.name.split('.').last,
        );
    final imageUrl = uploadResult.when(ok: (url) => url, err: (_) => null);
    if (imageUrl == null) return;

    await ref.read(chatRepositoryProvider).sendMessage(
          threadId: widget.threadId,
          senderId: userId,
          imageUrl: imageUrl,
        );
  }

  Future<void> _sendLocation() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    await ref.read(chatRepositoryProvider).sendMessage(
          threadId: widget.threadId,
          senderId: userId,
          locationLat: position.latitude,
          locationLng: position.longitude,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(currentUserIdProvider);
    final messagesAsync = ref.watch(threadMessagesProvider(widget.threadId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Could not load messages')),
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUserId;
                    return _MessageBubble(message: message, isMine: isMine);
                  },
                );
              },
            ),
          ),
          if (_typingUserIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Typing...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.image_outlined), onPressed: _sendImage),
                  IconButton(icon: const Icon(Icons.location_on_outlined), onPressed: _sendLocation),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send_rounded), onPressed: _sendText),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
        decoration: BoxDecoration(
          color: isMine ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              )
            else if (message.hasLocation)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on_rounded, size: 16, color: isMine ? Colors.white : null),
                  const SizedBox(width: 4),
                  Text(
                    'Shared location',
                    style: TextStyle(color: isMine ? Colors.white : theme.colorScheme.onSurface),
                  ),
                ],
              )
            else if (message.content != null)
              Text(
                message.content!,
                style: TextStyle(color: isMine ? Colors.white : theme.colorScheme.onSurface),
              ),
            const SizedBox(height: 2),
            Text(
              DateFormat('h:mm a').format(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: isMine ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
