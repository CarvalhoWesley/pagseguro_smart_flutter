import 'package:flutter/material.dart';

import '../core/app_log.dart';
import '../core/ui.dart';
import 'nfc_store.dart';

/// Cartão: UID (identificador para fluxos com saldo no servidor) e diagnóstico dos setores.
class CardTab extends StatefulWidget {
  const CardTab({super.key});

  @override
  State<CardTab> createState() => _CardTabState();
}

class _CardTabState extends State<CardTab> with ActionRunner {
  final _store = NfcStore.instance;

  @override
  LogSource get logSource => LogSource.nfc;

  @override
  Widget build(BuildContext context) {
    return ActionPage(
      busy: busy,
      children: [
        Section(
          title: 'Identificador (UID)',
          hint: 'Leia o mesmo cartão várias vezes: o ID precisa se repetir para servir de identificador no servidor.',
          children: [
            ActionWrap(children: [
              ActionButton(
                label: 'Ler ID do cartão',
                icon: Icons.contactless,
                primary: true,
                onPressed: busy
                    ? null
                    : () => run('Ler ID', () async {
                          final id = await _store.nfc.readCardId();
                          if (mounted) showTextDialog(context, 'ID do cartão', id, fontSize: 22);
                          return id;
                        }),
              ),
            ]),
          ],
        ),
        Section(
          title: 'Diagnóstico',
          hint: 'Lê os 16 setores (64 blocos) com a chave abaixo. Setores com outra chave aparecem como falha.',
          children: [
            FieldWrap(children: [
              AppField(controller: _store.key, label: 'Chave hex (vazio = padrão)', hex: true, width: 220),
            ]),
            ActionWrap(children: [
              ActionButton(
                label: 'Ler todos os setores',
                icon: Icons.grid_view,
                onPressed: busy
                    ? null
                    : () => run('Diagnóstico completo', () async {
                          final report = await _store.nfc.debugReadAllSectors(key: _store.parseKey());
                          if (mounted) showTextDialog(context, 'Setores do cartão', report, fontSize: 11);
                          return null;
                        }),
              ),
              // Interromper fica sempre habilitado
              ActionButton(
                label: 'Cancelar leitura',
                icon: Icons.stop_circle_outlined,
                danger: true,
                onPressed: () => run('Cancelar', () async {
                  await _store.nfc.abortNfc();
                  return null;
                }),
              ),
            ]),
          ],
        ),
      ],
    );
  }
}
