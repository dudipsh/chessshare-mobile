/// Engine statistics from UCI info output
class EngineStats {
  /// Current search depth
  final int depth;

  /// Selective search depth
  final int? selectiveDepth;

  /// Number of nodes searched
  final int nodes;

  /// Nodes per second
  final int nodesPerSecond;

  /// Time spent in milliseconds
  final int? timeMs;

  /// Hash table usage (0-1000)
  final int? hashFullPerMille;

  const EngineStats({
    required this.depth,
    this.selectiveDepth,
    required this.nodes,
    required this.nodesPerSecond,
    this.timeMs,
    this.hashFullPerMille,
  });

  /// Format nodes for display (e.g., "1.5M")
  String _formatNodes(int n) {
    if (n >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(1)}M';
    }
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return '$n';
  }

  /// Get compact display string
  String get displayString {
    final depthStr = 'D:$depth';
    final nodesStr = 'N:${_formatNodes(nodes)}';
    final npsStr = '${_formatNodes(nodesPerSecond)}/s';
    return '$depthStr $nodesStr $npsStr';
  }

  /// Get short display for limited space
  String get shortDisplay => 'd$depth';

  EngineStats copyWith({
    int? depth,
    int? selectiveDepth,
    int? nodes,
    int? nodesPerSecond,
    int? timeMs,
    int? hashFullPerMille,
  }) {
    return EngineStats(
      depth: depth ?? this.depth,
      selectiveDepth: selectiveDepth ?? this.selectiveDepth,
      nodes: nodes ?? this.nodes,
      nodesPerSecond: nodesPerSecond ?? this.nodesPerSecond,
      timeMs: timeMs ?? this.timeMs,
      hashFullPerMille: hashFullPerMille ?? this.hashFullPerMille,
    );
  }

  @override
  String toString() => 'EngineStats(depth: $depth, nodes: $nodes)';
}
