# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## O que é este projeto

`pagseguro_smart_flutter` é um plugin Flutter (federated-style single package) que integra apps Flutter com o SDK **PlugPagServiceWrapper** da PagSeguro/PagBank, permitindo processar pagamentos, ler/escrever cartões NFC e imprimir em maquininhas **Smart** (POS Android). Funciona apenas em máquinas PagSeguro Smart — a implementação real (`android/`) é Android-only. O lado iOS (`ios/`) é apenas um stub que não implementa nenhum método real (`FlutterMethodNotImplemented` para tudo além de `getPlatformVersion`).

Publicado no pub.dev; versão atual em `pubspec.yaml`/`CHANGELOG.md`.

## Comandos

Use FVM (Flutter Version Management) — a versão do Flutter é fixada em `.fvmrc` (`3.22.1`). Prefixe comandos Flutter com `fvm` quando disponível, ou garanta que o SDK do Flutter instalado corresponda à versão do `.fvmrc`.

```bash
# instalar dependências (raiz do plugin)
flutter pub get

# instalar dependências do app de exemplo
cd example && flutter pub get

# rodar o app de exemplo (precisa de uma maquininha Smart física via Android; não roda em emulador comum)
cd example && flutter run

# lint (usa flutter_lints via analysis_options.yaml)
flutter analyze

# formatação
dart format .
```

Não há testes automatizados no repositório (sem diretório `test/`). O workflow de CI (`.github/workflows/publish.yml`) publica no pub.dev ao criar uma tag `v[0-9]+.[0-9]+.[0-9]+*`; os passos de analyze/test/format estão comentados nesse workflow.

## Arquitetura

### Bridge Dart ↔ Android via MethodChannel

Um único `MethodChannel` nomeado `"pagseguro_smart_flutter"` é compartilhado por **pagamentos**, **NFC** e **impressão**. Não há channels separados por feature.

- **Dart → Native**: cada chamada Dart invoca um método pelo nome (string) no channel, com argumentos como `Map`. Os nomes de método ficam centralizados em `lib/payments/utils/payment_types.dart` (`PaymentTypeCall` enum + extension `.method`), e são espelhados manualmente do lado Java em `PagSeguroSmart.java` (constantes `PAYMENT_*`, `NFC_*`, `PRINTER_*`). **Ao adicionar um novo método nativo, é preciso atualizar ambos os lados manualmente** — não há geração de código.
- **Native → Dart**: o SDK nativo notifica o Flutter de volta invocando métodos no mesmo channel (`channel.invokeMethod(...)` no Java), que são roteados no Dart através de `_callHandler` em `lib/payments/payment.dart` e `lib/payments/nfc.dart`, usando o enum `PaymentTypeHandler` (também em `payment_types.dart`) para mapear a string do método para o callback correto no handler do usuário.

### API pública Dart (`lib/`)

- `PagseguroSmart` (`lib/pagseguro_smart_flutter.dart`) — singleton (`PagseguroSmart.instance()`) que expõe `payment` (`Payment`) e `nfc` (`Nfc`). É necessário chamar `initPayment(handler)` / `initNfc(handler)` antes de acessar os getters, senão eles lançam uma exceção (string, não uma `Exception` tipada).
- `NfcSmart` (`lib/nfc_smart_flutter.dart`) — singleton alternativo, expõe **apenas** NFC (usado quando o app só precisa de NFC, sem pagamento).
- `Payment` (`lib/payments/payment.dart`) — métodos de pagamento (crédito, débito, PIX, voucher, parcelado), operações (abort, refund, last transaction, ativação de pinpad) e impressão (`printer`, `printerFile`, `printerfromFile`, `printerFilePath`). Recebe um `PaymentHandler` (contrato em `lib/payments/handler/payment_handler.dart`) cujos callbacks são disparados a partir das mensagens nativas.
- `Nfc` (`lib/payments/nfc.dart`) — operações de leitura/escrita/reescrita/estorno/débito/formatação de cartão NFC. Recebe um `NfcHandler` (`lib/payments/handler/nfc_handler.dart`).
- `PrintRenderWidget` (`lib/payments/print_render_widget.dart`) — permite imprimir um widget Flutter arbitrário renderizando-o para imagem/arquivo e enviando para a impressora da maquininha.
- Valores monetários são passados em **centavos** (inteiros) para os métodos de pagamento nativos; a conversão de reais para centavos (`* 100`) é responsabilidade do app consumidor (ver exemplo no `README.md`).
- `userReference` é truncado para 10 caracteres (`_sanitizeUserReference`) antes de enviar ao SDK nativo — limitação do PlugPag.

### Lado Android (`android/src/main/java/dev/gabul/pagseguro_smart_flutter/`)

Implementação real, em Java, organizada por feature com um padrão MVP-like (Contract/Presenter/Fragment/UseCase):

- `PagseguroSmartFlutterPlugin.java` — entry point do `FlutterPlugin`; registra o `MethodCallHandler` e delega toda chamada cujo método comece com `"payment"` (ou seja `"startPayment"`) para `core/PagSeguroSmart.java`.
- `core/PagSeguroSmart.java` — roteador central: recebe o `MethodCall`, instancia `PlugPag` (SDK PagSeguro), e despacha para `payments/PaymentsPresenter`, `nfc/NFCPresenter` ou `printer/PrinterPresenter` conforme o nome do método.
- `payments/`, `nfc/`, `transactions/`, `printer/`, `user/` — cada pacote segue `*Contract` (interface), `*Presenter` (lógica), `*Fragment` (implementação do contrato que chama `channel.invokeMethod` de volta ao Dart), e `*UseCase`/`usecase/` quando aplicável.
- Dependências nativas relevantes (`android/build.gradle`): `br.com.uol.pagseguro.plugpagservice.wrapper` (SDK oficial da PagSeguro, resolvido via repositório Maven customizado do GitHub), Dagger 2 (DI), RxJava2, Mosby (MVP), Gson.
- `minSdkVersion` é fixado em 23 (exigência do PlugPagService). Apps consumidores precisam declarar a permissão `br.com.uol.pagseguro.permission.MANAGE_PAYMENTS` e um `intent-filter` de `br.com.uol.pagseguro.PAYMENT` no `AndroidManifest.xml` (documentado no `README.md`).

### Ao adicionar uma nova operação end-to-end

Tipicamente é preciso tocar em 5 lugares: (1) enum `PaymentTypeCall`/`PaymentTypeHandler` em `payment_types.dart`, (2) método público em `Payment`/`Nfc` (Dart), (3) constante + branch em `PagSeguroSmart.java`, (4) lógica no `*Presenter`/`*UseCase` Java correspondente, (5) se houver callback nativo→Dart novo, também o `*Fragment` Java e o `_callHandler` Dart.
