import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:bot_toast/bot_toast.dart';
import 'package:path_provider/path_provider.dart';

import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';

//Largura do papel da impressora da Smart, em pixels
const double _paperWidth = 384;

class PrinterPage extends StatefulWidget {
  const PrinterPage({Key? key}) : super(key: key);

  @override
  _PrinterPageState createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  Uint8List? _preview;
  int _sequenceCount = 3;
  bool _sequenceRunning = false;

  @override
  void initState() {
    _generateTestImage().then((bytes) => setState(() => _preview = bytes));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            "Imagem de teste",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 10),
          if (_preview != null)
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                child: Image.memory(_preview!, width: _paperWidth / 1.5),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => _run("printerFromBytes", (bytes) async {
              //Imprime direto dos bytes, sem salvar arquivo
              return PagseguroSmart.instance().payment.printerFromBytes(bytes);
            }),
            child: const Text("Imprimir bytes (printerFromBytes)"),
          ),
          ElevatedButton(
            onPressed: () => _run("printerfromFile", (bytes) async {
              //Imprime a partir do caminho absoluto do arquivo
              final file = await _saveToAppDirectory(bytes);
              return PagseguroSmart.instance().payment.printerfromFile(file.path);
            }),
            child: const Text("Imprimir arquivo (printerfromFile)"),
          ),
          ElevatedButton(
            onPressed: () => _run("printer", (bytes) async {
              //Imprime a partir do caminho absoluto do arquivo
              final file = await _saveToAppDirectory(bytes);
              return PagseguroSmart.instance().payment.printer(file.path);
            }),
            child: const Text("Imprimir arquivo (printer)"),
          ),
          ElevatedButton(
            onPressed: () => _run("printerFilePath", (bytes) async {
              //Imprime a partir do caminho absoluto do arquivo
              final file = await _saveToAppDirectory(bytes);
              return PagseguroSmart.instance().payment.printerFilePath(file.path);
            }),
            child: const Text("Imprimir arquivo (printerFilePath)"),
          ),
          ElevatedButton(
            onPressed: () => _run("printerFile", (bytes) async {
              //Imprime um arquivo pelo nome, buscando na pasta Download do dispositivo
              const fileName = "pagseguro_print_test.png";
              await File("/storage/emulated/0/Download/$fileName").writeAsBytes(bytes);
              return PagseguroSmart.instance().payment.printerFile(fileName);
            }),
            child: const Text("Imprimir da pasta Download (printerFile)"),
          ),
          ElevatedButton(
            onPressed: () {
              //Renderiza um widget e imprime
              PrintRenderWidget.print(
                context,
                pagseguroSmartInstance: PagseguroSmart.instance(),
                child: const _TestReceipt(),
              );
            },
            child: const Text("Imprimir widget (PrintRenderWidget)"),
          ),
          const SizedBox(height: 20),
          const Text(
            "Impressões em sequência",
            style: TextStyle(fontSize: 16),
          ),
          Row(
            children: <Widget>[
              const Text("Quantidade:"),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _sequenceCount > 1 && !_sequenceRunning ? () => setState(() => _sequenceCount--) : null,
              ),
              Text("$_sequenceCount", style: const TextStyle(fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _sequenceCount < 20 && !_sequenceRunning ? () => setState(() => _sequenceCount++) : null,
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _sequenceRunning ? null : _printSequence,
            child: Text(_sequenceRunning ? "Imprimindo..." : "Imprimir $_sequenceCount em sequência (printerFromBytes)"),
          ),
        ],
      ),
    );
  }

  //Imprime várias vezes em sequência, igual um app faria: o await só retorna quando a impressão termina
  Future<void> _printSequence() async {
    final total = _sequenceCount;
    setState(() => _sequenceRunning = true);
    final stopwatch = Stopwatch()..start();
    int printed = 0;
    try {
      for (int i = 1; i <= total; i++) {
        final bytes = await _generateTestImage(title: "SEQUÊNCIA $i/$total");
        final success = await PagseguroSmart.instance().payment.printerFromBytes(bytes).timeout(const Duration(seconds: 60));
        if (!success) {
          throw "a impressão retornou erro";
        }
        printed++;
      }
      BotToast.showText(text: "Sequência finalizada: $printed/$total em ${stopwatch.elapsed.inSeconds}s");
    } on TimeoutException {
      BotToast.showText(text: "Sequência parada: impressão ${printed + 1}/$total não terminou em 60s");
    } catch (e) {
      BotToast.showText(text: "Sequência parada em ${printed + 1}/$total: $e");
    } finally {
      if (mounted) setState(() => _sequenceRunning = false);
    }
  }

  Future<void> _run(String name, Future<bool> Function(Uint8List bytes) print) async {
    try {
      final bytes = _preview ?? await _generateTestImage();
      final result = await print(bytes);
      BotToast.showText(text: "$name retornou: $result");
    } catch (e) {
      BotToast.showText(text: "$name falhou: $e");
    }
  }

  Future<File> _saveToAppDirectory(Uint8List bytes) async {
    //O arquivo é lido pelo serviço da PagSeguro, então precisa ficar fora da pasta interna do app
    final directory = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final file = File("${directory.path}/pagseguro_print_test.png");
    return file.writeAsBytes(bytes);
  }

  //Desenha um cupom simples em memória e devolve os bytes em PNG
  Future<Uint8List> _generateTestImage({String title = "TESTE DE IMPRESSÃO"}) async {
    final lines = <String>[
      title,
      "pagseguro_smart_flutter",
      "--------------------------------",
      "Item 1 .............. R\$ 10,00",
      "Item 2 .............. R\$ 25,50",
      "Item 3 ............... R\$ 4,90",
      "--------------------------------",
      "TOTAL ............... R\$ 40,40",
    ];
    const double padding = 16;
    const double lineHeight = 32;
    const double height = padding * 2 + lineHeight * 9;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _paperWidth, height), Paint()..color = Colors.white);

    double y = padding;
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(minWidth: _paperWidth - padding * 2, maxWidth: _paperWidth - padding * 2);
      painter.paint(canvas, Offset(padding, y));
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
  const _TestReceipt({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold);
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text("TESTE DE WIDGET", style: style),
          Divider(color: Colors.black),
          Text("Impresso via PrintRenderWidget", style: TextStyle(color: Colors.black, fontSize: 16)),
          Divider(color: Colors.black),
          FlutterLogo(size: 80),
        ],
      ),
    );
  }
}
