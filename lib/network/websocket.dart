import 'package:indjcollectinglocationdata/marker_map_page.dart';
import 'package:naver_map_plugin/naver_map_plugin.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'dart:convert';


class WebSocket {
  IO.Socket socket;
  static const String SERVER_URL = 'http://3.34.179.171:3000/location';

  initWebSocket(){
    socket = IO.io(SERVER_URL, <String, dynamic>{
      'transports': ['websocket']
    });
    socket.on('connect', (_){});
  }

  sendData(var data) {
    socket.emit('mobile/send/data', data);
  }

  Future<dynamic> receiveData(){
    socket.on('server/send/data', (data){
      // print('Future, ${data}');
      return data;
    });
  }
}