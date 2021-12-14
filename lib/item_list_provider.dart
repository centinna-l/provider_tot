import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_state_management/modal.dart';
import 'package:flutter_state_management/todo_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


class StateProvider with ChangeNotifier {
  String _token;
  DateTime _expiryDate;
  String _userId;
  Timer _authTimer;


  bool get isAuth {
    return token != null;
  }

  String get token {
    if (_expiryDate != null &&
        _expiryDate.isAfter(DateTime.now()) &&
        _token != null) {
      return _token;
    }
    return null;
  }

  String get userId {
    return _userId;
  }

  List<Todo> items = List<Todo>.empty(growable: true);

  // Operations
  void editTask(Todo item, String description) {
    if (description != null && description != '') {
      item.description = description;

      notifyListeners();
    }
  }

  Future<Welcome> fetchAllTask() async{

    final fetchUrl = 'https://providetodo-default-rtdb.firebaseio.com/task.json?orderBy="userId"&equalTo="suaQhWXuvsYX4LmJrr2NajaWHMh1"';

    final listResponseData = await http.get(Uri.parse(fetchUrl));
    print(listResponseData.statusCode);

    final returningData = welcomeFromJson(listResponseData.body);
    print(returningData.toString());
    return returningData;
    //final finalData = json.decode(listResponseData.body);


  }


  void removeItem(Todo item) {
    items.remove(item);

    notifyListeners();
  }

  void addNewTask(String description) async{
    SharedPreferences shared = await SharedPreferences.getInstance();
    String usedData = shared.getString("userData");
    print("used"+usedData);
    Map<String, dynamic> userD = jsonDecode(usedData);
    print(userD["userId"]);
    if (description != null && description != '') {
      //items.add(Todo(description));
      final url =
          'https://providetodo-default-rtdb.firebaseio.com/task.json';
      try {
        final response = await http.post(
          Uri.parse(url),
          body: json.encode({
            'title': description,
            "status": false,
            'userId': userD["userId"]
          }),
        );
        print(response.statusCode.runtimeType);
        print(response.body);

          if(response.statusCode==200){
          final _todo= new Todo(
              description
          );
          items.add(_todo);
          notifyListeners();
        }
      }catch(e){
        print(e);
      }
      notifyListeners();
    }
  }

  void chanceCompleteness(Todo item) {
    item.complete = !item.complete;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _expiryDate = null;
    if (_authTimer != null) {
      _authTimer.cancel();
      _authTimer = null;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    // prefs.remove('userData');
    prefs.clear();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) {
      return false;
    }
    final extractedUserData =
    json.decode(prefs.getString('userData')) as Map<String, Object>;
    final expiryDate = DateTime.parse(extractedUserData['expiryDate']);

    if (expiryDate.isBefore(DateTime.now())) {
      return false;
    }
    _token = extractedUserData['token'];
    _userId = extractedUserData['userId'];
    _expiryDate = expiryDate;
    notifyListeners();
    autoLogout();
    return true;
  }

  void autoLogout() {
    if (_authTimer != null) {
      _authTimer.cancel();
    }
    final timeToExpiry = _expiryDate
        .difference(DateTime.now())
        .inSeconds;
    _authTimer = Timer(Duration(seconds: timeToExpiry), logout);
  }

    Future<String> fetchData()async {
     SharedPreferences shared = await SharedPreferences.getInstance();
     String usedData = shared.getString("userData");
     print("used"+usedData);
     Map<String, dynamic> userD = jsonDecode(usedData);
     print(userD["userId"]);
     return userD["userId"];

  }
  Future<void> updateProduct(String description, Todo newProduct) async {
    final prodIndex = items.indexWhere((prod) => prod.description == description);
    if (prodIndex >= 0) {
      final url =
          'https://providetodo-default-rtdb.firebaseio.com/task.json';
      await http.patch(Uri.parse(url),
          body: json.encode({
            'title': description,
            "status": false,
            'userId': fetchData().toString()
          }));
      items[prodIndex] = newProduct;
      notifyListeners();
    } else {
      print('...');
    }
  }

  Future<void> authenticate(String email, String password, String url) async {
    final myUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:$url?key=AIzaSyDbu8xbACev8qm_tQNFkvovTu-uDa63NQ0';
    try {
      print(myUrl);
      final loginResponse = await http.post(Uri.parse(myUrl),
          body: json.encode({
            'email': email,
            'returnSecureToken': true,
            'password': password
          })
      );
      final responseData = json.decode(loginResponse.body);
      if (responseData['error'] != null) {
        throw HttpException(responseData['error']['message']);
      }
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      autoLogout();
      _token = responseData['idToken'];
      _userId = responseData['localId'];
      _expiryDate = DateTime.now().add(
        Duration(
          seconds: int.parse(
            responseData['expiresIn'],
          ),
        ),
      );
      autoLogout();
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      final userData = json.encode(
        {
          'token': _token,
          'userId': _userId,
          'expiryDate': _expiryDate.toIso8601String(),
        },
      );
      prefs.setString('userData', userData);
    } catch (error) {
      throw error;
    }
  }
  Future<void> login(String email, String password) async {
    return authenticate(email, password, 'signInWithPassword');
  }
  Future<void> signup(String email, String password) async {
    return authenticate(email, password, 'signUp');
  }
}





