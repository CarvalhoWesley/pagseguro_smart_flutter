import 'package:flutter/material.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:pagseguro_smart_flutter/payments/payment.dart';

import '../core/app_log.dart';
import '../core/ui.dart';
import 'payment_status_dialog.dart';
import 'payment_store.dart';

/// Transações: consulta a última transação e estorna.
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key});

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> with ActionRunner {
  final _code = TextEditingController();
  final _id = TextEditingController();
  final _store = PaymentStore.instance;

  @override
  LogSource get logSource => LogSource.payment;

  Payment get _payment => PagseguroSmart.instance().payment;

  @override
  void initState() {
    super.initState();
    _store.transactionCode.addListener(_fill);
    _store.transactionId.addListener(_fill);
    _fill();
  }

  @override
  void dispose() {
    _store.transactionCode.removeListener(_fill);
    _store.transactionId.removeListener(_fill);
    super.dispose();
  }

  // Preenche com a última transação recebida pelo handler
  void _fill() {
    _code.text = _store.transactionCode.value ?? '';
    _id.text = _store.transactionId.value ?? '';
  }

  Future<void> _refund() async {
    if (_code.text.isEmpty || _id.text.isEmpty) {
      AppLog.add(logSource, 'Estorno: informe código e ID da transação', isError: true);
      return;
    }
    if (!await confirm(context, 'Estornar a transação ${_code.text}?')) return;
    run('Estorno', () async {
      if (mounted) showPaymentStatusDialog(context, 'Estorno');
      await _payment.refund(transactionCode: _code.text, transactionId: _id.text);
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      busy: busy,
      children: [
        Section(
          title: 'Última transação',
          hint: 'O resultado chega pelo handler e preenche os campos abaixo.',
          children: [
            ActionWrap(children: [
              ActionButton(
                label: 'Consultar',
                icon: Icons.history,
                primary: true,
                onPressed: busy
                    ? null
                    : () => run('Última transação', () async {
                          await _payment.lastTransaction();
                          return null;
                        }),
              ),
            ]),
          ],
        ),
        Section(
          title: 'Estorno',
          hint: 'Preenchido automaticamente com a última transação aprovada.',
          children: [
            FieldWrap(children: [
              AppField(controller: _code, label: 'Código', width: 200),
              AppField(controller: _id, label: 'ID', width: 200),
            ]),
            ActionWrap(children: [
              ActionButton(label: 'Estornar', icon: Icons.undo, danger: true, onPressed: busy ? null : _refund),
            ]),
          ],
        ),
      ],
    );
  }
}
