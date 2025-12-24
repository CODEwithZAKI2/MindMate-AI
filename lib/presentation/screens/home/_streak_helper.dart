/// Calculate consecutive day streak from mood logs
int _calculateStreak(List<dynamic> logs) {
  if (logs.isEmpty) return 0;
  
  // Create a Set of dates (day-only, ignoring time)
  final dateSet = logs.map((log) {
    final createdAt = log.createdAt as DateTime;
    return DateTime(createdAt.year, createdAt.month, createdAt.day);
  }).toSet();
  
  // Start from today and count backwards
  var currentDate = DateTime.now();
  currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
  var streak = 0;
  
  while (dateSet.contains(currentDate)) {
    streak++;
    currentDate = currentDate.subtract(const Duration(days: 1));
  }
  
  return streak;
}
