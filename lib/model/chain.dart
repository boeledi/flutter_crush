import 'dart:collection';
import 'package:flutter_crush/model/tile.dart';

///
/// Chain
///
class Chain {
  // Number of tiles that compose the chain
  int length = 0;

  // Type of chain (horizontal or vertical)
  ChainType type;

  // List of the tiles, part of the chain
  HashMap<int, Tile> _tiles = HashMap<int, Tile>();
  List<Tile> get tiles => _tiles.values.toList();

  // Constructor
  Chain({
    this.length: 0,
    this.type,
  });

  // Add a tile to the list of unique ones belonging to the chain
  void addTile(Tile tile){
    _tiles.putIfAbsent(tile.hashCode, () => tile);
    length = _tiles.length;
  }
}

//
// Types of chains
//
enum ChainType {
  horizontal,
  vertical,
}

