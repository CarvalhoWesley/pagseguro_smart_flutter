import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/app_log.dart';
import '../core/ui.dart';
import 'nfc_store.dart';

/// Blocos: leitura e gravação genérica de um bloco Mifare Classic.
class BlocksTab extends StatefulWidget {
  const BlocksTab({super.key});

  @override
  State<BlocksTab> createState() => _BlocksTabState();
}

class _BlocksTabState extends State<BlocksTab> with ActionRunner {
  final _block = TextEditingController(text: '16');
  final _text = TextEditingController(text: 'teste');
  final _store = NfcStore.instance;

  @override
  LogSource get logSource => LogSource.nfc;

  int get _blockNum {
    final n = int.tryParse(_block.text);
    if (n == null) throw 'Informe o número do bloco';
    return n;
  }

  String _toHex(Uint8List data) => data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  @override
  Widget build(BuildContext context) {
    final nfc = _store.nfc;
    return ActionPage(
      busy: busy,
      children: [
        Section(
          title: 'Bloco',
          hint: 'Use os setores 4 a 15 (blocos 16 em diante): 0 a 3 são do cartão de evento. '
              'Bloco 0 e trailers (3, 7, 11...) não aceitam gravação.',
          children: [
            FieldWrap(children: [
              AppField(controller: _block, label: 'Bloco (0-63)', numeric: true, width: 120),
              AppField(controller: _text, label: 'Texto (máx. 16 bytes)', width: 200),
              AppField(controller: _store.key, label: 'Chave hex (vazio = padrão)', hex: true, width: 220),
            ]),
            ActionWrap(children: [
              ActionButton(
                label: 'Ler texto',
                icon: Icons.text_fields,
                primary: true,
                onPressed: busy ? null : () => run('Ler bloco ${_block.text}', () async => '"${await nfc.readBlockText(_blockNum, key: _store.parseKey())}"'),
              ),
              ActionButton(
                label: 'Ler bytes',
                onPressed: busy ? null : () => run('Ler bloco ${_block.text}', () async => _toHex(await nfc.readBlock(_blockNum, key: _store.parseKey()))),
              ),
              ActionButton(
                label: 'Gravar texto',
                icon: Icons.save,
                onPressed: busy
                    ? null
                    : () => run('Gravar bloco ${_block.text}', () async {
                          // O plugin relê o bloco na mesma aproximação e falha (WRITE_NOT_CONFIRMED) se não bater
                          await nfc.writeBlockText(_blockNum, _text.text, key: _store.parseKey());
                          final written = Uint8List.fromList([...utf8.encode(_text.text), ...List.filled(16, 0)].take(16).toList());
                          return 'gravado e conferido: "${_text.text}" | ${_toHex(written)}';
                        }),
              ),
              ActionButton(
                label: 'Diagnóstico do bloco',
                onPressed: busy
                    ? null
                    : () => run('Diagnóstico bloco ${_block.text}', () async {
                          final report = await nfc.debugReadBlock(_blockNum, key: _store.parseKey());
                          if (mounted) showTextDialog(context, 'Bloco ${_block.text}', report);
                          return null;
                        }),
              ),
              // Interromper fica sempre habilitado
              ActionButton(
                label: 'Cancelar',
                icon: Icons.stop_circle_outlined,
                danger: true,
                onPressed: () => run('Cancelar', () async {
                  await nfc.abortNfc();
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
