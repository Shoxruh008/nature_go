import 'package:flutter/material.dart';

import '../main.dart';
import '../utils/date_format.dart';

/// "Qachon bordingiz?" oynasi. Standart sana: bugun (yoki [initial]).
/// Tasdiqlansa tanlangan kun (tush vaqti bilan), bekor qilinsa `null` qaytaradi.
Future<DateTime?> showVisitDateDialog(
  BuildContext context, {
  String title = 'Qachon bordingiz?',
  String? placeName,
  String confirmLabel = "Qo'shish",
  DateTime? initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _VisitDateDialog(
      title: title,
      placeName: placeName,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _VisitDateDialog extends StatefulWidget {
  final String title;
  final String? placeName;
  final String confirmLabel;
  final DateTime? initial;

  const _VisitDateDialog({
    required this.title,
    required this.placeName,
    required this.confirmLabel,
    required this.initial,
  });

  @override
  State<_VisitDateDialog> createState() => _VisitDateDialogState();
}

class _VisitDateDialogState extends State<_VisitDateDialog> {
  late DateTime _selected = visitDay(widget.initial ?? DateTime.now());

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected.isAfter(today) ? today : _selected,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null) setState(() => _selected = visitDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(_selected, DateTime.now());

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.placeName != null) ...[
            Text(widget.placeName!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 14),
          ],
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded,
                      color: AppTheme.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatUzDate(_selected),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain),
                        ),
                        if (isToday)
                          const Text('Bugun',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(widget.confirmLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
