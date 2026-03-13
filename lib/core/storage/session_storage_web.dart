// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

class SessionStorage {
  String? getItem(String key) => html.window.sessionStorage[key];

  void setItem(String key, String value) {
    html.window.sessionStorage[key] = value;
  }

  void removeItem(String key) {
    html.window.sessionStorage.remove(key);
  }
}
