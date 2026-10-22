import 'package:flutter/material.dart';

import 'blocks_tab.dart';
import 'card_tab.dart';
import 'event_tab.dart';

/// Área NFC: Cartão · Evento · Blocos.
class NfcPage extends StatelessWidget {
  const NfcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(tabs: [
            Tab(text: 'Cartão'),
            Tab(text: 'Evento'),
            Tab(text: 'Blocos'),
          ]),
          Expanded(
            child: TabBarView(children: [
              CardTab(),
              EventTab(),
              BlocksTab(),
            ]),
          ),
        ],
      ),
    );
  }
}
