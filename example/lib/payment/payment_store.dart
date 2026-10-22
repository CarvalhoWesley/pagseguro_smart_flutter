import 'package:flutter/foundation.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:pagseguro_smart_flutter/payments/handler/payment_handler.dart';

import '../core/app_log.dart';

/// Estado compartilhado da área Pagamento.
///
/// O plugin devolve o resultado dos pagamentos pelos callbacks do [PaymentHandler]:
/// cada callback vai para o log central e atualiza este estado.
class PaymentStore implements PaymentHandler {
  PaymentStore._();

  static final instance = PaymentStore._();

  /// true enquanto o SDK mostra o processamento (onLoading).
  final loading = ValueNotifier<bool>(false);

  /// Status da operação em andamento, exibido no dialog de status.
  final status = ValueNotifier<PaymentStatus>(const PaymentStatus.idle());

  /// Marca o início de uma operação: o dialog passa a acompanhar as mensagens do plugin.
  void begin(String operation) => status.value = PaymentStatus(operation, ['Iniciando...']);

  void _update(String message, {bool finished = false, bool failed = false}) {
    final current = status.value;
    status.value = PaymentStatus(
      current.operation,
      [...current.messages, message],
      finished: finished,
      failed: failed,
    );
  }

  /// Dados da última transação aprovada, usados no estorno.
  final transactionCode = ValueNotifier<String?>(null);
  final transactionId = ValueNotifier<String?>(null);

  /// O channel é compartilhado com o NFC: ao entrar na área Pagamento,
  /// este handler volta a receber os callbacks.
  void activate() => PagseguroSmart.instance().initPayment(this);

  void _log(String message, {bool isError = false}) => AppLog.add(LogSource.payment, message, isError: isError);

  @override
  void onTransactionSuccess() {
    _log('Transação aprovada');
    _update('Transação aprovada', finished: true);
  }

  @override
  void onError(String message) {
    _log(message, isError: true);
    _update(message, finished: true, failed: true);
  }

  @override
  void onMessage(String message) {
    _log(message);
    _update(message);
  }

  @override
  void onFinishedResponse(String message) => _log('Resposta: $message');

  @override
  void onLoading(bool show) => loading.value = show;

  @override
  void writeToFile({String? transactionCode, String? transactionId, String? response}) {}

  @override
  void onAbortedSuccessfully() {
    _log('Operação cancelada');
    _update('Operação cancelada', finished: true, failed: true);
  }

  @override
  void disposeDialog() {}

  @override
  void onActivationDialog() => _log('Ativação do terminal solicitada');

  @override
  void onAuthProgress(String message) {
    _log(message);
    _update(message);
  }

  @override
  void onTransactionInfo({String? transactionCode, String? transactionId, String? response}) {
    this.transactionCode.value = transactionCode;
    this.transactionId.value = transactionId;
    _log('Transação: código=$transactionCode id=$transactionId');
  }
}

/// Situação da operação acompanhada pelo dialog de status.
class PaymentStatus {
  final String operation;
  final List<String> messages;
  final bool finished;
  final bool failed;

  const PaymentStatus(this.operation, this.messages, {this.finished = false, this.failed = false});

  const PaymentStatus.idle()
      : operation = '',
        messages = const [],
        finished = true,
        failed = false;

  String get current => messages.isEmpty ? '' : messages.last;
}
