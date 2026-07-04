import 'package:churchapp_flutter/screens/EmptyListScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/EventsViewerScreen.dart';
import '../models/ScreenArguements.dart';
import 'dart:async';
import 'dart:convert';
import '../utils/img.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../models/Events.dart';
import '../utils/TextStyles.dart';
import 'NoitemScreen.dart';
import 'package:intl/intl.dart';
import '../i18n/strings.g.dart';

class EventsListScreen extends StatefulWidget {
  static const routeName = "/eventslist";

  @override
  _EventsListScreenState createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  DateTime selectedDate = DateTime.now();
  String _selecteddate = "";
  bool _isFindingNextEvent = true;
  bool _calendarOpened = false;
  List<Events> _allEvents = [];
  Set<String> _eventDateKeys = {};
  Set<String> _pastEventDateKeys = {};

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _EventCalendarDialog(
        initialDate: selectedDate,
        eventDateKeys: _eventDateKeys,
        pastEventDateKeys: _pastEventDateKeys,
      ),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _selecteddate = DateFormat('yyyy-MM-dd').format(selectedDate);
        print(_selecteddate);
      });
    } else {
      print("picked null" + picked.toString());
    }
  }

  @override
  void initState() {
    _selecteddate = DateFormat('yyyy-MM-dd').format(selectedDate);
    _selectNextAvailableEventDate();
    super.initState();
  }

  Future<void> _selectNextAvailableEventDate() async {
    try {
      final response = await Dio().post(
        ApiUrl.EVENTS,
        data: jsonEncode({"data": {}}),
      );
      final res = decodeApiResponse(response.data);
      final events = _parseEvents(res);
      final today = DateTime.now();
      final todayOnly = DateTime(today.year, today.month, today.day);
      final eventDateKeys = _eventDateKeysFromEvents(events);
      final pastEventDateKeys = _pastEventDateKeysFromEvents(events);
      DateTime? nextDate;

      for (final key in eventDateKeys) {
        final eventOnly = DateTime.tryParse(key);
        if (eventOnly == null) continue;
        if (eventOnly.isBefore(todayOnly)) continue;
        if (nextDate == null || eventOnly.isBefore(nextDate)) {
          nextDate = eventOnly;
        }
      }

      if (!mounted) return;
      setState(() {
        _allEvents = events;
        _eventDateKeys = eventDateKeys;
        _pastEventDateKeys = pastEventDateKeys;
        if (nextDate != null) {
          selectedDate = nextDate;
          _selecteddate = DateFormat('yyyy-MM-dd').format(selectedDate);
        }
        _isFindingNextEvent = false;
      });
      _openCalendarOnce();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFindingNextEvent = false);
      _openCalendarOnce();
    }
  }

  void _openCalendarOnce() {
    if (_calendarOpened || !mounted) return;
    _calendarOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selectDate(context);
    });
  }

  List<Events> _parseEvents(dynamic res) {
    final raw = res is Map ? res['events'] : null;
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((json) => Events.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  List<Events> _eventsForSelectedDate() {
    final selectedKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    return _allEvents
        .where((event) => _dateKeysForEvent(event).contains(selectedKey))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.events),
        actions: [
          SizedBox(
            height: 38,
            width: 38,
            child: InkWell(
              highlightColor: Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(32.0)),
              onTap: () {
                setState(() {
                  selectedDate = selectedDate.subtract(new Duration(days: 1));
                  _selecteddate = DateFormat('yyyy-MM-dd').format(selectedDate);
                });
              },
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_left,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 8,
              right: 8,
            ),
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.calendar_today,
                    size: 18,
                  ),
                ),
                InkWell(
                  onTap: () {
                    _selectDate(context);
                  },
                  child: Text(
                    DateFormat('d MMM').format(selectedDate),
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 18,
                      letterSpacing: -0.2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 38,
            width: 38,
            child: InkWell(
              highlightColor: Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(32.0)),
              onTap: () {
                setState(() {
                  selectedDate = selectedDate.add(new Duration(days: 1));
                  _selecteddate = DateFormat('yyyy-MM-dd').format(selectedDate);
                });
              },
              child: Center(
                child: Icon(
                  Icons.keyboard_arrow_right,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 12),
        child: _isFindingNextEvent
            ? Center(child: CupertinoActivityIndicator(radius: 20))
            : EventsListScreenPageBody(
                key: ValueKey(_selecteddate),
                date: _selecteddate,
                dateTime: selectedDate,
                initialItems: _eventsForSelectedDate(),
              ),
      ),
    );
  }
}

class _EventCalendarDialog extends StatefulWidget {
  const _EventCalendarDialog({
    required this.initialDate,
    required this.eventDateKeys,
    required this.pastEventDateKeys,
  });

  final DateTime initialDate;
  final Set<String> eventDateKeys;
  final Set<String> pastEventDateKeys;

  @override
  State<_EventCalendarDialog> createState() => _EventCalendarDialogState();
}

class _EventCalendarDialogState extends State<_EventCalendarDialog> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday % 7;
    final cells = leadingBlanks + daysInMonth;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                  }),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_visibleMonth),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF0C2230),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() {
                    _visibleMonth =
                        DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                  }),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (day) => Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF71808A),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((cells + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingBlanks + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final day = DateTime(
                    _visibleMonth.year, _visibleMonth.month, dayNumber);
                final key = _dateKey(day);
                final hasEvent = widget.eventDateKeys.contains(key);
                final isPastEvent = widget.pastEventDateKeys.contains(key);
                final isSelected = key == _dateKey(widget.initialDate);

                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.of(context).pop(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0C2230)
                          : hasEvent
                              ? isPastEvent
                                  ? const Color(0xFF60707A)
                                      .withValues(alpha: 0.12)
                                  : const Color(0xFFFFB51D)
                                      .withValues(alpha: 0.22)
                              : const Color(0xFFF4F8FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasEvent
                            ? isPastEvent
                                ? const Color(0xFF9AA7AF)
                                : const Color(0xFFFFB51D)
                            : const Color(0xFFE6EEF2),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isPastEvent
                                    ? const Color(0xFF71808A)
                                    : const Color(0xFF0C2230),
                            fontWeight:
                                hasEvent ? FontWeight.w900 : FontWeight.w700,
                          ),
                        ),
                        if (hasEvent)
                          Positioned(
                            bottom: 5,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFB51D)
                                    : isPastEvent
                                        ? const Color(0xFF9AA7AF)
                                        : const Color(0xFF0C2230),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFB51D),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Gold dates are upcoming events; grey dates are past events.',
                    style: TextStyle(
                      color: Color(0xFF71808A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Set<String> _eventDateKeysFromEvents(List<Events> events) {
  return events.expand(_dateKeysForEvent).toSet();
}

Set<String> _pastEventDateKeysFromEvents(List<Events> events) {
  return events
      .where((event) => event.isPast)
      .expand(_dateKeysForEvent)
      .toSet();
}

Set<String> _dateKeysForEvent(Events event) {
  final keys = <String>{};
  final start = event.startDateTime ?? _parseEventDate(event.date);
  final end = event.endDateTime;

  if (start != null) keys.add(_dateKey(start));

  if (start != null && end != null) {
    var cursor = DateTime(start.year, start.month, start.day);
    final endOnly = DateTime(end.year, end.month, end.day);
    var guard = 0;
    while (!cursor.isAfter(endOnly) && guard < 31) {
      keys.add(_dateKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
      guard++;
    }
  }

  for (final day in event.eventSchedule) {
    keys.addAll(_dateKeysFromScheduleDay(day, start));
  }

  return keys;
}

Set<String> _dateKeysFromScheduleDay(
  EventScheduleDay day,
  DateTime? fallbackDate,
) {
  final combined = '${day.dayLabel} ${day.dateLabel}'.trim();
  if (combined.isEmpty) return {};

  final month = _monthFromText(combined) ?? fallbackDate?.month;
  final year = _yearFromText(combined) ?? fallbackDate?.year;
  if (month == null || year == null) return {};

  final days = RegExp(
    r'\b([0-3]?\d)(?:st|nd|rd|th)?\b',
    caseSensitive: false,
  )
      .allMatches(combined)
      .map((match) => int.tryParse(match.group(1) ?? ''))
      .whereType<int>()
      .where((day) => day >= 1 && day <= 31)
      .toSet();

  return days
      .map((day) {
        try {
          return DateTime(year, month, day);
        } catch (_) {
          return null;
        }
      })
      .whereType<DateTime>()
      .map(_dateKey)
      .toSet();
}

DateTime? _parseEventDate(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

int? _yearFromText(String text) {
  final match = RegExp(r'\b(20\d{2})\b').firstMatch(text);
  return int.tryParse(match?.group(1) ?? '');
}

int? _monthFromText(String text) {
  const months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };

  final lower = text.toLowerCase();
  for (final entry in months.entries) {
    if (RegExp('\\b${entry.key}\\b').hasMatch(lower)) {
      return entry.value;
    }
  }
  return null;
}

class EventsListScreenPageBody extends StatefulWidget {
  const EventsListScreenPageBody(
      {Key? key, this.date, this.dateTime, this.initialItems})
      : super(key: key);
  final String? date;
  final DateTime? dateTime;
  final List<Events>? initialItems;
  @override
  _BranchesPageBodyState createState() => _BranchesPageBodyState();
}

class _BranchesPageBodyState extends State<EventsListScreenPageBody> {
  bool isLoading = true;
  bool isError = false;
  List<Events>? items = [];

  Future<void> loadItems() async {
    setState(() {
      isLoading = true;
    });
    try {
      final dio = Dio();
      final response = await dio.post(
        ApiUrl.EVENTS,
        data: jsonEncode({
          "data": {"date": widget.date}
        }),
      );

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        dynamic res = decodeApiResponse(response.data);
        print(res);
        List<Events>? _items = parseBranches(res);
        setState(() {
          isLoading = false;
          items = _items;
        });
      } else {
        // If the server did not return a 200 OK response,
        // then throw an exception.
        setState(() {
          isLoading = false;
          isError = true;
        });
      }
    } catch (exception) {
      // I get no exception here
      print(exception);
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  static List<Events>? parseBranches(dynamic res) {
    // final res = jsonDecode(responseBody);
    final parsed = res["events"].cast<Map<String, dynamic>>();
    return parsed.map<Events>((json) => Events.fromJson(json)).toList();
  }

  @override
  void initState() {
    if (widget.initialItems != null) {
      isLoading = false;
      items = widget.initialItems;
    } else {
      Future.delayed(const Duration(milliseconds: 0), () {
        loadItems();
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
          child: CupertinoActivityIndicator(
        radius: 20,
      ));
    } else if (isError) {
      return NoitemScreen(
          title: t.oops,
          message: t.dataloaderror,
          onClick: () {
            loadItems();
          });
    } else if (items!.length == 0) {
      return EmptyListScreen(
        message: t.noitemstodisplay,
      );
    } else
      return ListView.builder(
        itemCount: items!.length,
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.all(3),
        itemBuilder: (BuildContext context, int index) {
          return ItemTile(
            index: index,
            events: items![index],
          );
        },
      );
  }
}

class ItemTile extends StatelessWidget {
  final Events events;
  final int index;

  const ItemTile({
    Key? key,
    required this.index,
    required this.events,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    DateTime tempDate = new DateFormat("yyyy-MM-dd").parse(events.date!);
    final isPast = events.isPast;
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(EventsViewerScreen.routeName,
            arguments: ScreenArguements(
              position: 0,
              items: events,
              itemsList: [],
            ));
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 90),
        padding: const EdgeInsets.fromLTRB(15, 8, 15, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Card(
                    margin: EdgeInsets.all(0),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    child: Container(
                      height: 40,
                      width: 40,
                      child: CachedNetworkImage(
                        imageUrl: events.thumbnail ?? '',
                        imageBuilder: (context, imageProvider) => Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                                colorFilter: ColorFilter.mode(
                                    Colors.black12, BlendMode.darken)),
                          ),
                        ),
                        placeholder: (context, url) =>
                            Center(child: CupertinoActivityIndicator()),
                        errorWidget: (context, url, error) => Center(
                            child: Image.asset(
                          Img.get('event.jpg'),
                          fit: BoxFit.fill,
                          width: double.infinity,
                          height: double.infinity,
                          //color: Colors.black26,
                        )),
                      ),
                    )),
                Container(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              DateFormat('EEE, MMM d, yyyy').format(tempDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.caption(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            events.time!,
                            style: TextStyles.caption(context),
                          ),
                          if (isPast) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF60707A)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Past',
                                style: TextStyle(
                                  color: Color(0xFF60707A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(events.title!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.subhead(context).copyWith(
                              //color: MyColors.grey_80,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 0.1,
              //color: Colors.grey.shade800,
            )
          ],
        ),
      ),
    );
  }
}
