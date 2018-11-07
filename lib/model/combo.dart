import 'dart:collection';
import 'package:flutter_crush/model/chain.dart';
import 'package:flutter_crush/model/tile.dart';

///
/// Combo
///
///
class Combo {
  // List of all the tiles, part of the combo
  HashMap<int, Tile> _tiles = HashMap<int, Tile>();
  List<Tile> get tiles => UnmodifiableListView(_tiles.values.toList());

  // Type of combo
  ComboType _type = ComboType.none;
  ComboType get type => _type;

  // Type of tile that results from the combo
  TileType resultingTileType;

  // Which tile is responsible for the combo
  Tile commonTile;

  // Constructor
  Combo(Chain horizontalChain, Chain verticalChain, int row, int col){
    horizontalChain?.tiles?.forEach((Tile tile){
      _tiles.putIfAbsent(tile.hashCode, () => tile);
    });
    verticalChain?.tiles?.forEach((Tile tile){
      if (commonTile == null && _tiles.keys.contains(tile.hashCode)){
        commonTile = tile;
      }
      _tiles.putIfAbsent(tile.hashCode, () => tile);
    });

    int total = _tiles.length;
    _type = ComboType.values[total];

    // If the combo contains more than 3 tiles but is not the combination of both horizontal and vertical chains
    // we need to determine the tile which created the chain
    if (total > 3 && commonTile == null){
      _tiles.values.forEach((Tile tile){
        if (tile.row == row && tile.col == col){
          commonTile = tile;
        }
      });
    }

    // Determine the type of the resulting tile (case of more than 3 tiles)
    switch(total){
      case 4:
        resultingTileType = TileType.flare;
        break;

      case 6:
        resultingTileType = TileType.bomb;
        break;

      case 5:
        resultingTileType = TileType.wrapped;
        break;

      case 7:
        resultingTileType = TileType.fireball;
        break;
    }
  }
}

//
// All combo types
//
enum ComboType {
  none,
  one,
  two,
  three,
  four,
  five,
  six,
  seven,
}