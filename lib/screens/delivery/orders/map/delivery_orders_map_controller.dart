import 'dart:async';
import 'package:client_exhibideas/api/enviroment.dart';
import 'package:client_exhibideas/models/orders.dart';
import 'package:client_exhibideas/models/response_api.dart';
import 'package:client_exhibideas/models/user.dart';
import 'package:client_exhibideas/provider/orders_provider.dart';
import 'package:client_exhibideas/screens/delivery/orders/list/delivery_orders_list_page.dart';
import 'package:client_exhibideas/utils/my_snackbar.dart';
import 'package:client_exhibideas/utils/share_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import "package:location/location.dart" as location;
import 'package:url_launcher/url_launcher.dart';

class DeliveryOrdersMapController {
  BuildContext context;
  Function refresh;
  Position _position;
  StreamSubscription _positionStream;
  String addressName;
  LatLng addressLaglng;

  CameraPosition initialPosition = CameraPosition(
      target: LatLng(-11.991651, -77.0147332), zoom: 20); // zoom del 1 al 20

  Completer<GoogleMapController> _mapController = Completer();

  BitmapDescriptor deliveryMarker;
  BitmapDescriptor homeMarker;

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};

  OrdersProvider _ordersProvider = new OrdersProvider();
  User user;
  SharedPref _sharedPref = new SharedPref();
  Order order;
  double _distanceBetween;

  IO.Socket socket;

  Future init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    order = Order.fromJson(ModalRoute.of(context).settings.arguments
        as Map<String, dynamic>); // obtener datos de un argumento de la orden
    deliveryMarker =
        await createMarketFromAssets('assets/images/delivery3.png');
    homeMarker = await createMarketFromAssets('assets/images/home1.png');

    socket = IO.io(
        'http://${Enviroment.API_DELIVERY}/orders/delivery', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();

    user = User.fromJson(await _sharedPref.read("user"));
    _ordersProvider.init(context, user);

    checkGPS();
    refresh();
  }

  void saveLocation() async {
    order.latitud = _position.latitude;
    order.longitud = _position.longitude;
    await _ordersProvider.updateLatLong(order);
  }

  void emitPosition() {
    socket.emit('posicion', {
      'id_order': order.id,
      'latitud': _position.latitude,
      'longitud': _position.longitude,
    });
  }

  void isCloseToDeliveredPosition() {
    _distanceBetween = Geolocator.distanceBetween(_position.latitude,
        _position.longitude, order.direccion.latitud, order.direccion.longitud);
    print("----Distancia ${_distanceBetween} ---------");
  }

  void launchWaze() async {
    var url =
        'waze://?ll=${order.direccion.latitud.toString()},${order.direccion.longitud.toString()}';
    var fallbackUrl =
        'https://waze.com/ul?ll=${order.direccion.latitud.toString()},${order.direccion.longitud.toString()}&navigate=yes';
    try {
      bool launched =
          await launch(url, forceSafariVC: false, forceWebView: false);
      if (!launched) {
        await launch(fallbackUrl, forceSafariVC: false, forceWebView: false);
      }
    } catch (e) {
      await launch(fallbackUrl, forceSafariVC: false, forceWebView: false);
    }
  }

  void launchGoogleMaps() async {
    var url =
        'google.navigation:q=${order.direccion.latitud.toString()},${order.direccion.longitud.toString()}';
    var fallbackUrl =
        'https://www.google.com/maps/search/?api=1&query=${order.direccion.latitud.toString()},${order.direccion.longitud.toString()}';
    try {
      bool launched =
          await launch(url, forceSafariVC: false, forceWebView: false);
      if (!launched) {
        await launch(fallbackUrl, forceSafariVC: false, forceWebView: false);
      }
    } catch (e) {
      await launch(fallbackUrl, forceSafariVC: false, forceWebView: false);
    }
  }

  void updateToDelivered() async {
    if (_distanceBetween == null) {
      return;
    }
    if (_distanceBetween <= 200) {
      ResponseApi responseApi = await _ordersProvider.updateToDelivered(order);
      if (responseApi.success) {
        Fluttertoast.showToast(
            msg: responseApi.message, toastLength: Toast.LENGTH_LONG);
        Navigator.pushNamedAndRemoveUntil(
            context, DeliveryOrdersListPage.routeName, (route) => false);
      }
    } else {
      MySnackBar.show(
          context, "Debes estar más cerca de la posición de entrega");
    }
  }

  void addMarker(String markerId, double lat, double long, String title,
      String content, BitmapDescriptor iconMarker) {
    MarkerId id = MarkerId(markerId);
    Marker marker = Marker(
        markerId: id,
        icon: iconMarker,
        position: LatLng(lat, long),
        infoWindow: InfoWindow(title: title, snippet: content));

    markers[id] = marker;
    refresh();
  }

  // geocoder: ^0.2.1 si algo no funciona

  void selectRefPoint() async {
    Map<String, dynamic> data = {
      "address": addressName,
      "lat": addressLaglng.latitude,
      "lng": addressLaglng.longitude,
    };
// pasar la informacion al navigator cerrando la pestaña
    Navigator.pop(context, data);
  }

  Future<BitmapDescriptor> createMarketFromAssets(String path) async {
    ImageConfiguration configuration = ImageConfiguration();
    BitmapDescriptor descriptor =
        await BitmapDescriptor.fromAssetImage(configuration, path);
    return descriptor;
  }

  Future<Null> setLocationDraggableInfo() async {
    if (initialPosition != null) {
      double lat = initialPosition.target.latitude;
      double long = initialPosition.target.longitude;
      List<Placemark> address = await placemarkFromCoordinates(lat, long);

      if (address != null) {
        if (address.length > 0) {
          String direction = address[0].thoroughfare;
          String street = address[0].subThoroughfare;
          String city = address[0].locality;
          String deparment = address[0].administrativeArea;
          /* String country = address[0].country; */
          addressName = '$direction #$street, $city, $deparment';
          addressLaglng = new LatLng(lat, long);

          refresh();
        }
      }
    }
  }

  void onMapCreate(GoogleMapController controller) {
    controller.setMapStyle(
        '[{"elementType":"geometry","stylers":[{"color":"#f5f5f5"}]},{"elementType":"labels.icon","stylers":[{"visibility":"off"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#f5f5f5"}]},{"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},{"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},{"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dadada"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},{"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},{"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e5e5e5"}]},{"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eeeeee"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#c9c9c9"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]}]');
    _mapController.complete(controller);
  }

  void dispose() {
    _positionStream?.cancel();
    socket?.disconnect(); // desconectar el socket
  }

  void updateLocation() async {
    try {
      await _determinePosition(); // OBTENER LA POSICIÓN ACTUAL Y SOLICITAR PERMISOS
      _position = await Geolocator
          .getLastKnownPosition(); // obtener la ultima posicion del dispositivo la latitud y longitud actual es lo que devuelve
      saveLocation();
      animatedCameraToPosition(order.latitud, order.longitud);
      addMarker("Delivery", order.latitud, order.longitud, "Tu posición", "",
          deliveryMarker);
      addMarker("Home", order.direccion.latitud, order.direccion.longitud,
          "Lugar de entrega", "", homeMarker);

      //setPolylines
      animatedCameraToPosition(_position.latitude, _position.longitude);
      isCloseToDeliveredPosition();
      refresh();
    } catch (e) {
      print("ERROR $e");
    }
  }

  void call() {
    launch("tel://${order?.cliente?.telefono}");
  }

  void checkGPS() async {
    bool isLocationEnabled = await Geolocator.isLocationServiceEnabled();
    if (isLocationEnabled) {
      updateLocation();
    } else {
      //requerir que el usuario habilite el GPs
      bool locationGPS = await location.Location()
          .requestService(); // solicitar al usuario activar el gps para continuar
      if (locationGPS) {
        updateLocation();
      }
    }
  }

  Future animatedCameraToPosition(double lat, double long) async {
    GoogleMapController controller = await _mapController.future;
    if (controller != null) {
      controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, long), zoom: 15, bearing: 0),
      ));
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled; // para saber si la localizacion está activada GPS
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}