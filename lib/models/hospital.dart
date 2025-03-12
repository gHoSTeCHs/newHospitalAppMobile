class Hospital {
  final int id;
  final String name;
  final String code;

  Hospital({required this.id, required this.name, required this.code});

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      id: json['id'],
      name: json['name'],
      code: json['hospital_code'] ?? '',
    );
  }
}
