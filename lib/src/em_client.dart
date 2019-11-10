import 'dart:async';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

import 'em_chat_manager.dart';
import 'em_chatroom_manager.dart';
import 'em_contact_manager.dart';
import 'em_domain_terms.dart';
import 'em_group_manager.dart';
import 'em_log.dart';
import 'em_listeners.dart';
import 'em_sdk_method.dart';


class EMClient {
  static const _channelPrefix = 'com.easemob.im';
  static const MethodChannel _emClientChannel =
      const MethodChannel('$_channelPrefix/em_client', JSONMethodCodec());

  static final EMLog _log = EMLog();
  final EMChatManager _chatManager = EMChatManager.getInstance(log: _log);
  final EMContactManager _contactManager =
      EMContactManager.getInstance(log: _log);
  final EMChatRoomManager _chatRoomManager = EMChatRoomManager.getInstance();

  final EMGroupManager _groupManager =
  EMGroupManager.getInstance(log: _log);


  final _connectionListeners = List<EMConnectionListener>();
  final _multiDeviceListeners = List<EMMultiDeviceListener>();
  static EMClient _instance;

  /// instance fields
  String _currentUser;
  bool _connected = false;
  EMOptions _options;
  String _accessToken;

  factory EMClient.getInstance() {
    return _instance = _instance ?? EMClient._internal();
  }

  /// private constructor
  EMClient._internal() {
    _addNativeMethodCallHandler();
  }

  void _addNativeMethodCallHandler() {
    _emClientChannel.setMethodCallHandler((MethodCall call) {
      Map argMap = call.arguments;
      if (call.method == EMSDKMethod.onConnected) {
        return _onConnected();
      } else if (call.method == EMSDKMethod.onDisconnected) {
        return _onDisconnected(argMap);
      } else if (call.method == EMSDKMethod.onMultiDeviceEvent) {
        return _onMultiDeviceEvent(argMap);
      }
      return null;
    });
  }

  /// init - init Easemob SDK client with specified [options] instance.
  void init(EMOptions options) {
    _options = options;
    _emClientChannel.invokeMethod(EMSDKMethod.init, options.convertToMap());
  }

  /// createAccount - create an account with [userName]/[password].
  /// Callback [onError] once account creation failed.
  void createAccount(
      { @required String userName,
        @required String password,
        onSuccess(),
        onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.createAccount,
        {"userName": userName, "password": password});
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) {
          onSuccess();
        }
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// login - login server with [id]/[password].
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void login(
      {@required String userName,
      @required String password,
      onSuccess(String username),
      onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.login, {"userName": userName, "password": password});
    result.then((response) {
      print(response);
      if (response['success']) {
        if (onSuccess != null) {
          // set current user name
          _currentUser = userName;
          onSuccess(_currentUser);
        }
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// loginWithToken - login with [userName] and [token].
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void loginWithToken(
      {@required String userName,
      @required String token,
      onSuccess(),
      onError(int errorCode, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.login, {"userName": userName, "token": token});
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) onSuccess();
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// logout - log out synchronously.
  /// int logout(bool unbindToken){}

  /// logout - log out.
  /// if [unbindToken] is true, then invalidate the previous bound token.
  /// Call [onSuccess] once login succeed and [onError] error occured.
  void logout(
      {bool unbindToken = false, onSuccess(), onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel
        .invokeMethod(EMSDKMethod.logout, {"unbindToken": unbindToken});
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) onSuccess();
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// changeAppKey - change app key with new [appKey].
  /// Call [onError] if something wrong.
  void changeAppKey({@required String appKey, onSuccess(), onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel
        .invokeMethod(EMSDKMethod.changeAppKey, {"appKey": appKey});
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) onSuccess();
      } else {
        if (onError != null) onError(response['code'], response['desc']);
      }
    });
  }

  /// setDebugMode - set to run in debug mode.
  void setDebugMode(bool debugMode) {
    _emClientChannel
        .invokeMethod(EMSDKMethod.setDebugMode, {"debugMode": debugMode});
  }

  /// updateCurrentUserNick - update user nick with [nickName].
  Future<bool> updateCurrentUserNick(String nickName) async {
    Map<String, dynamic> result = await _emClientChannel.invokeMethod(
        EMSDKMethod.updateCurrentUserNick, {"nickName": nickName});
    if (result['success']) {
      return result['status'] as bool;
    } else {
      return false;
    }
  }

  void uploadLog({onSuccess(), onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(EMSDKMethod.uploadLog);
    result.then((response) {
      if (response['success']) {
        if (onSuccess != null) {
          onSuccess();
        } else {
          if (onError != null) {
            onError(response['code'], response['desc']);
          }
        }
      }
    });
  }

  /// getOptions - return [EMOptions] inited.
  EMOptions getOptions() {
    return _options;
  }

  Future<String> compressLogs(onError(int code, String desc)) async {
    Map<String, dynamic> result =
        await _emClientChannel.invokeMethod(EMSDKMethod.compressLogs);
    if (result['success']) {
      return result['logs'] as String;
    } else {
      if (onError != null) onError(result['code'], result['desc']);
      return '';
    }
  }

  /// getLoggedInDevicesFromServer - return all logged in devices.
  /// Access controlled by [userName]/[password] and if error occured,
  /// [onError] is called.
  Future<List<EMDeviceInfo>> getLoggedInDevicesFromServer(
      {@required String userName,
      @required String password,
      onError(int code, String desc)}) async {
    Map<String, dynamic> result = await _emClientChannel.invokeMethod(
        EMSDKMethod.getLoggedInDevicesFromServer,
        {"userName": userName, "password": password});
    if (result['success']) {
      return _convertDeviceList(result['devices']);
    } else {
      if (onError != null) onError(result['code'], result['desc']);
      return null;
    }
  }

  List<EMDeviceInfo> _convertDeviceList(List deviceList) {
    var result = List<EMDeviceInfo>();
    for (var device in deviceList) {
      result.add(
          EMDeviceInfo(device['resource'], device['UUID'], device['name']));
    }
    return result;
  }

  /// kickDevice - kick device out.
  /// Access control by [userName]/[password] pair, device identified by [resource].
  /// If anything wrong, [onError] will be called.
  void kickDevice(
      {@required String userName,
      @required String password,
      @required String resource,
      onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(EMSDKMethod.kickDevice,
        {"userName": userName, "password": password, "resource": resource});
    result.then((response) {
      if (!response['success']) {
        if (onError != null) onError(response['code'], response['desc']);
        return null;
      }
    });
  }

  /// kickAllDevices - kick out all devices by force.
  /// Access control by [userName]/[password] pair. If anything wrong, [onError] will be called.
  void kickAllDevices(
      {@required String userName,
      @required String password,
      onError(int code, String desc)}) {
    Future<Map> result = _emClientChannel.invokeMethod(
        EMSDKMethod.kickAllDevices,
        {"userName": userName, "password": password});
    result.then((response) {
      if (!response['success']) {
        if (onError != null) onError(response['code'], response['desc']);
        return null;
      }
    });
  }

  /// sendFCMTokenToServer - send FCM token [fcmToken] to server.
  void sendFCMTokenToServer({@required String fcmToken}) {
    _emClientChannel
        .invokeMethod(EMSDKMethod.sendFCMTokenToServer, {"token": fcmToken});
  }

  /// sendHMSPushTokenToServer - send HMS push token [token] of app [appId] to server.
  void sendHMSPushTokenToServer({@required String token}) {
    _emClientChannel.invokeMethod(EMSDKMethod.sendHMSPushTokenToServer,
        {"token": token});
  }

  /// isFCMAvailable - fcm available?
  bool isFCMAvailable() {
    return _options.isUseFCM();
  }

  /// getAccessToken - Returns local cached access token.
  String getAccessToken() {
    return _accessToken;
  }

  /// getCurrentUser - get current user name.
  /// Return null if not successfully login IM server yet.
  String getCurrentUser() {
    return _currentUser;
  }

  /// isLoggedInBefore - whether successful login invoked before.
  Future<bool> isLoggedInBefore() async{
    Map<String, dynamic> result =
    await _emClientChannel.invokeMethod(EMSDKMethod.isLoggedInBefore);
    if(result['success']){
      return result['isLogged'];
    }
    return false;
  }

  /// isConnected - whether connection connected now.
  bool isConnected() {
    return _connected;
  }

  List<EMContact> _convertContactList(contactList) {
    var result = List<EMContact>();
    for (var contact in contactList) {
      var c = EMContact(userName: contact["userName"]);
      c.nickName = contact["nickName"];
      result.add(c);
    }
    return result;
  }

  /// getChatConfigPrivate - TODO: implement later
  /// EMChatConfigPrivate getChatConfigPrivate() {}

  /* Listeners*/

  /// addMultiDeviceListener - add multiple device [listener].
  void addMultiDeviceListener(EMMultiDeviceListener listener) {
    assert(listener != null);
    _multiDeviceListeners.add(listener);
  }

  /// removeMultiDeviceListener - remove multiple device [listener].
  void removeMultiDeviceListener(EMMultiDeviceListener listener) {
    assert(listener != null);
    _multiDeviceListeners.remove(listener);
  }

  /// addConnectionListener - set listeners for connected/disconnected events.
  void addConnectionListener(EMConnectionListener listener) {
    assert(listener != null);
    _connectionListeners.add(listener);
  }

  /// removeConnectionListener - get rid of listener from receiving connection events.
  void removeConnectionListener(EMConnectionListener listener) {
    assert(listener != null);
    _connectionListeners.remove(listener);
  }

  /// once connection changed, listeners to be informed.
  Future<void> _onConnected() async {
    for (var listener in _connectionListeners) {
      listener.onConnected();
    }
  }

  Future<void> _onDisconnected(Map map) async {
    for (var listener in _connectionListeners) {
      int errorCode = map["errorCode"];
      listener.onDisconnected(errorCode);
    }
  }

  /// on multi device event emitted, call listeners func.
  Future<void> _onMultiDeviceEvent(Map map) async {
    var event = map["event"];
    for (var listener in _multiDeviceListeners) {
      if (event >= 10) {
        listener.onGroupEvent(convertIntToEMContactGroupEvent(event), map['target'], map['userNames']);
      } else {
        listener.onContactEvent(convertIntToEMContactGroupEvent(event), map['target'], map['ext']);
      }
    }
  }

  /// chatManager - retrieve [EMChatManager] handle.
  EMChatManager chatManager() {
    return _chatManager;
  }

  /// contactManager - retrieve [EMContactManager] handle.
  EMContactManager contactManager() {
    return _contactManager;
  }

  EMChatRoomManager chatRoomManager(){
    return _chatRoomManager;
  }
  /// groupManager - retrieve [EMGroupManager] handle.
  EMGroupManager groupManager(){
    return _groupManager;
  }

  EMContactGroupEvent convertIntToEMContactGroupEvent(int i){
    switch(i){
      case 2:
        return EMContactGroupEvent.CONTACT_REMOVE;
      case 3:
        return EMContactGroupEvent.CONTACT_ACCEPT;
      case 4:
        return EMContactGroupEvent.CONTACT_DECLINE;
      case 5:
        return EMContactGroupEvent.CONTACT_BAN;
      case 6:
        return EMContactGroupEvent.CONTACT_ALLOW;
      case 10:
        return EMContactGroupEvent.GROUP_CREATE;
      case 11:
        return EMContactGroupEvent.GROUP_DESTROY;
      case 12:
        return EMContactGroupEvent.GROUP_JOIN;
      case 13:
        return EMContactGroupEvent.GROUP_LEAVE;
      case 14:
        return EMContactGroupEvent.GROUP_APPLY;
      case 15:
        return EMContactGroupEvent.GROUP_APPLY_ACCEPT;
      case 16:
        return EMContactGroupEvent.GROUP_APPLY_DECLINE;
      case 17:
        return EMContactGroupEvent.GROUP_INVITE;
      case 18:
        return EMContactGroupEvent.GROUP_INVITE_ACCEPT;
      case 19:
        return EMContactGroupEvent.GROUP_INVITE_DECLINE;
      case 20:
        return EMContactGroupEvent.GROUP_KICK;
      case 21:
        return EMContactGroupEvent.GROUP_BAN;
      case 22:
        return EMContactGroupEvent.GROUP_ALLOW;
      case 23:
        return EMContactGroupEvent.GROUP_BLOCK;
      case 24:
        return EMContactGroupEvent.GROUP_UNBLOCK;
      case 25:
        return EMContactGroupEvent.GROUP_ASSIGN_OWNER;
      case 26:
        return EMContactGroupEvent.GROUP_ADD_ADMIN;
      case 27:
        return EMContactGroupEvent.GROUP_REMOVE_ADMIN;
      case 28:
        return EMContactGroupEvent.GROUP_ADD_MUTE;
      case 29:
        return EMContactGroupEvent.GROUP_REMOVE_MUTE;
      default:
        return null;
    }
  }

}
