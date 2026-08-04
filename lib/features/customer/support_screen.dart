import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../models/support.dart';
import '../../services/support_service.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/states.dart';

/// Chat with the garage.
///
/// One screen, two states: a list of past conversations, and a conversation.
/// It opens straight into a conversation — either the most recent one or a new
/// one — because somebody who taps "Help" has a question now, and making them
/// pick from a list first is a step between them and asking it.
///
/// An assistant answers first. Which questions it can take is the server's
/// decision, not this screen's: it answers what it knows and hands the rest to
/// a person, so there is no mode here to keep in sync with the backend.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  SupportConversation? _conversation;
  List<SupportThread> _threads = const [];

  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// True while the list of past conversations is showing instead of a chat.
  bool _browsing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<SupportService>();
      final threads = await service.threads();

      // Straight into the newest conversation. A first-time user has none, and
      // gets an empty chat with the assistant's opening line instead.
      final conversation = threads.isEmpty
          ? null
          : await service.conversation(threads.first.id);

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _conversation = conversation;
        _loading = false;
      });

      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(int id) async {
    setState(() {
      _browsing = false;
      _loading = true;
    });

    try {
      final conversation = await context.read<SupportService>().conversation(id);

      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _loading = false;
      });

      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _input.clear();
    });

    _scrollToEnd();

    try {
      final service = context.read<SupportService>();

      final conversation = _conversation == null
          ? await service.start(text)
          : await service.send(_conversation!.thread.id, text);

      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _sending = false;
      });

      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);

      // The message is gone from the box by now, so it goes back in — losing
      // what somebody typed because the network blinked is the rudest possible
      // failure here.
      _input.text = text;
      showSnack(context, error.message, isError: true);
    }
  }

  Future<void> _escalate() async {
    final conversation = _conversation;
    if (conversation == null) return;

    try {
      final updated = await context.read<SupportService>().escalate(
        conversation.thread.id,
      );

      if (!mounted) return;
      setState(() => _conversation = updated);
      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      showSnack(context, error.message, isError: true);
    }
  }

  void _scrollToEnd() {
    // After the frame, so the list has the new message in it before we measure.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: t('support.title'),
            subtitle: _browsing
                ? t('support.past')
                : _conversation?.botActive == false
                ? t('support.withGarage')
                : t('support.subtitle'),
            onBack: () {
              if (_browsing) {
                setState(() => _browsing = false);
                return;
              }
              Navigator.pop(context);
            },
            actions: [
              if (_threads.isNotEmpty)
                HeaderAction(
                  icon: _browsing
                      ? Icons.chat_bubble_outline_rounded
                      : Icons.history_rounded,
                  tooltip: t('support.past'),
                  onPressed: () => setState(() => _browsing = !_browsing),
                ),
              HeaderAction(
                icon: Icons.add_comment_outlined,
                tooltip: t('support.newChat'),
                onPressed: () => setState(() {
                  _conversation = null;
                  _browsing = false;
                }),
              ),
            ],
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    final t = AppText.of(context);

    if (_loading) return LoadingView(label: t('support.loading'));

    if (_error != null && _conversation == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    if (_browsing) return _threadList();

    return Column(
      children: [
        Expanded(child: _messages()),
        _composer(),
      ],
    );
  }

  Widget _threadList() {
    final palette = AppTheme.of(context);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final thread = _threads[index];

        return InkWell(
          onTap: () => _open(thread.id),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread.subject,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ),
                    if (thread.waitingOnGarage)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          AppText.of(context)('support.waiting'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.amber,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  thread.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: palette.faint),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _messages() {
    final t = AppText.of(context);
    final messages = _conversation?.messages ?? const <SupportMessage>[];

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        // The opening line on a brand-new chat. Not a stored message — it is
        // the screen introducing itself, and storing it would put a bot
        // greeting at the top of every thread in the garage's inbox.
        if (messages.isEmpty) _Intro(),

        for (final message in messages) _Bubble(message: message),

        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 9),
                Text(
                  t('support.thinking'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.of(context).faint,
                  ),
                ),
              ],
            ),
          ),

        // Only while the assistant still owns the thread. Once a person is on
        // it, an "ask a human" button would ask for somebody who is already
        // there.
        if (_conversation != null && _conversation!.botActive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: TextButton.icon(
                onPressed: _escalate,
                icon: const Icon(Icons.support_agent_rounded, size: 17),
                label: Text(t('support.talkToGarage')),
              ),
            ),
          ),

        if (_conversation != null && !_conversation!.botActive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Text(
                t('support.garageHasIt'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.of(context).faint,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer() {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: t('support.placeholder'),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 46,
            width: 46,
            child: FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: const Icon(Icons.send_rounded, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the screen says before anybody has typed anything.
class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.brandLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              size: 26,
              color: AppTheme.brand,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            t('support.introTitle'),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              t('support.introBody'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: palette.faint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    final mine = message.fromMe;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    message.fromBot
                        ? Icons.auto_awesome_rounded
                        : Icons.person_rounded,
                    size: 12,
                    color: palette.faint,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.faint,
                    ),
                  ),
                  // A generated answer says so. A scripted one does not need
                  // to — it was written by a person and is reliable.
                  if (message.isGenerated) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.field,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppText.of(context)('support.aiAnswer'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: palette.faint,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine
                  ? AppTheme.brand
                  : message.fromBot
                  ? palette.field
                  : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: mine ? null : Border.all(color: palette.border),
            ),
            child: Text(
              message.body,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: mine ? Colors.white : palette.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
