class DdpMessage {
  final String msg;
  final String? id;
  final String? session;
  final String? name;
  final List<dynamic>? params;
  final String? collection;
  final Map<String, dynamic>? fields;
  final String? method;
  final String? error;
  final dynamic result;

  DdpMessage({
    required this.msg, this.id, this.session, this.name,
    this.params, this.collection, this.fields, this.method,
    this.error, this.result,
  });

  factory DdpMessage.fromJson(Map<String, dynamic> json) => DdpMessage(
    msg: json['msg'] ?? '',
    id: json['id'],
    session: json['session'],
    name: json['name'],
    params: json['params'] as List<dynamic>?,
    collection: json['collection'],
    method: json['method'],
    fields: json['fields'] as Map<String, dynamic>?,
    error: json['error'],
    result: json['result'],
  );
}
