class ChurchBirthdayCelebrationLink {
  const ChurchBirthdayCelebrationLink({this.celebrationId});

  final String? celebrationId;
}

ChurchBirthdayCelebrationLink? parseChurchBirthdayCelebrationLink(Uri uri) {
  final normalizedPath = uri.pathSegments.join('/');
  final matchesWeb = uri.scheme == 'https' &&
      uri.host == 'portal.goshenretreat.uk' &&
      (normalizedPath == 'church-birthday-celebrations' ||
          normalizedPath == 'app/church-birthday-celebrations');
  final matchesApp =
      uri.scheme == 'triumphant' && uri.host == 'church-birthday-celebrations';
  if (!matchesWeb && !matchesApp) return null;
  final id = uri.queryParameters['celebration_id']?.trim();
  return ChurchBirthdayCelebrationLink(
    celebrationId: id == null || id.isEmpty ? null : id,
  );
}

bool isChurchBirthdayCelebrationNotification(Map<String, dynamic> data) {
  final action = '${data['action'] ?? data['type'] ?? ''}'.trim();
  return action == 'church_birthday_celebrations' ||
      action == 'church-birthday-celebrations';
}
