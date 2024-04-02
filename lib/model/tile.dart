import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_crush/model/level.dart';

///
/// Tile
///
class Tile extends Object {
  TileType? type;
  int row;
  int col;
  Level? level;
  int depth;
  Widget? _widget;
  double? x;
  double? y;
  bool visible;

  Tile({
    this.type,
    this.row = 0,
    this.col = 0,
    this.level,
    this.depth = 0,
    this.visible = true,
  });

  factory Tile.clone(Tile otherTile) {
    Tile newTile = Tile(
      type: otherTile.type,
      row: otherTile.row,
      col: otherTile.col,
      level: otherTile.level,
      depth: otherTile.depth,
      visible: otherTile.visible,
    );
    newTile._widget = otherTile._widget;
    newTile.x = otherTile.x;
    newTile.y = otherTile.y;

    return newTile;
  }

  @override
  int get hashCode => row * level!.numberOfRows + col;

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other.hashCode == this.hashCode;
  }

  @override
  String toString() {
    return '[$row][$col] => ${type!.name}';
  }

  //
  // Builds the tile in terms of "decoration" ( = image )
  //
  void build({bool computePosition = true}) {
    if (depth > 0 && type != TileType.wall) {
      _widget = Stack(
        children: <Widget>[
          Opacity(
            opacity: 0.7,
            child: Transform.scale(
              scale: 0.8,
              child: _buildDecoration(),
            ),
          ),
          _buildDecoration('deco/ice_02.png'),
        ],
      );
    } else if (type == TileType.empty) {
      _widget = Container();
    } else {
      _widget = _buildDecoration();
    }

    if (computePosition) {
      setPosition();
    }
  }

  Widget _buildDecoration([String path = ""]) {
    String imageAsset = path;
    if (imageAsset == "") {
      switch (type) {
        case TileType.wall:
          imageAsset = "deco/wall.png";
          break;

        case TileType.bomb:
          imageAsset = "bombs/mine.png";
          break;

        case TileType.flare:
          imageAsset = "bombs/tnt.png";
          break;

        case TileType.wrapped:
          imageAsset = "tiles/multicolor.png";
          break;

        case TileType.fireball:
          imageAsset = "bombs/rocket.png";
          break;

        case TileType.blue_v:
        case TileType.blue_h:
        case TileType.red_v:
        case TileType.red_h:
        case TileType.green_v:
        case TileType.green_h:
        case TileType.orange_v:
        case TileType.orange_h:
        case TileType.purple_v:
        case TileType.purple_h:
        case TileType.yellow_v:
        case TileType.yellow_h:
          imageAsset = "bombs/${type!.name}.png";
          break;

        default:
          try {
            imageAsset = "tiles/${type!.name}.png";
          } catch (e) {
            return Container();
          }
          break;
      }
    }
    return Container(
      decoration: BoxDecoration(
          image: DecorationImage(
        image: AssetImage('assets/images/$imageAsset'),
        fit: BoxFit.contain,
      )),
    );
  }

  //
  // Returns the position of this tile in the checkerboard
  // based on its position in the grid (row, col) and
  // the dimensions of the board and a tile
  //
  void setPosition() {
    double bottom =
        level!.boardTop + (level!.numberOfRows - 1) * level!.tileHeight;
    x = level!.boardLeft + col * level!.tileWidth;
    y = bottom - row * level!.tileHeight;
  }

  //
  // Generate a tile to be used during the swap animations
  //
  Tile cloneForAnimation() {
    Tile tile = Tile(level: level, type: type, row: row, col: col);
    tile.build();

    return tile;
  }

  //
  // Swaps this tile (row, col) with the ones of another Tile
  //
  void swapRowColWith(Tile destTile) {
    int tft = destTile.row;
    destTile.row = row;
    row = tft;

    tft = destTile.col;
    destTile.col = col;
    col = tft;
  }

  //
  // Returns the Widget to be used to render the Tile
  //
  Widget get widget => getWidgetSized(level!.tileWidth, level!.tileHeight);

  Widget getWidgetSized(double width, double height) => Container(
        width: width,
        height: height,
        child: _widget,
      );

  //
  // Can the Tile move?
  //
  bool get canMove => (depth == 0) && (canBePlayed(type!));

  //
  // Can a Tile fall?
  //
  bool get canFall =>
      type != TileType.wall &&
      type != TileType.forbidden &&
      type != TileType.empty;

  // ################  HELPERS  ######################
  //
  // Generate a random tile
  //
  static TileType random(math.Random rnd) {
    int minValue = _firstNormalTile;
    int maxValue = _lastNormalTile;
    int value = rnd.nextInt(maxValue - minValue) + minValue;
    return TileType.values[value];
  }

  static int get _firstNormalTile => TileType.red.index;
  static int get _lastNormalTile => TileType.yellow.index;
  static int get _firstBombTile => TileType.bomb.index;
  static int get _lastBombTile => TileType.fireball.index;

  static bool isNormal(TileType type) {
    int index = type.index;
    return (index >= _firstNormalTile && index <= _lastNormalTile);
  }

  static bool isBomb(TileType type) {
    int index = type.index;
    return (index >= _firstBombTile && index <= _lastBombTile);
  }

  static bool canBePlayed(TileType type) =>
      (type != TileType.wall && type != TileType.forbidden);

  static TileType normalizeBombType(TileType bombType) {
    switch (bombType) {
      case TileType.blue_v:
      case TileType.red_v:
      case TileType.green_v:
      case TileType.orange_v:
      case TileType.purple_v:
      case TileType.yellow_v:
        return TileType.bomb_v;

      case TileType.blue_h:
      case TileType.red_h:
      case TileType.green_h:
      case TileType.orange_h:
      case TileType.purple_h:
      case TileType.yellow_h:
        return TileType.bomb_h;

      default:
        return bombType;
    }
  }
}

//
// Types of tiles
//
enum TileType {
  forbidden,
  empty,
  red,
  green,
  blue,
  orange,
  purple,
  yellow,
  wall,
  bomb,
  flare,
  blue_v,
  blue_h,
  red_v,
  red_h,
  green_v,
  green_h,
  orange_v,
  orange_h,
  purple_v,
  purple_h,
  yellow_v,
  yellow_h,
  wrapped,
  fireball,
  bomb_v,
  bomb_h,
  last,
}
