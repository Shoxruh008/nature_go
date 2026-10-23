const _uzMonths = [
  'Yanvar',
  'Fevral',
  'Mart',
  'Aprel',
  'May',
  'Iyun',
  'Iyul',
  'Avgust',
  'Sentabr',
  'Oktabr',
  'Noyabr',
  'Dekabr',
];

/// 5-Avgust, 2026
String formatUzDate(DateTime d) => '${d.day}-${_uzMonths[d.month - 1]}, ${d.year}';

/// Tashrif sanasi faqat kun sifatida saqlanadi. Tush vaqti (12:00) olinadi,
/// shunda vaqt zonasi o'zgarganda ham sana bir kunga siljib ketmaydi.
DateTime visitDay(DateTime d) => DateTime(d.year, d.month, d.day, 12);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
