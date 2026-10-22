import 'package:flutter/material.dart';

import '../core/app_log.dart';
import '../core/ui.dart';
import 'nfc_store.dart';

/// Evento: cartão cashless gravado nos setores 0 a 3.
/// O resultado de cada operação chega pelo NfcHandler (ver NfcStore) e aparece na aba Logs.
class EventTab extends StatefulWidget {
  const EventTab({super.key});

  @override
  State<EventTab> createState() => _EventTabState();
}

class _EventTabState extends State<EventTab> with ActionRunner {
  final _event = TextEditingController(text: 'EVT001');
  final _amount = TextEditingController(text: '50.00');
  final _name = TextEditingController(text: 'Fulano');
  final _cpf = TextEditingController(text: '12345678900');
  final _tag = TextEditingController(text: '0001');
  final _phone = TextEditingController(text: '11999999999');
  final _opened = TextEditingController(text: '1');
  final _store = NfcStore.instance;

  @override
  LogSource get logSource => LogSource.nfc;

  void _send(String name, Future<bool> Function() action) {
    // Depois de gravar com sucesso, o NfcStore relê o cartão com este evento
    _store.rereadEventId = _event.text;
    run(name, () async {
      await action();
      return 'enviado, aproxime o cartão';
    });
  }

  Future<void> _format() async {
    if (!await confirm(context, 'Formatar zera os blocos do cartão de evento (1, 2, 4, 5, 6, 8, 9 e 12). Continuar?')) return;
    _send('Formatar', _store.nfc.formatNfc);
  }

  Future<void> _formatAll() async {
    if (!await confirm(context, 'Formatar tudo zera TODOS os 47 blocos de dados do cartão (evento e setores 4 a 15). Bloco 0 e chaves não são alterados. Continuar?')) return;
    _send('Formatar tudo', _store.nfc.formatAllNfc);
  }

  @override
  Widget build(BuildContext context) {
    final nfc = _store.nfc;
    return ValueListenableBuilder(
      valueListenable: _store.loading,
      builder: (context, loading, _) {
        final locked = busy || loading;
        return ActionPage(
          busy: locked,
          children: [
            ValueListenableBuilder<EventCardInfo?>(
              valueListenable: _store.lastCard,
              builder: (context, card, _) => card == null ? const SizedBox.shrink() : _CardSummary(card: card),
            ),
            Section(
              title: 'Dados do cartão',
              hint: 'Cada campo ocupa um bloco: até 16 caracteres. Valor com ponto (ex.: 50.00).',
              children: [
                FieldWrap(children: [
                  AppField(controller: _event, label: 'ID do evento'),
                  AppField(controller: _amount, label: 'Valor', numeric: true),
                  AppField(controller: _name, label: 'Nome'),
                  AppField(controller: _cpf, label: 'CPF', numeric: true),
                  AppField(controller: _tag, label: 'Número da tag'),
                  AppField(controller: _phone, label: 'Celular', numeric: true),
                  AppField(controller: _opened, label: 'Aberto', width: 100),
                ]),
              ],
            ),
            Section(
              title: 'Operações',
              children: [
                ActionWrap(children: [
                  ActionButton(label: 'Ler', icon: Icons.contactless, primary: true, onPressed: locked ? null : () => _send('Ler cartão', () => nfc.readNfc(_event.text))),
                  ActionButton(
                    label: 'Abrir',
                    icon: Icons.add_card,
                    onPressed: locked
                        ? null
                        : () => _send('Abrir cartão', () => nfc.writeNfc(_amount.text, _name.text, _cpf.text, _tag.text, _phone.text, _opened.text, _event.text)),
                  ),
                  ActionButton(label: 'Recarregar', onPressed: locked ? null : () => _send('Recarga', () => nfc.reWriteNfc(_amount.text, _event.text))),
                  ActionButton(label: 'Debitar', onPressed: locked ? null : () => _send('Débito', () => nfc.debitNfc(_event.text, _amount.text))),
                  ActionButton(label: 'Estornar', onPressed: locked ? null : () => _send('Estorno', () => nfc.refundNfc(_amount.text, _event.text))),
                  ActionButton(label: 'Formatar', icon: Icons.delete_outline, danger: true, onPressed: locked ? null : _format),
                  ActionButton(label: 'Formatar tudo', icon: Icons.delete_forever, danger: true, onPressed: locked ? null : _formatAll),
                ]),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Resumo do último cartão lido, no topo da aba.
class _CardSummary extends StatelessWidget {
  final EventCardInfo card;

  const _CardSummary({required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final time = '${card.readAt.hour.toString().padLeft(2, '0')}:${card.readAt.minute.toString().padLeft(2, '0')}:'
        '${card.readAt.second.toString().padLeft(2, '0')}';
    return Card(
      color: card.stale ? scheme.surfaceContainerHighest : scheme.primaryContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Saldo', style: theme.textTheme.labelLarge),
                const Spacer(),
                Chip(
                  label: Text(card.isOpened ? 'Aberto' : 'Fechado'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(EventCardInfo.money(card.value), style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Total carregado: ${EventCardInfo.money(card.openValue)}'),
            Text('Portador: ${card.name.isEmpty ? '-' : card.name} · CPF ${card.cpf.isEmpty ? '-' : card.cpf}'),
            Text('Tag ${card.tag.isEmpty ? '-' : card.tag} · Cel ${card.cellPhone.isEmpty ? '-' : card.cellPhone}'),
            const SizedBox(height: 4),
            Text(
              card.stale ? 'Lido às $time · cartão alterado depois, leia de novo para atualizar' : 'Lido às $time',
              style: theme.textTheme.bodySmall?.copyWith(color: card.stale ? scheme.error : scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
