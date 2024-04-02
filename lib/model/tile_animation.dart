import 'package:flutter_crush/model/row_col.dart';
import 'package:flutter_crush/model/tile.dart';

///
/// TileAnimation
///
/// Class which is used to register a Tile animation
class TileAnimation {
  TileAnimation({
    required this.animationType,
    required this.delay,
    required this.from,
    required this.to,
    this.tileType,
    required this.tile,
  });

  final TileAnimationType animationType;
  final int delay;
  final RowCol from;
  final RowCol to;
  final TileType? tileType;
  Tile tile;
}

//
// Types of animations
//
enum TileAnimationType {
  moveDown,
  avalanche,
  newTile,
  chain,
  collapse,
}
