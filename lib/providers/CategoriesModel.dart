import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import '../utils/ApiUrl.dart';
import '../utils/api_response.dart';
import '../models/Categories.dart';

class CategoriesModel with ChangeNotifier {
  //List<Comments> _items = [];
  bool isError = false;
  bool isLoading = false;
  List<Categories>? categories;

  CategoriesModel() {
    loadItems();
  }

  loadItems() {
    isLoading = true;
    notifyListeners();
    fetchItems();
  }

  Future<void> fetchItems() async {
    try {
      final dio = Dio();

      final response = await dio.get(
        ApiUrl.CATEGORIES,
      );

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        isLoading = false;
        isError = false;

        dynamic res = decodeApiResponse(response.data);
        categories = parseCategories(res);
        notifyListeners();
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

  static List<Categories>? parseCategories(dynamic res) {
    final rawItems = res is Map ? res["categories"] : null;
    if (rawItems is! List) return const <Categories>[];
    return rawItems
        .whereType<Map>()
        .map((json) => Categories.fromJson(Map<String, dynamic>.from(json)))
        .where((category) => category.id != null)
        .toList();
  }

  setFetchError() {
    isError = true;
    isLoading = false;
    notifyListeners();
  }
}
