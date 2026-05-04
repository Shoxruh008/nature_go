import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/trip.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../services/share_service.dart';
import '../main.dart';
import '../utils/money.dart';
import 'add_expense_screen.dart';
import 'result_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;

  const TripDetailScreen({super.key, required this.tripId});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  Trip? _trip;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTrip();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadTrip() {
    setState(() {
      _trip = StorageService.getTrip(widget.tripId);
    });
  }

  void _openAddExpense() async {
    if (_trip == null) return;
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(trip: _trip!)),
    );
    if (result == true) _loadTrip();
  }

  void _openResult() {
    if (_trip == null) return;
    if (_trip!.members.isEmpty) {
      _showSnack('Avval ishtirokchi qo\'shing');
      return;
    }
    if (_trip!.expenses.isEmpty) {
      _showSnack('Avval xarajat qo\'shing');
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(trip: _trip!)),
    );
  }

  void _deleteExpense(Expense expense) async {
    HapticFeedback.selectionClick();
    setState(() => _trip!.expenses.removeWhere((e) => e.id == expense.id));
    await StorageService.saveTrip(_trip!);
    _loadTrip();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7F5),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        body: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder: (ctx, innerScrolled) => [
            _buildSliverAppBar(),
            _buildStatsBanner(),
            _buildTabBar(),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildExpensesTab(),
              _buildMembersTab(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      centerTitle: true,
      backgroundColor: const Color(0xFFF5F7F5),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
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
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_trip!.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _trip!.name,
              style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            ShareService.shareResult(_trip!, context);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            width: 36,
            height: 35,
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
              Icons.share_outlined,
              size: 17,
              color: AppTheme.textMain,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBanner() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Jami',
                  value: formatMoney(_trip!.totalAmount),
                  icon: '💰',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.25),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Har biri',
                  value: formatMoney(_trip!.perPerson),
                  icon: '👤',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withOpacity(0.25),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Xarajatlar',
                  value: '${_trip!.expenses.length} ta',
                  icon: '📋',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'Xarajatlar'),
            Tab(text: 'Ishtirokchilar'),
          ],
        ),
        backgroundColor: const Color(0xFFF5F7F5),
        dividerColor: const Color(0xFFE8EDE8),
      ),
    );
  }

  Widget _buildExpensesTab() {
    if (_trip!.expenses.isEmpty) {
      return _buildEmpty(
        emoji: '💸',
        title: 'Xarajat yo\'q',
        subtitle: 'Qo\'shish uchun "+" tugmasini bosing',
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _trip!.expenses.length,
        itemBuilder: (ctx, i) {
          final expense = _trip!.expenses[i];
          final payer = _trip!.memberById(expense.payerId);
          final memberIdx =
          _trip!.members.indexWhere((m) => m.id == expense.payerId);
          final color = memberIdx >= 0
              ? AppTheme.memberColors[memberIdx % AppTheme.memberColors.length]
              : AppTheme.primary;

          return AnimationConfiguration.staggeredList(
            position: i,
            duration: const Duration(milliseconds: 350),
            child: SlideAnimation(
              horizontalOffset: 40,
              child: FadeInAnimation(
                child: _ExpenseCard(
                  expense: expense,
                  payerName: payer?.name ?? '?',
                  payerColor: color,
                  onDelete: () => _deleteExpense(expense),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMembersTab() {
    if (_trip!.members.isEmpty) {
      return _buildEmpty(
        emoji: '👥',
        title: 'Ishtirokchi yo\'q',
        subtitle: 'Sayohatni tahrirlash uchun orqaga qayting',
      );
    }

    final balances = _trip!.balances;

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _trip!.members.length,
        itemBuilder: (ctx, i) {
          final member = _trip!.members[i];
          final color =
          AppTheme.memberColors[i % AppTheme.memberColors.length];
          final balance = balances[member.id] ?? 0;
          final paid = _trip!.expenses
              .where((e) => e.payerId == member.id)
              .fold(0.0, (s, e) => s + e.amount);

          return AnimationConfiguration.staggeredList(
            position: i,
            duration: const Duration(milliseconds: 350),
            child: SlideAnimation(
              horizontalOffset: 40,
              child: FadeInAnimation(
                child: _MemberCard(
                  name: member.name,
                  color: color,
                  paid: paid,
                  balance: balance,
                  perPerson: _trip!.perPerson,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty({
    required String emoji,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE8EDE8), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _openAddExpense,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Xarajat qo\'shish',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _openResult,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                children: [
                  Icon(Icons.calculate_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Natija',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
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

class _ExpenseCard extends StatelessWidget {
  final Expense expense;
  final String payerName;
  final Color payerColor;
  final VoidCallback onDelete;

  const _ExpenseCard({
    required this.expense,
    required this.payerName,
    required this.payerColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: payerColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                ExpenseCategory.emoji(expense.category),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  style: const TextStyle(
                    color: AppTheme.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: payerColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          payerName[0].toUpperCase(),
                          style: TextStyle(
                            color: payerColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      payerName,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(expense.amount),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String name;
  final Color color;
  final double paid;
  final double balance;
  final double perPerson;

  const _MemberCard({
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
    final statusText = isCreditor
        ? '+${formatMoney(balance)}'
        : isDebtor
        ? '-${formatMoney(balance.abs())}'
        : '✓ Hisob';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
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
                  fontSize: 18,
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
                    color: AppTheme.textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'To\'lagan: ${formatMoney(paid)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ulush: ${formatMoney(perPerson)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final Color dividerColor;

  _SliverTabBarDelegate(
      this.tabBar, {
        required this.backgroundColor,
        required this.dividerColor,
      });

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          tabBar,
          Container(height: 1, color: dividerColor),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}