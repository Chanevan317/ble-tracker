class TrackerTag {
  final String id;
  final String tagName;
  final String macAddress;
  final String token;
  final String stealthBytes;
  DateTime lastSeen;

  TrackerTag({
    required this.id,
    required this.tagName,
    required this.macAddress,
    required this.token,
    required this.stealthBytes,
    required this.lastSeen,
  });

  List<int> get tokenBytes {
    return List.generate(
      4,
      (i) => int.parse(token.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tagName': tagName,
    'macAddress': macAddress,
    'token': token,
    'stealthBytes': stealthBytes,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory TrackerTag.fromJson(Map<String, dynamic> json) => TrackerTag(
    id: json['id'],
    tagName: json['tagName'],
    macAddress: json['macAddress'] ?? '',
    token: json['token'] ?? '',
    stealthBytes: json['stealthBytes'] ?? '',
    lastSeen: DateTime.parse(json['lastSeen']),
  );
}
