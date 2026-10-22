package dev.gabul.pagseguro_smart_flutter.nfc.usecase;

import android.nfc.tech.MifareClassic;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag;
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagNFCResult;
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagNearFieldCardData;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagLedData;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagSimpleNFCData;
import br.com.uol.pagseguro.plugpagservice.wrapper.exception.PlugPagException;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagNFCAuth;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.EM1KeyType;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagNFCAuthDirectly;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.result.PlugPagNFCInfosResultDirectly;
import dev.gabul.pagseguro_smart_flutter.helpers.NFCConstants;
import dev.gabul.pagseguro_smart_flutter.helpers.Utils;
import io.reactivex.Completable;
import io.reactivex.Observable;
import io.reactivex.ObservableOnSubscribe;

public class NFCUseCase {

    private final PlugPag mPlugPag;

    public NFCUseCase(PlugPag plugPag) {
        mPlugPag = plugPag;
    }

    public Observable<Integer> writeNfc(PlugPagSimpleNFCData cardData){
        return Observable.create(emitter -> {
            try {

                int resultStartNfc = mPlugPag.startNFCCardDirectly();
                if (resultStartNfc != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    emitter.onComplete();
                    return;
                }

                PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, (byte) cardData.getSlot(), MifareClassic.KEY_DEFAULT);
                int resultAuth = mPlugPag.authNFCCardDirectly(auth);
                if (resultAuth != 1) {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                if(cardData.getSlot() == NFCConstants.CARD_OPENED_BLOCK) {

                    PlugPagSimpleNFCData readCardData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, cardData.getSlot(), new byte[16]);
                    PlugPagNFCResult resultRead = mPlugPag.readNFCCardDirectly(readCardData);

                    if (resultRead.getResult() == 1) {

                        String isOpened = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));

                        if(isOpened.equals("1")) {

                            mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                            emitter.onError(new PlugPagException(String.format("cartao_ja_aberto", cardData.getSlot())));
                            emitter.onComplete();
                            return;
                        }

                    } else {

                        mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                        emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc para verificar se o cartão está aberto", cardData.getSlot())));
                        emitter.onComplete();
                        return;
                    }

                }

                mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_YELLOW));
                Integer result = writeAndVerify(cardData);

                if (result == 1) {
                    emitter.onNext(result);
                } else {
                    emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ]  do cartão nfc", cardData.getSlot())));
                }

                mPlugPag.stopNFCCardDirectly();
            } catch (Exception e){
                e.printStackTrace();
                emitter.onError(e);
            }

            emitter.onComplete();
        });
    }

    public Observable<String> reWriteNfc(PlugPagSimpleNFCData cardData) {
        return Observable.create(emitter -> {

            try {

                int resultStartNfc = mPlugPag.startNFCCardDirectly();

                if (resultStartNfc != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    emitter.onComplete();
                    return;
                }

                PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, (byte) cardData.getSlot(), MifareClassic.KEY_DEFAULT);
                int resultAuth = mPlugPag.authNFCCardDirectly(auth);
                if (resultAuth != 1) {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                PlugPagSimpleNFCData readCardData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, cardData.getSlot(), new byte[16]);
                PlugPagNFCResult resultRead = mPlugPag.readNFCCardDirectly(readCardData);

                // Só o setor de cardData.getSlot() está autenticado: ler o bloco da tag (setor 1)
                // a partir de outro setor gera NF02. A tag é lida quando o próprio slot é o da tag.
                String resultReadstring = "";

                if(cardData.getSlot() == NFCConstants.TAG_BLOCK && resultRead.getResult() == 1) {
                    resultReadstring = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));
                }

                System.out.println("resultReadstring");
                System.out.println(resultReadstring);

                if (resultRead.getResult() == 1) {

                } else {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

              /*  if(cardData.getSlot() == NFCConstants.EVENT_ID_BLOCK) {

                    String idEventoCard = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));

                    System.out.println("idEventoCard");
                    System.out.println(idEventoCard);



                    if(!idEventoCard.equals(new String(cardData.getValue()))) {
                        mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                        emitter.onError(new PlugPagException(String.format("evento_nao_compativel", cardData.getSlot())));
                        emitter.onComplete();
                        return;
                    }
                } */


                Integer resultWrite = 1;
                if((NFCConstants.VALUE_BLOCK == cardData.getSlot()) || (NFCConstants.OPEN_VALUE_CARD_BLOCK == cardData.getSlot())) {

                    //Soma valor atual com o valor de recarga
                    Double valorAtual = Double.parseDouble(Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data"))));
                    Double valorRecarga = Double.parseDouble(Utils.removeAsterisco(new String(cardData.getValue())));
                    Double valorNovo = (valorAtual + valorRecarga);
                    String valorNovoString = Utils.adicionaAsterisco(valorNovo.toString());
                    cardData.setValue(valorNovoString.getBytes());

                    resultWrite = writeAndVerify(cardData);

                }



//                StringBuffer resultReadstring = new StringBuffer("");
//
//                for (Integer block : blocks ) {
//
//                    PlugPagSimpleNFCData readCardDataFinal = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[16]);
//                    PlugPagNFCResult resultReadFinal = mPlugPag.readNFCCardDirectly(readCardDataFinal);
//
//                    resultReadstring.append(Utils.removeAsterisco(new String(resultReadFinal.getSlots()[block].get("data"))));
//                }



                if (resultRead.getResult() == 1) {

                } else {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                if (resultWrite == 1) {
                    emitter.onNext(resultReadstring);
                } else {
                    emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ]  do cartão nfc", cardData.getSlot())));
                }


                mPlugPag.stopNFCCardDirectly();
            } catch (Exception e){
                e.printStackTrace();
                emitter.onError(e);
            }

            emitter.onComplete();
        });
    }

    public Observable<String> reFundNfc(PlugPagSimpleNFCData cardData) {
        return Observable.create(emitter -> {


            try {

                int resultStartNfc = mPlugPag.startNFCCardDirectly();
                if (resultStartNfc != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    emitter.onComplete();
                    return;
                }

                PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, (byte) cardData.getSlot(), MifareClassic.KEY_DEFAULT);
                int resultAuth = mPlugPag.authNFCCardDirectly(auth);
                if (resultAuth != 1) {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                PlugPagSimpleNFCData readCardData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, cardData.getSlot(), new byte[16]);
                PlugPagNFCResult resultRead = mPlugPag.readNFCCardDirectly(readCardData);

                String resultReadstring = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));

                if (resultRead.getResult() == 1) {

                } else {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

              /*  if(cardData.getSlot() == NFCConstants.EVENT_ID_BLOCK) {

                    String idEventoCard = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));

                    System.out.println("idEventoCard");
                    System.out.println(idEventoCard);



                    if(!idEventoCard.equals(new String(cardData.getValue()))) {
                        mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                        emitter.onError(new PlugPagException(String.format("evento_nao_compativel", cardData.getSlot())));
                        emitter.onComplete();
                        return;
                    }
                } */


                Integer resultWrite = 1;
                if(NFCConstants.VALUE_BLOCK == cardData.getSlot()) {

                    //Soma valor atual com o valor de recarga
                    Double valorAtual = Double.parseDouble(Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data"))));
                    Double valorRecarga = Double.parseDouble(Utils.removeAsterisco(new String(cardData.getValue())));
                    Double valorNovo = (valorAtual + valorRecarga);
                    String valorNovoString = Utils.adicionaAsterisco(valorNovo.toString());
                    cardData.setValue(valorNovoString.getBytes());

                    resultWrite = writeAndVerify(cardData);

                }



//                StringBuffer resultReadstring = new StringBuffer("");
//
//                for (Integer block : blocks ) {
//
//                    PlugPagSimpleNFCData readCardDataFinal = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[16]);
//                    PlugPagNFCResult resultReadFinal = mPlugPag.readNFCCardDirectly(readCardDataFinal);
//
//                    resultReadstring.append(Utils.removeAsterisco(new String(resultReadFinal.getSlots()[block].get("data"))));
//                }



                if (resultRead.getResult() == 1) {

                } else {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                if (resultWrite == 1) {
                    emitter.onNext(resultReadstring);
                } else {
                    emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ]  do cartão nfc", cardData.getSlot())));
                }


                mPlugPag.stopNFCCardDirectly();
            } catch (Exception e){
                e.printStackTrace();
                emitter.onError(e);
            }

            emitter.onComplete();
        });
    }

    public Observable<String> debitNfc(PlugPagSimpleNFCData cardData) {
        return Observable.create(emitter -> {
            try {

                int resultStartNfc = mPlugPag.startNFCCardDirectly();
                if (resultStartNfc != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    emitter.onComplete();
                    return;
                }

                PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, (byte) cardData.getSlot(), MifareClassic.KEY_DEFAULT);
                int resultAuth = mPlugPag.authNFCCardDirectly(auth);
                if (resultAuth != 1) {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                PlugPagSimpleNFCData readCardData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, cardData.getSlot(), new byte[16]);
                PlugPagNFCResult resultRead = mPlugPag.readNFCCardDirectly(readCardData);

                String resultReadstring = "";
                if (resultRead.getResult() == 1) {

                 resultReadstring = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));

                } else {

                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

//                if(cardData.getSlot() == NFCConstants.EVENT_ID_BLOCK) {
//
//                    String idEventoReadCard = Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data")));
//                    boolean vazio = Arrays.equals(idEventoReadCard.getBytes(), new byte[16]);
//                    String idEventoWriteCard = new String(cardData.getValue());
//
//                    System.out.println("idEventoCard");
//                    System.out.println(idEventoReadCard);
//
//                    if(!vazio) {
//                        if(!idEventoReadCard.equals(idEventoWriteCard)) {
//                            mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
//                            emitter.onError(new PlugPagException(String.format("evento_nao_compativel", cardData.getSlot())));
//                            emitter.onComplete();
//                            return;
//                        }
//                    }
//                }

                //Soma valor atual com o valor de recarga

                Integer resultWrite = 1;
                if(NFCConstants.VALUE_BLOCK == cardData.getSlot()) {

                    Double valorAtual = Double.parseDouble(Utils.removeAsterisco(new String(resultRead.getSlots()[cardData.getSlot()].get("data"))));
                    Double valorProdutos = Double.parseDouble(Utils.removeAsterisco(new String(cardData.getValue())));
                    Double novoSaldo = 0.00;

                    if (valorAtual < valorProdutos) {
                        mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                        emitter.onError(new PlugPagException(String.format("saldo_insuficiente", cardData.getSlot())));
                        emitter.onComplete();
                        return;
                    } else {
                        novoSaldo = (valorAtual - valorProdutos);
                    }

                    String valorNovoString = Utils.adicionaAsterisco(novoSaldo.toString());
                    cardData.setValue(valorNovoString.getBytes());

                    resultWrite = writeAndVerify(cardData);

                }

                if (resultWrite == 1) {
                    emitter.onNext(resultReadstring);
                } else {
                    emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ]  do cartão nfc", cardData.getSlot())));
                }


                mPlugPag.stopNFCCardDirectly();
            } catch (Exception e){
                e.printStackTrace();
                emitter.onError(e);
            }

            emitter.onComplete();
        });
    }


    /**
     * Grava o bloco e relê na mesma sessão (o setor continua autenticado), comparando os 16 bytes.
     * Retorna o resultado da gravação do SDK (1 = ok); lança PlugPagException se o lido não bater.
     * Trailers não são conferidos: a chave A sempre é lida como zeros.
     */
    private int writeAndVerify(PlugPagSimpleNFCData cardData) throws PlugPagException {
        int written = mPlugPag.writeToNFCCardDirectly(cardData);
        int block = cardData.getSlot();
        if (written != 1 || (block + 1) % 4 == 0) {
            return written;
        }

        byte[] expected = Arrays.copyOf(cardData.getValue() == null ? new byte[0] : cardData.getValue(), 16);
        PlugPagNFCResult read = mPlugPag.readNFCCardDirectly(new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[16]));
        byte[] actual = null;
        if (read != null && read.getResult() == 1 && read.getSlots() != null) {
            HashMap<String, byte[]>[] slots = read.getSlots();
            if (block < slots.length && slots[block] != null) actual = slots[block].get(PlugPagNearFieldCardData.NFC_DATA);
            if (actual == null && read.getStartSlot() < slots.length && slots[read.getStartSlot()] != null) {
                actual = slots[read.getStartSlot()].get(PlugPagNearFieldCardData.NFC_DATA);
            }
        }

        if (actual == null || !Arrays.equals(expected, Arrays.copyOf(actual, 16))) {
            mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
            throw new PlugPagException(String.format("Gravação não confirmada no bloco [ %s ]: lido %s", block, actual == null ? "nada" : Utils.convertBytes2String(actual, true)));
        }
        return written;
    }

    public Observable<PlugPagNFCResult> readNfc(Integer block, String idEvento) {
        return Observable.create(emitter -> {
            int resultStartNfc = mPlugPag.startNFCCardDirectly();
            if (resultStartNfc != 1){
                emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                emitter.onComplete();
                return;
            }

            PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, block.byteValue(), MifareClassic.KEY_DEFAULT);
            int resultAuth = mPlugPag.authNFCCardDirectly(auth);
            if (resultAuth != 1){
                emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", block)));
                emitter.onComplete();
                return;
            }

            PlugPagSimpleNFCData cardData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[16]);

            PlugPagNFCResult result = mPlugPag.readNFCCardDirectly(cardData);

            // Cartão de outro evento: recusa. Cartão sem evento gravado (bloco zerado) é aceito.
            if (result.getResult() == 1 && block.equals(NFCConstants.EVENT_ID_BLOCK) && idEvento != null) {
                byte[] eventData = result.getSlots()[block].get("data");
                boolean vazio = Arrays.equals(eventData, new byte[eventData.length]);
                String idEventoCard = Utils.removeAsterisco(new String(eventData)).trim();

                if (!vazio && !idEventoCard.equals(idEvento.trim())) {
                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    mPlugPag.stopNFCCardDirectly();
                    emitter.onError(new PlugPagException("evento_nao_compativel"));
                    emitter.onComplete();
                    return;
                }
            }

            if (result.getResult() == 1){
                Log.d(NFCUseCase.class.getSimpleName(), Utils.convertBytes2String(result.getSlots()[result.getStartSlot()].get("data"), false));
                emitter.onNext(result);
            } else {
                emitter.onError(new PlugPagException(String.format("Ocoreu um erro ao ler bloco [ %s ] do cartão nfc", block)));
            }

            mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_YELLOW));
            mPlugPag.stopNFCCardDirectly();

            emitter.onComplete();
        });
    }

    public Observable<Integer> formatNfc(PlugPagSimpleNFCData cardData) {
        return Observable.create(emitter -> {
            try {

                int resultStartNfc = mPlugPag.startNFCCardDirectly();
                if (resultStartNfc != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    emitter.onComplete();
                    return;
                }

                PlugPagNFCAuth auth = new PlugPagNFCAuth(PlugPagNearFieldCardData.ONLY_M, (byte) cardData.getSlot(), MifareClassic.KEY_DEFAULT);

                int resultAuth = mPlugPag.authNFCCardDirectly(auth);
                if (resultAuth != 1) {


                    emitter.onError(new PlugPagException(String.format("Erro ao autenticar bloco [ %s ]", cardData.getSlot())));
                    emitter.onComplete();
                    return;
                }

                Integer result = mPlugPag.writeToNFCCardDirectly(cardData);

                if (result == 1) {
                    emitter.onNext(result);
                } else {
                    emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ]  do cartão nfc", cardData.getSlot())));
                }

                mPlugPag.stopNFCCardDirectly();

            } catch (Exception e){
                e.printStackTrace();
                emitter.onError(e);
            }

            emitter.onComplete();
        });
    }


    public Observable<Object> controlLed(PlugPagLedData plugPagLedData) {

        return Observable.create(emitter -> {
            int result = mPlugPag.setLed(plugPagLedData);
            if (result == 1) {
                emitter.onNext(result);
            } else {
                emitter.onError(new PlugPagException());
            }
            emitter.onComplete();
        });
    }

    public Completable abort(){
        return Completable.create(emitter -> mPlugPag.abortNFC());
    }

    /**
     * Zera todos os blocos de dados do Mifare Classic 1K (47 blocos) numa única aproximação.
     * Não toca no bloco 0 (fabricante) nem nos trailers (chaves e permissões).
     * Emite a quantidade de blocos zerados.
     */
    public Observable<Integer> formatAllDataBlocks() {
        return Observable.create(emitter -> {
            try {
                if (mPlugPag.startNFCCardDirectly() != 1) {
                    emitter.onError(new PlugPagException("Ocorreu um erro ao iniciar serviço nfc"));
                    return;
                }

                PlugPagNFCInfosResultDirectly card = mPlugPag.detectNfcCardDirectly(PlugPagNearFieldCardData.ONLY_M, 10);
                if (card == null || card.getResult() != 1 || card.getSerialNumber() == null) {
                    mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                    emitter.onError(new PlugPagException("Cartão não detectado"));
                    return;
                }

                int cleared = 0;
                for (int sector = 0; sector < 16; sector++) {
                    int first = sector * 4;
                    int trailer = first + 3;

                    // Cada setor tem a própria chave: autentica antes de gravar nos blocos dele
                    PlugPagNFCAuthDirectly auth = new PlugPagNFCAuthDirectly((byte) first, MifareClassic.KEY_DEFAULT, EM1KeyType.TYPE_A, card.getSerialNumber());
                    if (mPlugPag.justAuthNfcDirectly(auth) != 1) {
                        mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                        emitter.onError(new PlugPagException(String.format("Erro ao autenticar setor [ %s ] (%s blocos já zerados)", sector, cleared)));
                        return;
                    }

                    for (int block = first; block < trailer; block++) {
                        if (block == 0) continue; // fabricante: somente leitura
                        int written = mPlugPag.writeToNFCCardDirectly(new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[16]));
                        if (written != 1) {
                            mPlugPag.setLed(new PlugPagLedData(PlugPagLedData.LED_RED));
                            emitter.onError(new PlugPagException(String.format("Ocorreu um erro ao escrever no bloco [ %s ] do cartão nfc (%s blocos já zerados)", block, cleared)));
                            return;
                        }
                        cleared++;
                    }
                }

                emitter.onNext(cleared);
                emitter.onComplete();
            } catch (Exception e) {
                e.printStackTrace();
                emitter.onError(e);
            } finally {
                try {
                    mPlugPag.stopNFCCardDirectly();
                } catch (Exception ignored) {
                }
            }
        });
    }

    public Observable<Integer> clearBlocks(List<Integer> blocks) {
        return Observable.create((ObservableOnSubscribe<Integer>) emitter -> {

            for (Integer trailerBlock : getSectorTrailerBlocks()) {
                if (blocks.contains(trailerBlock)){
                    emitter.onError(new PlugPagException(String.format("O bloco [ %s ] é de permissão de acesso e não pode ser limpo!", trailerBlock)));
                    emitter.onComplete();
                    return;
                }
            }

            for ( Integer block : blocks ){
                emitter.onNext(block);
            }

            if (!emitter.isDisposed()){
                emitter.onComplete();
            }
        })
                .concatMap(block -> { // Using concatMap to ensure that observables are not called at the same time
                    PlugPagSimpleNFCData emptyData = new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, MifareClassic.KEY_DEFAULT);
                    emptyData.setValue(new byte[16]);
                    return formatNfc(emptyData);
                }).distinct();

    }

    public Observable<Integer> writePermissions(@NonNull byte[] keyA, @NonNull byte[] permissions, @Nullable byte[] keyB){
        return Observable.create((ObservableOnSubscribe<Integer>) emitter -> {
            for (Integer i : getSectorTrailerBlocks()){
                emitter.onNext(i);
            }

            if (!emitter.isDisposed()){
                emitter.onComplete();
            }
        })
                .concatMap(sectorTrailerBlock -> {
                    PlugPagSimpleNFCData cardData = new PlugPagSimpleNFCData(
                            PlugPagNearFieldCardData.ONLY_M,
                            sectorTrailerBlock,
                            MifareClassic.KEY_DEFAULT);
                    cardData.setValue(buildDataAccess(keyA, permissions, keyB));
                    return writeNfc(cardData);
                });
    }

    private List<Integer> getSectorTrailerBlocks(){
        final List<Integer> ret = new ArrayList<>();
        for (int i = 7; i < 64; i += 4){
            ret.add(i);
        }
        return ret;
    }

    private byte[] buildDataAccess(@NonNull byte[] keyA, @NonNull byte[] permissions, @Nullable byte[] keyB){
        byte[] data = new byte[16];
        System.arraycopy(keyA, 0, data, 0, 6);
        System.arraycopy(permissions, 0, data, 6, 4);
        if (keyB != null){
            System.arraycopy(keyB, 0, data, 10, 6);
        }
        return data;
    }


}