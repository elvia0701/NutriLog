DateTime localDateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

String databaseDate(DateTime value) {
  final date = localDateOnly(value);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime parseDatabaseDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Expected yyyy-MM-dd local date.', value);
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

String slashLocalDate(DateTime value) {
  final date = localDateOnly(value);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}/$month/$day';
}

bool isSameLocalDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String fullLocalDate(DateTime value) {
  final date = localDateOnly(value);
  return '${date.year}年${date.month}月${date.day}日';
}

String weekdayLabel(DateTime value) {
  const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  return weekdays[localDateOnly(value).weekday - 1];
}
