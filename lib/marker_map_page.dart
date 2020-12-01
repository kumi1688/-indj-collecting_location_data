import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:indjcollectinglocationdata/network/websocket.dart';
import 'package:naver_map_plugin/naver_map_plugin.dart';

import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class MarkerMapPage extends StatefulWidget {
  @override
  _MarkerMapPageState createState() => _MarkerMapPageState();
}

class _MarkerMapPageState extends State<MarkerMapPage> {
  static const MODE_ADD = 0xF1;
  static const MODE_REMOVE = 0xF2;
  static const MODE_NONE = 0xF3;
  static const MODE_HIDE_MARKER = 0xF4;
  static final _formKey = GlobalKey<FormState>();

  static const LOCATION_LIST = <String>['은행', '마트', '병원', '카페', '편의점', '식당', '직장', '집'];

  Completer<NaverMapController> _controller = Completer();

  Map<String, dynamic> _mapConfiguration = {
    'currentMode': MODE_NONE,
    'hide_markers': false,
  };

  List<Marker> _markers = [];
  List<CircleOverlay> _circles = [];
  List<LocationType> _locationTypes = [];
  List<String> _locationNames = [];

  double _sliderValue = 20.0;
  int _selectedCircleIndex;
  Timer _timer;

  WebSocket websocket;

  String dropdownValue = '은행';

  FocusNode focusNode;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      OverlayImage.fromAssetImage(ImageConfiguration(), 'icon/marker.png').then((image) {});
    });
    super.initState();
    _configureWebsocket();
    _set_initial_marker();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: <Widget>[
            _controlPanel(),
            _naverMap(),
            _locationInputForm(),
          ],
        ),
      ),
    );
  }

  _locationInputForm(){
    if(_mapConfiguration['currentMode'] == MODE_ADD){
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: TextFormField(
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: '위치를 입력해주세요',
                ),
                onTap: () => focusNode.requestFocus(),
                onChanged: (text){
                  setState(() {
                    _locationNames[_selectedCircleIndex] = text;
                  });
                },
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _circlePanel(),
                _selectBox(),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: RaisedButton(
                    onPressed: () {
                      _sendDataToServer();
                      setState(() {
                        _mapConfiguration['currentMode'] = MODE_NONE;
                      });
                    },
                    child: Text('완료'),
                  ),
                ),
              ],
            )
          ],
        ),
      );
    } else {
      return Container();
    }
  }

  _selectBox() {
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
  }

  _circlePanel(){
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
                  Text("반경"),
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
              onTap: () => setState(() => _mapConfiguration['currentMode'] = MODE_ADD),
              child: Container(
                decoration: BoxDecoration(
                    color: _mapConfiguration['currentMode'] == MODE_ADD
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
                    color: _mapConfiguration['currentMode'] == MODE_ADD
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
              onTap: () => setState(() => _mapConfiguration['currentMode'] = MODE_REMOVE),
              child: Container(
                decoration: BoxDecoration(
                    color: _mapConfiguration['currentMode'] == MODE_REMOVE
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
                    color: _mapConfiguration['currentMode'] == MODE_REMOVE
                        ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // 마커 숨기기
          Expanded(
            child: GestureDetector(
              onTap: (){
                if(!_mapConfiguration['hide_markers']){
                  setState(()=>_mapConfiguration['hide_markers'] = true);
                } else {
                  setState(()=>_mapConfiguration['hide_markers'] = false);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                    color: _mapConfiguration['hide_markers'] ? Colors.black : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black)
                ),
                padding: EdgeInsets.all(8),
                margin: EdgeInsets.only(right: 8),
                child: Text(
                  '마커 숨기기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _mapConfiguration['hide_markers'] ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // none
          GestureDetector(
            onTap: (){
              setState(() {
                _mapConfiguration['currentMode'] = MODE_NONE;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                  color: _mapConfiguration['currentMode'] == MODE_NONE ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.black)
              ),
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.clear,
                color: _mapConfiguration['currentMode'] == MODE_NONE
                    ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _naverMap() {
    if(_mapConfiguration['hide_markers']){
      return Expanded(
        child: Stack(
          children: <Widget>[
            NaverMap(
              onMapCreated: _onMapCreated,
              onMapTap: _onMapTap,
              markers: [],
              circles: [],
              initialCameraPosition: CameraPosition(
                  target: LatLng(37.566570, 126.978442),
                  zoom: 18
              ),
              initLocationTrackingMode: LocationTrackingMode.Follow,
            ),
          ],
        ),
      );
    } else {
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
  }


  // ================== method ==========================

  void _onMapCreated(NaverMapController controller) {
    _controller.complete(controller);
  }

  void _onMapTap(LatLng latLng) {
    if (_selectedCircleIndex != null) {
      _circles[_selectedCircleIndex].color = Colors.black.withOpacity(0.3);
    }

    if (_mapConfiguration['currentMode'] == MODE_ADD) {
      String id = Uuid().v4();
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
        _locationNames.add('이름을 입력해주세요');
      });

      if(_selectedCircleIndex == null){
        setState(() {
          _selectedCircleIndex = 0;
        });
      } else {
        setState(() {
          _selectedCircleIndex = _circles.length -1;
        });
      }
    }
  }

  void _onMarkerTap(Marker marker, Map<String, int> iconSize) {
    if (_mapConfiguration['currentMode'] == MODE_REMOVE){
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
      _circles[_selectedCircleIndex].radius = value;
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

  void _configureWebsocket() async {
    websocket = WebSocket();
    websocket.initWebSocket();
  }

  void _sendDataToServer(){
    List<dynamic> data = [];
    for(int i = 0; i < _markers.length; i++){
      data.add({
        'id': Uuid().v4(),
        'latitude': _markers[i].position.latitude,
        'longitude': _markers[i].position.longitude,
        'radius': _circles[i].radius.toStringAsFixed(3),
        'type': _locationTypes[i].type,
        'name': _locationNames[i],
        'time': new DateTime.now().toString()
      });
    }
    websocket.sendData(jsonEncode(data));
  }

  void _set_initial_marker() async {
    var data = await _getLocationData();
    for(int i = 0; i < data.length; i++){
      print('${i}번, ${data[i]}');
      setState(() {
        _markers.add(Marker(
          markerId: data[i]['id'],
          position: LatLng(data[i]['latitude'], data[i]['longitude']),
          infoWindow: data[i]['name'],
          onMarkerTab: _onMarkerTap,
        ));
        _circles.add(CircleOverlay(
          overlayId: data[i]['id'],
          center: LatLng(data[i]['latitude'], data[i]['longitude']),
          radius: double.parse(data[i]['radius'].toString()),
          onTap: _onCircleTap,
          color: Colors.blueAccent.withOpacity(0.3),
          outlineColor: Colors.black,
          outlineWidth: 1,
        ));
        _locationTypes.add(LocationType(data[i]['id'], data[i]['type']));
        _locationNames.add(data[i]['name']);
      });
    }
  }

   _getLocationData() async {
    String url = 'http://3.34.179.171:3000/location/data';
    var response = await http.get(url);
    List<dynamic> parsed_data = jsonDecode(response.body);
    return parsed_data;
  }
}

class LocationType{
  String id;
  String type;

  LocationType(this.id, this.type);
}