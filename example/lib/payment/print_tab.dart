import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../core/app_log.dart';
import '../core/ui.dart';

//Largura do papel da impressora da Smart, em pixels
const double _paperWidth = 384;

/// Impressão: todos os métodos de impressão do plugin com um cupom de teste.
class PrintTab extends StatefulWidget {
  const PrintTab({super.key});

  @override
  State<PrintTab> createState() => _PrintTabState();
}

class _PrintTabState extends State<PrintTab> with ActionRunner {
  Uint8List? _preview;
  int _sequenceCount = 3;

  @override
  LogSource get logSource => LogSource.printer;

  @override
  void initState() {
    super.initState();
    _generateTestImage().then((bytes) {
      if (mounted) setState(() => _preview = bytes);
    });
  }

  void _print(String name, Future<bool> Function(Uint8List bytes) action) {
    run(name, () async {
      final bytes = _preview ?? await _generateTestImage();
      final ok = await action(bytes);
      if (!ok) throw 'a impressão retornou erro';
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final payment = PagseguroSmart.instance().payment;
    return ActionPage(
      busy: busy,
      children: [
        Section(
          title: 'Cupom de teste',
          children: [
            if (_preview != null)
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                  child: Image.memory(_preview!, width: _paperWidth / 1.5),
                ),
              ),
          ],
        ),
        Section(
          title: 'Métodos de impressão',
          hint: 'Cada botão imprime o cupom acima por um método diferente do plugin.',
          children: [
            ActionWrap(children: [
              ActionButton(
                label: 'printerFromBytes',
                icon: Icons.print,
                primary: true,
                onPressed: busy ? null : () => _print('printerFromBytes', payment.printerFromBytes),
              ),
              ActionButton(
                label: 'printerfromFile',
                onPressed: busy ? null : () => _print('printerfromFile', (b) async => payment.printerfromFile((await _saveToAppDirectory(b)).path)),
              ),
              ActionButton(
                label: 'printer',
                onPressed: busy ? null : () => _print('printer', (b) async => payment.printer((await _saveToAppDirectory(b)).path)),
              ),
              ActionButton(
                label: 'printerFilePath',
                onPressed: busy ? null : () => _print('printerFilePath', (b) async => payment.printerFilePath((await _saveToAppDirectory(b)).path)),
              ),
              ActionButton(
                label: 'printerFile (Download)',
                onPressed: busy
                    ? null
                    : () => _print('printerFile', (b) async {
                          //Imprime um arquivo pelo nome, buscando na pasta Download do dispositivo
                          const fileName = 'pagseguro_print_test.png';
                          await File('/storage/emulated/0/Download/$fileName').writeAsBytes(b);
                          return payment.printerFile(fileName);
                        }),
              ),
            ]),
          ],
        ),
        Section(
          title: 'Widget',
          hint: 'Renderiza um widget Flutter e imprime (PrintRenderWidget).',
          children: [
            ActionWrap(children: [
              ActionButton(
                label: 'Cupom simples',
                onPressed: () {
                  AppLog.add(logSource, 'PrintRenderWidget: cupom simples');
                  PrintRenderWidget.print(context, pagseguroSmartInstance: PagseguroSmart.instance(), child: const _TestReceipt());
                },
              ),
              ActionButton(
                label: 'Lista longa (45 itens)',
                onPressed: () {
                  AppLog.add(logSource, 'PrintRenderWidget: lista longa');
                  PrintRenderWidget.print(context, pagseguroSmartInstance: PagseguroSmart.instance(), child: const _LongList());
                },
              ),
            ]),
          ],
        ),
        Section(
          title: 'Impressões em sequência',
          hint: 'Imprime várias vezes seguidas; cada await só retorna quando a impressão termina.',
          children: [
            Row(children: [
              const Text('Quantidade:'),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _sequenceCount > 1 && !busy ? () => setState(() => _sequenceCount--) : null,
              ),
              Text('$_sequenceCount', style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _sequenceCount < 20 && !busy ? () => setState(() => _sequenceCount++) : null,
              ),
            ]),
            ActionWrap(children: [
              ActionButton(label: 'Imprimir $_sequenceCount em sequência', onPressed: busy ? null : _printSequence),
            ]),
          ],
        ),
      ],
    );
  }

  void _printSequence() {
    final total = _sequenceCount;
    run('Sequência de $total', () async {
      final stopwatch = Stopwatch()..start();
      for (int i = 1; i <= total; i++) {
        final bytes = await _generateTestImage(title: 'SEQUÊNCIA $i/$total');
        final bool ok;
        try {
          ok = await PagseguroSmart.instance().payment.printerFromBytes(bytes).timeout(const Duration(seconds: 60));
        } on TimeoutException {
          throw 'impressão $i/$total não terminou em 60s';
        }
        if (!ok) throw 'impressão $i/$total retornou erro';
      }
      return '$total/$total em ${stopwatch.elapsed.inSeconds}s';
    });
  }

  Future<File> _saveToAppDirectory(Uint8List bytes) async {
    //O arquivo é lido pelo serviço da PagSeguro, então precisa ficar fora da pasta interna do app
    final directory = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File('${directory.path}/pagseguro_print_test.png');
    return file.writeAsBytes(bytes);
  }

  //Desenha um cupom simples em memória e devolve os bytes em PNG
  Future<Uint8List> _generateTestImage({String title = 'TESTE DE IMPRESSÃO'}) async {
    final lines = <String>[
      title,
      'pagseguro_smart_flutter',
      '--------------------------------',
      'Item 1 .............. R\$ 10,00',
      'Item 2 .............. R\$ 25,50',
      'Item 3 ............... R\$ 4,90',
      '--------------------------------',
      'TOTAL ............... R\$ 40,40',
    ];
    const double padding = 16;
    const double lineHeight = 32;
    const double height = padding * 2 + lineHeight * 9;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _paperWidth, height), Paint()..color = Colors.white);

    double y = padding;
    for (final line in lines) {
      TextPainter(
        text: TextSpan(text: line, style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )
        ..layout(minWidth: _paperWidth - padding * 2, maxWidth: _paperWidth - padding * 2)
        ..paint(canvas, Offset(padding, y));
      y += lineHeight;
    }

    final now = DateTime.now().toString().substring(0, 19);
    TextPainter(
      text: TextSpan(text: now, style: const TextStyle(color: Colors.black, fontSize: 16)),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )
      ..layout(minWidth: _paperWidth - padding * 2, maxWidth: _paperWidth - padding * 2)
      ..paint(canvas, Offset(padding, y));

    final image = await recorder.endRecording().toImage(_paperWidth.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

class _TestReceipt extends StatelessWidget {
  const _TestReceipt();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('TESTE DE WIDGET', style: style),
          Divider(color: Colors.black),
          Text('Impresso via PrintRenderWidget', style: TextStyle(color: Colors.black, fontSize: 16)),
          Divider(color: Colors.black),
          FlutterLogo(size: 80),
        ],
      ),
    );
  }
}

class _LongList extends StatelessWidget {
  const _LongList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: 45,
      itemBuilder: (context, index) {
        final dark = index.isEven;
        return Row(children: [
          Container(
            color: dark ? Colors.black : Colors.white,
            child: Text('Item ${index + 1}', style: TextStyle(fontSize: 20, color: dark ? Colors.white : Colors.black)),
          ),
        ]);
      },
    );
  }
}
