import 'dart:async';
import 'package:client_exhibideas/models/category.dart';
import 'package:client_exhibideas/models/product.dart';
import 'package:client_exhibideas/models/user.dart';
import 'package:client_exhibideas/provider/categories_provider.dart';
import 'package:client_exhibideas/provider/products_provider.dart';
import 'package:client_exhibideas/screens/client/orders/create/client_orders_create_page.dart';
import 'package:client_exhibideas/screens/client/orders/list/client_orders_list_page.dart';
import 'package:client_exhibideas/screens/client/products/details/client_products_details_page.dart';
import 'package:client_exhibideas/screens/roles/roles_page.dart';
import 'package:client_exhibideas/utils/share_preferences.dart';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ClientProductsListController {
  BuildContext context;
  Function refresh;
  User user;

  List<Category> categories = [];

  final CategoriesProvider _categoriesProvider = CategoriesProvider();
  final ProductsProvider _productsProvider = ProductsProvider();

  SharedPref sharedPref = SharedPref();

  GlobalKey<ScaffoldState> key = GlobalKey<ScaffoldState>();

  Timer searchOnStoppedTyping;
  String productName = '';

  Future init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    user = User.fromJson(
        await sharedPref.read("user")); // PUEDE TARDAR UN TIEMPO EN OBTENER
    _categoriesProvider.init(context, user);
    _productsProvider.init(context, user);
    getCategories(); // llamar al metodo
    refresh();
  }

  void openBottomSheets(Product product) {
    showMaterialModalBottomSheet(
        context: context,
        builder: (context) => ClientProductDetailsPage(
              product: product,
            ));
  }

  void onChangeText(String text) {
    Duration duration = const Duration(milliseconds: 800);
    if (searchOnStoppedTyping != null) {
      searchOnStoppedTyping.cancel();
      refresh();
    }
    searchOnStoppedTyping = Timer(duration, () {
      productName = text;
      refresh();
    });
  }

  Future<List<Product>> getProducts(
      String idCategory, String productName) async {
    if (productName.isEmpty) {
      return await _productsProvider.getByCategory(idCategory);
    } else {
      return await _productsProvider.getByCategoryAndProductName(
          idCategory, productName);
    }
  }

  void getCategories() async {
    categories = await _categoriesProvider.getAll();
    refresh();
  }

  logout() {
    sharedPref.logout(context, user.id);
  }

  void goToOrdersList() {
    Navigator.pushNamed(context, ClientOrdersListPage.routeName);
  }

  void openDrawer() {
    key.currentState.openDrawer();
  }

  void goToRoles() {
    Navigator.pushNamedAndRemoveUntil(
        context, RolesPage.routeName, (route) => false);
  }

  void goToOrderCreatePage() {
    Navigator.pushNamed(context, ClientOrderCreatePage.routeName);
  }
}
