import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

import '../utils/ApiUrl.dart';
import '../utils/TextStyles.dart';
import '../utils/api_response.dart';

class AboutUsScreen extends StatefulWidget {
  static const routeName = '/about-us';
  static const privacyRouteName = '/privacy-page';
  static const termsRouteName = '/terms-page';

  const AboutUsScreen({
    Key? key,
    this.type = 'about',
    this.title = 'About Us',
  }) : super(key: key);

  final String type;
  final String title;

  @override
  State<AboutUsScreen> createState() => _AboutUsScreenState();
}

class _AboutUsScreenState extends State<AboutUsScreen> {
  bool isLoading = true;
  bool isError = false;
  Map<String, dynamic>? page;

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  Future<void> _loadPage() async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      final response = await Dio().get(ApiUrl.CONTENT_PAGE + widget.type);
      final data = decodeApiResponse(response.data);
      setState(() {
        page = data['page'] as Map<String, dynamic>?;
        isLoading = false;
        isError = page == null;
      });
    } catch (error) {
      setState(() {
        isLoading = false;
        isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 18));
          }

          if (isError) {
            return Center(
              child: ElevatedButton(
                onPressed: _loadPage,
                child: const Text('Retry'),
              ),
            );
          }

          final sections = ((page?['sections'] as List?) ?? const [])
              .cast<Map<String, dynamic>>();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              if (_hasImage(page?['hero_image']))
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: page!['hero_image'],
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                page?['title']?.toString() ?? 'About Us',
                style: TextStyles.headline(context)
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              HtmlWidget(page?['body']?.toString() ?? ''),
              ...sections.map((section) => _AboutSection(section: section)),
            ],
          );
        },
      ),
    );
  }

  bool _hasImage(dynamic url) {
    final value = url?.toString() ?? '';
    return value.startsWith('http://') || value.startsWith('https://');
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.section});

  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final image = section['image']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image.startsWith('http://') || image.startsWith('https://'))
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: image,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          if ((section['title']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              section['title'].toString(),
              style: TextStyles.title(context)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          HtmlWidget(section['body']?.toString() ?? ''),
        ],
      ),
    );
  }
}
