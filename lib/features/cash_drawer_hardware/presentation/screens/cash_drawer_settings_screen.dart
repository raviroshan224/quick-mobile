import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/cash_drawer_service.dart';
import '../../domain/printer_connection_config.dart';
import '../providers/cash_drawer_settings_provider.dart';

final _cashDrawerServiceProvider = Provider<CashDrawerService>((ref) => CashDrawerService());

class CashDrawerSettingsScreen extends ConsumerStatefulWidget {
  const CashDrawerSettingsScreen({super.key});

  @override
  ConsumerState<CashDrawerSettingsScreen> createState() => _CashDrawerSettingsScreenState();
}

class _CashDrawerSettingsScreenState extends ConsumerState<CashDrawerSettingsScreen> {
  late CashDrawerTransport _transport;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;

  List<PrinterConnectionConfig> _usbDevices = [];
  PrinterConnectionConfig? _selectedUsb;
  bool _scanningUsb = false;

  List<PrinterConnectionConfig> _networkDevices = [];
  bool _scanningNetwork = false;

  bool _testing = false;
  String? _testMessage;
  bool _testSucceeded = false;

  @override
  void initState() {
    super.initState();
    final connection = ref.read(cashDrawerSettingsProvider).connection;
    _transport = connection?.transport ?? CashDrawerTransport.network;
    _hostCtrl = TextEditingController(text: connection?.networkHost ?? '');
    _portCtrl = TextEditingController(text: '${connection?.networkPort ?? 9100}');
    _selectedUsb = connection?.transport == CashDrawerTransport.usb ? connection : null;
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  PrinterConnectionConfig? get _currentConfig {
    if (_transport == CashDrawerTransport.network) {
      final host = _hostCtrl.text.trim();
      if (host.isEmpty) return null;
      final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
      return PrinterConnectionConfig.network(host: host, networkPort: port);
    }
    return _selectedUsb;
  }

  Future<void> _scanUsb() async {
    setState(() {
      _scanningUsb = true;
      _testMessage = null;
    });
    final devices = await ref.read(_cashDrawerServiceProvider).scanUsbDevices();
    if (!mounted) return;
    setState(() {
      _usbDevices = devices;
      _scanningUsb = false;
      if (_selectedUsb != null &&
          !devices.any((d) => d.usbIdentifier == _selectedUsb!.usbIdentifier)) {
        _selectedUsb = null;
      }
    });
  }

  Future<void> _scanNetwork() async {
    setState(() {
      _scanningNetwork = true;
      _testMessage = null;
    });
    final devices = await ref.read(_cashDrawerServiceProvider).scanNetworkDevices();
    if (!mounted) return;
    setState(() {
      _networkDevices = devices;
      _scanningNetwork = false;
    });
  }

  void _pickNetworkDevice(PrinterConnectionConfig device) {
    setState(() {
      _hostCtrl.text = device.networkHost ?? '';
      _portCtrl.text = '${device.networkPort}';
      _testMessage = null;
    });
  }

  Future<void> _test() async {
    final config = _currentConfig;
    if (config == null || !config.isValid) {
      setState(() {
        _testMessage = 'Enter a printer connection first.';
        _testSucceeded = false;
      });
      return;
    }
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    final result = await ref.read(_cashDrawerServiceProvider).openDrawer(config);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testSucceeded = result.success;
      _testMessage = result.success
          ? 'Drawer opened — connection works.'
          : (result.message ?? "Couldn't reach the printer.");
    });
  }

  Future<void> _save() async {
    final config = _currentConfig;
    await ref.read(cashDrawerSettingsProvider.notifier).setConnection(config);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cash drawer connection saved.'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(cashDrawerSettingsProvider);
    final notifier = ref.read(cashDrawerSettingsProvider.notifier);
    final canEnable = settings.connection?.isValid ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.moreSettings),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black),
              ),
              const Spacer(),
              const Text('Cash Drawer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              const SizedBox(width: 18),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(children: [
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Show cash drawer button',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        SizedBox(height: 2),
                        Text(
                          'Floating button on every screen to pop the drawer',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ]),
                    ),
                    Switch.adaptive(
                      value: settings.enabled,
                      onChanged: canEnable
                          ? (v) => notifier.setEnabled(v)
                          : (v) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Configure and save a printer connection first.'),
                                  behavior: SnackBarBehavior.floating,
                                  margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                ),
                              );
                            },
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.black,
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
                const Text('PRINTER CONNECTION',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SegmentedButton<CashDrawerTransport>(
                      segments: [
                        const ButtonSegment(
                          value: CashDrawerTransport.network,
                          label: Text('Network'),
                          icon: Icon(Icons.wifi_rounded, size: 16),
                        ),
                        if (Platform.isAndroid)
                          const ButtonSegment(
                            value: CashDrawerTransport.usb,
                            label: Text('USB'),
                            icon: Icon(Icons.usb_rounded, size: 16),
                          ),
                      ],
                      selected: {_transport},
                      onSelectionChanged: (s) => setState(() {
                        _transport = s.first;
                        _testMessage = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    if (_transport == CashDrawerTransport.network) ...[
                      TextField(
                        controller: _hostCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Printer IP address',
                          hintText: '192.168.1.100',
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _portCtrl,
                        decoration: const InputDecoration(labelText: 'Port'),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: Text(
                            _networkDevices.isEmpty
                                ? 'Scan to find printers on this WiFi network'
                                : '${_networkDevices.length} found on this network',
                            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          ),
                        ),
                        TextButton(
                          onPressed: _scanningNetwork ? null : _scanNetwork,
                          child: Text(_scanningNetwork ? 'Scanning…' : 'Scan'),
                        ),
                      ]),
                      if (_networkDevices.isNotEmpty)
                        Column(
                          children: _networkDevices
                              .map((d) => ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    dense: true,
                                    title: Text(d.label, style: const TextStyle(fontSize: 14)),
                                    trailing: const Icon(Icons.chevron_right,
                                        size: 16, color: AppColors.border),
                                    onTap: () => _pickNetworkDevice(d),
                                  ))
                              .toList(),
                        ),
                    ] else ...[
                      Row(children: [
                        Expanded(
                          child: Text(
                            _selectedUsb?.label ?? 'No USB printer selected',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        TextButton(
                          onPressed: _scanningUsb ? null : _scanUsb,
                          child: Text(_scanningUsb ? 'Scanning…' : 'Scan'),
                        ),
                      ]),
                      if (_usbDevices.isNotEmpty)
                        RadioGroup<String>(
                          groupValue: _selectedUsb?.usbIdentifier,
                          onChanged: (id) => setState(() {
                            PrinterConnectionConfig? match;
                            for (final d in _usbDevices) {
                              if (d.usbIdentifier == id) {
                                match = d;
                                break;
                              }
                            }
                            _selectedUsb = match;
                            _testMessage = null;
                          }),
                          child: Column(
                            children: _usbDevices
                                .map((d) => RadioListTile<String>(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      title: Text(d.label, style: const TextStyle(fontSize: 14)),
                                      value: d.usbIdentifier!,
                                    ))
                                .toList(),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _testing ? null : _test,
                          child: Text(_testing ? 'Testing…' : 'Test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save'),
                        ),
                      ),
                    ]),
                    if (_testMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _testMessage!,
                        style: TextStyle(
                          fontSize: 13,
                          color: _testSucceeded ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
