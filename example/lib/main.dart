import 'package:esc_pos_printer_status/esc_pos_printer_status.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:ping_discover_network/ping_discover_network.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void testReceipt(NetworkPrinter printer) async {
    int paperStatus = await printer.paperStatus();
    print('paperStatus: $paperStatus');
    if (paperStatus == 1) {
      printer.feed(60);

      await Future.delayed(Duration(seconds: 1), () {}); //Tempo da impressão.

      int offlineCauseStatus = await printer.offlineCauseStatus();
      print('offlineCauseStatus: $offlineCauseStatus');

      int printerStatus = await printer.printerStatus();
      print('printerStatus: $printerStatus');
      if (printerStatus == 1) {
        print("Sucesso!");
      } else {
        print("Erro! Chamar CANCELA!");
      }
    }

    printer.disconnect();
  }

  _testPrinter() async {
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res =
        await printer.connect('192.168.0.25', port: 9100);

    if (res == PosPrintResult.success) {
      testReceipt(printer);
    } else {
      print("${res.msg}");
    }
  }

  @override
  void initState() {
    const port = 80;
    final stream = NetworkAnalyzer.discover2(
      '192.168.0',
      port,
      timeout: Duration(milliseconds: 5000),
    );

    int found = 0;
    stream.listen((NetworkAddress addr) {
      if (addr.exists) {
        found++;
        print('Found device: ${addr.ip}:$port');
      }
    }).onDone(() => print('Finish. Found $found device(s)'));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _testPrinter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }
}
