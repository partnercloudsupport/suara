import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:suara/common/common.dart';
import 'package:suara/models/vendor_settings.dart';
import 'package:suara/screens/payment_topup.dart';
import 'package:flutter_geofire/flutter_geofire.dart';

class VendorSettingsScreen extends StatefulWidget {
  final double _latitude;
  final double _longitude;
  final String _loggedInUserId;

  VendorSettingsScreen(this._latitude, this._longitude, this._loggedInUserId);

  @override
  State<StatefulWidget> createState() => VendorSettingsScreenState();
}

class VendorSettingsScreenState extends State<VendorSettingsScreen> {
  bool isChangedFlag = false;
  static const platform = const MethodChannel('saura.biz/deeplinks');
  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey();
  VendorSettings _vendorSettings;
  final _categoriesList = <String>[
    'Delivery',
    'Learn',
    'Service',
    'Sell',
    'Rent'
  ];

  Future<dynamic> navigateToSettingsPage(String title, initialValue) {
    return Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            ChangeVendorSettingPage(title, initialValue)));
  }

  Future<dynamic> openWazeLink() async {
    try {
      var result = await platform.invokeMethod('openWazeClientApp', {
        'latitude': '${_vendorSettings.location['latitude']}',
        'longitude': '${_vendorSettings.location['longitude']}'
      });
      print(result);
    } catch (error) {
      print(error);
    }
  }

  @override
  void initState() {
    super.initState();
    _vendorSettings = VendorSettings(widget._loggedInUserId);
    setState(() {
      _vendorSettings.location = {
        'latitude': widget._latitude,
        'longitude': widget._longitude
      };
    });
    getLoggedInUserDetails();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String pathToRef = 'locations';
    Geofire.initialize(pathToRef);
  }

  void getLoggedInUserDetails() async {
    Firestore.instance
        .collection('vendorsettings')
        .where('uid', isEqualTo: _vendorSettings.uid)
        .snapshots()
        .listen((data) {
      if (data.documents.length > 0) {
        print(data.documents[0]['businessDesc']);
        var result = VendorSettings.fromJson(data.documents[0]);
        setState(() {
          _vendorSettings = result;
        });
        Geofire.initialize('locations/${_vendorSettings.category}');
      }
    });

    /*setState(() {
      _switchState = status == null ? false : status;
    });*/
  }

  Future<void> removeExistingGeofireEntries() async {
    for (var cat in _categoriesList) {
      await Geofire.initialize('locations/$cat');
      await Geofire.removeLocation(_vendorSettings.uid);
    }
  }

  void showProgressSnackBar(ScaffoldState scaffState, String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Row(
        children: <Widget>[
          CircularProgressIndicator(),
          Padding(
            padding: EdgeInsets.only(left: 15.0),
            child: Text(message),
          )
        ],
      ),
      duration: Duration(seconds: 5),
    ));
  }

  Future<bool> showLocationNullValidationDialog() => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
            title: Text('Location not found'),
            content: Text(
                'The current location has not been set. Do you want to get the location and try again?'),
            actions: <Widget>[
              FlatButton(
                child: Text('NO'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              FlatButton(
                child: Text('YES'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ));

  Future<bool> showCategoryNullValidationDialog() => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
            title: Text('Category not found'),
            content: Text(
                'Default category has not been set. Do you want to set it and try again?'),
            actions: <Widget>[
              FlatButton(
                child: Text('NO'),
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
              ),
              FlatButton(
                child: Text('YES'),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ],
          ));

  Future<void> saveChanges() async {
    print(_vendorSettings.uid);
    var vendorSettings = _vendorSettings.toJson();
    await Firestore.instance
        .collection('vendorsettings')
        .document(_vendorSettings.uid)
        .setData(vendorSettings);

    isChangedFlag = false;
    print('done');
  }

  Future<bool> willPopScope() {
    Future<bool> result;
    if (isChangedFlag) {
      result = showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: Text('Changes not saved'),
                content:
                    Text('There are unsaved changes. Do you want to save?'),
                actions: <Widget>[
                  FlatButton(
                    child: Text('NO'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      return true;
                    },
                  ),
                  FlatButton(
                    child: Text('YES'),
                    onPressed: () async {
                      await saveChanges();
                      Navigator.of(context).pop(true);
                      return true;
                    },
                  )
                ],
              ));
    } else {
      result = Future.value(true);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Vendor Settings'),
          leading: Switch(
            value: _vendorSettings.isOnline == null
                ? false
                : _vendorSettings.isOnline,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.grey,
            onChanged: (val) async {
              if (val) {
                //checking if location is null. if it is, asking if want to fetch the current location
                if (_vendorSettings.location['latitude'] == null ||
                    _vendorSettings.location['longitude'] == null) {
                  var result = await showLocationNullValidationDialog();

                  //getting location
                  if (result) {
                    showProgressSnackBar(_scaffoldKey.currentState,
                        'Getting current location...');

                    //getting result
                    var currentLocation = await Location().getLocation();
                    setState(() {
                      _vendorSettings.location = {
                        'latitude': currentLocation['latitude'],
                        'longitude': currentLocation['longitude']
                      };
                    });
                    isChangedFlag = true;
                    _scaffoldKey.currentState.hideCurrentSnackBar();
                  } else {
                    return;
                  }
                }

                //checking if we have a default category selected
                if (_vendorSettings.category == null) {
                  var result = await showCategoryNullValidationDialog();

                  if (result) {
                    var category = await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) =>
                                CategoriesScreen(_vendorSettings.category),
                            fullscreenDialog: true));
                    if (category != null) {
                      setState(() {
                        _vendorSettings.category = category;
                      });
                      isChangedFlag = true;
                    }
                  } else {
                    return;
                  }
                }

                //before switching online, we need to save the user made changes to maintain the data consistency
                if (isChangedFlag) {
                  var result = await showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => AlertDialog(
                            title: Text('Changes not saved'),
                            content: Text(
                                'There are unsaved changes. Do you want to save?'),
                            actions: <Widget>[
                              FlatButton(
                                child: Text('NO'),
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                              ),
                              FlatButton(
                                child: Text('YES'),
                                onPressed: () async {
                                  showProgressSnackBar(
                                      _scaffoldKey.currentState,
                                      'Saving changes...');
                                  await saveChanges();
                                  _scaffoldKey.currentState.hideCurrentSnackBar();
                                  Navigator.of(context).pop(true);
                                },
                              )
                            ],
                          ));

                  if (result == false) {
                    return;
                  }
                }

                showProgressSnackBar(
                    _scaffoldKey.currentState, 'Switching to online...');

                //removing existing geofire entries
                await removeExistingGeofireEntries();

                //re-initializing the user selected category
                await Geofire.initialize(
                    'locations/${_vendorSettings.category}');

                print('logged in user Id: ${_vendorSettings.uid}');
                bool response = await Geofire.setLocation(
                    _vendorSettings.uid,
                    _vendorSettings.location['latitude'],
                    _vendorSettings.location['longitude']);
                print('geofire response: $response');
              } else {
                showProgressSnackBar(
                    _scaffoldKey.currentState, 'Going offline...');
                //removing existing geofire entries
                await removeExistingGeofireEntries();
              }

              await Firestore.instance
                  .collection('vendorsettings')
                  .document(_vendorSettings.uid)
                  .updateData({'isOnline': val});

              //hide the progressive snack bar
              _scaffoldKey.currentState.hideCurrentSnackBar();

              setState(() {
                _vendorSettings.isOnline = val;
              });

              _scaffoldKey.currentState.showSnackBar(SnackBar(
                content: Text(val ? 'Online' : 'Offline'),
              ));
            },
          ),
          actions: <Widget>[
            Row(
              children: <Widget>[
                Text('Available Balance'),
                IconButton(
                  icon: Icon(Icons.payment),
                  tooltip: 'Buy credit',
                  onPressed: () {
                    var route = MaterialPageRoute(
                        builder: (BuildContext context) =>
                            PaymentTopUpScreen());

                    Navigator.of(context).push(route);
                  },
                )
              ],
            )
          ],
        ),
        body: ListView(
          children: <Widget>[
            ListTile(
              title: Text('Business Name'),
              subtitle: Text(_vendorSettings.businessName != null
                  ? _vendorSettings.businessName
                  : 'Unspecified'),
              onTap: () async {
                var businessName = await navigateToSettingsPage(
                    'Business Name',
                    _vendorSettings.businessName != null
                        ? _vendorSettings.businessName
                        : '');
                if (businessName != null) {
                  setState(() {
                    _vendorSettings.businessName = businessName;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: Text('Business Description'),
              subtitle: Text(_vendorSettings.businessDesc != null
                  ? _vendorSettings.businessDesc
                  : 'Unspecified'),
              onTap: () async {
                var businessDesc = await navigateToSettingsPage(
                    'Business Description',
                    _vendorSettings.businessDesc != null
                        ? _vendorSettings.businessDesc
                        : '');
                if (businessDesc != null) {
                  setState(() {
                    _vendorSettings.businessDesc = businessDesc;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: Text('FB Page URL'),
              subtitle: Text(_vendorSettings.fbURL != null
                  ? _vendorSettings.fbURL
                  : 'Unspecified'),
              onTap: () async {
                var fbURL = await navigateToSettingsPage('FB Page URL',
                    _vendorSettings.fbURL != null ? _vendorSettings.fbURL : '');
                if (fbURL != null) {
                  setState(() {
                    _vendorSettings.fbURL = fbURL;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: Text('Location'),
              subtitle: Text(_vendorSettings.location != null
                  ? 'Lat: ${_vendorSettings.location['latitude']}  |  Long: ${_vendorSettings.location['longitude']}'
                  : 'Lat: 0.0000  |  Long: 0.0000'),
              onTap: () async {
                var location = await navigateToSettingsPage(
                    'Location',
                    _vendorSettings.location != null
                        ? '${_vendorSettings.location['latitude']}|${_vendorSettings.location['longitude']}'
                        : null);
                if (location != null) {
                  setState(() {
                    _vendorSettings.location = location;
                  });
                  isChangedFlag = true;
                }
              },
              trailing: IconButton(
                icon: Icon(Icons.pin_drop),
                onPressed: () async {
                  var currentLocation = await Location().getLocation();
                  Clipboard.setData(ClipboardData(
                      text:
                          'Lat: ${currentLocation['latitude']} | Long: ${currentLocation['longitude']}'));

                  setState(() {
                    _vendorSettings.location = {
                      'latitude': currentLocation['latitude'],
                      'longitude': currentLocation['longitude']
                    };
                  });
                  isChangedFlag = true;
                },
              ),
            ),
            ListTile(
              title: Text('Whatsapp Number'),
              subtitle: Text(_vendorSettings.whatsappNo != null
                  ? _vendorSettings.whatsappNo.isNotEmpty
                      ? _vendorSettings.whatsappNo
                      : 'Unspecified'
                  : 'Unspecified'),
              onTap: () async {
                var whatsappNo = await navigateToSettingsPage(
                    'Whatsapp No',
                    _vendorSettings.whatsappNo != null
                        ? _vendorSettings.whatsappNo.isNotEmpty
                            ? _vendorSettings.whatsappNo
                            : ''
                        : '');
                if (whatsappNo != null) {
                  setState(() {
                    _vendorSettings.whatsappNo = whatsappNo;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: Text('Phone Number'),
              subtitle: Text(_vendorSettings.phoneNo != null
                  ? _vendorSettings.phoneNo.isNotEmpty
                      ? _vendorSettings.phoneNo
                      : 'Unspecified'
                  : 'Unspecified'),
              onTap: () async {
                var phoneNo = await navigateToSettingsPage(
                    'Phone No',
                    _vendorSettings.phoneNo != null
                        ? _vendorSettings.phoneNo.isNotEmpty
                            ? _vendorSettings.phoneNo
                            : ''
                        : '');
                if (phoneNo != null) {
                  setState(() {
                    _vendorSettings.phoneNo = phoneNo;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: Text('Open in Waze'),
              onTap: () {
                openWazeLink().then((result) {
                  print(result);
                });
              },
            ),
            ListTile(
              title: Text('Default Category'),
              subtitle: Text(_vendorSettings.category == null
                  ? 'Unspecified'
                  : _vendorSettings.category.isEmpty
                      ? 'Unspecified'
                      : _vendorSettings.category),
              onTap: () async {
                var category = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) =>
                            CategoriesScreen(_vendorSettings.category),
                        fullscreenDialog: true));
                if (category != null) {
                  setState(() {
                    _vendorSettings.category = category;
                  });
                  isChangedFlag = true;
                }
              },
            ),
            ListTile(
              title: RaisedButton(
                color: Colors.blue,
                onPressed: () {
                  saveChanges();
                },
                child: Text(
                  'Save',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          ],
        ),
      ),
      onWillPop: willPopScope,
    );
  }
}

class ChangeVendorSettingPage extends StatelessWidget {
  final String _appBarTitle;
  final String _initialValue;
  final TextEditingController _txt1 = TextEditingController(text: '');
  final TextEditingController _txt2 = TextEditingController(text: '');

  ChangeVendorSettingPage(this._appBarTitle, this._initialValue);

  @override
  Widget build(BuildContext context) {
    _txt1.text = _appBarTitle.toString() == 'Location'
        ? _initialValue != null ? _initialValue.split('|')[0] : ''
        : _initialValue;
    _txt2.text = _appBarTitle.toString() == 'Location'
        ? _initialValue != null ? _initialValue.split('|')[1] : ''
        : null;

    return Scaffold(
        appBar: AppBar(
          title: Text(_appBarTitle),
          actions: <Widget>[
            FlatButton(
              child: Text(
                'SAVE',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                dynamic returnVal = _appBarTitle.toLowerCase() == 'location'
                    ? {'latitude': _txt1.text, 'longitude': _txt2.text}
                    : _txt1.text;
                Navigator.of(context).pop(returnVal);
              },
            )
          ],
        ),
        body: ListView(children: <Widget>[
          ListTile(
            title: _appBarTitle.toLowerCase() == 'business description'
                ? TextField(
                    controller: _txt1,
                    autofocus: true,
                    maxLines: 10,
                    decoration: InputDecoration(labelText: 'Enter a value'),
                  )
                : _appBarTitle.toLowerCase() == 'location'
                    ? Column(
                        children: <Widget>[
                          TextField(
                            controller: _txt1,
                            autofocus: true,
                            decoration:
                                InputDecoration(labelText: 'Enter latitude'),
                          ),
                          TextField(
                            controller: _txt2,
                            autofocus: true,
                            decoration:
                                InputDecoration(labelText: 'Enter longitude'),
                          )
                        ],
                      )
                    : TextField(
                        controller: _txt1,
                        autofocus: true,
                        decoration: InputDecoration(
                            labelText: 'Enter a value',
                            prefix: _appBarTitle.toLowerCase() == 'fb page url'
                                ? Container(
                                    child: Text('http://m.facebook.com/'))
                                : null),
                      ),
          )
        ]));
  }
}

class CategoriesScreen extends StatefulWidget {
  final String _initialValue;

  CategoriesScreen(this._initialValue);

  @override
  State<StatefulWidget> createState() => CategoriesScreenState();
}

class CategoriesScreenState extends State<CategoriesScreen> {
  final categoriesList = <String>[
    'Delivery',
    'Learn',
    'Service',
    'Sell',
    'Rent'
  ];

  String _selectedValue = '';

  @override
  void initState() {
    super.initState();
    setState(() {
      _selectedValue = widget._initialValue == null
          ? categoriesList[0]
          : widget._initialValue.isEmpty
              ? categoriesList[0]
              : widget._initialValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose a category'),
        actions: <Widget>[
          FlatButton(
            child: Text(
              'SAVE',
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () {
              Navigator.of(context).pop(_selectedValue);
            },
          )
        ],
      ),
      body: ListView(
        children: categoriesList
            .map((cat) => RadioListTile(
                  groupValue: _selectedValue,
                  title: Text(cat),
                  value: cat,
                  onChanged: (value) {
                    setState(() {
                      _selectedValue = value;
                    });
                    print(value);
                  },
                ))
            .toList(),
      ),
    );
  }
}
