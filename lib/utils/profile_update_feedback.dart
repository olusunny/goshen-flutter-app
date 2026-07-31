String profileUpdateErrorMessage(
  Map<String, dynamic> response, {
  int? statusCode,
}) {
  final errors = response['errors'];
  if (errors is Map) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }

  final message = response['message'] ?? response['msg'];
  if (message != null && message.toString().trim().isNotEmpty) {
    return message.toString();
  }
  if (statusCode == 401 || statusCode == 403) {
    return 'Your session has expired. Please sign in again, then save your profile.';
  }
  return 'We could not update your profile. Please check the details and try again.';
}
