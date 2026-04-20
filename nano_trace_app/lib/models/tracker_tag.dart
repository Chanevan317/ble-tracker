class TrackerTag {
  final String id;           
  final String tagName;      
  final String hardwareName; // This stores our 3-byte Stealth ID (e.g., "K\x94\xA2")
  final String macAddress;   // The full RemoteId (e.g., "8C:FD:49:4B:94:A2")
  DateTime lastSeen;

  TrackerTag({
    required this.id,
    required this.tagName,
    required this.hardwareName,
    required this.macAddress,
    required this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'tagName': tagName,
    'hardwareName': hardwareName,
    'macAddress': macAddress,
    'lastSeen': lastSeen.toIso8601String(),
  };

  factory TrackerTag.fromJson(Map<String, dynamic> json) => TrackerTag(
    id: json['id'],
    tagName: json['tagName'],
    hardwareName: json['hardwareName'],
    macAddress: json['macAddress'] ?? '', // Fallback for old saved tags
    lastSeen: DateTime.parse(json['lastSeen']),
  );
}