import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter_crush/helpers/array_2d.dart';
import 'package:flutter_crush/model/chain.dart';
import 'package:flutter_crush/model/combo.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter_crush/model/row_col.dart';
import 'package:flutter_crush/model/swap.dart';
import 'package:flutter_crush/model/swap_move.dart';
import 'package:flutter_crush/model/tile.dart';

class GameController {
  Level level;
  Array2d<Tile> _grid;
  Array2d<Tile> get grid => _grid;
  math.Random _rnd;

  //
  // List of all possible Swaps
  //
  HashMap<int, Swap> _swaps;
  List<Swap> get swaps => _swaps.values.toList();

  //
  // Helper to identify the variations of a move
  // (used to determine the possible swaps)
  //
  static List<SwapMove> _moves = <SwapMove>[
    const SwapMove(row: 0, col: -1),
    const SwapMove(row: 0, col: 1),
    const SwapMove(row: -1, col: 0),
    const SwapMove(row: 1, col: 0),
  ];

  //
  // Helper to identity the variations of positions
  // depending on an explosion type
  //
  Map<TileType, List<SwapMove>> _explosions = {
    TileType.flare: <SwapMove>[
                      const SwapMove(row: 0, col: -1),
                      const SwapMove(row: 0, col: 1),
                      const SwapMove(row: -1, col: 0),
                      const SwapMove(row: 1, col: 0),
                      const SwapMove(row: 0, col: 0),
                    ],
    TileType.bomb: <SwapMove>[
                      const SwapMove(row: 0, col: -2),
                      const SwapMove(row: 0, col: -1),
                      const SwapMove(row: 0, col: 1),
                      const SwapMove(row: 0, col: 2),
                      const SwapMove(row: -1, col: 0),
                      const SwapMove(row: -1, col: -1),
                      const SwapMove(row: -1, col: 1),
                      const SwapMove(row: 1, col: -1),
                      const SwapMove(row: 1, col: 0),
                      const SwapMove(row: 1, col: 1),
                      const SwapMove(row: -2, col: 0),
                      const SwapMove(row: 2, col: 0),
                      const SwapMove(row: 0, col: 0),
                    ],
    TileType.wrapped: <SwapMove>[
                      const SwapMove(row: 0, col: -3),
                      const SwapMove(row: 0, col: -2),
                      const SwapMove(row: 0, col: -1),
                      const SwapMove(row: 0, col: 1),
                      const SwapMove(row: 0, col: 2),
                      const SwapMove(row: 0, col: 3),
                      const SwapMove(row: -1, col: -2),
                      const SwapMove(row: -1, col: -1),
                      const SwapMove(row: -1, col: 0),
                      const SwapMove(row: -1, col: 1),
                      const SwapMove(row: -1, col: 2),
                      const SwapMove(row: 1, col: -2),
                      const SwapMove(row: 1, col: -1),
                      const SwapMove(row: 1, col: 0),
                      const SwapMove(row: 1, col: 1),
                      const SwapMove(row: 1, col: 2),
                      const SwapMove(row: -2, col: -1),
                      const SwapMove(row: -2, col: 0),
                      const SwapMove(row: -2, col: 1),
                      const SwapMove(row: 2, col: -1),
                      const SwapMove(row: 2, col: 0),
                      const SwapMove(row: 2, col: 1),
                      const SwapMove(row: -3, col: 0),
                      const SwapMove(row: 3, col: 0),
                      const SwapMove(row: 0, col: 0),
                    ],
  };

  //
  // Initialization
  //
  GameController({
    this.level,
  }) {
    // Initialize the grid to the dimensions of the Level and fill it with "empty" tiles
    _grid = Array2d<Tile>(level.numberOfRows, level.numberOfCols, defaultValue: Tile(type: TileType.empty));

    // Initialize the Random generator
    _rnd = math.Random();

    // Initialize the swaps Set
    _swaps = HashMap<int, Swap>();
  }

  ///
  /// Initialize the Tiles in the game
  /// Only the empty cells are to be considered
  ///
  void shuffle() {
    TileType type;
    Array2d<Tile> clone = _grid.clone<Tile>();
    bool isFirst = true;

    do {
      if (!isFirst){
        _grid = clone.clone<Tile>();
      }
      isFirst = false;

      //
      // 1. Fill the empty cells
      //
      for (int row = 0; row < level.numberOfRows; row++) {
        for (int col = 0; col < level.numberOfCols; col++) {
          // Only consider the empty cells
          if (_grid[row][col].type != TileType.empty) {
            continue;
          }

          Tile tile;
          switch (level.grid[row][col]) {
            case '1': // Regular cell
            case '2': // Regular cell but frozen
              
              do {
                type = Tile.random(_rnd);
              } while ((col > 1 &&
                      _grid[row][col - 1].type == type &&
                      _grid[row][col - 2].type == type) ||
                  (row > 1 &&
                      _grid[row - 1][col].type == type &&
                      _grid[row - 2][col].type == type));
              tile = Tile(row: row, col: col, type: type, level: level, depth: (level.grid[row][col] == '2') ? 1 : 0);
              break;

            case 'X':
              // No cell
              tile = Tile(row: row, col: col, type: TileType.forbidden, level: level, depth: 1);
              break;

            case 'W':
              // A wall
              tile = Tile(row: row, col: col, type: TileType.wall, level: level, depth: 1);
              break;
          }

          // Assign the tile
          _grid[row][col] = tile;
        }
      }

      //
      // 2. Identify the possible swaps
      //
      identifySwaps();
    } while (_swaps.length == 0);

    //
    // Once everything is set, build the tile Widgets
    //
    for (int row = 0; row < level.numberOfRows; row++) {
        for (int col = 0; col < level.numberOfCols; col++) {
          // Only consider the authorized cells (not forbidden)
          if (_grid[row][col].type == TileType.forbidden) continue;

          _grid[row][col].build();
        }
    }
  }

  //
  // Identify the possible Swaps
  //
  void identifySwaps() {
    _swaps.clear();

    int index;
    int destRow;
    int destCol;
    int totalRows = _grid.height;
    int totalCols = _grid.width;
    Tile fromTile;
    Tile toTile;
    bool isSrcNormalTile;
    bool isSrcBombTile;
    bool isDestNormalTile;
    bool isDestBombTile;

    SwapMove move;

    for (int row = 0; row < totalRows; row++) {
      for (int col = 0; col < totalCols; col++) {
        index = -1;
        fromTile = _grid[row][col];

        isSrcNormalTile = Tile.isNormal(fromTile.type);
        isSrcBombTile = Tile.isBomb(fromTile.type);

        if (isSrcNormalTile || isSrcBombTile) {
          do {
            index++;
            move = _moves[index];
//TODO: check if the move is allowed (barriers)
            destRow = row + move.row;
            destCol = col + move.col;

            if (destRow > -1 &&
                destRow < totalRows &&
                destCol > -1 &&
                destCol < totalCols) {
              toTile = _grid[destRow][destCol];

              // If the destination does not exist, skip
              if (toTile.type == TileType.forbidden) continue;

              // If the source tile is a bomb or if the destination tile is empty, all swaps are possible
              if (isSrcBombTile) {
                _addSwaps(fromTile, toTile);
                continue;
              }

              isDestNormalTile = Tile.isNormal(toTile.type);
              isDestBombTile = Tile.isBomb(toTile.type);

              // If the destination tile is a bomb, all swaps are possible
              if (isDestBombTile) {
                _addSwaps(fromTile, toTile);
                continue;
              }

              // If we want to swap the same type of tile => skip
              if (toTile.type == fromTile.type) continue;

              if (isDestNormalTile || toTile.type == TileType.empty) {
                // Exchange the tiles
                _grid[destRow][destCol] = Tile(row: row, col: col, type: fromTile.type, level: level);
                _grid[row][col] = Tile(row: destRow, col: destCol, type: toTile.type, level: level);

                //
                // check if this change creates a chain
                //
                Chain chainH = checkHorizontalChain(destRow, destCol);
                if (chainH != null) {
                  _addSwaps(fromTile, toTile);
                }

                Chain chainV = checkVerticalChain(destRow, destCol);
                if (chainV != null) {
                  _addSwaps(fromTile, toTile);
                }

                chainH = checkHorizontalChain(row, col);
                if (chainH != null) {
                  _addSwaps(toTile, fromTile);
                }

                chainV = checkVerticalChain(row, col);
                if (chainV != null) {
                  _addSwaps(toTile, fromTile);
                }

                // Revert back
                _grid[destRow][destCol] = toTile;
                _grid[row][col] = fromTile;
              }
            }
          } while (index < 3);
        }
      }
    }
  }

  //
  // Since the hashCode varies with the direction of a swap, we need
  // to record both
  //
  void _addSwaps(Tile fromTile, Tile toTile){
    Swap newSwap = Swap(from: fromTile, to: toTile);
     _swaps.putIfAbsent(newSwap.hashCode, () => newSwap);
     
     newSwap = Swap(from: toTile, to: fromTile);
     _swaps.putIfAbsent(newSwap.hashCode, () => newSwap);
  }

  //
  // Check if there is a vertical chain.
  //
  Chain checkVerticalChain(int row, int col) {
    Chain chain = Chain(type: ChainType.vertical);
    int minRow = math.max(0, row - 5);
    int maxRow = math.min(row + 5, _grid.height - 1);
    int index = row;
    TileType type = _grid[row][col].type;

    // By default the tested tile is part of the chain
    chain.addTile(_grid[row][col]);

    // Search Down
    index = row - 1;
    while (index >= minRow && _grid[index][col].type == type && _grid[index][col].type != TileType.empty) {
      chain.addTile(_grid[index][col]);
      index--;
    }

    // Search Up
    index = row + 1;
    while (index <= maxRow && _grid[index][col].type == type && _grid[index][col].type != TileType.empty) {
      chain.addTile(_grid[index][col]);
      index++;
    }

    // If the chain counts at least 3 tiles => return it
    return chain.length > 2 ? chain : null;
  }

  //
  // Check if there is a horizontal chain.
  //
  Chain checkHorizontalChain(int row, int col) {
    Chain chain = Chain(type: ChainType.horizontal);
    int minCol = math.max(0, col - 5);
    int maxCol = math.min(col + 5, _grid.width - 1);
    int index = col;
    TileType type = _grid[row][col].type;

    // By default the tested tile is part of the chain
    chain.addTile(_grid[row][col]);

    // Search Left
    index = col - 1;
    while (index >= minCol && _grid[row][index].type == type && _grid[row][index].type != TileType.empty) {
      chain.addTile(_grid[row][index]);
      index--;
    }

    // Search Right
    index = col + 1;
    while (index <= maxCol && _grid[row][index].type == type && _grid[row][index].type != TileType.empty) {
      chain.addTile(_grid[row][index]);
      index++;
    }

    // If the chain counts at least 3 tiles => return it
    return chain.length > 2 ? chain : null;
  }

  //
  // Check if the swap between 2 tiles is recognized
  //
  bool swapContains(Tile source, Tile destination){
    Swap testSwap = Swap(from: source, to: destination);
    return _swaps.keys.contains(testSwap.hashCode);
  }
  
  //
  // Swap 2 tiles
  //
  void swapTiles(Tile source, Tile destination){
    RowCol sourceRowCol = RowCol(row: source.row, col: source.col);
    RowCol destRowCol = RowCol(row: destination.row, col: destination.col);
    source.swapRowColWith(destination);
    Tile tft = grid[sourceRowCol.row][sourceRowCol.col];
    grid[sourceRowCol.row][sourceRowCol.col] = grid[destRowCol.row][destRowCol.col];
    grid[destRowCol.row][destRowCol.col] = tft;
  }

  //
  // Get combo resulting from a move
  //
  Combo getCombo(int row, int col){
    Chain verticalChain = checkVerticalChain(row, col);
    Chain horizontalChain = checkHorizontalChain(row, col);

    return Combo(horizontalChain, verticalChain, row, col);
  }

  //
  // Resolves a combo
  //
  void resolveCombo(Combo combo, GameBloc gameBloc){
    
    // We now need to remove all the Tiles from the grid and change the type if necessary
    combo.tiles.forEach((Tile tile){
      if (tile != combo.commonTile){
        // Decrement the depth
        if (--grid[tile.row][tile.col].depth < 0){
          // Check for objectives
          gameBloc.pushTileEvent(grid[tile.row][tile.col].type, 1);

          // If the depth is lower than 0, this means that we can remove the tile
          grid[tile.row][tile.col].type = TileType.empty;
        }
        // We need to rebuild the Widget
        grid[tile.row][tile.col].build();
      } else {
        grid[tile.row][tile.col].row = combo.commonTile.row;
        grid[tile.row][tile.col].col = combo.commonTile.col;
        grid[tile.row][tile.col].type = combo.resultingTileType;
        grid[tile.row][tile.col].visible = true;
        grid[tile.row][tile.col].build();

        // We need to notify about the creation of a new tile
        gameBloc.pushTileEvent(combo.resultingTileType, 1);
      }
    });
  }

  //
  // Rebuilds the grid, once all animations are complete
  //
  void refreshGridAfterAnimations(Array2d<TileType> tileTypes, Set<RowCol> involvedCells){

    involvedCells.forEach((RowCol rowCol){
        _grid[rowCol.row][rowCol.col].row = rowCol.row;
        _grid[rowCol.row][rowCol.col].col = rowCol.col;
        _grid[rowCol.row][rowCol.col].type = tileTypes[rowCol.row][rowCol.col];
        _grid[rowCol.row][rowCol.col].visible = true;
        _grid[rowCol.row][rowCol.col].depth = 0;
        _grid[rowCol.row][rowCol.col].build();
    });
  }

  //
  // Proceed with an explosion
  // The spread of the explosion depends on the type of bomb
  //
  void proceedWithExplosion(Tile tileExplosion, GameBloc gameBloc, {bool skipThis: false}){
    // Retrieve the list of row/col variations
    List<SwapMove> _swaps = _explosions[tileExplosion.type];

    // We will record any explosions that could happen should
    // a bomb make another bomb explode
    List<Tile> _subExplosions = <Tile>[];

    // All the tiles in that area will disappear
    _swaps?.forEach((SwapMove move){
      int row = tileExplosion.row + move.row;
      int col = tileExplosion.col + move.col;

      // Test if the cell is valid
      if (row > -1 && row < level.numberOfRows && col > -1 && col < level.numberOfCols){
        // And also if we may explode the tile
        if (level.grid[row][col] == '1'){
          Tile tile = _grid[row][col];

          if (tile != null && Tile.isBomb(tile.type) && !skipThis){
            // Another bomb must explode
            _subExplosions.add(tile);
          } else {
            // Notify that we removed some tiles
            gameBloc.pushTileEvent(tile.type, 1);

            // Empty the cell
            tile.type = TileType.empty;
            tile.build();
          }
        }
      }
    });

    // Proceed with chained explosions
    _subExplosions.forEach((Tile tile){
      proceedWithExplosion(tile, gameBloc, skipThis: true);
    });
  }
}
