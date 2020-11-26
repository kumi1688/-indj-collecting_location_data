import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:indjcollectinglocationdata/network/websocket.dart';
import 'package:naver_map_plugin/naver_map_plugin.dart';

class MarkerMapPage extends StatefulWidget {
  @override
  _MarkerMapPageState createState() => _MarkerMapPageState();
}

class _MarkerMapPageState extends State<MarkerMapPage> {
  static const MODE_ADD = 0xF1;
  static const MODE_REMOVE = 0xF2;
  static const MODE_NONE = 0xF3;

  static const LOCATION_LIST = <String>['은행', '마트', '병원', '카페', '편의점', '식당', '직장', '집'];

  int _currentMode = MODE_NONE;

  Completer<NaverMapController> _controller = Completer();
  List<Marker> _markers = [];
  List<CircleOverlay> _circles = [];
  List<LocationType> _locationTypes = [];

  double _sliderValue = 20.0;
  int _selectedCircleIndex;
  Timer _timer;
  List<dynamic> tData = [];
  WebSocket websocket;

  String dropdownValue = '은행';

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OverlayImage.fromAssetImage(ImageConfiguration(), 'icon/marker.png').then((image) {
        // setState(() {
        //   _markers.add(Marker(
        //       markerId: 'id',
        //       position: LatLng(37.563600, 126.962370),
        //       captionText: "커스텀 아이콘",
        //       captionColor: Colors.indigo,
        //       captionTextSize: 20.0,
        //       alpha: 0.8,
        //       icon: image,
        //       width: 45,
        //       height: 45,
        //       infoWindow: '인포 윈도우',
        //       onMarkerTab: _onMarkerTap
        //   ));
        // });
      });
    });
    super.initState();
    websocket = WebSocket();
    websocket.initWebSocket();

    _timer = Timer.periodic(Duration(seconds: 10), (timer) {
      List<dynamic> data = [];
      for(int i = 0; i < _markers.length; i++){
        data.add({
          'len': _markers.length,
          'id': _markers[i].markerId,
          'latitude': _markers[i].position.latitude,
          'longitude': _markers[i].position.longitude,
          'radius': _circles[i].radius,
          'type': _locationTypes[i].type,
          'time': new DateTime.now().toString()
        });
      }
      // jsonEncode(data);
      websocket.sendData(jsonEncode(data));
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: <Widget>[
            _controlPanel(),
            _naverMap(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _circlePanel(),
                _selectBox()
              ],
            ),
            Text(tData.toString())
          ],
        ),
      ),
    );
  }

  _selectBox() {
    if(_currentMode == MODE_ADD){
      return DropdownButton<String>(
        value: dropdownValue,
        icon: Icon(Icons.arrow_downward),
        iconSize: 24,
        elevation: 16,
        style: TextStyle(color: Colors.deepPurple),
        underline: Container(
          height: 2,
          color: Colors.deepPurpleAccent,
        ),
        onChanged: _onChangeSelectBox,
        items: LOCATION_LIST
            .map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
      );
    }else {
      return Container();
    }
  }

  _circlePanel(){
    if(_currentMode == MODE_ADD){
      return Container(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            // width: MediaQuery.of(context).size.width,
            width: MediaQuery.of(context).size.width*0.6,
            padding: EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            child: Container(
              padding: EdgeInsets.all(8),
              height: MediaQuery.of(context).size.height*0.1,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [BoxShadow(
                    color: Colors.black12,
                    blurRadius: 3,
                  )]
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                      "반지름"
                  ),
                  SizedBox(width: 4),
                  Expanded(
                    child: Slider.adaptive(
                      value: _sliderValue,
                      onChanged: _onSliderChange,
                      onChangeEnd: _onSliderChangeEnd,
                      min: 1.0, max: 100.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      return Container();
    }

  }

  _controlPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 추가
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentMode = MODE_ADD),
              child: Container(
                decoration: BoxDecoration(
                    color: _currentMode == MODE_ADD
                        ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black)
                ),
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(right: 8),
                child: Text(
                  '추가',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentMode == MODE_ADD
                        ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // 삭제
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _currentMode = MODE_REMOVE),
              child: Container(
                decoration: BoxDecoration(
                    color: _currentMode == MODE_REMOVE
                        ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black)
                ),
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(right: 8),
                child: Text(
                  '삭제',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _currentMode == MODE_REMOVE
                        ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // none
          GestureDetector(
            onTap: () => setState(() => _currentMode = MODE_NONE),
            child: Container(
              decoration: BoxDecoration(
                  color: _currentMode == MODE_NONE
                      ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black)
              ),
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.clear,
                color: _currentMode == MODE_NONE
                    ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _naverMap() {
    return Expanded(
      child: Stack(
        children: <Widget>[
          NaverMap(
            onMapCreated: _onMapCreated,
            onMapTap: _onMapTap,
            markers: _markers,
            circles: _circles,
            initialCameraPosition: CameraPosition(
                target: LatLng(37.566570, 126.978442),
                zoom: 18
            ),
            initLocationTrackingMode: LocationTrackingMode.Follow,
          ),
        ],
      ),
    );
  }


  // ================== method ==========================

  void _onMapCreated(NaverMapController controller) {
    _controller.complete(controller);
  }

  void _onMapTap(LatLng latLng) {
    if (_selectedCircleIndex != null) {
      _circles[_selectedCircleIndex].color = Colors.black.withOpacity(0.3);
    }

    if (_currentMode == MODE_ADD) {
      String id = DateTime.now().toIso8601String();
      setState(() {
        _markers.add(Marker(
          markerId: id,
          position: latLng,
          infoWindow: '테스트',
          onMarkerTab: _onMarkerTap,
        ));
        _circles.add(CircleOverlay(
          overlayId: id,
          center: latLng,
          radius: _sliderValue,
          onTap: _onCircleTap,
          color: Colors.blueAccent.withOpacity(0.3),
          outlineColor: Colors.black,
          outlineWidth: 1,
        ));
        _locationTypes.add(LocationType(id, dropdownValue));
        _selectedCircleIndex = _circles.length -1;
      });
    }
  }

  void _onMarkerTap(Marker marker, Map<String, int> iconSize) {
    if (_currentMode == MODE_REMOVE){
      setState(() {
        _markers.removeWhere((m) => m.markerId == marker.markerId);
        _circles.removeWhere((m) => m.overlayId == marker.markerId);
        _locationTypes.removeWhere((m) => m.id == marker.markerId);

        _selectedCircleIndex = null;
      });
    }
  }

  void _onSliderChange(double value) {
    setState(() {
      _sliderValue = value;
    });
  }

  void _onSliderChangeEnd(double value) {
    if (_selectedCircleIndex != null) {
      setState(() {
        _circles[_selectedCircleIndex].radius = value;
      });
    }
  }

  void _onCircleTap(String overlayId) {
    if (_selectedCircleIndex != null) {
      _circles[_selectedCircleIndex].color = Colors.black.withOpacity(0.3);
      LocationType location = _locationTypes.firstWhere((m) => m.id == overlayId);
      setState(() {
        dropdownValue = location.type;
      });

    }

    for(int i = 0; i < _circles.length; i++) {
      if (_circles[i].overlayId == overlayId) {
        _selectedCircleIndex = i;
        setState(() {
          _sliderValue = _circles[i].radius;
          _circles[i].color = Colors.blueAccent.withOpacity(0.3);
        });
        break;
      }
    }
  }

  void _onChangeSelectBox(String newValue){
    if(_selectedCircleIndex != null){
      String id = _circles[_selectedCircleIndex].overlayId;
      LocationType location = _locationTypes.firstWhere((m) => m.id == id);
      _locationTypes[_locationTypes.indexOf(location)].type = newValue;
    }
      setState(() {
        dropdownValue = newValue;
      });
  }
}


class LocationType{
  String id;
  String type;

  LocationType(this.id, this.type);
}