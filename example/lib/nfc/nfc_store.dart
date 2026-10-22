import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:pagseguro_smart_flutter/payments/handler/nfc_handler.dart';
import 'package:pagseguro_smart_flutter/payments/nfc.dart';

import '../core/app_log.dart';

/// Estado compartilhado da área NFC.
///
/// O cartão de evento (cashless) devolve o resultado pelos callbacks do [NfcHandler]:
/// cada callback vai para o log central. A API genérica (UID e blocos) devolve no próprio Future.
class NfcStore implements NfcHandler {
  NfcStore._();

  static final instance = NfcStore._();

  /// true enquanto o fluxo de evento está processando (onLoading).
  final loading = ValueNotifier<bool>(false);

  /// Último cartão de evento lido (showSuccess), exibido no topo da aba Evento.
  final lastCard = ValueNotifier<EventCardInfo?>(null);

  /// Evento usado para reler o cartão automaticamente depois de uma gravação bem-sucedida.
  String? rereadEventId;

  /// Chave do setor usada nas abas Cartão e Blocos (vazio = chave padrão FF FF FF FF FF FF).
  final key = TextEditingController(text: 'FFFFFFFFFFFF');

  Nfc get nfc => PagseguroSmart.instance().nfc;

  /// O channel é compartilhado com o pagamento: ao entrar na área NFC,
  /// este handler volta a receber os callbacks.
  void activate() => PagseguroSmart.instance().initNfc(this);

  Uint8List? parseKey() {
    final hex = key.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.isEmpty) return null;
    if (hex.length != 12) throw 'A chave deve ter 6 bytes (12 caracteres hex)';
    return Uint8List.fromList(List.generate(6, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  void _log(String message, {bool isError = false}) => AppLog.add(LogSource.nfc, message, isError: isError);

  @override
  void showSuccess(List result) {
    _log('Leitura OK: $result');
    lastCard.value = EventCardInfo.fromList(result);
  }

  @override
  void showSuccessWrite(int result) {
    _log('Cartão aberto: $result');
    _rereadAfterWrite();
  }

  @override
  void showSuccessReWrite(String result) {
    _log('Recarga OK: $result');
    _rereadAfterWrite();
  }

  @override
  void showSuccessFormat(int result) {
    _log('Formatado: $result');
    lastCard.value = null;
  }

  @override
  void showSuccessDebitNfc(String result) {
    _log('Débito OK: $result');
    _rereadAfterWrite();
  }

  @override
  void showSuccessRefundNfc(String result) {
    _log('Estorno OK: $result');
    _rereadAfterWrite();
  }

  // Gravações não devolvem os dados do cartão: relê para atualizar o resumo.
  // É uma nova sessão NFC; se o cartão já tiver sido afastado, o resumo fica marcado como desatualizado.
  void _rereadAfterWrite() {
    _markStale();
    final eventId = rereadEventId;
    if (eventId == null) return;
    _log('Relendo o cartão para conferir...');
    nfc.readNfc(eventId);
  }

  // Gravações não devolvem os dados do cartão: o resumo fica marcado até a próxima leitura
  void _markStale() {
    final card = lastCard.value;
    if (card != null) lastCard.value = card.copyStale();
  }

  @override
  void showErrorRead(String message) => _log('Erro na leitura: $message', isError: true);
  @override
  void showErrorWrite(String message) => _log('Erro na gravação: $message', isError: true);
  @override
  void showErrorReWrite(String message) => _log('Erro na recarga: $message', isError: true);
  @override
  void showErrorFormat(String message) => _log('Erro ao formatar: $message', isError: true);
  @override
  void showErrorDebitNfc(String message) => _log('Erro no débito: $message', isError: true);
  @override
  void showErrorRefundNfc(String message) => _log('Erro no estorno: $message', isError: true);

  @override
  void onError(String message) => _log(message, isError: true);
  @override
  void onMessage(String message) => _log(message);
  @override
  void onLoading(bool show) => loading.value = show;
  @override
  void onTransactionSuccess() => _log('Sucesso');
  @override
  void onAbortedSuccessfully() => _log('Cancelado');
  @override
  void onAuthProgress(String message) => _log(message);
  @override
  void disposeDialog() {}
  @override
  void onActivationDialog() {}
  @override
  void writeToFile({String? transactionCode, String? transactionId}) {}
  @override
  void onTransactionInfo({String? transactionCode, String? transactionId}) {}
}

/// Dados do cartão de evento devolvidos pelo plugin na leitura.
/// Ordem da lista do showSuccess: saldo, nome, CPF, tag, celular, aberto, valor de abertura.
class EventCardInfo {
  final String value;
  final String name;
  final String cpf;
  final String tag;
  final String cellPhone;
  final String opened;
  final String openValue;
  final DateTime readAt;
  final bool stale;

  const EventCardInfo({
    required this.value,
    required this.name,
    required this.cpf,
    required this.tag,
    required this.cellPhone,
    required this.opened,
    required this.openValue,
    required this.readAt,
    this.stale = false,
  });

  factory EventCardInfo.fromList(List result) {
    String at(int i) => i < result.length ? (result[i]?.toString() ?? '').trim() : '';
    return EventCardInfo(
      value: at(0),
      name: at(1),
      cpf: at(2),
      tag: at(3),
      cellPhone: at(4),
      opened: at(5),
      openValue: at(6),
      readAt: DateTime.now(),
    );
  }

  EventCardInfo copyStale() => EventCardInfo(
        value: value,
        name: name,
        cpf: cpf,
        tag: tag,
        cellPhone: cellPhone,
        opened: opened,
        openValue: openValue,
        readAt: readAt,
        stale: true,
      );

  bool get isOpened => opened.isNotEmpty && opened != '0';

  static String money(String raw) {
    final v = double.tryParse(raw.replaceAll(',', '.'));
    return v == null ? (raw.isEmpty ? '-' : raw) : 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }
}
