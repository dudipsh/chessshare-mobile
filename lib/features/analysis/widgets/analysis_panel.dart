import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/principal_variation.dart';
import '../providers/engine_provider.dart';

/// Panel showing engine analysis with PV lines
class AnalysisPanel extends ConsumerWidget {
  /// Maximum number of PV lines to show
  final int maxLines;

  /// Callback when a PV line is tapped
  final void Function(PrincipalVariation pv)? onPvTap;

  const AnalysisPanel({
    super.key,
    this.maxLines = 3,
    this.onPvTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engineState = ref.watch(engineAnalysisProvider);
    final isReady = engineState.isReady;
    final isAnalyzing = engineState.isAnalyzing;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with controls
          _AnalysisPanelHeader(
            isReady: isReady,
            isAnalyzing: isAnalyzing,
          ),

          const Divider(height: 1),

          // PV lines
          _PvLinesList(
            pvLines: engineState.pvLines,
            maxLines: maxLines,
            onPvTap: onPvTap,
          ),

          // Stats footer
          if (engineState.stats != null)
            _StatsFooter(stats: engineState.stats!),
        ],
      ),
    );
  }
}

class _AnalysisPanelHeader extends ConsumerWidget {
  final bool isReady;
  final bool isAnalyzing;

  const _AnalysisPanelHeader({
    required this.isReady,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Engine icon
          Icon(
            Icons.psychology,
            size: 20,
            color: isAnalyzing
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              'Stockfish',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Status indicator
          _StatusIndicator(
            isReady: isReady,
            isAnalyzing: isAnalyzing,
          ),

          const SizedBox(width: 8),

          // Toggle button
          _AnalysisToggleButton(
            isReady: isReady,
            isAnalyzing: isAnalyzing,
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool isReady;
  final bool isAnalyzing;

  const _StatusIndicator({
    required this.isReady,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    if (!isReady) {
      color = Colors.grey;
      text = 'Loading';
    } else if (isAnalyzing) {
      color = Colors.green;
      text = 'Analyzing';
    } else {
      color = Colors.orange;
      text = 'Ready';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
              ),
        ),
      ],
    );
  }
}

class _AnalysisToggleButton extends ConsumerWidget {
  final bool isReady;
  final bool isAnalyzing;

  const _AnalysisToggleButton({
    required this.isReady,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: Icon(
        isAnalyzing ? Icons.pause : Icons.play_arrow,
        size: 20,
      ),
      onPressed: isReady
          ? () {
              final notifier = ref.read(engineAnalysisProvider.notifier);
              if (isAnalyzing) {
                notifier.stopAnalysis();
              } else {
                // Resume analysis with current position
                final currentFen =
                    ref.read(engineAnalysisProvider).currentFen;
                if (currentFen != null) {
                  notifier.analyzePosition(currentFen);
                }
              }
            }
          : null,
      tooltip: isAnalyzing ? 'Pause' : 'Analyze',
      visualDensity: VisualDensity.compact,
    );
  }
}

class _PvLinesList extends StatelessWidget {
  final List<PrincipalVariation> pvLines;
  final int maxLines;
  final void Function(PrincipalVariation pv)? onPvTap;

  const _PvLinesList({
    required this.pvLines,
    required this.maxLines,
    this.onPvTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pvLines.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No analysis yet',
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final linesToShow = pvLines.take(maxLines).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < linesToShow.length; i++) ...[
          if (i > 0) const Divider(height: 1, indent: 12, endIndent: 12),
          PvLineItem(
            pv: linesToShow[i],
            isMainLine: i == 0,
            onTap: onPvTap != null ? () => onPvTap!(linesToShow[i]) : null,
          ),
        ],
      ],
    );
  }
}

/// Single PV line display
class PvLineItem extends StatelessWidget {
  final PrincipalVariation pv;
  final bool isMainLine;
  final VoidCallback? onTap;

  const PvLineItem({
    super.key,
    required this.pv,
    this.isMainLine = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Evaluation score
            SizedBox(
              width: 56,
              child: Text(
                pv.evaluation.displayString,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getEvaluationColor(pv.evaluation, theme),
                ),
              ),
            ),

            // Depth indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'd${pv.depth}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Move line
            Expanded(
              child: Text(
                pv.displayLine(8),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: isMainLine
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getEvaluationColor(evaluation, ThemeData theme) {
    if (evaluation.isMate) {
      return evaluation.mateInMoves! > 0 ? Colors.green : Colors.red;
    }

    final cp = evaluation.centipawns ?? 0;
    if (cp > 100) return Colors.green;
    if (cp < -100) return Colors.red;
    return theme.colorScheme.onSurface;
  }
}

class _StatsFooter extends StatelessWidget {
  final dynamic stats;

  const _StatsFooter({required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(7),
          bottomRight: Radius.circular(7),
        ),
      ),
      child: Text(
        stats.displayString,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

/// Compact analysis display for limited space
class CompactAnalysisDisplay extends ConsumerWidget {
  const CompactAnalysisDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evaluation = ref.watch(engineEvaluationProvider);
    final bestLine = ref.watch(enginePvLinesProvider).isNotEmpty
        ? ref.watch(enginePvLinesProvider).first
        : null;
    final isAnalyzing = ref.watch(engineIsAnalyzingProvider);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Analysis indicator
          if (isAnalyzing)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

          // Evaluation
          Text(
            evaluation?.displayString ?? '-',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          if (bestLine != null) ...[
            const SizedBox(width: 8),
            // Best move
            Text(
              bestLine.displayLine(3),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
