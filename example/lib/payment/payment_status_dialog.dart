import 'package:flutter/material.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';

import '../core/app_log.dart';
import 'payment_store.dart';

/// Abre um dialog que acompanha, em tempo real, as mensagens do plugin
/// ("APROXIME, INSIRA OU PASSE O CARTÃO", "PROCESSANDO"...) da operação [operation].
///
/// Enquanto a operação está em andamento só dá para abortar; ao terminar
/// (aprovada, erro ou cancelada) o botão Fechar é liberado.
void showPaymentStatusDialog(BuildContext context, String operation) {
  final store = PaymentStore.instance;
  store.begin(operation);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: ValueListenableBuilder<PaymentStatus>(
        valueListenable: store.status,
        builder: (context, status, _) => _StatusDialog(status: status),
      ),
    ),
  );
}

class _StatusDialog extends StatelessWidget {
  final PaymentStatus status;

  const _StatusDialog({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Histórico sem a mensagem atual, da mais recente para a mais antiga
    final history = status.messages.length > 1 ? status.messages.sublist(0, status.messages.length - 1).reversed.take(5).toList() : <String>[];

    return AlertDialog(
      title: Text(status.operation),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56,
              child: Center(
                child: !status.finished
                    ? const CircularProgressIndicator()
                    : Icon(
                        status.failed ? Icons.error_outline : Icons.check_circle_outline,
                        size: 48,
                        color: status.failed ? scheme.error : Colors.green,
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // Mensagem atual do plugin, em destaque
            Text(
              status.current,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: status.failed ? scheme.error : null),
            ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              for (final message in history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        // Saída de segurança caso o plugin não envie o callback de fim: fecha sem abortar
        if (!status.finished) TextButton(onPressed: () => Navigator.pop(context), child: const Text('Ocultar')),
        if (!status.finished)
          TextButton(
            onPressed: () async {
              AppLog.add(LogSource.payment, 'Abortar solicitado pelo dialog');
              await PagseguroSmart.instance().payment.abortTransaction();
            },
            child: Text('Abortar', style: TextStyle(color: scheme.error)),
          )
        else
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}
