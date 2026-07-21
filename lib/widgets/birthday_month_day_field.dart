import 'package:flutter/material.dart';

import '../utils/member_profile_presentation.dart';
import '../utils/my_colors.dart';

Future<String?> pickBirthdayMonthDay(BuildContext context, String value) async {
  final current = normalizeBirthdayMonthDay(value);
  final parts = current.split('-');
  var month = parts.length == 2 ? int.parse(parts.first) : DateTime.now().month;
  var day = parts.length == 2 ? int.parse(parts.last) : DateTime.now().day;

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Birthday',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Choose the day and month only. Your birth year is not requested.',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: month,
                      decoration: const InputDecoration(labelText: 'Month'),
                      items: List.generate(
                        12,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text(_monthLabel(index + 1)),
                        ),
                      ),
                      onChanged: (value) => setSheetState(() {
                        month = value!;
                        day = day.clamp(1, daysInBirthdayMonth(month));
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: day,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: List.generate(
                        daysInBirthdayMonth(month),
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('${index + 1}'),
                        ),
                      ),
                      onChanged: (value) => setSheetState(() => day = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                  ),
                  child: const Text('Use this birthday'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BirthdayMonthDayField extends StatelessWidget {
  const BirthdayMonthDayField({
    super.key,
    required this.value,
    required this.onTap,
    required this.text,
    required this.muted,
  });

  final String value;
  final VoidCallback onTap;
  final Color text;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayValue = formatBirthdayMonthDay(value);
    return Semantics(
      button: true,
      label: 'Birthday, day and month only',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Birthday',
            helperText: 'Use MM-DD. Your birth year is not requested.',
            prefixIcon: Icon(
              Icons.cake_outlined,
              color: isDark ? const Color(0xFFFFC857) : MyColors.primary,
            ),
            suffixIcon: const Icon(Icons.calendar_month_outlined),
            filled: true,
            fillColor:
                isDark ? const Color(0xFF071720) : const Color(0xFFF5F8FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            displayValue.isEmpty
                ? 'Select your birthday (MM-DD)'
                : normalizeBirthdayMonthDay(value),
            style: TextStyle(
              color: displayValue.isEmpty ? muted : text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

String _monthLabel(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}
