import 'package:equatable/equatable.dart';
import 'package:flrb/recipe.dart';
import 'package:flutter/cupertino.dart';

Future<List<Recipe>> fetchRecipes(SearchQuery searchQuery) async {
  var cdoc = CKDocument(searchQuery.searchterm, searchQuery.page.toString(),
      searchQuery.searchFilter.abbrev);
  var body = await cdoc.getDoc();
  return recipes(body);
}

Future<RecipeDetail> fetchRecipeDetail(Uri url) async {
  var doc = await getPage(url);
  return RecipeDetail.fromDoc(CKRecipeDetailDocument(doc));
}

@immutable
class RecipeSource extends Equatable {
  final String name;
  const RecipeSource(this.name);

  @override
  List<Object> get props => [name];
}

final List<RecipeSource> sources = [
  RecipeSource('Chefkoch'),
  RecipeSource('BBCGF'),
];
