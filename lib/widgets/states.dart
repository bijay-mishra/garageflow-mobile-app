import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Centred spinner with a line of context, for a screen that has nothing to
/// show yet.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        if (label != null) ...[
          const SizedBox(height: 14),
          Text(label!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

/// A screen with nothing in it — and a reason why, in plain words.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.ink100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppTheme.ink400),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

/// A failed load, with the server's own sentence and a way to try again.
///
/// Shows [message] verbatim — the API writes these to be read by a person, and
/// replacing them with "An error occurred" throws away the only useful part.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.rose.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 28,
              color: AppTheme.rose,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Could not load',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(160, 46),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Shows a message at the bottom of the screen. Success is neutral-dark,
/// failure is red — the two must not look alike when someone is glancing.
void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.rose : AppTheme.ink900,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
}
