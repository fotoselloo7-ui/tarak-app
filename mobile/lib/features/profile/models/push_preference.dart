class PushPreference {
  final bool pushEnabled;

  const PushPreference({required this.pushEnabled});

  factory PushPreference.fromJson(Map<String, dynamic> json) {
    return PushPreference(
      pushEnabled: json['push_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'push_enabled': pushEnabled,
    };
  }
}
