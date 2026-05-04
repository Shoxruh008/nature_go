import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import '../models/trip.dart';
import '../main.dart';
import '../utils/money.dart';

class ShareService {
  static Future<void> shareResult(Trip trip, BuildContext context) async {
    final buffer = StringBuffer();
    buffer.writeln('📍 ${trip.name} — Xarajatlar hisobi');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();
    buffer.writeln('💰 Jami: ${formatMoney(trip.totalAmount)}');
    buffer.writeln('👥 ${trip.members.length} kishi × ${formatMoney(trip.perPerson)}');
    buffer.writeln();
    buffer.writeln('📊 Xarajatlar:');
    for (final e in trip.expenses) {
      final payer = trip.memberById(e.payerId);
      buffer.writeln('  ${e.title} — ${formatMoney(e.amount)} (${payer?.name ?? '?'})');
    }
    buffer.writeln();
    buffer.writeln('💳 Kim kimga to\'laydi:');
    final settlements = trip.settlements;
    if (settlements.isEmpty) {
      buffer.writeln('  Hamma hisob-kitob tugagan! ✅');
    } else {
      for (final s in settlements) {
        final from = trip.memberById(s.fromId);
        final to = trip.memberById(s.toId);
        buffer.writeln('  ${from?.name ?? '?'} → ${to?.name ?? '?'}: ${formatMoney(s.amount)}');
      }
    }
    buffer.writeln();
    buffer.writeln('🚀 TripSplit ilovasi orqali hisoblandi');

    // ✅ To'g'rilandi
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: trip.name,
        sharePositionOrigin: box != null
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }

  static String buildShareText(Trip trip) {
    final buffer = StringBuffer();
    buffer.writeln('📍 ${trip.name}');
    buffer.writeln('💰 Jami: ${formatMoney(trip.totalAmount)}');
    buffer.writeln('👤 Har biri: ${formatMoney(trip.perPerson)}');
    buffer.writeln();
    final settlements = trip.settlements;
    if (settlements.isEmpty) {
      buffer.writeln('✅ Hamma to\'langan!');
    } else {
      for (final s in settlements) {
        final from = trip.memberById(s.fromId);
        final to = trip.memberById(s.toId);
        buffer.writeln('${from?.name} → ${to?.name}: ${formatMoney(s.amount)}');
      }
    }
    return buffer.toString();
  }
}