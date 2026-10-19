package dev.gabul.pagseguro_smart_flutter.nfc;

import android.nfc.tech.MifareClassic;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.Arrays;
import java.util.HashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPag;
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagNFCResult;
import br.com.uol.pagseguro.plugpagservice.wrapper.PlugPagNearFieldCardData;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.EM1KeyType;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagNFCAuthDirectly;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.request.PlugPagSimpleNFCData;
import br.com.uol.pagseguro.plugpagservice.wrapper.data.result.PlugPagNFCInfosResultDirectly;
import io.flutter.plugin.common.MethodChannel;

/**
 * Leitura/gravação genérica de blocos Mifare Classic (sem regra de negócio).
 * Cada operação é uma sessão completa: start -> detect -> auth -> read/write -> stop.
 * O resultado volta direto no Future do Dart (MethodChannel.Result).
 */
public class NfcRawHandler {

  private static final String TAG = "NfcRawHandler";
  private static final int BLOCK_SIZE = 16;
  private static final int MAX_BLOCK = 63; // Mifare Classic 1K: blocos 0..63
  private static final int DETECT_TIMEOUT = 10;

  // Uma thread só: as chamadas do PlugPag bloqueiam e o leitor atende um cartão por vez
  private static final ExecutorService EXECUTOR = Executors.newSingleThreadExecutor();

  private final PlugPag mPlugPag;
  private final Handler mMainHandler = new Handler(Looper.getMainLooper());

  public NfcRawHandler(PlugPag plugPag) {
    this.mPlugPag = plugPag;
  }

  public void readBlock(Integer block, byte[] key, MethodChannel.Result result) {
    String error = validateBlock(block, true);
    if (error != null) {
      result.error("INVALID_BLOCK", error, null);
      return;
    }
    byte[] authKey = key != null ? key : MifareClassic.KEY_DEFAULT;

    EXECUTOR.execute(() -> {
      try {
        String sessionError = openSession(block, authKey, null);
        if (sessionError != null) {
          reply(result, "NFC_ERROR", sessionError);
          return;
        }
        PlugPagNFCResult read = mPlugPag.readNFCCardDirectly(readRequest(block));
        if (read == null || read.getResult() != 1) {
          String detalhe = read == null ? "sem resposta" : read.getErrorCode() + " " + read.getMessage();
          reply(result, "READ_ERROR", "Erro ao ler o bloco " + block + " (" + detalhe + ")");
          return;
        }
        byte[] data = extractData(read, block);
        if (data == null || data.length == 0) {
          reply(result, "READ_ERROR", "Leitura sem dados");
          return;
        }
        mMainHandler.post(() -> result.success(data));
      } catch (Exception e) {
        reply(result, "NFC_ERROR", e.getClass().getSimpleName() + ": " + e.getMessage());
      } finally {
        stopQuietly();
      }
    });
  }

  public void writeBlock(Integer block, byte[] data, byte[] key, MethodChannel.Result result) {
    String error = validateBlock(block, false);
    if (error != null) {
      result.error("INVALID_BLOCK", error, null);
      return;
    }
    if (data == null || data.length > BLOCK_SIZE) {
      result.error("INVALID_DATA", "Os dados devem ter no máximo 16 bytes", null);
      return;
    }
    byte[] authKey = key != null ? key : MifareClassic.KEY_DEFAULT;
    // Bloco tem sempre 16 bytes: completa com zeros
    byte[] padded = Arrays.copyOf(data, BLOCK_SIZE);

    EXECUTOR.execute(() -> {
      try {
        String sessionError = openSession(block, authKey, null);
        if (sessionError != null) {
          reply(result, "NFC_ERROR", sessionError);
          return;
        }
        int written = mPlugPag.writeToNFCCardDirectly(new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, padded));
        if (written != 1) {
          reply(result, "WRITE_ERROR", "Erro ao gravar o bloco " + block);
          return;
        }
        mMainHandler.post(() -> result.success(true));
      } catch (Exception e) {
        reply(result, "NFC_ERROR", e.getClass().getSimpleName() + ": " + e.getMessage());
      } finally {
        stopQuietly();
      }
    });
  }

  /** Lê o identificador (UID) do cartão: funciona com qualquer cartão ISO 14443-A, inclusive os com processador. */
  public void readCardId(MethodChannel.Result result) {
    EXECUTOR.execute(() -> {
      try {
        if (mPlugPag.startNFCCardDirectly() != 1) {
          reply(result, "NFC_ERROR", "Não foi possível iniciar o leitor NFC");
          return;
        }
        // Modo Mifare primeiro; se o cartão não for Mifare (ex.: só processador), tenta ISO 14443-A genérico
        PlugPagNFCInfosResultDirectly card = detectQuietly(PlugPagNearFieldCardData.ONLY_M);
        if (card == null || card.getResult() != 1) {
          card = detectQuietly(PlugPagNearFieldCardData.ONLY_A);
        }
        byte[] serial = card == null ? null : card.getSerialNumber();
        if (card == null || card.getResult() != 1 || serial == null || serial.length == 0) {
          reply(result, "NO_CARD", "Cartão não detectado");
          return;
        }
        StringBuilder uid = new StringBuilder();
        for (byte b : serial) uid.append(String.format("%02X", b));
        String id = uid.toString();
        mMainHandler.post(() -> result.success(id));
      } catch (Exception e) {
        reply(result, "NFC_ERROR", e.getClass().getSimpleName() + ": " + e.getMessage());
      } finally {
        stopQuietly();
      }
    });
  }

  private PlugPagNFCInfosResultDirectly detectQuietly(int cardType) {
    try {
      return mPlugPag.detectNfcCardDirectly(cardType, DETECT_TIMEOUT);
    } catch (Exception e) {
      return null;
    }
  }

  /** Diagnóstico: executa a sessão passo a passo e devolve o que o SDK retornou em cada etapa. */
  public void debugRead(Integer block, byte[] key, MethodChannel.Result result) {
    byte[] authKey = key != null ? key : MifareClassic.KEY_DEFAULT;
    EXECUTOR.execute(() -> {
      StringBuilder sb = new StringBuilder();
      try {
        String sessionError = openSession(block, authKey, sb);
        if (sessionError == null) {
          PlugPagNFCResult read = mPlugPag.readNFCCardDirectly(readRequest(block));
          sb.append(" | read=").append(read.getResult())
            .append(" err=").append(read.getErrorCode())
            .append(" msg=").append(read.getMessage());
          HashMap<String, byte[]>[] slots = read.getSlots();
          if (slots != null) {
            for (int i = 0; i < slots.length; i++) {
              if (slots[i] == null) continue;
              byte[] d = slots[i].get(PlugPagNearFieldCardData.NFC_DATA);
              boolean temDados = d != null && !Arrays.equals(d, new byte[d.length]);
              if (i == block || temDados) sb.append(" | [").append(i).append("].data = ").append(toHex(d));
            }
          }
        } else {
          sb.append(" | ERRO: ").append(sessionError);
        }
      } catch (Exception e) {
        sb.append(" | EXCEPTION ").append(e.getClass().getSimpleName()).append(": ").append(e.getMessage());
      } finally {
        stopQuietly();
      }
      String dump = sb.toString();
      Log.d(TAG, dump);
      mMainHandler.post(() -> result.success(dump));
    });
  }

  public void abort(MethodChannel.Result result) {
    EXECUTOR.execute(() -> {
      try {
        mPlugPag.abortNFC();
      } catch (Exception ignored) {
      }
    });
    result.success(true);
  }

  /**
   * Liga a antena, detecta o cartão (obtendo o número de série) e autentica o setor do bloco.
   * A autenticação Mifare precisa do número de série do cartão selecionado — sem o detect,
   * o SDK responde "OK" mas devolve dados zerados.
   * Retorna null em caso de sucesso ou a mensagem de erro.
   */
  private String openSession(int block, byte[] key, StringBuilder log) {
    int start = mPlugPag.startNFCCardDirectly();
    if (log != null) log.append("start=").append(start);
    if (start != 1) return "Não foi possível iniciar o leitor NFC";

    PlugPagNFCInfosResultDirectly card = mPlugPag.detectNfcCardDirectly(PlugPagNearFieldCardData.ONLY_M, DETECT_TIMEOUT);
    if (log != null) {
      log.append(" | detect=").append(card == null ? "null" : card.getResult());
      if (card != null) {
        log.append(" type=").append(card.getCardType())
           .append(" cid=").append(card.getCid())
           .append(" serial=").append(toHex(card.getSerialNumber()))
           .append(" other=").append(toHex(card.getOther()));
      }
    }
    if (card == null || card.getResult() != 1 || card.getSerialNumber() == null) {
      return "Cartão não detectado";
    }

    PlugPagNFCAuthDirectly auth = new PlugPagNFCAuthDirectly((byte) block, key, EM1KeyType.TYPE_A, card.getSerialNumber());
    int authResult = mPlugPag.justAuthNfcDirectly(auth);
    if (log != null) log.append(" | auth=").append(authResult);
    if (authResult != 1) return "Falha ao autenticar o bloco " + block + " (chave incorreta?)";
    return null;
  }

  // 3º parâmetro é o VALOR do bloco (não a chave): na leitura vai um buffer de 16 bytes
  private static PlugPagSimpleNFCData readRequest(int block) {
    return new PlugPagSimpleNFCData(PlugPagNearFieldCardData.ONLY_M, block, new byte[BLOCK_SIZE]);
  }

  // O SDK devolve os dados na posição do bloco ou na posição startSlot: tenta as duas
  private static byte[] extractData(PlugPagNFCResult read, int block) {
    HashMap<String, byte[]>[] slots = read.getSlots();
    if (slots == null) return null;
    int[] candidates = {block, read.getStartSlot()};
    for (int i : candidates) {
      if (i >= 0 && i < slots.length && slots[i] != null && slots[i].get(PlugPagNearFieldCardData.NFC_DATA) != null) {
        return slots[i].get(PlugPagNearFieldCardData.NFC_DATA);
      }
    }
    return null;
  }

  // Bloco 0 (fabricante) e blocos trailer (3, 7, 11...) guardam chaves/permissões:
  // gravar neles pode inutilizar o cartão, então só a leitura é permitida.
  private static String validateBlock(Integer block, boolean isRead) {
    if (block == null || block < 0 || block > MAX_BLOCK) {
      return "Bloco deve estar entre 0 e " + MAX_BLOCK;
    }
    if (!isRead && (block == 0 || (block + 1) % 4 == 0)) {
      return "O bloco " + block + " é protegido (fabricante ou trailer) e não pode ser gravado";
    }
    return null;
  }

  private static String toHex(byte[] data) {
    if (data == null) return "null";
    StringBuilder sb = new StringBuilder();
    for (byte b : data) sb.append(String.format("%02X ", b));
    return sb.toString().trim() + " (" + data.length + " bytes)";
  }

  private void stopQuietly() {
    try {
      mPlugPag.stopNFCCardDirectly();
    } catch (Exception ignored) {
    }
  }

  private void reply(MethodChannel.Result result, String code, String message) {
    mMainHandler.post(() -> result.error(code, message, null));
  }
}
