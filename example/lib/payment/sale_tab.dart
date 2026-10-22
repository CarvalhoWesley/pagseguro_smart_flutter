import 'package:flutter/material.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:pagseguro_smart_flutter/payments/payment.dart';

import '../core/app_log.dart';
import '../core/ui.dart';
import 'payment_status_dialog.dart';
import 'payment_store.dart';

/// Vender: escolhe o valor e o meio de pagamento.
/// O resultado chega pelo PaymentHandler (ver PaymentStore) e aparece na aba Logs.
class SaleTab extends StatefulWidget {
  const SaleTab({super.key});

  @override
  State<SaleTab> createState() => _SaleTabState();
}

class _SaleTabState extends State<SaleTab> with ActionRunner {
  final _amount = TextEditingController(text: '10,00');
  final _installments = TextEditingController(text: '2');

  @override
  LogSource get logSource => LogSource.payment;

  Payment get _payment => PagseguroSmart.instance().payment;

  // O plugin recebe o valor em centavos
  int get _cents => (parseAmount(_amount.text) * 100).round();

  void _pay(String name, Future<bool> Function(int cents) action) {
    run(name, () async {
      final cents = _cents;
      if (cents <= 0) throw 'Informe um valor maior que zero';
      // Acompanha as mensagens do plugin num dialog até a operação terminar
      if (mounted) showPaymentStatusDialog(context, name);
      await action(cents);
      return 'enviado (R\$ ${(cents / 100).toStringAsFixed(2)})';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: PaymentStore.instance.loading,
      builder: (context, loading, _) {
        final locked = busy || loading;
        return ActionPage(
          busy: locked,
          children: [
            Section(
              title: 'Pagamento',
              hint: 'Valor em reais. O resultado aparece na aba Logs.',
              children: [
                FieldWrap(children: [
                  AppField(controller: _amount, label: 'Valor (R\$)', numeric: true),
                  AppField(controller: _installments, label: 'Parcelas', numeric: true, width: 100),
                ]),
                ActionWrap(children: [
                  ActionButton(label: 'Débito', icon: Icons.credit_card, primary: true, onPressed: locked ? null : () => _pay('Débito', _payment.debitPayment)),
                  ActionButton(label: 'Crédito', icon: Icons.credit_card, primary: true, onPressed: locked ? null : () => _pay('Crédito', _payment.creditPayment)),
                  ActionButton(
                    label: 'Crédito parcelado',
                    onPressed: locked
                        ? null
                        : () => _pay('Crédito parcelado', (c) => _payment.creditPaymentParc(c, int.tryParse(_installments.text) ?? 2)),
                  ),
                  ActionButton(label: 'Voucher', onPressed: locked ? null : () => _pay('Voucher', _payment.voucherPayment)),
                  ActionButton(label: 'PIX', icon: Icons.pix, onPressed: locked ? null : () => _pay('PIX', _payment.pixPayment)),
                ]),
              ],
            ),
            Section(
              title: 'Operação em andamento',
              children: [
                ActionWrap(children: [
                  // Interromper fica sempre habilitado
                  ActionButton(
                    label: 'Abortar',
                    icon: Icons.stop_circle_outlined,
                    danger: true,
                    onPressed: () => run('Abortar', () async {
                      await _payment.abortTransaction();
                      return null;
                    }),
                  ),
                ]),
              ],
            ),
            Section(
              title: 'Terminal',
              children: [
                ActionWrap(children: [
                  ActionButton(
                    label: 'Ativar pinpad',
                    icon: Icons.key,
                    onPressed: locked
                        ? null
                        : () => run('Ativar pinpad', () async {
                              showPaymentStatusDialog(context, 'Ativar pinpad');
                              await _payment.activePinpad('');
                              return null;
                            }),
                  ),
                ]),
              ],
            ),
          ],
        );
      },
    );
  }
}
