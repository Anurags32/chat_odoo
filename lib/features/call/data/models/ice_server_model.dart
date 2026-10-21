class IceServerModel {
  final dynamic urls;
  final String? username;
  final String? credential;

  IceServerModel({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServerModel.fromJson(Map<String, dynamic> json) {
    return IceServerModel(
      urls: json['urls'],
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'urls': urls};
    if (username != null) map['username'] = username;
    if (credential != null) map['credential'] = credential;
    return map;
  }
}
