import 'package:flrb/searchfilter.dart' show SearchFilter;
import 'package:flutter/material.dart' hide Element;
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:quiver/core.dart' show hash2;

class Recipe {
  String? title;
  String? url;
  String? thumbnail;
  String? difficulty;
  String? preptime;

  Recipe(this.title, this.url, this.thumbnail, this.difficulty, this.preptime);

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(json['title'], json['url'], json['thumbnail'],
        json['difficulty'], json['preptime']);
  }

  factory Recipe.fromCkDocSelection(CKDocSelection sel) {
    return Recipe(sel.title(), sel.url(), sel.thumbnail(), sel.difficulty(),
        sel.preptime());
  }
}

@immutable
class RecipeDetail {
  final String? title;
  final String? rating;
  final String? difficulty;
  final String? cookingtime;
  final String? thumbnail;
  final List<RecipeIngredient> ingredients;
  final String? method;

  const RecipeDetail(
      {this.title,
      this.rating,
      this.difficulty,
      this.cookingtime,
      this.thumbnail,
      required this.ingredients,
      this.method});

  factory RecipeDetail.fromJson(Map<String, dynamic> json) {
    return RecipeDetail(
        title: json['title'],
        rating: json['rating'],
        difficulty: json['difficulty'],
        cookingtime: json['cookingtime'],
        thumbnail: json['thumbnail'],
        ingredients: json['ingredients'] ?? [],
        method: json['method']);
  }

  factory RecipeDetail.fromDoc(CKRecipeDetailDocument doc) {
    return RecipeDetail(
      title: doc.title(),
      rating: doc.rating(),
      difficulty: doc.difficulty(),
      cookingtime: doc.cookingtime(),
      thumbnail: doc.thumbnail(),
      ingredients: doc.ingredients(),
      method: doc.method(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'rating': rating,
      'difficulty': difficulty,
      'cookingtime': cookingtime,
      'thumbnail': thumbnail,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'method': method,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is RecipeDetail && other.thumbnail == thumbnail;

  @override
  int get hashCode => hash2(title.hashCode, thumbnail.hashCode);
}

class RecipeIngredient {
  String? amount;
  String? ingredient;

  RecipeIngredient(this.amount, this.ingredient);

  RecipeIngredient.fromJson(Map<String, dynamic> json)
      : amount = json['amount'],
        ingredient = json['ingredient'];

  Map<String, dynamic> toJson() => {'amount': amount, 'ingredient': ingredient};
}

class SearchQuery {
  String searchterm;
  String page;
  SearchFilter searchFilter;

  SearchQuery(this.searchterm, this.page, this.searchFilter);
}

const cKPrefix = 'www.chefkoch.de';
const bBGFPrefix = 'www.bbcgoodfood.com/search';

class RecDocument {
  String searchterm;
  String page;
  String searchfilter;

  RecDocument(this.searchterm, this.page, this.searchfilter);

  Future<String> getPage() async {
    http.Response response = await http.get(queryUrl());
    return response.body;
  }

  Uri queryUrl() {
    var addr = '$cKPrefix/rs/s$page$searchfilter/$searchterm/Rezepte.html';
    return Uri.https(addr, '');
  }

  Future<Document> getDoc() async {
    String ckbody = await getPage();
    return parse(ckbody);
  }
}

class CKDocument extends RecDocument {
  String searchterm;
  String page;
  String searchfilter;

  CKDocument(this.searchterm, this.page, this.searchfilter)
      : super(searchterm, page, searchfilter);
}

class BGFDocument extends RecDocument {
  String searchterm;
  String page;
  String searchfilter;

  BGFDocument(this.searchterm, this.page, this.searchfilter)
      : super(searchterm, page, searchfilter);

  @override
  Uri queryUrl() {
    var addr =
        '$bBGFPrefix/recipes?query=$searchterm&page=$page${searchfilter != "" ? "&sort=" + searchfilter : ""}';
    return Uri.https(addr, '');
  }
}

class DocSelection {
  Element node;

  DocSelection(this.node);
}

class CKDocSelection extends DocSelection {
  Element cknode;

  CKDocSelection(this.cknode) : super(cknode);

  String? title() {
    return cknode.querySelector(".ds-heading-link")?.text;
  }

  String? url() {
    var url = cknode.querySelector(".rsel-item > a");
    return url?.attributes["href"];
  }

  String? thumbnail() {
    var thumbs =
        cknode.querySelector(".ds-mb-left > amp-img")?.attributes["srcset"];
    var img = thumbs?.split('\n')[2].trim().replaceFirst(' 3x', '');
    if (img!.startsWith('//img')) {
      return 'https:$img';
    }
    return img;
  }

  String? difficulty() {
    return cknode
        .querySelector(".recipe-difficulty")
        ?.text
        .split('\n')[1]
        .trim();
  }

  String? preptime() {
    return cknode.querySelector(".recipe-preptime")?.text.split('\n')[1].trim();
  }
}

class BGFSelection extends DocSelection {
  Element bgfnode;

  BGFSelection(this.bgfnode) : super(bgfnode);

  String? title() {
    return bgfnode.querySelector('.teaser-item__title')?.text.trim();
  }

  String? url() {
    return 'https://www.bbcgoodfood.com${bgfnode.querySelector('.teaser-item__image > a')?.attributes["href"]}';
  }

  String? thumbnail() {
    return 'https:${bgfnode.querySelector('.teaser-item__image > a > img')?.attributes["src"]}';
  }

  String? preptime() {
    return bgfnode
        .querySelector(
            'li.teaser-item__info-item.teaser-item__info-item--total-time')
        ?.text
        .trim();
  }

  String? difficulty() {
    return bgfnode
        .querySelector(
            'li.teaser-item__info-item.teaser-item__info-item--skill-level')
        ?.text
        .trim();
  }
}

List<Recipe> recipes(Document doc) {
  var sels = doc.querySelectorAll('.rsel-item');
  return sels.map((i) => Recipe.fromCkDocSelection(CKDocSelection(i))).toList();
}

class RecipeDetailDocument {
  Document doc;

  RecipeDetailDocument(this.doc);

  String? title() {
    return doc.querySelector('h1')?.text.trim();
  }

  String? rating() {
    return doc.querySelector('.ds-rating-avg>span>strong')?.text.trim() ?? "";
  }

  String? difficulty() {
    return doc
        .querySelector('.recipe-difficulty')
        ?.text
        .replaceAll('\n', '')
        .replaceAll('', '')
        .trim();
  }

  String? cookingtime() {
    var ct = doc.querySelector('.recipe-preptime')?.text;
    var split = ct?.split('\n');
    return split?[1].trim();
  }

  String? thumbnail() {
    var thumbs = doc
        .querySelector('.bi-recipe-slider-open > amp-img')
        ?.attributes['srcset']!;
    var img = thumbs?.split('\n')[2].trim().replaceFirst(' 600w', '');
    return img;
  }

  String? method() {
    return doc.querySelector('.rds-recipe-meta+.ds-box')?.text.trimLeft();
  }

  List<RecipeIngredient> ingredients() {
    List<RecipeIngredient> ingredients = [];
    var ingtable = doc.querySelectorAll('.ingredients>tbody>tr');
    for (var i in ingtable) {
      var amount = i.querySelector('.td-left')!.text.trim();
      var amsplit = amount.split(' ');
      if (amsplit.length > 2) {
        amount = amsplit.first + ' ' + amsplit.last;
      }
      var ing = i.querySelector('.td-right')!.text.trim();
      ingredients.add(RecipeIngredient(amount, ing));
    }
    return ingredients;
  }
}

class CKRecipeDetailDocument extends RecipeDetailDocument {
  Document doc;

  CKRecipeDetailDocument(this.doc) : super(doc);
}

class BGFRecipeDetailDocument extends RecipeDetailDocument {
  Document doc;

  BGFRecipeDetailDocument(this.doc) : super(doc);

  @override
  String? title() {
    return doc.querySelector('.recipe-header__title')?.text;
  }

  @override
  String? rating() {
    return doc
        .querySelector('meta[itemprop="ratingValue"]')
        ?.attributes["content"];
  }

  @override
  String? difficulty() {
    return doc
        .querySelector('.recipe-details__item--skill-level > span')
        ?.text
        .trim();
  }

  @override
  String? cookingtime() {
    return doc
        .querySelector('.recipe-details__cooking-time-cook')
        ?.text
        .substring(7)
        .trim();
  }

  @override
  String? thumbnail() {
    return 'https:${doc.querySelector('.img-container > img')?.attributes['src']}';
  }

  List<String?> methodlist() {
    var ol = doc.querySelector('.method__list');
    if (ol != null) {
      return ol.children.map((i) => i.text).toList();
    }
    return [];
  }

  List<String> ingredientList() {
    return doc
        .querySelectorAll('.ingredients-list__item')
        .map((i) => i.attributes["content"]!.trim())
        .toList();
  }
}

Future<Document> getPage(Uri url) async {
  http.Response response = await http.get(url);
  return parse(response.body);
}
