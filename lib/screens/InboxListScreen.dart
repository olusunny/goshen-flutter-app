import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../screens/InboxViewerScreen.dart';
import '../models/ScreenArguements.dart';
import 'dart:async';
import '../utils/TimUtil.dart';
import '../models/Inbox.dart';
import 'NoitemScreen.dart';
import '../i18n/strings.g.dart';
import '../utils/TextStyles.dart';
import 'dart:convert';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../utils/inbox_read_store.dart';
import '../providers/events.dart';
import '../providers/AppStateManager.dart';
import '../widgets/premium_confirm_dialog.dart';

class InboxListScreenState extends StatelessWidget {
  static const routeName = "/inboxlist";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.inbox),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 12),
        child: InboxScreenBody(),
      ),
    );
  }
}

class InboxScreenBody extends StatefulWidget {
  @override
  InboxScreenBodyRouteState createState() => new InboxScreenBodyRouteState();
}

class InboxScreenBodyRouteState extends State<InboxScreenBody> {
  List<Inbox>? items = [];
  bool isLoading = false;
  bool isError = false;
  RefreshController refreshController =
      RefreshController(initialRefresh: false);
  int page = 0;

  void _onRefresh() async {
    loadItems();
  }

  void _onLoading() async {
    loadMoreItems();
  }

  loadItems() {
    refreshController.requestRefresh();
    page = 0;
    setState(() {});
    fetchItems();
  }

  loadMoreItems() {
    page = page + 1;
    fetchItems();
  }

  void setItems(List<Inbox>? item) {
    items!.clear();
    items = item;
    refreshController.refreshCompleted();
    isError = false;
    setState(() {});
  }

  void setMoreItems(List<Inbox> item) {
    refreshController.loadComplete();
    isError = false;
    items!.addAll(item);
    setState(() {});
  }

  Future<void> fetchItems() async {
    try {
      final dio = Dio();
      final user =
          Provider.of<AppStateManager>(context, listen: false).userdata;
      // Adding an interceptor to enable caching.

      final response = await dio.post(
        ApiUrl.INBOX,
        data: jsonEncode({
          "data": {
            "page": page.toString(),
            if (user?.apiToken?.isNotEmpty == true) "api_token": user!.apiToken,
            if (user?.email?.isNotEmpty == true) "email": user!.email,
          }
        }),
      );

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        dynamic res = decodeApiResponse(response.data);
        print(res);
        List<Inbox> mediaList = parseSliderMedia(res);
        if (page == 0) {
          setItems(mediaList);
        } else {
          setMoreItems(mediaList);
        }
      } else {
        // If the server did not return a 200 OK response,
        // then throw an exception.
        setFetchError();
      }
    } catch (exception) {
      // I get no exception here
      print(exception);
      setFetchError();
    }
  }

  static List<Inbox> parseSliderMedia(dynamic res) {
    final rawItems = res is Map ? res["inbox"] : null;
    if (rawItems is! List) return const <Inbox>[];
    return rawItems
        .whereType<Map>()
        .map((json) => Inbox.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  setFetchError() {
    if (page == 0) {
      setState(() {
        isError = true;
        refreshController.refreshFailed();
      });
    } else {
      setState(() {
        refreshController.loadFailed();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 0), () {
      loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _confirmDeleteRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Delete read'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0C2230),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        Expanded(
          child: SmartRefresher(
            enablePullDown: true,
            enablePullUp: true,
            header: WaterDropHeader(),
            footer: CustomFooter(
              builder: (BuildContext context, LoadStatus? mode) {
                Widget body;
                if (mode == LoadStatus.idle) {
                  body = Text(t.pulluploadmore);
                } else if (mode == LoadStatus.loading) {
                  body = CupertinoActivityIndicator();
                } else if (mode == LoadStatus.failed) {
                  body = Text(t.loadfailedretry);
                } else if (mode == LoadStatus.canLoading) {
                  body = Text(t.releaseloadmore);
                } else {
                  body = Text(t.nomoredata);
                }
                return SizedBox(
                  height: 55.0,
                  child: Center(child: body),
                );
              },
            ),
            controller: refreshController,
            onRefresh: _onRefresh,
            onLoading: _onLoading,
            child: (isError == true && items!.length == 0)
                ? NoitemScreen(
                    title: t.oops,
                    message: t.dataloaderror,
                    onClick: _onRefresh,
                  )
                : ListView.builder(
                    itemCount: items!.length,
                    scrollDirection: Axis.vertical,
                    padding: EdgeInsets.all(3),
                    itemBuilder: (BuildContext context, int index) {
                      return ItemTile(
                        object: items![index],
                        onDeleted: () {
                          setState(() {
                            items!.removeAt(index);
                          });
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteRead() async {
    final readIds = await InboxReadStore.readIds();
    final visibleReadIds = items!
        .map((item) => item.id?.toString() ?? '')
        .where((id) => id.isNotEmpty && readIds.contains(id))
        .toList();

    if (visibleReadIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No read notifications to delete.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) => PremiumConfirmDialog(
        title: 'Delete read notifications?',
        message:
            'This will permanently remove ${visibleReadIds.length} read notification${visibleReadIds.length == 1 ? '' : 's'} from your account. Deleted messages will not return after reinstalling the app.',
        cancelLabel: t.cancel,
        confirmLabel: 'Delete',
        icon: Icons.done_all_rounded,
        confirmIcon: Icons.delete_outline_rounded,
        isDanger: true,
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );

    if (confirmed == true) {
      await _deleteReadNotifications(visibleReadIds);
    }
  }

  Future<void> _deleteReadNotifications(List<String> ids) async {
    final user = Provider.of<AppStateManager>(context, listen: false).userdata;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please sign in to delete notifications.')),
      );
      return;
    }

    try {
      final response = await Dio().post(
        ApiUrl.DELETE_INBOX,
        data: jsonEncode({
          'data': {
            'mode': 'read',
            'read_ids': ids,
            if (user.apiToken?.isNotEmpty == true) 'api_token': user.apiToken,
            if (user.email?.isNotEmpty == true) 'email': user.email,
          }
        }),
      );
      final res = decodeApiResponse(response.data);
      if ('${res['status']}' != 'ok') {
        throw Exception(
            '${res['message'] ?? 'Unable to delete notifications.'}');
      }

      final deleted = ids.toSet();
      setState(() {
        items!.removeWhere((item) => deleted.contains(item.id?.toString()));
      });
      eventBus.fire(const InboxNotificationsChanged());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${res['deleted_count'] ?? ids.length} read notification${ids.length == 1 ? '' : 's'} deleted.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }
}

class ItemTile extends StatelessWidget {
  final Inbox object;
  final VoidCallback? onDeleted;

  const ItemTile({
    Key? key,
    required this.object,
    this.onDeleted,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = (object.title ?? '').trim().isEmpty
        ? 'Inbox message'
        : object.title!.trim();
    final firstLetter = title.substring(0, 1).toUpperCase();
    final date =
        object.date == null ? '' : TimUtil.formatDatestamp(object.date!);
    final time =
        object.date == null ? '' : TimUtil.formatTimestamp(object.date!);
    final messagePreview = _plainInboxPreview(object.message);
    final avatarColor = Colors.primaries[
        (object.id ?? title.hashCode).abs() % Colors.primaries.length];

    return InkWell(
      onTap: () async {
        InboxReadStore.markRead(object.id);
        eventBus.fire(const InboxNotificationsChanged());
        final deleted =
            await Navigator.of(context).pushNamed(InboxViewerScreen.routeName,
                arguments: ScreenArguements(
                  position: 0,
                  items: object,
                  itemsList: [],
                ));
        if (deleted == true) {
          onDeleted?.call();
        }
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
        child: Column(
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 31,
                  backgroundColor: avatarColor,
                  backgroundImage: object.imageUrl?.isNotEmpty == true
                      ? CachedNetworkImageProvider(object.imageUrl!)
                      : null,
                  child: object.imageUrl?.isNotEmpty == true
                      ? null
                      : Text(
                          firstLetter,
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.caption(context)
                                  .copyWith(fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyles.caption(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyles.subhead(context).copyWith(
                          fontSize: 15,
                          height: 1.22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (messagePreview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          messagePreview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyles.caption(context).copyWith(
                            fontSize: 13,
                            height: 1.22,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(
              height: 1,
              //color: Colors.grey.shade800,
            )
          ],
        ),
      ),
    );
  }
}

String _plainInboxPreview(String? message) {
  final text = (message ?? '')
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.toLowerCase() == 'null' ? '' : text;
}
