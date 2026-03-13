class SessionStorage {
  static final Map<String, String> _memory = <String, String>{};

  String? getItem(String key) => _memory[key];

  void setItem(String key, String value) {
    _memory[key] = value;
  }

  void removeItem(String key) {
    _memory.remove(key);
  }
}
