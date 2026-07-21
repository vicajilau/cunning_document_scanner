import 'dart:async';
import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';

class ScannerHomeScreen extends StatefulWidget {
  const ScannerHomeScreen({super.key});

  @override
  State<ScannerHomeScreen> createState() => _ScannerHomeScreenState();
}

class _ScannerHomeScreenState extends State<ScannerHomeScreen> {
  List<String> _pictures = [];
  bool _asPdf = false;
  bool _isPdfResult = false;
  bool _isGalleryImportAllowed = false;
  bool _useScannerSource = true;
  int _noOfPages = 100;
  ScannerSource _scannerSource = ScannerSource.cameraAndGallery;
  AndroidScannerMode _androidScannerMode = AndroidScannerMode.full;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin example app'),
      ),
      body: SingleChildScrollView(
          child: Column(
        children: [
          SwitchListTile(
            title: const Text("Scan as PDF"),
            subtitle: const Text("Compile pages into a single PDF document"),
            value: _asPdf,
            onChanged: (value) {
              setState(() {
                _asPdf = value;
              });
            },
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextFormField(
              initialValue: _noOfPages.toString(),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: "Max Number of Pages (noOfPages)",
                hintText: "Minimum 1",
                border: OutlineInputBorder(),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter a valid number (min 1)";
                }
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 1) {
                  return "Number of pages must be at least 1";
                }
                return null;
              },
              onChanged: (value) {
                final parsed = int.tryParse(value);
                if (parsed != null) {
                  setState(() {
                    _noOfPages = parsed;
                  });
                }
              },
            ),
          ),
          SwitchListTile(
            title: const Text("Use ScannerSource Enum (New API)"),
            subtitle: const Text("Use new scannerSource configuration"),
            value: _useScannerSource,
            onChanged: (value) {
              setState(() {
                _useScannerSource = value;
              });
            },
          ),
          if (_useScannerSource)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: DropdownButtonFormField<ScannerSource>(
                decoration: const InputDecoration(
                  labelText: "Scanner Source",
                  border: OutlineInputBorder(),
                ),
                initialValue: _scannerSource,
                items: ScannerSource.values.map((source) {
                  String label = "";
                  switch (source) {
                    case ScannerSource.camera:
                      label = "Camera Only";
                      break;
                    case ScannerSource.gallery:
                      label = "Gallery Only";
                      break;
                    case ScannerSource.cameraAndGallery:
                      label = "Camera & Gallery Menu";
                      break;
                  }
                  return DropdownMenuItem<ScannerSource>(
                    value: source,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _scannerSource = value;
                    });
                  }
                },
              ),
            )
          else
            SwitchListTile(
              title: const Text("Allow Gallery Import (Legacy API)"),
              subtitle: const Text("Import documents from photo library"),
              value: _isGalleryImportAllowed,
              onChanged: (value) {
                setState(() {
                  _isGalleryImportAllowed = value;
                });
              },
            ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<AndroidScannerMode>(
              decoration: const InputDecoration(
                labelText: "Android Scanner Mode (Android Only)",
                border: OutlineInputBorder(),
              ),
              initialValue: _androidScannerMode,
              items: AndroidScannerMode.values.map((mode) {
                String label = "";
                switch (mode) {
                  case AndroidScannerMode.full:
                    label = "Full (ML Enhancements & Filters)";
                    break;
                  case AndroidScannerMode.base:
                    label = "Base (No Filters)";
                    break;
                  case AndroidScannerMode.baseWithFilter:
                    label = "Base with Filter";
                    break;
                }
                return DropdownMenuItem<AndroidScannerMode>(
                  value: mode,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _androidScannerMode = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: onPressed, child: const Text("Add Pictures")),
          const SizedBox(height: 20),
          if (_isPdfResult)
            for (var picture in _pictures)
              Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.all(16.0),
                child: InkWell(
                  onTap: () {
                    OpenFile.open(picture);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.picture_as_pdf,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 8),
                        Text(
                          picture,
                          style: const TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.open_in_new,
                                size: 16, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              "Tap to open PDF",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
          else
            for (var picture in _pictures) Image.file(File(picture))
        ],
      )),
    );
  }

  void onPressed() async {
    List<String> pictures;
    try {
      pictures = await CunningDocumentScanner.getPictures(
              noOfPages: _noOfPages,
              scannerSource: _useScannerSource ? _scannerSource : null,
              // ignore: deprecated_member_use
              isGalleryImportAllowed: _isGalleryImportAllowed,
              androidScannerMode: _androidScannerMode,
              asPdf: _asPdf,
              iosScannerOptions: IosScannerOptions(
                imageFormat: IosImageFormat.jpg,
                jpgCompressionQuality: 0.5,
              )) ??
          [];
      if (!mounted) return;
      setState(() {
        _pictures = pictures;
        _isPdfResult = _asPdf;
      });
    } on ArgumentError catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid parameter: ${exception.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } on CunningDocumentScannerException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Scanner Error: ${exception.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $exception"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
