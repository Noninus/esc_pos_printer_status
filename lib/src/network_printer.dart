/*
 * esc_pos_printer
 * Created by Andrey Ushakov
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:io';
import 'dart:typed_data' show Uint8List;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart';
import './enums.dart';

/// Network Printer
class NetworkPrinter {
  NetworkPrinter(this._paperSize, this._profile, {int spaceBetweenRows = 5}) {
    _generator =
        Generator(paperSize, profile, spaceBetweenRows: spaceBetweenRows);
  }

  final PaperSize _paperSize;
  final CapabilityProfile _profile;
  String _host;
  int _port;
  Generator _generator;
  RawSocket _socket;

  int get port => _port;
  String get host => _host;
  PaperSize get paperSize => _paperSize;
  CapabilityProfile get profile => _profile;

  Future<PosPrintResult> connect(String host,
      {int port = 91000, Duration timeout = const Duration(seconds: 5)}) async {
    _host = host;
    _port = port;
    try {
      _socket = await RawSocket.connect(host, port, timeout: timeout);
      _socket.write(_generator.reset());

      return Future<PosPrintResult>.value(PosPrintResult.success);
    } catch (e) {
      return Future<PosPrintResult>.value(PosPrintResult.timeout);
    }
  }

  /// [delayMs]: milliseconds to wait after destroying the socket
  void disconnect({int delayMs}) async {
    _socket.close();
    if (delayMs != null) {
      await Future.delayed(Duration(milliseconds: delayMs), () => null);
    }
  }

  // ******** Printer Commands ********
  void reset() {
    _socket.write(_generator.reset());
  }

  /// Return the status from printer
  ///
  /// [int] can be
  /// 0: offline
  /// 1: online
  Future<int> printerStatus() async {
    _socket.write([16, 4, 1]);
    int res;
    String binary = "";

    await Future.delayed(Duration(milliseconds: 250), () {
      var read = (_socket.read());
      if (read != null) {
        final result = read.map((b) =>
            int.parse('0x${b.toRadixString(16).padLeft(2, '0')}')
                .toRadixString(2)
                .padLeft(8, '0'));
        binary = result.first;
      }
    });

    //res é um número binário que cada um de seus chars significam alguma coisa:
    //Ver em: https://www.epson-biz.com/modules/ref_escpos/index.php?content_id=118
    //
    //Ex: 00010110 <- de tras para frente
    // 0:Fixed
    // 1:Fixed
    // 1:Drawer kick-out connector pin 3 is HIGH
    // 0:Online
    // 1:Fixed
    // 0:Not waiting for online recovery
    // 0:Paper feed button is not being pressed
    // 0:Fixed
    print(binary);
    if (binary != "") {
      String onlineStatus = binary.substring(4, 5);

      if (onlineStatus == '0') {
        // print('Online');
        res = 1;
      } else if (onlineStatus == '1') {
        // print('Offline');
        res = 0;
      }
    } else {
      res = 0;
    }

    return res;
  }

  /// Return the status from printer
  ///
  /// [int] can be
  /// 0: general error
  /// 1: no errors
  /// 2: paper-end stopped error
  /// 3: cover is open error
  Future<int> offlineCauseStatus() async {
    _socket.write([16, 4, 2]);
    int res;
    String binary = "";

    await Future.delayed(Duration(milliseconds: 250), () {
      var read = (_socket.read());
      if (read != null) {
        final result = read.map((b) =>
            int.parse('0x${b.toRadixString(16).padLeft(2, '0')}')
                .toRadixString(2)
                .padLeft(8, '0'));
        binary = result.first;
      }
    });

    //res é um número binário que cada um de seus chars significam alguma coisa:
    //Ver em: https://www.epson-biz.com/modules/ref_escpos/index.php?content_id=118
    //
    //Ex: 00010010 <- de tras para frente
    // 0:Fixed
    // 1:Fixed
    // 0:Cover is closed
    // 0:Paper is not being fed by the paper feed button
    // 1:Fixed
    // 0:No paper-end stop
    // 0:No Error Ocurred !IMPORTANT
    // 0:Fixed

    if (binary != "") {
      String error = binary.substring(1, 2);
      String paperError = binary.substring(2, 3);
      String coverError = binary.substring(5, 6);

      if (error == '0') {
        res = 1;
      } else if (error == '1') {
        if (paperError == '1') {
          res = 2;
        } else if (coverError == '1') {
          res = 3;
        }
      }
    } else {
      res = 0;
    }

    return res;
  }

  /// Return the paper status from printer
  ///
  /// [int] can be
  /// 0: out of paper
  /// 1: paper adequate
  /// 2: paper near-end
  Future<int> paperStatus() async {
    _socket.write([16, 4, 4]);
    int res;
    String binary = "";

    await Future.delayed(Duration(milliseconds: 250), () {
      // print('_socket.available(): ${_socket.available()}');
      var read = (_socket.read());
      // print('read: $read');
      if (read != null) {
        final result = read.map((b) =>
            int.parse('0x${b.toRadixString(16).padLeft(2, '0')}')
                .toRadixString(2)
                .padLeft(8, '0'));
        // print('bytes: $result');
        binary = result.first;
      }
    });

    print(binary);

    //res é um número binário que cada um de seus chars significam alguma coisa:
    //Ver em: https://www.epson-biz.com/modules/ref_escpos/index.php?content_id=118
    //
    //Ex: 00010010 <- de tras para frente
    // 0:Fixed
    // 1:Fixed
    // (chars: 2,3) 00:Roll paper near-end sensor: paper adequate !IMPORTANTE
    // 1:Fixed
    // (chars: 5,6) 00:Roll paper end sensor: paper present !IMPORTANTE
    // 0:Fixed

    if (binary != "") {
      String paperSensor = binary.substring(4, 6);

      if (paperSensor == '00') {
        // print('Roll paper near-end sensor: paper adequate');
        res = 1;
      } else if (paperSensor == '11') {
        // print('Roll paper near-end sensor: paper near-end');
        res = 2;
      }
    } else {
      res = 0;
    }

    return res;
  }

  void read() {
    print('ava: ${_socket.available()}');
    print('read: ${_socket.read()}');
  }

  void text(
    String text, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    bool containsChinese = false,
    int maxCharsPerLine,
  }) {
    int textB = _socket.write(_generator.text(text,
        styles: styles,
        linesAfter: linesAfter,
        containsChinese: containsChinese,
        maxCharsPerLine: maxCharsPerLine));
    print('textB: $textB');
  }

  void setGlobalCodeTable(String codeTable) {
    _socket.write(_generator.setGlobalCodeTable(codeTable));
  }

  void setGlobalFont(PosFontType font, {int maxCharsPerLine}) {
    _socket.write(
        _generator.setGlobalFont(font, maxCharsPerLine: maxCharsPerLine));
  }

  void setStyles(PosStyles styles, {bool isKanji = false}) {
    _socket.write(_generator.setStyles(styles, isKanji: isKanji));
  }

  void rawBytes(List<int> cmd, {bool isKanji = false}) {
    _socket.write(_generator.rawBytes(cmd, isKanji: isKanji));
  }

  void emptyLines(int n) {
    _socket.write(_generator.emptyLines(n));
  }

  void feed(int n) {
    _socket.write(_generator.feed(n));
  }

  void cut({PosCutMode mode = PosCutMode.full}) {
    _socket.write(_generator.cut(mode: mode));
  }

  void printCodeTable({String codeTable}) {
    _socket.write(_generator.printCodeTable(codeTable: codeTable));
  }

  void beep({int n = 3, PosBeepDuration duration = PosBeepDuration.beep450ms}) {
    _socket.write(_generator.beep(n: n, duration: duration));
  }

  void reverseFeed(int n) {
    _socket.write(_generator.reverseFeed(n));
  }

  void row(List<PosColumn> cols) {
    _socket.write(_generator.row(cols));
  }

  void image(Image imgSrc, {PosAlign align = PosAlign.center}) {
    _socket.write(_generator.image(imgSrc, align: align));
  }

  void imageRaster(
    Image image, {
    PosAlign align = PosAlign.center,
    bool highDensityHorizontal = true,
    bool highDensityVertical = true,
    PosImageFn imageFn = PosImageFn.bitImageRaster,
  }) {
    _socket.write(_generator.imageRaster(
      image,
      align: align,
      highDensityHorizontal: highDensityHorizontal,
      highDensityVertical: highDensityVertical,
      imageFn: imageFn,
    ));
  }

  void barcode(
    Barcode barcode, {
    int width,
    int height,
    BarcodeFont font,
    BarcodeText textPos = BarcodeText.below,
    PosAlign align = PosAlign.center,
  }) {
    _socket.write(_generator.barcode(
      barcode,
      width: width,
      height: height,
      font: font,
      textPos: textPos,
      align: align,
    ));
  }

  void qrcode(
    String text, {
    PosAlign align = PosAlign.center,
    QRSize size = QRSize.Size4,
    QRCorrection cor = QRCorrection.L,
  }) {
    _socket.write(_generator.qrcode(text, align: align, size: size, cor: cor));
  }

  void drawer({PosDrawer pin = PosDrawer.pin2}) {
    _socket.write(_generator.drawer(pin: pin));
  }

  void hr({String ch = '-', int len, int linesAfter = 0}) {
    _socket.write(_generator.hr(ch: ch, linesAfter: linesAfter));
  }

  void textEncoded(
    Uint8List textBytes, {
    PosStyles styles = const PosStyles(),
    int linesAfter = 0,
    int maxCharsPerLine,
  }) {
    _socket.write(_generator.textEncoded(
      textBytes,
      styles: styles,
      linesAfter: linesAfter,
      maxCharsPerLine: maxCharsPerLine,
    ));
  }
  // ******** (end) Printer Commands ********
}
