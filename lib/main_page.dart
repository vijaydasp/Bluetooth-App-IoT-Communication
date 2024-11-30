import 'dart:convert';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _bluetooth = FlutterBluetoothSerial.instance;
  bool _bluetoothState = false;
  BluetoothConnection? _connection;
  BluetoothDevice? _deviceConnected;
  String receivedMessage = "";

  void _getDevices() async {
    var res = await _bluetooth.getBondedDevices();
    if (res.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceListPage(
            devices: res,
            onDeviceSelected: _connectToDevice,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No bonded devices found.")),
      );
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _deviceConnected = device;
      _receiveData();
      setState(() {});
    } catch (e) {
      print('Cannot connect, exception: $e');
    }
  }

  void _receiveData() {
    _connection?.input?.listen((event) {
      String message = String.fromCharCodes(event);
      setState(() {
        receivedMessage += message;
      });
    });
  }

  void _sendData(String data) {
    if (_connection?.isConnected ?? false) {
      _connection?.output.add(ascii.encode(data));
    }
  }

  void _clearReceivedMessages() {
    setState(() {
      receivedMessage = "";
    });
  }

  void _requestPermission() async {
    await Permission.location.request();
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
  }

  @override
  void initState() {
    super.initState();

    _requestPermission();

    _bluetooth.state.then((state) {
      setState(() => _bluetoothState = state.isEnabled);
    });

    _bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BluetoothState.STATE_OFF:
          setState(() => _bluetoothState = false);
          break;
        case BluetoothState.STATE_ON:
          setState(() => _bluetoothState = true);
          break;
      }
    });
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      centerTitle: true,
      title: const Text(
        'Blueto-V',
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: Colors.blueGrey[900],
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12.0, top: 35),
          child: Center(
            child: Text(
              "By Vijay Das P",
              style: TextStyle(
                color: Colors.white,
                fontSize: 10.0,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    ),
    resizeToAvoidBottomInset: true, // This adjusts the layout when the keyboard appears
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _controlBT(),
            const SizedBox(height: 16.0),
            _infoDevice(),
            const SizedBox(height: 16.0),
            _sendDataArea(),
            const SizedBox(height: 16.0),
            _displayReceivedMessage(),
          ],
        ),
      ),
    ),
  );
}


  Widget _controlBT() {
    return Card(
      elevation: 4.0,
      child: ListTile(
        tileColor: Colors.blueGrey[50],
        leading: Icon(
          _bluetoothState ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
          color: _bluetoothState ? Colors.blue : Colors.red,
        ),
        title: Text(
          _bluetoothState ? "Bluetooth is On" : "Bluetooth is Off",
          style: const TextStyle(fontSize: 18.0),
        ),
        trailing: Switch(
          value: _bluetoothState,
          onChanged: (bool value) async {
            if (value) {
              await _bluetooth.requestEnable();
            } else {
              await _bluetooth.requestDisable();
            }
          },
        ),
      ),
    );
  }

  Widget _infoDevice() {
    return Card(
      elevation: 4.0,
      child: ListTile(
        tileColor: Colors.blueGrey[50],
        title: Text(
          "Connected to: ${_deviceConnected?.name ?? "None"}",
          style: const TextStyle(fontSize: 18.0),
        ),
        trailing: _connection?.isConnected ?? false
            ? TextButton.icon(
                onPressed: () async {
                  await _connection?.finish();
                  setState(() => _deviceConnected = null);
                },
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text("Disconnect"),
              )
            : TextButton(
                onPressed: _getDevices,
                child: const Text("View Devices"),
              ),
      ),
    );
  }

  Widget _sendDataArea() {
    TextEditingController textController = TextEditingController();

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter Data to Send', style: TextStyle(fontSize: 18.0)),
            const SizedBox(height: 16.0),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter data',
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  String dataToSend = textController.text;
                  if (dataToSend.isNotEmpty) {
                    _sendData(dataToSend);
                  }
                  textController.clear();
                },
                child: const Text('Send Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _displayReceivedMessage() {
  return SizedBox(
    width: double.infinity,
    height: 350,
    child: Card(
      elevation: 4.0,
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Received message:",
              style: TextStyle(fontSize: 18.0),
            ),
            const SizedBox(height: 8.0),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  receivedMessage.isEmpty
                      ? ""
                      : receivedMessage,
                  style: const TextStyle(fontSize: 16.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: ElevatedButton(
                onPressed: _clearReceivedMessages,
                child: const Text(
                  'Clear Messages',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 53, 16, 218), // Custom button color
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// New page for device listing
class DeviceListPage extends StatelessWidget {
  final List<BluetoothDevice> devices;
  final Function(BluetoothDevice) onDeviceSelected;

  const DeviceListPage({
    Key? key,
    required this.devices,
    required this.onDeviceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Device'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: ListView(
        children: devices.map((device) {
          return Card(
            elevation: 3.0,
            child: ListTile(
              title: Text(device.name ?? device.address),
              trailing: TextButton(
                child: const Text('Connect'),
                onPressed: () {
                  onDeviceSelected(device);
                  Navigator.pop(context);
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
