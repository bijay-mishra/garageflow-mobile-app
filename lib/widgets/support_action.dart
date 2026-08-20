import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../features/support/support_screen.dart';
import '../state/support_controller.dart';
import 'gradient_header.dart';

/// The chat icon, with a badge when the office has replied.
///
/// Shared by both apps deliberately. A mechanic asking the office and a
/// customer asking the garage are the same gesture from the same kind of
/// screen, and the server already decides who the question goes to from the
/// role on the token — so a second copy of this would differ only in the
/// bug one of them was missing.
class SupportAction extends StatelessWidget {
  const SupportAction({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupportController>();
    final unread = controller.unread;

    return HeaderAction(
      // A filled icon when something is waiting, so the difference reads at a
      // glance rather than only from the number — the same rule the bell uses.
      icon: unread > 0 ? Icons.support_agent_rounded : Icons.support_agent_outlined,
      badge: unread,
      tooltip: AppText.of(context)('support.title'),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        );

        // Opening a conversation marks it read on the server, so the badge is
        // refreshed on the way back rather than waiting up to a poll interval
        // to stop claiming there is something unread.
        controller.markSeen();
      },
    );
  }
}
