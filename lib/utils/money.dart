String formatMoney(double amount) {
  final abs = amount.abs();
  if (abs >= 1000000) {
    return "${(abs / 1000000).toStringAsFixed(0)}M so'm";
  } else if (abs >= 1000) {
    final formatted = abs
        .toStringAsFixed(0)
        .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},');
    return "$formatted so'm";
  }
  return "${abs.toStringAsFixed(0)} so'm";
}