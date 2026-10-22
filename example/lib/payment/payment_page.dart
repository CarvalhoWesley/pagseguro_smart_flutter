import 'package:flutter/material.dart';

import 'print_tab.dart';
import 'sale_tab.dart';
import 'transactions_tab.dart';

/// Área Pagamento: Vender · Transações · Impressão.
class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(tabs: [
            Tab(text: 'Vender'),
            Tab(text: 'Transações'),
            Tab(text: 'Impressão'),
          ]),
          Expanded(
            child: TabBarView(children: [
              SaleTab(),
              TransactionsTab(),
              PrintTab(),
            ]),
          ),
        ],
      ),
    );
  }
}
