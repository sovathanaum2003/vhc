import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  // Singleton instance
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;

  // Stream controller to send data back to the UI
  final StreamController<String> _messageController =
  StreamController<String>.broadcast();

  Stream<String> get messageStream => _messageController.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<bool> connect(String broker, int port, String clientId) async {
    _client = MqttServerClient(broker, clientId);

    _client!.port = port;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;

    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMess;

    try {
      if (kDebugMode) {
        print('MQTT: Connecting to $broker...');
      }

      await _client!.connect();
    } on NoConnectionException catch (e) {
      if (kDebugMode) {
        print('MQTT: Client exception - $e');
      }
      _client!.disconnect();
      return false;
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('MQTT: Socket exception - $e');
      }
      _client!.disconnect();
      return false;
    }

    if (_client!.connectionStatus!.state ==
        MqttConnectionState.connected) {
      if (kDebugMode) {
        print('MQTT: Connected');
      }

      // Listen for updates
      _client!.updates!.listen(_onMessage);
      return true;
    } else {
      if (kDebugMode) {
        print(
          'MQTT: Connection failed - status is ${_client!.connectionStatus}',
        );
      }
      _client!.disconnect();
      return false;
    }
  }

  void disconnect() {
    _client?.disconnect();
  }

  void subscribe(String topic) {
    if (isConnected) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
    }
  }

  void publish(String topic, String message) {
    if (isConnected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);

      _client!.publishMessage(
        topic,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
    }
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? c) {
    final recMess = c![0].payload as MqttPublishMessage;
    final pt =
    MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    // Send the payload to the UI
    _messageController.add(pt);
  }

  void _onConnected() {
    if (kDebugMode) {
      print('MQTT: Connected callback');
    }
  }

  void _onDisconnected() {
    if (kDebugMode) {
      print('MQTT: Disconnected callback');
    }
  }

  void _onSubscribed(String topic) {
    if (kDebugMode) {
      print('MQTT: Subscribed to $topic');
    }
  }
}
