import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../providers/app_provider.dart';
import '../services/supabase_service.dart';

class ArtistChatPage extends StatefulWidget {
  final String artistName;
  const ArtistChatPage({super.key, required this.artistName});

  @override
  State<ArtistChatPage> createState() => _ArtistChatPageState();
}

class _ArtistChatPageState extends State<ArtistChatPage> {
  final _supabase = SupabaseService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _refreshTimer;
  String? _editingId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _supabase.getArtistChats(widget.artistName);
      if (mounted) {
        setState(() {
          _messages = msgs.reversed.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    final provider = context.read<AppProvider>();
    final profile = provider.profile;
    final nickname = profile?.nickname ?? 'Fan';
    final nationality = profile?.nationality ?? '';
    final fandom = profile?.representativeFandom ?? '';

    setState(() => _isSending = true);
    try {
      if (_editingId != null) {
        await _supabase.updateArtistChat(chatId: _editingId!, newMessage: text);
        setState(() => _editingId = null);
      } else {
        await _supabase.sendArtistChat(
          artistName: widget.artistName,
          nickname: nickname,
          message: text,
          nationality: nationality,
          fandom: fandom,
        );
      }
      _controller.clear();
      await _loadMessages();
      if (_editingId == null) _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KokColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startEdit(Map<String, dynamic> msg) {
    setState(() {
      _editingId = msg['id'] as String;
      _controller.text = msg['message'] as String? ?? '';
    });
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _controller.clear();
    });
  }

  Future<void> _deleteMessage(String chatId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: KokColors.surface,
        title: const Text('Delete message', style: TextStyle(color: KokColors.textPrimary, fontSize: 16)),
        content: const Text('Are you sure?', style: TextStyle(color: KokColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: KokColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: KokColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.deleteArtistChat(chatId);
      await _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KokColors.error),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KokColors.background,
      appBar: AppBar(
        backgroundColor: KokColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: KokColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(widget.artistName,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: KokColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: KokColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('LIVE',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, fontWeight: FontWeight.w800,
                      color: KokColors.primary, letterSpacing: 1)),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(Icons.people_outline_rounded, size: 14, color: KokColors.textMuted.withAlpha(120)),
                const SizedBox(width: 4),
                Text('${_messages.length}',
                    style: TextStyle(fontSize: 11, color: KokColors.textMuted.withAlpha(120))),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildNotice(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: KokColors.primary))
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : _buildChatList(),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: KokColors.accent.withAlpha(10),
      child: Row(
        children: [
          Icon(Icons.auto_delete_outlined, size: 14, color: KokColors.textMuted.withAlpha(150)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Messages auto-expire after 24h. Max 300 per board.',
              style: TextStyle(fontSize: 11, color: KokColors.textMuted.withAlpha(150)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: KokColors.textMuted.withAlpha(60)),
          const SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(fontSize: 15, color: KokColors.textMuted.withAlpha(120))),
          const SizedBox(height: 4),
          Text('Start the conversation about ${widget.artistName}!',
              style: TextStyle(fontSize: 12, color: KokColors.textMuted.withAlpha(80))),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildMessage(_messages[i]),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final nickname = msg['nickname'] as String? ?? 'Fan';
    final message = msg['message'] as String? ?? '';
    final nationality = msg['nationality'] as String? ?? '';
    final fandom = msg['fandom'] as String? ?? '';
    final createdAt = DateTime.tryParse(msg['created_at'] ?? '') ?? DateTime.now();
    final timeAgo = _formatTimeAgo(createdAt);
    final isMe = msg['user_id'] == _supabase.currentUserId;
    final chatId = msg['id'] as String? ?? '';
    final isEditing = _editingId == chatId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isMe ? KokColors.primary.withAlpha(30) : KokColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                nickname.isNotEmpty ? nickname[0].toUpperCase() : 'F',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: isMe ? KokColors.primary : KokColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nickname,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isMe ? KokColors.primary : KokColors.textSecondary)),
                    if (nationality.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: KokColors.accent.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(UserProfile.shortCode(nationality),
                            style: const TextStyle(fontSize: 9, color: KokColors.accentLight, fontWeight: FontWeight.w600)),
                      ),
                    ],
                    if (fandom.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: KokColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(fandom,
                            style: const TextStyle(fontSize: 9, color: KokColors.primary, fontWeight: FontWeight.w500)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(timeAgo,
                        style: TextStyle(fontSize: 10, color: KokColors.textMuted.withAlpha(100))),
                    if (isMe) ...[
                      const Spacer(),
                      _buildMessageActions(msg, isEditing),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEditing
                        ? KokColors.accent.withAlpha(12)
                        : isMe
                            ? KokColors.primary.withAlpha(12)
                            : KokColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: isEditing
                        ? Border.all(color: KokColors.accent.withAlpha(40), width: 1)
                        : null,
                  ),
                  child: Text(message,
                      style: const TextStyle(fontSize: 14, color: KokColors.textPrimary, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageActions(Map<String, dynamic> msg, bool isEditing) {
    final chatId = msg['id'] as String? ?? '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: isEditing ? _cancelEdit : () => _startEdit(msg),
          child: Icon(
            isEditing ? Icons.close_rounded : Icons.edit_outlined,
            size: 14,
            color: isEditing ? KokColors.error : KokColors.textMuted.withAlpha(120),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _deleteMessage(chatId),
          child: Icon(Icons.delete_outline_rounded, size: 14,
              color: KokColors.textMuted.withAlpha(120)),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    final isEditing = _editingId != null;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: KokColors.surface,
        border: Border(
          top: BorderSide(
            color: isEditing ? KokColors.accent.withAlpha(60) : KokColors.border,
            width: isEditing ? 1.5 : 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, size: 12, color: KokColors.accent.withAlpha(180)),
                  const SizedBox(width: 6),
                  Text('Editing message',
                      style: TextStyle(fontSize: 11, color: KokColors.accent.withAlpha(180), fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelEdit,
                    child: Text('Cancel',
                        style: TextStyle(fontSize: 11, color: KokColors.textMuted.withAlpha(120))),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(fontSize: 14, color: KokColors.textPrimary),
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: isEditing ? 'Edit your message...' : 'Say something...',
                    hintStyle: TextStyle(color: KokColors.textMuted.withAlpha(100), fontSize: 14),
                    filled: true,
                    fillColor: KokColors.surfaceLight,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: KokColors.primary))
                    : Icon(
                        isEditing ? Icons.check_rounded : Icons.send_rounded,
                        color: isEditing ? KokColors.accent : KokColors.primary,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
