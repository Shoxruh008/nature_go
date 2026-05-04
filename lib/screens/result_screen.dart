import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/trip.dart';
import '../services/share_service.dart';
import '../main.dart';
import '../utils/money.dart';

class ResultScreen extends StatefulWidget {
  final Trip trip;

  const ResultScreen({super.key, required this.trip});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    final text = ShareService.buildShareText(widget.trip);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Natija nusxalandi!'),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final settlements = trip.settlements;
    final balances = trip.balances;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCard(trip),
              const SizedBox(height: 12),
              _buildBalancesSection(trip, balances),
              const SizedBox(height: 12),
              if (settlements.isEmpty)
                _buildAllSettledCard()
              else
                _buildSettlementsSection(trip, settlements),
              const SizedBox(height: 16),
              _buildShareButtons(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF5F7F5),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_rounded,
            size: 16,
            color: AppTheme.textMain,
          ),
        ),
      ),
      title: const Text(
        'Hisob-kitob natijasi',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMain,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSummaryCard(Trip trip) {
    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🎉', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Natija tayyor!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Hisob-kitob tugallandi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    label: 'Jami xarajat',
                    value: formatMoney(trip.totalAmount),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _SummaryItem(
                    label: 'Har biri',
                    value: formatMoney(trip.perPerson),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _SummaryItem(
                    label: 'Ishtirokchi',
                    value: '${trip.members.length} ta',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancesSection(Trip trip, Map<String, double> balances) {
    return _card([
      _secTitle('Balanslar', '📊'),
      const SizedBox(height: 14),
      AnimationLimiter(
        child: Column(
          children: trip.members.asMap().entries.map((entry) {
            final i = entry.key;
            final member = entry.value;
            final color =
            AppTheme.memberColors[i % AppTheme.memberColors.length];
            final balance = balances[member.id] ?? 0;
            final paid = trip.expenses
                .where((e) => e.payerId == member.id)
                .fold(0.0, (s, e) => s + e.amount);
            final isLast = i == trip.members.length - 1;

            return AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 400),
              child: SlideAnimation(
                verticalOffset: 24,
                child: FadeInAnimation(
                  child: Column(
                    children: [
                      _BalanceRow(
                        name: member.name,
                        color: color,
                        paid: paid,
                        balance: balance,
                        perPerson: trip.perPerson,
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          indent: 54,
                          endIndent: 0,
                          color: Color(0xFFF0F0F0),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildAllSettledCard() {
    return _card([
      const SizedBox(height: 8),
      Center(
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Hamma hisob-kitob qilgan!',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hech kim hech kimga qarzdor emas',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _buildSettlementsSection(Trip trip, List<Settlement> settlements) {
    return _card([
      _secTitle('Kim kimga to\'laydi', '💳'),
      const SizedBox(height: 14),
      AnimationLimiter(
        child: Column(
          children: settlements.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final fromIdx =
            trip.members.indexWhere((m) => m.id == s.fromId);
            final toIdx = trip.members.indexWhere((m) => m.id == s.toId);
            final fromColor = fromIdx >= 0
                ? AppTheme.memberColors[fromIdx % AppTheme.memberColors.length]
                : AppTheme.accentWarm;
            final toColor = toIdx >= 0
                ? AppTheme.memberColors[toIdx % AppTheme.memberColors.length]
                : AppTheme.primary;
            final from = trip.memberById(s.fromId);
            final to = trip.memberById(s.toId);
            final isLast = i == settlements.length - 1;

            return AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 400),
              child: SlideAnimation(
                verticalOffset: 24,
                child: FadeInAnimation(
                  child: Column(
                    children: [
                      _SettlementRow(
                        fromName: from?.name ?? '?',
                        toName: to?.name ?? '?',
                        amount: s.amount,
                        fromColor: fromColor,
                        toColor: toColor,
                      ),
                      if (!isLast)
                        const Divider(
                          height: 1,
                          color: Color(0xFFF0F0F0),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  Widget _buildShareButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _copyToClipboard();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nusxalash',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              ShareService.shareResult(widget.trip, context);
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ulashish',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.only(bottom: 0),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _secTitle(String t, String icon) => Row(
    children: [
      Text(icon, style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 7),
      Text(
        t,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMain,
        ),
      ),
    ],
  );
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String name;
  final Color color;
  final double paid;
  final double balance;
  final double perPerson;

  const _BalanceRow({
    required this.name,
    required this.color,
    required this.paid,
    required this.balance,
    required this.perPerson,
  });

  @override
  Widget build(BuildContext context) {
    final isCreditor = balance > 0.01;
    final isDebtor = balance < -0.01;
    final statusColor = isCreditor
        ? AppTheme.positive
        : isDebtor
        ? AppTheme.negative
        : AppTheme.accentGold;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'To\'lagan: ${formatMoney(paid)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  isCreditor
                      ? '+ ${formatMoney(balance)}'
                      : isDebtor
                      ? '- ${formatMoney(balance.abs())}'
                      : '✓ Balanslangan',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isCreditor
                    ? 'Olishi kerak'
                    : isDebtor
                    ? 'Berishi kerak'
                    : '',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final String fromName;
  final String toName;
  final double amount;
  final Color fromColor;
  final Color toColor;

  const _SettlementRow({
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.fromColor,
    required this.toColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // FROM — chap tomon
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: fromColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      fromName[0].toUpperCase(),
                      style: TextStyle(
                        color: fromColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "to'laydi",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // O'rta — miqdor va o'q
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    formatMoney(amount),
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primary.withOpacity(0.5),
                  size: 16,
                ),
              ],
            ),
          ),

          // TO — o'ng tomon
          Expanded(
            flex: 5,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        toName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "oladi",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: toColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      toName[0].toUpperCase(),
                      style: TextStyle(
                        color: toColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}