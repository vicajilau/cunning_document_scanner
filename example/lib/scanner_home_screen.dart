import 'dart:async';
import 'dart:io';

import 'package:app_settings/app_settings.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:cunning_document_scanner_example/example_strings.dart';
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
  IosDocumentFilter _iosDefaultFilter = IosDocumentFilter.original;
  bool _iosShowFilterBar = true;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {}

  @override
  Widget build(BuildContext context) {
    final strings = ExampleStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          // iOS can only change the language of Apple's scanner screens by restarting the app in
          // the language chosen on its Settings page, so that is where this button leads.
          if (Platform.isIOS)
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: strings.changeLanguage,
              onPressed: () => AppSettings.openAppSettings(),
            ),
        ],
      ),
      body: SingleChildScrollView(
          child: Column(
        children: [
          SwitchListTile(
            title: Text(strings.scanAsPdf),
            subtitle: Text(strings.scanAsPdfSubtitle),
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
              decoration: InputDecoration(
                labelText: strings.maxPages,
                hintText: strings.maxPagesHint,
                border: OutlineInputBorder(),
              ),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return strings.invalidNumber;
                }
                final parsed = int.tryParse(value);
                if (parsed == null || parsed < 1) {
                  return strings.pagesMin;
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
            title: Text(strings.useScannerSource),
            subtitle: Text(strings.useScannerSourceSubtitle),
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
                decoration: InputDecoration(
                  labelText: strings.scannerSource,
                  border: OutlineInputBorder(),
                ),
                initialValue: _scannerSource,
                items: ScannerSource.values.map((source) {
                  String label = "";
                  switch (source) {
                    case ScannerSource.camera:
                      label = strings.cameraOnly;
                      break;
                    case ScannerSource.gallery:
                      label = strings.galleryOnly;
                      break;
                    case ScannerSource.cameraAndGallery:
                      label = strings.cameraAndGallery;
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
              title: Text(strings.allowGalleryImport),
              subtitle: Text(strings.allowGalleryImportSubtitle),
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
              decoration: InputDecoration(
                labelText: strings.androidMode,
                border: OutlineInputBorder(),
              ),
              initialValue: _androidScannerMode,
              items: AndroidScannerMode.values.map((mode) {
                String label = "";
                switch (mode) {
                  case AndroidScannerMode.full:
                    label = strings.androidFull;
                    break;
                  case AndroidScannerMode.base:
                    label = strings.androidBase;
                    break;
                  case AndroidScannerMode.baseWithFilter:
                    label = strings.androidBaseWithFilter;
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
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: DropdownButtonFormField<IosDocumentFilter>(
              decoration: InputDecoration(
                labelText: strings.iosFilter,
                border: OutlineInputBorder(),
              ),
              initialValue: _iosDefaultFilter,
              items: IosDocumentFilter.values.map((filter) {
                return DropdownMenuItem<IosDocumentFilter>(
                  value: filter,
                  child: Text(filter.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _iosDefaultFilter = value;
                  });
                }
              },
            ),
          ),
          SwitchListTile(
            title: Text(strings.showFilterBar),
            subtitle: Text(strings.showFilterBarSubtitle),
            value: _iosShowFilterBar,
            onChanged: (value) {
              setState(() {
                _iosShowFilterBar = value;
              });
            },
          ),
          const SizedBox(height: 10),
          ElevatedButton(
              onPressed: onPressed, child: Text(strings.addPictures)),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.open_in_new,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              strings.tapToOpenPdf,
                              style: const TextStyle(
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
                defaultFilter: _iosDefaultFilter,
                showFilterBar: _iosShowFilterBar,
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
          content: Text(
              ExampleStrings.of(context).invalidParameter(exception.message)),
          backgroundColor: Colors.red,
        ),
      );
    } on CunningDocumentScannerException catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(ExampleStrings.of(context).scannerError(exception.message)),
          backgroundColor: Colors.red,
        ),
      );
    } catch (exception) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ExampleStrings.of(context).error(exception)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
