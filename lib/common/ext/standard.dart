
extension NullStringExt on String? {
  String get val => isNullOrEmpty ? '' : this!;

}


extension NullNumExt on num? {
  num get val => isNullOrEmpty ? 0 : this!;
}

extension IntExt on int? {
  int get val => isNullOrEmpty ? 0 : this!;
}

extension DoubleExt on double? {
  double get val => isNullOrEmpty ? 0 : this!;
}

extension BoolExt on bool? {
  bool get val => this == null ? false : this == true;
}

extension Dynamic on dynamic {
  bool get isEmpty => this == null || toString().trim().isEmpty;

  bool get isNullOrEmpty => this == null || toString().trim().isEmpty;
}