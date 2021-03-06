import 'dart:convert';
import 'dart:io';
import 'package:client_exhibideas/models/category.dart';
import 'package:client_exhibideas/models/product.dart';
import 'package:client_exhibideas/models/response_api.dart';
import 'package:client_exhibideas/models/user.dart';
import 'package:client_exhibideas/provider/categories_provider.dart';
import 'package:client_exhibideas/provider/products_provider.dart';
import 'package:client_exhibideas/utils/my_snackbar.dart';
import 'package:client_exhibideas/utils/share_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';

class AdminProductsCreateController {
  BuildContext context;
  Function refresh;

  TextEditingController nameController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController linkRAController = TextEditingController();
  MoneyMaskedTextController priceController =  MoneyMaskedTextController();

  final CategoriesProvider _categoriesProvider = CategoriesProvider();
  final ProductsProvider _productsProvider = ProductsProvider();

  User user;

  SharedPref sharedPref = SharedPref();

  List<Category> categories = [];
  String idCategory; // almacena el id de la categoria seleccionada

  //imagenes
  PickedFile pickedFile;
  File imageFile1;
  File imageFile2;
  File imageFile3;

  ProgressDialog _progressDialog;

  Future init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    _progressDialog = ProgressDialog(context: context);
    user = User.fromJson(await sharedPref.read("user"));
    _categoriesProvider.init(context, user);
    _productsProvider.init(context, user);

    getCategories();
    refresh();
  }

  void getCategories() async {
    categories = await _categoriesProvider.getAll();
    refresh();
  }

  void createProduct() async {
    String name = nameController.text;
    String description = descriptionController.text;
    String linkRA = linkRAController.text;
    double price = priceController.numberValue; // obtener valores enteros

    if (name.isEmpty || description.isEmpty || price == 0 || linkRA.isEmpty) {
      MySnackBar.show(context, "Debe ingresar todos los campos");
      return;
    }

    if (imageFile1 == null || imageFile2 == null || imageFile3 == null) {
      MySnackBar.show(context, "Selecciona las 3 im??genes");
      return;
    }

    if (idCategory == null) {
      MySnackBar.show(context, "Debe selecciona la categor??a del producto");
      return;
    }

    Product product = Product(
      nombre: name,
      descripcion: description,
      linkRA: linkRA,
      precio: price,
      categoria: idCategory,
    );

    List<File> images = [];
    images.add(imageFile1);
    images.add(imageFile2);
    images.add(imageFile3);

    _progressDialog.show(max: 100, msg: "Espere un momento");
    Stream stream = await _productsProvider.create(product, images);

    stream.listen((res) {
      _progressDialog.close();

      ResponseApi responseApi = ResponseApi.fromJson(json.decode(res));
      MySnackBar.show(context, responseApi.message);

      if (responseApi.success) {
        resetValues();
      }
    });

    print("Formulario Producto: ${product.toJson()}");
  }

  void resetValues() {
    nameController.text = "";
    descriptionController.text = "";
    linkRAController.text = "";
    priceController.text = "0.0";
    imageFile1 = null;
    imageFile2 = null;
    imageFile3 = null;
    idCategory = null;
    refresh();
  }

  Future selectedImage(ImageSource imageSource, int numberFile) async {
    pickedFile = await ImagePicker().getImage(source: imageSource);
    if (pickedFile != null) {
      if (numberFile == 1) {
        imageFile1 = File(pickedFile?.path);
      } else if (numberFile == 2) {
        imageFile2 = File(pickedFile?.path);
      } else if (numberFile == 3) {
        imageFile3 = File(pickedFile?.path);
      }
    }
    Navigator.pop(context);
    refresh();
  }

  void showAlertDialog(int numberFile) {
    Widget galleryButton = ElevatedButton(
        onPressed: () {
          selectedImage(ImageSource.gallery, numberFile);
        },
        child: const Text("Galer??a"));

    Widget cameraButton = ElevatedButton(
        onPressed: () {
          selectedImage(ImageSource.camera, numberFile);
        },
        child: const Text("Camara"));

    AlertDialog alertDialog = AlertDialog(
      title: const Text("Selecciona tu imagen"),
      actions: [galleryButton, cameraButton],
    );

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return alertDialog;
        });
  }
}
