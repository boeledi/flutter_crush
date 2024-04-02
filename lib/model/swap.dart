import 'package:flutter_crush/model/tile.dart';

///
/// Swap
///
/// Identifies a possible swap between 2 tiles
///
class Swap extends Object {
  Tile from;
  Tile to;

  Swap({
    required this.from,
    required this.to,
  });

  @override
  int get hashCode => from.hashCode * 1000 + to.hashCode;

  @override
  bool operator ==(Object other) {
    return identical(other, this) || other.hashCode == this.hashCode;
  }

  @override
  String toString() => '[${from.row}][${from.col}] => [${to.row}][${to.col}]';
}
