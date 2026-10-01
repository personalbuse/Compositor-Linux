class LayerMask {
  final String? maskSourceID;
  final String? maskFile;
  final bool maskEnabled;
  final Map<String, dynamic> unknown;

  LayerMask({
    this.maskSourceID,
    this.maskFile,
    this.maskEnabled = true,
    Map<String, dynamic>? unknown,
  }) : unknown = unknown ?? {};

  factory LayerMask.fromJson(Map<String, dynamic> json) {
    final unknown = <String, dynamic>{};
    json.forEach((k, v) {
      if (!_knownKeys.contains(k)) unknown[k] = v;
    });

    return LayerMask(
      maskSourceID: json['maskSourceID'] as String?,
      maskFile: json['maskFile'] as String?,
      maskEnabled: json['maskEnabled'] as bool? ?? true,
      unknown: unknown,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      if (maskSourceID != null) 'maskSourceID': maskSourceID,
      if (maskFile != null) 'maskFile': maskFile,
      'maskEnabled': maskEnabled,
    };
    map.addAll(unknown);
    return map;
  }

  static const _knownKeys = {
    'maskSourceID', 'maskFile', 'maskEnabled',
  };
}