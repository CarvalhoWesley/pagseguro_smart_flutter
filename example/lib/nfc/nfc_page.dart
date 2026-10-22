import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pagseguro_smart_flutter/pagseguro_smart_flutter.dart';
import 'package:pagseguro_smart_flutter/payments/handler/nfc_handler.dart';
import 'package:pagseguro_smart_flutter/payments/nfc.dart';

/// Tela de testes de todas as funções NFC.
/// Obs.: o channel é compartilhado — ao abrir esta aba, os callbacks passam para o NfcHandler
/// (e a aba "Vender" reativa o PaymentHandler quando é aberta de novo).
class NfcPage extends StatefulWidget {
  const NfcPage({Key? key}) : super(key: key);

  @override
  State<NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcPage> implements NfcHandler {
  // Cartão de evento
  final _idEvento = TextEditingController(text: 'EVT001');
  final _valor = TextEditingController(text: '50.00');
  final _nome = TextEditingController(text: 'Fulano');
  final _cpf = TextEditingController(text: '12345678900');
  final _tag = TextEditingController(text: '0001');
  final _celular = TextEditingController(text: '11999999999');
  final _aberto = TextEditingController(text: '1');

  // Blocos
  final _bloco = TextEditingController(text: '13');
  final _texto = TextEditingController(text: 'teste');
  final _chave = TextEditingController(text: 'FFFFFFFFFFFF');

  final List<String> _logs = [];
  bool _loading = false;

  Nfc get _nfc => PagseguroSmart.instance().nfc;

  @override
  void initState() {
    super.initState();
    PagseguroSmart.instance().initNfc(this);
  }

  void _log(String msg) {
    if (!mounted) return;
    final hora = TimeOfDay.now().format(context);
    setState(() => _logs.insert(0, '[$hora] $msg'));
  }

  Uint8List? _parseKey() {
    final hex = _chave.text.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.isEmpty) return null;
    if (hex.length != 12) throw 'A chave deve ter 6 bytes (12 caracteres hex)';
    return Uint8List.fromList(List.generate(6, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  String _toHex(Uint8List data) => data.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  // Executa uma chamada e registra sucesso/erro no log
  Future<void> _run(String nome, Future<String?> Function() acao) async {
    _log('$nome: aproxime o cartão...');
    setState(() => _loading = true);
    try {
      final r = await acao();
      if (r != null) _log('$nome OK: $r');
    } on PlatformException catch (e) {
      _log('$nome ERRO [${e.code}]: ${e.message}');
    } catch (e) {
      _log('$nome ERRO: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _blocoNum => int.parse(_bloco.text);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_loading) const LinearProgressIndicator(),
        _secao('Identificador do cartão (UID)'),
        const Text(
          'Leia o mesmo cartão várias vezes: o ID precisa se repetir para servir de identificador no servidor.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        _botoes([
          _botao('Ler ID do cartão', () => _run('Ler ID', () async {
                final id = await _nfc.readCardId();
                _mostrarId(id);
                return id;
              })),
        ]),
        const Divider(height: 32),
        _secao('Cartão de evento (cashless)'),
        _campos([
          _campo(_idEvento, 'ID do evento'),
          _campo(_valor, 'Valor (ex.: 50.00)', numerico: true),
          _campo(_nome, 'Nome'),
          _campo(_cpf, 'CPF', numerico: true),
          _campo(_tag, 'Número da tag'),
          _campo(_celular, 'Celular', numerico: true),
          _campo(_aberto, 'Aberto'),
        ]),
        _botoes([
          _botao('Ler', () => _run('Ler cartão', () async {
                await _nfc.readNfc(_idEvento.text);
                return null; // resultado chega em showSuccess / showErrorRead
              })),
          _botao('Abrir (gravar)', () => _run('Abrir cartão', () async {
                await _nfc.writeNfc(_valor.text, _nome.text, _cpf.text, _tag.text, _celular.text, _aberto.text, _idEvento.text);
                return null;
              })),
          _botao('Recarregar', () => _run('Recarga', () async {
                await _nfc.reWriteNfc(_valor.text, _idEvento.text);
                return null;
              })),
          _botao('Debitar', () => _run('Débito', () async {
                await _nfc.debitNfc(_idEvento.text, _valor.text);
                return null;
              })),
          _botao('Estornar', () => _run('Estorno', () async {
                await _nfc.refundNfc(_valor.text, _idEvento.text);
                return null;
              })),
          _botao('Formatar', () => _confirmar('Formatar apaga todos os dados do cartão. Continuar?', () {
                _run('Formatar', () async {
                  await _nfc.formatNfc();
                  return null;
                });
              }), perigo: true),
        ]),
        const Divider(height: 32),
        _secao('Blocos (leitura/gravação genérica)'),
        _campos([
          _campo(_bloco, 'Bloco (0-63)', numerico: true),
          _campo(_texto, 'Texto (máx. 16 bytes)'),
          _campo(_chave, 'Chave hex (vazio = padrão)'),
        ]),
        const Text(
          'Evite os blocos 1-12: são usados pelo cartão de evento. Bloco 0 e trailers (3, 7, 11...) não aceitam gravação.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        _botoes([
          _botao('Ler texto', () => _run('Ler bloco $_blocoNum', () => _nfc.readBlockText(_blocoNum, key: _parseKey()).then((t) => '"$t"'))),
          _botao('Ler bytes', () => _run('Ler bloco $_blocoNum', () => _nfc.readBlock(_blocoNum, key: _parseKey()).then(_toHex))),
          _botao('Gravar texto', () => _run('Gravar bloco $_blocoNum', () => _nfc.writeBlockText(_blocoNum, _texto.text, key: _parseKey()).then((_) => 'gravado'))),
          _botao('Diagnóstico (todos setores)', () => _run('Diagnóstico completo', () async {
                final relatorio = await _nfc.debugReadAllSectors(key: _parseKey());
                _mostrarRelatorio(relatorio);
                return 'ver dialog';
              })),
          _botao('Diagnóstico', () => _run('Diagnóstico bloco $_blocoNum', () => _nfc.debugReadBlock(_blocoNum, key: _parseKey()))),
          _botao('Cancelar', () => _run('Cancelar', () => _nfc.abortNfc().then((_) => 'enviado'))),
        ]),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: _secao('Log')),
            TextButton(onPressed: () => setState(_logs.clear), child: const Text('Limpar')),
          ],
        ),
        ..._logs.map((l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            )),
      ],
    );
  }

  Widget _secao(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Widget _campos(List<Widget> campos) => Wrap(spacing: 8, runSpacing: 8, children: campos);

  Widget _campo(TextEditingController c, String label, {bool numerico = false}) => SizedBox(
        width: 160,
        child: TextField(
          controller: c,
          keyboardType: numerico ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      );

  Widget _botoes(List<Widget> botoes) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(spacing: 8, runSpacing: 8, children: botoes),
      );

  Widget _botao(String t, VoidCallback onTap, {bool perigo = false}) => ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: perigo ? ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white) : null,
        child: Text(t),
      );

  void _mostrarRelatorio(String texto) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Setores do cartão'),
        content: SingleChildScrollView(
          child: SelectableText(texto, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: texto));
              Navigator.pop(c);
            },
            child: const Text('Copiar'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  void _mostrarId(String id) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ID do cartão'),
        content: SelectableText(id, style: const TextStyle(fontFamily: 'monospace', fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: id));
              Navigator.pop(c);
            },
            child: const Text('Copiar'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _confirmar(String msg, VoidCallback ok) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sim')),
        ],
      ),
    );
    if (sim == true) ok();
  }

  // ===== NfcHandler: respostas assíncronas dos métodos do cartão de evento =====
  @override
  void showSuccess(List result) => _log('Leitura OK: $result');
  @override
  void showSuccessWrite(int result) => _log('Cartão aberto: $result');
  @override
  void showSuccessReWrite(String result) => _log('Recarga OK: $result');
  @override
  void showSuccessFormat(int result) => _log('Formatado: $result');
  @override
  void showSuccessDebitNfc(String result) => _log('Débito OK: $result');
  @override
  void showSuccessRefundNfc(String result) => _log('Estorno OK: $result');

  @override
  void showErrorRead(String message) => _log('Erro leitura: $message');
  @override
  void showErrorWrite(String message) => _log('Erro gravação: $message');
  @override
  void showErrorReWrite(String message) => _log('Erro recarga: $message');
  @override
  void showErrorFormat(String message) => _log('Erro formatar: $message');
  @override
  void showErrorDebitNfc(String message) => _log('Erro débito: $message');
  @override
  void showErrorRefundNfc(String message) => _log('Erro estorno: $message');

  @override
  void onError(String message) => _log('Erro: $message');
  @override
  void onMessage(String message) => _log('Mensagem: $message');
  @override
  void onLoading(bool show) {
    if (mounted) setState(() => _loading = show);
  }

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
