## 1.7.0

- Adiciona `formatAllNfc`: zera os 47 blocos de dados do Mifare Classic 1K numa única aproximação, autenticando setor por setor (não altera o bloco 0 nem os trailers). Em caso de falha informa o setor e quantos blocos já foram zerados
- `formatNfc` continua zerando apenas os blocos do cartão de evento
- `writeBlock`/`writeBlockText` relêem o bloco na mesma aproximação e conferem os 16 bytes; se não bater, lançam `WRITE_NOT_CONFIRMED`
- `writeNfc`, `reWriteNfc`, `debitNfc` e `refundNfc` conferem cada bloco gravado na mesma sessão; divergência chega no `showError...` como "Gravação não confirmada no bloco N"
- Corrige recarga NFC (`reWriteNfc`): lia o bloco da tag sem autenticar o setor dele, causando `NF02`
- Adiciona `debugReadAllSectors` (diagnóstico dos 16 setores)
- App de exemplo reorganizado: navegação por áreas (Pagamento, NFC, Logs), log central, dialog de status do pagamento, resumo do cartão de evento lido (relido automaticamente após gravar) e botões Formatar / Formatar tudo

## 1.6.0

- Adiciona API NFC genérica com retorno via `Future`: `readCardId`, `readBlock`, `writeBlock`, `readBlockText`, `writeBlockText`, `abortNfc` e `debugReadBlock`
- `readCardId` lê o UID de qualquer cartão NFC tipo A (inclusive cartões com processador), para fluxos com saldo no servidor
- Leitura/gravação Mifare passa a detectar o cartão e autenticar com o número de série antes de ler/gravar
- Corrige leitura NFC: o valor enviado ao SDK na leitura era a chave do setor, causando erro `NF02`
- Corrige métodos NFC antigos (`readNfc`, `writeNfc`, `debitNfc`, etc.) que nunca completavam o `Future`
- Corrige `writeNfc` gravando o campo "aberto" no bloco do evento em vez do `idEvento`
- Reativa a validação de evento na leitura (`evento_nao_compativel`)
- **Atenção:** cartões abertos em versões anteriores têm o bloco do evento incorreto e serão recusados na leitura; reabra-os (`formatNfc` + `writeNfc`)
- Ajusta `ActionResult` para compatibilidade do número de parcelas entre versões do wrapper
- App de exemplo: nova aba "NFC" para testar todas as funções

## 1.3.0

- Atualiza versão do `wrapper` da pagseguro para `1.29.5`

## 1.2.0

- Adiciona função para renderizar e imprimir um componente

## 1.1.11

- Adiciona função reboot do dispositivo
- Adiciona função beep do dispositivo
- Atualiza SDK plugpag service para versão 1.29.2

## 1.1.10

- Adiciona função printerByFilePath
- Corrige possíveis erros ao devolver o retorno do método de impressão

## 1.1.9

- Adiciona CI/CD para deploy no pub.dev

## 1.1.8

- Correção do método printerFromFile

## 1.1.7

- Correção dos métodos de transação
- Nova versão do SDK da PagSeguro 1.27.2
- Adicionado funções de NFC para transação

## 1.1.6

- Nova versão do SDK da PagSeguro 1.27.2
- Adicionado funções de NFC para transação

## 1.1.5

- Adicionado parâmetros nos métodos de pagamento para informar userReference, printReceipt, partialPay e isCarne
- Disponibilizado método startPayment da biblioteca PlugPag
- Alterado versão plugpagservice.wrapper para 1.27.2
- Adicionada a resposta todas as propriedades do objeto PlugPagTransactionResult - https://pagseguro.github.io/pagseguro-sdk-plugpagservicewrapper/-wrapper-p-p-s/br.com.uol.pagseguro.plugpagservice.wrapper/-plug-pag-transaction-result/index.html

## 1.1.4

- Correção do status de erro no método de transação
- Configurado nova função para obter status de ativação do terminal pinpad

## 1.1.3

- Correção sobre a impressão do estabelecimento que não estava imprimindo.

## 1.1.2

- Correção da documentação do plugin.

## 1.1.1

- Adicionado método pix para pagseguro.

# 1.0.1

- Atualizado documentação de uso

## 1.0.0+1

- Atualização da documentação do Plugin para utilização.

## 1.0.0

- Primeiro release do Plugin.
