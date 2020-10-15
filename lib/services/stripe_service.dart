import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:stripe_app/models/payment_intent_response.dart';
import 'package:stripe_app/models/stripe_custom_response.dart';
import 'package:stripe_payment/stripe_payment.dart';

class StripeService {
  // Singleton
  StripeService._privateConstructor();
  static final StripeService _instance = StripeService._privateConstructor();
  factory StripeService() => _instance;

  String _paymenApiUrl = 'https://api.stripe.com/v1/payment_intents';
  static String _secretKey = 'sk_test_51HbCMvGcoGkQVDsGYSxTkkqWdT1EfmOB1SR5EWUeUrPX2zKsMyz1eM4Hw5VdIb9ltQTg13nlCsp1lNojlSKRpvJM009Jjqg0bG';
  String _apiKey = 'pk_test_51HbCMvGcoGkQVDsGzwZsxvO4qXw3yHEjFTBbpvmLVnxkBnJZaupwIspUSJlF8TyMyQKrQZIyY65PilMgDEdRNzrQ00giPYHkPB';

  final headerOptions = new Options(
      contentType: Headers.formUrlEncodedContentType,
      headers: {
        'Authorization': 'Bearer ${StripeService._secretKey}'
      });

  void init() {
    StripePayment.setOptions(StripeOptions(
        publishableKey: this._apiKey,
        androidPayMode: 'test',
        merchantId: 'test'));
  }

  Future<StripeCustomResponse> pagarConTarjetaExiste(
      {@required String amount,
      @required String currency,
      @required CreditCard card}) async {
    try {
      final paymentMethod = await StripePayment.createPaymentMethod(
          PaymentMethodRequest(card: card));
      final stripeResponse = await this._realizarPago(
          amount: amount, currency: currency, paymentMethod: paymentMethod);
      return stripeResponse;
    } catch (e) {
      return StripeCustomResponse(ok: false, msg: e.toString());
    }
  }

  Future<StripeCustomResponse> pagarConNuevaTarjeta(
      {@required String amount, @required String currency}) async {
    try {
      final paymentMethod = await StripePayment.paymentRequestWithCardForm(
          CardFormPaymentRequest());
      final stripeResponse = await this._realizarPago(
          amount: amount, currency: currency, paymentMethod: paymentMethod);
      return stripeResponse;
    } catch (e) {
      return StripeCustomResponse(ok: false, msg: e.toString());
    }
  }

  Future pagarApplePayGooglePay(
      {@required String amount, @required String currency}) async {
    try{
      final newAmount = double.parse(amount) / 100;
      final token = await StripePayment.paymentRequestWithNativePay(
        androidPayOptions: AndroidPayPaymentRequest(
          currencyCode: currency,
          totalPrice: amount
        ),
        applePayOptions: ApplePayPaymentOptions(
          countryCode: 'US',
          currencyCode: currency,
          items: [
            ApplePayItem(
              label: 'Super producto 1',
              amount: '$newAmount'
            )
          ]
        )
      );
      final paymentMethod = await StripePayment.createPaymentMethod(
        PaymentMethodRequest(
          card: CreditCard(
            token: token.tokenId
          )
        )
      );
      final stripeResponse = await this._realizarPago(
          amount: amount, currency: currency, paymentMethod: paymentMethod);
      await StripePayment.completeNativePayRequest();
      return stripeResponse;
    }catch(e){
      return StripeCustomResponse(ok: false, msg: e.toString());
    }
  }

  Future<PaymentIntentResponse> _crearPaymentIntent(
      {@required String amount, @required String currency}) async {
    try {
      final dio = new Dio();
      final data = {'amount': amount, 'currency': currency};
      final resp =
          await dio.post(_paymenApiUrl, data: data, options: headerOptions);
      return PaymentIntentResponse.fromJson( resp.data );
    } catch (e) {
      print('Error en intento: ${e.toString()}');
      return PaymentIntentResponse(status: '400');
    }
  }

  Future<StripeCustomResponse> _realizarPago(
      {@required String amount,
      @required String currency,
      @required PaymentMethod paymentMethod}) async {
    try {
      // Create Inent
      final paymentIntent =
          await this._crearPaymentIntent(amount: amount, currency: currency);
      // Confirm Intent
      final paymentResult = await StripePayment.confirmPaymentIntent(
          PaymentIntent(
              clientSecret: paymentIntent.clientSecret,
              paymentMethodId: paymentMethod.id));
      if (paymentResult.status == 'succeeded') {
        return StripeCustomResponse(ok: true);
      } else {
        return StripeCustomResponse(
            ok: false, msg: 'Fallo: ${paymentResult.status}');
      }
    } catch (e) {
      print(e.toString());
      return StripeCustomResponse(ok: false, msg: e.toString());
    }
  }
}
