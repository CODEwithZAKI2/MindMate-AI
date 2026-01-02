import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/journal_entry.dart';
import '../../../core/constants/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/journal_provider.dart';

/// Calendar View for Journal entries
/// Shows monthly view with mood color indicators for each day
class JournalCalendarView extends ConsumerStatefulWidget {
  const JournalCalendarView({super.key});

  @override
  ConsumerState<JournalCalendarView> createState() =>
      _JournalCalendarViewState();
}

class _JournalCalendarViewState extends ConsumerState<JournalCalendarView> {
  late DateTime _currentMonth;
  DateTime? _selectedDay;

  static const _primaryColor = Color(0xFF6366F1);
  static const _secondaryColor = Color(0xFF8B5CF6);
  static const _surfaceColor = Color(0xFFFAFAFC);

  static const _moodColors = [
    Color(0xFFEF4444), // 1 - Sad
    Color(0xFFF97316), // 2 - Low
    Color(0xFFEAB308), // 3 - Okay
    Color(0xFF22C55E), // 4 - Good
    Color(0xFF6366F1), // 5 - Great
  ];

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDay = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final entriesAsync = ref.watch(
      monthEntriesProvider((
        userId: userId,
        year: _currentMonth.year,
        month: _currentMonth.month,
      )),
    );

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Calendar',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.grey.shade800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildWeekdayHeader(),
          Expanded(
            child: entriesAsync.when(
              data: (entries) => _buildCalendarGrid(entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          if (_selectedDay != null)
            Expanded(
              child: entriesAsync.when(
                data: (entries) => _buildDayEntries(entries),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _previousMonth,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.chevron_left_rounded,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          GestureDetector(
            onTap: _nextMonth,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children:
            weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(List<JournalEntry> entries) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startPadding = firstDay.weekday % 7; // Sunday = 0
    final totalDays = lastDay.day;

    // Group entries by day
    final entriesByDay = <int, List<JournalEntry>>{};
    for (final entry in entries) {
      final day = entry.createdAt.day;
      entriesByDay.putIfAbsent(day, () => []).add(entry);
    }

    final cells = <Widget>[];

    // Empty cells for days before month starts
    for (int i = 0; i < startPadding; i++) {
      cells.add(const SizedBox());
    }

    // Day cells
    for (int day = 1; day <= totalDays; day++) {
      final dayEntries = entriesByDay[day] ?? [];
      final isToday =
          DateTime.now().year == _currentMonth.year &&
          DateTime.now().month == _currentMonth.month &&
          DateTime.now().day == day;
      final isSelected =
          _selectedDay?.day == day &&
          _selectedDay?.month == _currentMonth.month &&
          _selectedDay?.year == _currentMonth.year;

      cells.add(_buildDayCell(day, dayEntries, isToday, isSelected));
    }

    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }

  Widget _buildDayCell(
    int day,
    List<JournalEntry> entries,
    bool isToday,
    bool isSelected,
  ) {
    // Get average mood color if entries exist
    Color? moodColor;
    if (entries.isNotEmpty) {
      final moods =
          entries
              .where((e) => e.moodScore != null)
              .map((e) => e.moodScore!)
              .toList();
      if (moods.isNotEmpty) {
        final avgMood = (moods.reduce((a, b) => a + b) / moods.length).round();
        moodColor = _moodColors[avgMood.clamp(1, 5) - 1];
      }
    }

    return GestureDetector(
      onTap:
          entries.isNotEmpty
              ? () => setState(
                () =>
                    _selectedDay = DateTime(
                      _currentMonth.year,
                      _currentMonth.month,
                      day,
                    ),
              )
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? _primaryColor
                  : entries.isNotEmpty
                  ? (moodColor?.withOpacity(0.15) ?? Colors.grey.shade100)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isToday ? Border.all(color: _primaryColor, width: 2) : null,
          boxShadow:
              entries.isNotEmpty
                  ? [
                    BoxShadow(
                      color: (moodColor ?? Colors.grey).withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? Colors.white
                        : isToday
                        ? _primaryColor
                        : entries.isNotEmpty
                        ? Colors.grey.shade800
                        : Colors.grey.shade400,
              ),
            ),
            // Entry indicator dot
            if (entries.isNotEmpty && !isSelected)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: moodColor ?? _primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // Entry count badge
            if (entries.length > 1 && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entries.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayEntries(List<JournalEntry> allEntries) {
    if (_selectedDay == null) return const SizedBox.shrink();

    final dayEntries =
        allEntries
            .where(
              (e) =>
                  e.createdAt.day == _selectedDay!.day &&
                  e.createdAt.month == _selectedDay!.month &&
                  e.createdAt.year == _selectedDay!.year,
            )
            .toList();

    if (dayEntries.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay!),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dayEntries.length} ${dayEntries.length == 1 ? 'entry' : 'entries'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: dayEntries.length,
              itemBuilder: (_, i) => _buildEntryCard(dayEntries[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry) {
    final moodIndex = (entry.moodScore ?? 3).clamp(0, _moodColors.length - 1);
    final moodColor = _moodColors[moodIndex];

    return GestureDetector(
      onTap: () => context.push('${Routes.journalDetail}/${entry.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            if (moodColor != null)
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: moodColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('h:mm a').format(entry.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
