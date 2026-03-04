import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SimpleScannerScreen extends StatefulWidget {
  const SimpleScannerScreen({super.key});

  @override
  State<SimpleScannerScreen> createState() => _SimpleScannerScreenState();
}

class _SimpleScannerScreenState extends State<SimpleScannerScreen> {
  bool _hasScanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Barcode")),
      body: MobileScanner(
        onDetect: (capture) {
          if (_hasScanned) return;
          
          final List<Barcode> barcodes = capture.barcodes;
           for (final barcode in barcodes) {
             if (barcode.rawValue != null) {
               setState(() {
                 _hasScanned = true;
               });
               Navigator.pop(context, barcode.rawValue);
               return; 
             }
           }
        },
      ),
    );
  }
}
