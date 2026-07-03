import 'package:shared_preferences/shared_preferences.dart';

class InboxReadStore {
  static const String _key = 'read_inbox_message_ids';

  static Future<Set<String>> readIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const <String>[]).toSet();
  }

  static Future<int> unreadCount(Iterable<dynamic> inboxIds) async {
    final read = await readIds();
    return inboxIds
        .map((id) => id.toString())
        .where((id) => id.trim().isNotEmpty)
        .where((id) => !read.contains(id))
        .length;
  }

  static Future<void> markRead(dynamic inboxId) async {
    final id = inboxId?.toString().trim() ?? '';
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final read = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    read.add(id);
    await prefs.setStringList(_key, read.toList()..sort());
  }
}
