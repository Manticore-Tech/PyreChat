class PyreSession {
  const PyreSession({
    required this.id,
    required this.label,
    required this.current,
    this.deviceId,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String label;
  final bool current;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory PyreSession.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final rawLabel = json['label']?.toString().trim() ?? '';
    return PyreSession(
      id: json['id']?.toString() ?? '',
      label: rawLabel.isEmpty ? 'PyreChat session' : rawLabel,
      current: json['current'] == true || json['current'] == 1,
      deviceId: switch (json['deviceId']?.toString().trim()) {
        final value? when value.isNotEmpty => value,
        _ => null,
      },
      createdAt: parseDate(json['createdAt']),
      expiresAt: parseDate(json['expiresAt']),
    );
  }
}
