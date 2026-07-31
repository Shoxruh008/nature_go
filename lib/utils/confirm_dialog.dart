import 'package:flutter/material.dart';

/// Muhim harakatlardan oldin (qo'shish/olib tashlash) tasdiqlash oynasini
/// ko'rsatadi. Foydalanuvchi "Ha" bossa `true`, aks holda `false` qaytaradi.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ha',
  String cancelLabel = 'Bekor qilish',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: destructive ? const Color(0xFFEF4444) : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}
