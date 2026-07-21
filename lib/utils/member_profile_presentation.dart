import 'member_profile_requirements.dart';

String triumphantIdStatusMessage({
  required String memberType,
  required String triumphantId,
}) {
  if (triumphantId.trim().isNotEmpty) return triumphantId.trim();
  if (isVisitorMemberType(memberType)) {
    return 'You are registered as a visitor';
  }
  return 'Your Triumphant ID is being prepared';
}

String triumphantIdStatusDetail({
  required String memberType,
  required String triumphantId,
}) {
  if (triumphantId.trim().isNotEmpty) return '';
  if (isVisitorMemberType(memberType)) {
    return 'Visitors do not receive a Triumphant ID. Update your membership status when you become a church member and an ID will be assigned to you.';
  }
  return 'Your Triumphant ID will appear here once your church-member profile is confirmed.';
}

DateTime? parseMembershipStatusEditableAt(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

bool isMembershipStatusLocked(String? editableAt, {DateTime? now}) {
  final availableAt = parseMembershipStatusEditableAt(editableAt);
  if (availableAt == null) return false;
  return availableAt.isAfter(now ?? DateTime.now());
}

String membershipStatusLockMessage(String? editableAt, {DateTime? now}) {
  final availableAt = parseMembershipStatusEditableAt(editableAt);
  if (availableAt == null || !availableAt.isAfter(now ?? DateTime.now())) {
    return 'Membership status can be changed once every 30 days.';
  }

  final localNow = now ?? DateTime.now();
  final remainingDays = availableAt.difference(localNow).inDays + 1;
  final day = availableAt.day.toString().padLeft(2, '0');
  final month = _monthName(availableAt.month);
  return 'Your membership status can be changed again on $day $month (${remainingDays.clamp(1, 30)} days remaining).';
}

String normalizeBirthdayMonthDay(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return '';

  final match = RegExp(r'^(?:\d{4}-)?(\d{1,2})-(\d{1,2})$').firstMatch(raw);
  if (match == null) return '';
  final month = int.tryParse(match.group(1)!);
  final day = int.tryParse(match.group(2)!);
  if (month == null || day == null || month < 1 || month > 12) return '';
  if (day < 1 || day > _daysInMonth(month)) return '';
  return '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

String formatBirthdayMonthDay(String? value) {
  final normalized = normalizeBirthdayMonthDay(value);
  if (normalized.isEmpty) return '';
  final parts = normalized.split('-');
  return '${int.parse(parts[1])} ${_monthName(int.parse(parts[0]))}';
}

int daysInBirthdayMonth(int month) => _daysInMonth(month);

int _daysInMonth(int month) {
  const days = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return days[month - 1];
}

String _monthName(int month) {
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
