import 'package:flutter/material.dart';

import 'api.dart';
import 'theme.dart';

/// Rounded card, PRD 6.1 style.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// Section heading used across screens.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Shown only when the backend reports is_demo=true. Never shown for
/// real runs, and never used to disguise real runs as demos.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.18),
        border: Border.all(color: AppColors.accentBlue),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'DEMO — Sample data for exploration only. This is not a real '
        'simulation and does not represent real customers.',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Generic error state with a retry action. Used whenever the backend
/// or engine is unavailable — the app never substitutes invented data.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reaction badge for a simulation event. Classification comes from the
/// backend only; unknown values render as a neutral chip, never as a
/// guessed sentiment.
class ReactionBadge extends StatelessWidget {
  final String? classification;
  const ReactionBadge({super.key, this.classification});

  @override
  Widget build(BuildContext context) {
    final value = (classification ?? '').toLowerCase();
    final (label, color) = switch (value) {
      'positive' => ('Positive', AppColors.positive),
      'negative' => ('Negative', AppColors.negativeRed),
      'question' => ('Question', AppColors.accentBlue),
      'suggestion' => ('Suggestion', AppColors.accentBlue),
      'objection' => ('Objection', AppColors.negativeRed),
      'neutral' => ('Neutral', AppColors.textSecondary),
      _ => ('Unclassified', AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

/// One feed row. Renders only backend-supplied fields.
class EventCard extends StatelessWidget {
  final SimEvent event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final initial = event.agentName.isNotEmpty
        ? event.agentName[0].toUpperCase()
        : '?';
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.accentPink,
            foregroundColor: Colors.white,
            child: Text(initial,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(event.agentName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                    ReactionBadge(classification: event.classification),
                  ],
                ),
                if (event.persona != null) ...[
                  const SizedBox(height: 2),
                  Text(event.persona!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 6),
                Text(event.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
