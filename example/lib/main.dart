import 'package:flutter/material.dart';

import 'core/app_log.dart';
import 'logs/logs_page.dart';
import 'nfc/nfc_page.dart';
import 'nfc/nfc_store.dart';
import 'payment/payment_page.dart';
import 'payment/payment_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Os dois precisam ser inicializados para os getters payment/nfc funcionarem.
  // O channel é um só: o último init é quem recebe os callbacks, então começa no Pagamento.
  NfcStore.instance.activate();
  PaymentStore.instance.activate();
  AppLog.add(LogSource.system, 'Handler de pagamento ativo');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PagSeguro Smart',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1BB99A),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _titles = ['Pagamento', 'NFC', 'Logs'];

  void _select(int index) {
    // Troca o handler ativo no channel compartilhado ao mudar de área
    if (index == 0 && _index != 0) {
      PaymentStore.instance.activate();
      AppLog.add(LogSource.system, 'Handler de pagamento ativo');
    } else if (index == 1 && _index != 1) {
      NfcStore.instance.activate();
      AppLog.add(LogSource.system, 'Handler de NFC ativo');
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const [
          PaymentPage(),
          NfcPage(),
          LogsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'Pagamento'),
          const NavigationDestination(icon: Icon(Icons.contactless), label: 'NFC'),
          NavigationDestination(
            icon: ValueListenableBuilder(
              valueListenable: AppLog.entries,
              builder: (context, entries, _) => Badge(
                isLabelVisible: entries.any((e) => e.isError),
                child: const Icon(Icons.terminal),
              ),
            ),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
