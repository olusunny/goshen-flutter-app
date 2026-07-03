import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/Categories.dart';
import '../models/ScreenArguements.dart';
import '../providers/CategoriesModel.dart';
import '../screens/NoitemScreen.dart';
import '../screens/CategoriesMediaScreen.dart';
import '../i18n/strings.g.dart';

class CategoriesScreen extends StatefulWidget {
  static const routeName = "/categories";
  CategoriesScreen();

  @override
  CategoriesScreenRouteState createState() => new CategoriesScreenRouteState();
}

class CategoriesScreenRouteState extends State<CategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => CategoriesModel(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.categories),
        ),
        body: Padding(
          padding: EdgeInsets.only(top: 12),
          child: CategoriesPageBody(),
        ),
      ),
    );
  }
}

class CategoriesPageBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    CategoriesModel categoriesModel = Provider.of<CategoriesModel>(context);
    final items = categoriesModel.categories ?? const <Categories>[];
    if (categoriesModel.isLoading) {
      return Center(
          child: CupertinoActivityIndicator(
        radius: 20,
      ));
    } else if (categoriesModel.isError) {
      return NoitemScreen(
          title: t.oops,
          message: t.dataloaderror,
          onClick: () {
            categoriesModel.loadItems();
          });
    } else if (items.isEmpty) {
      return NoitemScreen(
          title: t.oops,
          message: t.dataloaderror,
          onClick: () {
            categoriesModel.loadItems();
          });
    } else {
      return GridView.builder(
        itemCount: items.length,
        scrollDirection: Axis.vertical,
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10.0,
            mainAxisSpacing: 18.0,
            childAspectRatio: 0.78),
        itemBuilder: (BuildContext context, int index) {
          return ItemTile(
            index: index,
            categories: items[index],
          );
        },
      );
    }
  }
}

class ItemTile extends StatelessWidget {
  final Categories categories;
  final int index;

  const ItemTile({
    Key? key,
    required this.index,
    required this.categories,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final rawTitle = categories.title?.trim() ?? '';
    final title = rawTitle.isEmpty ? 'Untitled category' : rawTitle;
    final thumbnailUrl = (categories.thumbnailUrl ?? '').trim();
    final mediaCount = categories.mediaCount ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 0.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: thumbnailUrl.isEmpty
                      ? const _CategoryImageFallback()
                      : CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          imageBuilder: (context, imageProvider) => Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          placeholder: (context, url) =>
                              const Center(child: CupertinoActivityIndicator()),
                          errorWidget: (context, url, error) =>
                              const _CategoryImageFallback(),
                        ),
                ),
              ),
              const SizedBox(height: 9.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Text(
                      "$mediaCount ${t.messages}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.0,
                        color: Colors.blueGrey[300],
                      ),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        onTap: () {
          if (categories.id == null) return;
          Navigator.pushNamed(
            context,
            CategoriesMediaScreen.routeName,
            arguments: ScreenArguements(position: 0, items: categories),
          );
        },
      ),
    );
  }
}

class _CategoryImageFallback extends StatelessWidget {
  const _CategoryImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEAF1F4),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF8EA0AA),
          size: 34,
        ),
      ),
    );
  }
}
