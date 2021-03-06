import 'dart:convert';
import 'package:client_exhibideas/models/address.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_card_token.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_installment.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_issuer.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_payment.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_payment_method_installments.dart';
import 'package:client_exhibideas/models/orders.dart';
import 'package:client_exhibideas/models/product.dart';
import 'package:client_exhibideas/models/user.dart';
import 'package:client_exhibideas/provider/mercado_pago_provider.dart';
import 'package:client_exhibideas/screens/client/payments/status/client_status_installments_page.dart';
import 'package:client_exhibideas/utils/my_snackbar.dart';
import 'package:client_exhibideas/utils/share_preferences.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:sn_progress_dialog/sn_progress_dialog.dart';

class ClientPaymentsInstallmentsController {
  BuildContext context;
  Function refresh;

  final MercadoPagoProvider _mercadoPagoProvider =  MercadoPagoProvider();
  User user;
  final SharedPref _sharedPref = SharedPref();
  List<Product> selectedProducts = [];

  double totalPayment = 0;

  MercadoPagoPaymentMethodInstallments installments;
  MercadoPagoIssuer issuer; // contiene la informacion del banco emisor
  MercadoPagoPayment creditCardPayment;
  List<MercadoPagoInstallment> installmentsList = [];
  MercadoPagoCardToken cardToken;

  Address address;

  ProgressDialog progressDialog;
  String identificationType;
  String identificationNumber;
  String selectedInstallment;

  Future init(BuildContext context, Function refresh) async {
    this.context = context;
    this.refresh = refresh;
    Map<String, dynamic> arguments =
        ModalRoute.of(context).settings.arguments as Map<String, dynamic>;

    cardToken = MercadoPagoCardToken.fromJsonMap(await arguments['card_token']);
    identificationType = arguments['identification_type'];
    identificationNumber = arguments['identification_number'];

    progressDialog = ProgressDialog(context: context);

    selectedProducts =
        Product.fromJsonList(await _sharedPref.read("order")).toList;

    user = User.fromJson(await _sharedPref.read('user'));
    _mercadoPagoProvider.init(context, user);
    address = Address.fromJson(await _sharedPref.read('address'));

    getTotalPayment();
    getInstallments();
  }

  void getInstallments() async {
    installments = await _mercadoPagoProvider.getInstallments(
        cardToken?.firstSixDigits, totalPayment);

    installmentsList = installments?.payerCosts;
    issuer = installments?.issuer;

    refresh();
  }

  void getTotalPayment() {
    for (var product in selectedProducts) {
      totalPayment = totalPayment + (product.cantidad * product.precio);
    }
    refresh();
  }

  void createPay() async {
    if (selectedInstallment == null) {
      MySnackBar.show(context, "Debes seleccionar el numero de cuotas");
      return;
    }
    Order order = Order(
      direccion: address,
      cliente: user,
      producto: selectedProducts,
      estado: "PAGADO",
    );
    progressDialog.show(max: 100, msg: "Realizando transacci??n");

    Response response = await _mercadoPagoProvider.createPayment(
        cardId: cardToken.cardId,
        transactionAmount: totalPayment,
        installments: int.parse(selectedInstallment),
        paymentMethodId: installments.paymentMethodId,
        paymentTypeId: installments.paymentTypeId,
        issuerId: installments.issuer.id,
        emailCustomer: user.correo,
        cardToken: cardToken.id,
        identificationType: identificationType,
        identificationNumber: identificationNumber,
        order: order);

    progressDialog.close();

    if (response != null) {
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        print("Se gener?? un pago ${response.body}");
        creditCardPayment = MercadoPagoPayment.fromJsonMap(data);
        Navigator.pushNamedAndRemoveUntil(
            context, ClientPaymentsStatusPage.routeName, (route) => false,
            arguments: creditCardPayment.toJson());
            
      } else if (response.statusCode == 501) {
        if (data['err']['status'] == 400) {
          badRequestProcess(data);
        } else {
          badTokenProcess(data['status'], installments);
        }
      }
    }
  }

  ///SI SE RECIBE UN STATUS 400
  void badRequestProcess(dynamic data) {
    Map<String, String> paymentErrorCodeMap = {
      '3034': 'Informacion de la tarjeta invalida',
      '205': 'Ingresa el n??mero de tu tarjeta',
      '208': 'Digita un mes de expiraci??n',
      '209': 'Digita un a??o de expiraci??n',
      '212': 'Ingresa tu documento',
      '213': 'Ingresa tu documento',
      '214': 'Ingresa tu documento',
      '220': 'Ingresa tu banco emisor',
      '221': 'Ingresa el nombre y apellido',
      '224': 'Ingresa el c??digo de seguridad',
      'E301': 'Hay algo mal en el n??mero. Vuelve a ingresarlo.',
      'E302': 'Revisa el c??digo de seguridad',
      '316': 'Ingresa un nombre v??lido',
      '322': 'Revisa tu documento',
      '323': 'Revisa tu documento',
      '324': 'Revisa tu documento',
      '325': 'Revisa la fecha',
      '326': 'Revisa la fecha'
    };
    String errorMessage;
    print('CODIGO ERROR ${data['err']['cause'][0]['code']}');

    if (paymentErrorCodeMap.containsKey('${data['err']['cause'][0]['code']}')) {
      print('ENTRO IF');
      errorMessage = paymentErrorCodeMap['${data['err']['cause'][0]['code']}'];
    } else {
      errorMessage = 'No pudimos procesar tu pago';
    }
    MySnackBar.show(context, errorMessage);
    // Navigator.pop(context);
  }

  void badTokenProcess(
      String status, MercadoPagoPaymentMethodInstallments installments) {
    Map<String, String> badTokenErrorCodeMap = {
      '106': 'No puedes realizar pagos a usuarios de otros paises.',
      '109':
          '${installments.paymentMethodId} no procesa pagos en $selectedInstallment cuotas',
      '126': 'No pudimos procesar tu pago.',
      '129':
          '${installments.paymentMethodId} no procesa pagos del monto seleccionado.',
      '145': 'No pudimos procesar tu pago',
      '150': 'No puedes realizar pagos',
      '151': 'No puedes realizar pagos',
      '160': 'No pudimos procesar tu pago',
      '204':
          '${installments.paymentMethodId} no est?? disponible en este momento.',
      '801':
          'Realizaste un pago similar hace instantes. Intenta nuevamente en unos minutos',
    };
    String errorMessage;
    if (badTokenErrorCodeMap.containsKey(status.toString())) {
      errorMessage = badTokenErrorCodeMap[status];
    } else {
      errorMessage = 'No pudimos procesar tu pago';
    }
    MySnackBar.show(context, errorMessage);
    // Navigator.pop(context);
  }
}
