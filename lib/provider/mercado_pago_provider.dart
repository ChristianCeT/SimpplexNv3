import 'dart:convert';

import 'package:client_exhibideas/api/enviroment.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_document_type.dart';
import 'package:client_exhibideas/models/mercado_pago/mercado_pago_payment_method_installments.dart';
import 'package:client_exhibideas/models/orders.dart';
import 'package:client_exhibideas/models/user.dart';
import 'package:client_exhibideas/utils/share_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;

class MercadoPagoProvider {
  final String _urlMercadoPago = 'api.mercadopago.com';
  final String _url = Enviroment.API_DELIVERY;
  final String _urlGuardarOrden = "/api/payments/createPay";

  final _mercadoPagoCredentials = Enviroment.mercadoPagoCredentials;

  User user;
  BuildContext context;

  Future init(BuildContext context, User user) {
    this.context = context;
    this.user = user;
  }

  Future<List<MercadoPagoDocumentType>> getIdentificacionTtpes() async {
    try {
      final url = Uri.https(_urlMercadoPago, '/v1/identification_types', {
        'access_token': _mercadoPagoCredentials.accessToken,
      });
      // ignore: avoid_print
      print("URL $url");

      final res = await http.get(url);

      final data = json.decode(res.body);

      final result = MercadoPagoDocumentType.fromJsonList(data);

      return result.documentTypeList;
    } catch (e) {
      return null;
    }
  }

  Future<http.Response> createPayment({
    @required String cardId,
    @required double transactionAmount,
    @required int installments,
    @required String paymentMethodId,
    @required String paymentTypeId,
    @required String issuerId,
    @required String emailCustomer,
    @required String cardToken,
    @required String identificationType,
    @required String identificationNumber,
    @required Order order,
  }) async {
    try {
      Uri url = Uri.https(_url, _urlGuardarOrden, {
        _urlGuardarOrden: _mercadoPagoCredentials.publicKey,
      });
      // ignore: avoid_print
      print("URL DE CREAR PAGO $url");

      Map<String, dynamic> body = {
        'order': order,
        'card_id': cardId,
        'description': 'Flutter EXHIBIDEAS',
        'transaction_amount': transactionAmount,
        'installments': installments,
        'payment_method_id': paymentMethodId,
        'payment_type_id': paymentTypeId,
        'token': cardToken,
        'issuer_id': issuerId,
        'payer': {
          'email': emailCustomer,
          'identification': {
            'type': identificationType,
            'number': identificationNumber,
          }
        }
      };

      String bodyParams = json.encode(body);
      Map<String, String> headers = {
        "Content-type": "application/json",
        "Authorization": user.sessionToken
      };

      final res = await http.post(url, headers: headers, body: bodyParams);

      if (res.statusCode == 404) {
        Fluttertoast.showToast(msg: "Sesi??n expirada");
        SharedPref().logout(context, user.id);
      }

      return res;
    } catch (e) {
      return null;
    }
  }

  Future<MercadoPagoPaymentMethodInstallments> getInstallments(
      String bin, double amount) async {
    try {
      final url =
          Uri.https(_urlMercadoPago, '/v1/payment_methods/installments', {
        'access_token': _mercadoPagoCredentials.accessToken,
        'bin': bin,
        'amount': '$amount',
      });

      final res = await http.get(url);

      final data = json.decode(res.body);

      final result = MercadoPagoPaymentMethodInstallments.fromJsonList(data);

      return result.installmentList.first;
    } catch (e) {
      return null;
    }
  }

  Future<http.Response> createCardToken({
    String cvv,
    String expirationYear,
    int expirationMonth,
    String cardNumber,
    String documentNumber,
    String documentId,
    String cardHolderName,
  }) async {
    try {
      final url = Uri.https(_urlMercadoPago, '/v1/card_tokens', {
        'public_key': _mercadoPagoCredentials.publicKey,
      });

      final body = {
        'security_code': cvv,
        'expiration_year': expirationYear,
        'expiration_month': expirationMonth,
        'card_number': cardNumber,
        'cardholder': {
          'identification': {
            'number': documentNumber,
            'type': documentId,
          },
          'name': cardHolderName
        }
      };

      final res = await http.post(url, body: json.encode(body));

      return res;
    } catch (e) {
      return null;
    }
  }
}
