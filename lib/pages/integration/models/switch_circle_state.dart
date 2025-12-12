class SwitchCircleState {
  final bool enabled;
  final bool isOn;

  const SwitchCircleState({required this.enabled, required this.isOn});

  SwitchCircleState copyWith({bool? enabled, bool? isOn}) {
    return SwitchCircleState(
      enabled: enabled ?? this.enabled,
      isOn: isOn ?? this.isOn,
    );
  }
}

