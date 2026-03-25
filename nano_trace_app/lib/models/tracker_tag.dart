class TrackerTag {
  final String id;           // Unique ID for the local list
  final String tagName;      // User's nickname (e.g., "Blue Backpack")
  final String hardwareName; // The BLE name (e.g., "NanoTrace-01")
  DateTime lastSeen;

  TrackerTag({
    required this.id,
    required this.tagName,
    required this.hardwareName,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tagName': tagName,
    'hardwareName': hardwareName,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory TrackerTag.fromJson(Map<String, dynamic> json) => TrackerTag(
    id: json['id'],
    tagName: json['tagName'],
    hardwareName: json['hardwareName'],
    lastSeen: DateTime.parse(json['lastSeen']),
  );
}