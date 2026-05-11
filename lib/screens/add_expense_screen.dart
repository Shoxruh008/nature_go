import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/trip.dart';
import '../models/expense.dart';
import '../services/storage_service.dart';
import '../main.dart';
import '../utils/money.dart';

class AddExpenseScreen extends StatefulWidget {
  final Trip trip;
  final Expense? editExpense; // <- tahrirlash uchun

  const AddExpenseScreen({
    super.key,
    required this.trip,
    this.editExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _selectedPayerId;
  String _selectedCategory = 'other';
  bool _isSaving = false;

  bool get _isEditing => widget.editExpense != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      // Tahrirlash rejimi: mavjud qiymatlarni to'ldirish
      final e = widget.editExpense!;
      _titleController.text = e.title;
      _amountController.text = e.amount.toInt().toString();
      _selectedPayerId = e.payerId;
      _selectedCategory = e.category;
    } else {
      // Qo'shish rejimi
      if (widget.trip.members.isNotEmpty) {
        _selectedPayerId = widget.trip.members.first.id;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPayerId == null) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    if (_isEditing) {
      // Mavjud xarajatni yangilash
      final idx = widget.trip.expenses
          .indexWhere((e) => e.id == widget.editExpense!.id);
      if (idx >= 0) {
        widget.trip.expenses[idx] = Expense(
          id: widget.editExpense!.id, // ID saqlanadi
          title: _titleController.text.trim(),
          amount: double.parse(_amountController.text.replaceAll(' ', '')),
          payerId: _selectedPayerId!,
          category: _selectedCategory,
        );
      }
    } else {
      // Yangi xarajat qo'shish
      widget.trip.expenses.add(Expense(
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(' ', '')),
        payerId: _selectedPayerId!,
        category: _selectedCategory,
      ));
    }

    await StorageService.saveTrip(widget.trip);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: _buildAppBar(),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card([
                  _secTitle('Kategoriya', '🏷️'),
                  const SizedBox(height: 14),
                  _buildCategorySelector(),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Nima uchun?', '📝'),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMain,
                    ),
                    decoration: _inputDec(
                      'Benzin, Ovqat, Hotel...',
                      null,
                    ).copyWith(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          ExpenseCategory.emoji(_selectedCategory),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                    ),
                    validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nomi kiriting' : null,
                  ),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Miqdor', '💵'),
                  const SizedBox(height: 14),
                  _buildAmountField(),
                ]),
                const SizedBox(height: 12),
                _card([
                  _secTitle('Kim to\'ladi?', '👤'),
                  const SizedBox(height: 14),
                  _buildPayerSelector(),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      disabledBackgroundColor:
                      AppTheme.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing
                              ? 'O\'zgarishlarni saqlash'
                              : 'Xarajatni saqlash',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      title: Text(
        _isEditing ? 'Xarajatni tahrirlash' : 'Xarajat qo\'shish',
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppTheme.textMain,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.categories.entries.map((entry) {
        final selected = entry.key == _selectedCategory;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategory = entry.key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withOpacity(0.12)
                  : const Color(0xFFF5F7F5),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: selected ? AppTheme.primary : const Color(0xFFE0E0E0),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.value['emoji']!,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.value['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppTheme.primary : AppTheme.textMain,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _amountController,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMain,
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _inputDec('0', Icons.payments_outlined).copyWith(
            suffixText: 'so\'m',
            suffixStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Miqdor kiriting';
            final val = double.tryParse(v);
            if (val == null || val <= 0) return 'To\'g\'ri miqdor kiriting';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Text(
          'Tez tanlash',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [10000, 20000, 50000, 100000, 200000, 500000]
              .map(
                (v) => GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _amountController.text = v.toString());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  formatMoney(v.toDouble()),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPayerSelector() {
    return Column(
      children: widget.trip.members.asMap().entries.map((entry) {
        final i = entry.key;
        final member = entry.value;
        final color = AppTheme.memberColors[i % AppTheme.memberColors.length];
        final selected = _selectedPayerId == member.id;
        final isLast = i == widget.trip.members.length - 1;

        return Column(
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedPayerId = member.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? color.withOpacity(0.09)
                      : const Color(0xFFF5F7F5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? color.withOpacity(0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          member.name[0].toUpperCase(),
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
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? color : AppTheme.textMain,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: color,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
            if (!isLast) const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _card(List<Widget> children) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
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

  InputDecoration _inputDec(String hint, IconData? icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 13,
    ),
    prefixIcon: icon != null
        ? Icon(icon, size: 18, color: AppTheme.textSecondary)
        : null,
    filled: true,
    fillColor: const Color(0xFFF5F7F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(25),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}