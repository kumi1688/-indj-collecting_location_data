import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';


void main() => runApp(LocationCollectingDemo());

class LocationCollectingDemo extends StatefulWidget {
  @override
  _LocationCollectingDemoState createState() => _LocationCollectingDemoState();
}

class _LocationCollectingDemoState extends State<LocationCollectingDemo> {
  LocationPermission _permission;
  StreamSubscription<Position> _positionStream;
  Position _position;

  _getPermission() async {
    _permission = await Geolocator.checkPermission();
    if(_permission == LocationPermission.denied){
      _permission = await Geolocator.requestPermission();
    }
    setState(() {});
  }

  _getCurrentPosition() async {
    _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {});
  }

  _getPositionStream() async {
    _positionStream = Geolocator.getPositionStream(desiredAccuracy: LocationAccuracy.best).listen(
            (Position position) {
          // print(position == null ? 'Unknown' : position.latitude.toString() + ', ' + position.longitude.toString());
          setState(() {
            _position = position;
          });
        });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _getPermission();
    // _getCurrentPosition();
    _getPositionStream();
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '위치 수집',
        home: Scaffold(
            appBar: AppBar(title: Text('위치 수집')),
            body: Column(
              children: <Widget>[
                Text('권한 ${_permission.toString()}'),
                Text('위도 ${_position?.latitude}'),
                Text('경도 ${_position?.longitude}'),
                // FloatingActionButton(
                //   onPressed: _getCurrentPosition,
                //   child: Text('현재 위치 얻기'),
                // )
              ],
            )
        )
    );
  }
}
