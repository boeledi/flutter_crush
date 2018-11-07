import 'dart:math' as math;

import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter_crush/controllers/game_controller.dart';
import 'package:flutter_crush/helpers/array_2d.dart';
import 'package:flutter_crush/model/animation_sequence.dart';
import 'package:flutter_crush/model/avalanche_test.dart';
import 'package:flutter_crush/model/chain.dart';
import 'package:flutter_crush/model/combo.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter_crush/model/row_col.dart';
import 'package:flutter_crush/model/tile.dart';
import 'package:flutter_crush/model/tile_animation.dart';
import 'package:quiver/iterables.dart';

class AnimationsResolver {
  final GameBloc gameBloc;
  final Level level;
  GameController gameController;
  int rows;
  int cols;

  AnimationsResolver({
    this.gameBloc,
    this.level,
  }){
    rows = level.numberOfRows;
    cols = level.numberOfCols;
    gameController = gameBloc.gameController;
  }

  // _state contains the states of the grid after each move
  // 0:  empty cell (no tiles)
  // -1: forbidden (no cell or not movable tile)
  // 1:  tile is present
  Array2d<int> _state;
  Array2d<int> get resultingGridInTermsOfUse => _state;

  // _type contains the types of tiles in the grid after each move
  Array2d<TileType> _types;
  Array2d<TileType> get resultingGridInTermsOfTileTypes => _types;

  // _tiles contains the definitions of the tiles (type, depth, widget)
  Array2d<Tile> _tiles;
  Array2d<Tile> get resultingGridInTermsOfTiles => _tiles;

  // _names contains the tiles identities
  // Identities are important since animations will be played in sequence
  // for a same identity
  Array2d<int> _identities;
  int _nextIdentity = 0;

  // _avalanches contains a list of possible avalanches per column
  List<List<AvalancheTest>> _avalanches;

  // List of all animations, per identity and per delay
  Map<int, Map<int, TileAnimation>> _animationsPerIdentityAndDelay;
  Map<int, List<int>> _animationsIdentitiesPerDelay;
  
  // List of all cells, involved in the animations
  Set<RowCol> _involvedCells = Set<RowCol>();
  Set<RowCol> get involvedCells => _involvedCells;

  // Longuest delay for all animations
  int longestDelay = 0;

  // Working array that contains the last moves that took place
  // following a single resolution
  // Used to check for combos
  Set<RowCol> _lastMoves = Set<RowCol>();

  // Registers an animation
  void _registerAnimation(int identity, int delay, TileAnimation animation){
      // First register per identity, then per delay
      if (_animationsPerIdentityAndDelay[identity] == null){
        _animationsPerIdentityAndDelay[identity] = Map<int, TileAnimation>();
      }

      _animationsPerIdentityAndDelay[identity][delay] = animation;

      // Then the list of identities per delay
      if (_animationsIdentitiesPerDelay[delay] == null){
          _animationsIdentitiesPerDelay[delay] = <int>[];
      }
      _animationsIdentitiesPerDelay[delay].add(identity);
  }


  void resolve() {
//Stopwatch stopwatch = new Stopwatch()..start();    
      //
      // Fill both arrays based on the current definition
      //
      _state = Array2d<int>(rows, cols);
      _types = Array2d<TileType>(rows, cols);
      _tiles = Array2d<Tile>(rows, cols);
      _identities = Array2d<int>(rows, cols);
      _nextIdentity = 0;

      for (int row = 0; row < rows; row++){
          for (int col = 0; col < cols; col++){
              if (level.grid[row][col] == "X"){
                  _state[row][col] = -1;
                  _types[row][col] = TileType.forbidden;
                  _tiles[row][col] = null;
              } else {
                  Tile tile = gameController.grid[row][col];
                  if (tile.type == TileType.empty){
                      _state[row][col] = 0;
                      _types[row][col] = TileType.empty;
                  } else if (tile.canMove){
                      _state[row][col] = 1;
                      _types[row][col] = tile.type;
                  } else {
                      _state[row][col] = -1;
                      _types[row][col] = tile.type;
                  }
                  _tiles[row][col] = tile;
              }
              // Give an identity to each cell
              _identities[row][col] = _nextIdentity++;
          }
      }

      //
      // Initialize the _avalanches
      //
      _avalanches = List<List<AvalancheTest>>.generate(
        cols,
        (int index) => <AvalancheTest>[],
      );

      //
      // Initialize the list of all animations per delay, and per identity
      //
      _animationsPerIdentityAndDelay = Map<int, Map<int, TileAnimation>>();
      _animationsIdentitiesPerDelay = Map<int, List<int>>();

      //
      // delay before starting an animation
      //
      int delay = 0;
      longestDelay = 0;

      //
      // Loop until there is nothing more to be done
      //
      bool continueLoop;

      do {
        //
        // Check for combos
        //
        delay = _resolveCombos(delay);

        //
        // Once the combos have been resolved,
        // look for the moves
        //
        continueLoop = false;

        //
        // Process all the columns
        //
        _lastMoves.clear();

        for (int column = 0; column < cols; column++){

            // Start by processing the avalanches
            bool somethingHappens = _processAvalanches(column, delay);

            // Then process the moves inside a column
            int newDelay = _processColumn(column, delay);
            somethingHappens |= (newDelay != delay);

            // If something happens, we need to continue
            if (somethingHappens){
              // Compute the longest delay
              longestDelay = math.max(longestDelay, newDelay);

              // As something happened, we need to continue looping
              continueLoop = true;
            }
        } 

        // Adapt the delay to the longest one
        delay = longestDelay;      

      } while (continueLoop);

// print('executed in ${stopwatch.elapsed}');
  }

  //
  // Resolves any potential combos
  //
  int _resolveCombos(int startDelay){
    int delay = startDelay;
    bool hasCombo = false;

    _lastMoves.forEach((RowCol rowCol){
      Chain verticalChain = checkVerticalChain(rowCol.row, rowCol.col);
      Chain horizontalChain = checkHorizontalChain(rowCol.row, rowCol.col);

      // Check if there is a combo
      Combo combo = Combo(horizontalChain, verticalChain, rowCol.row, rowCol.col);
      if (combo.type != ComboType.none){
        // We found a combo.  We therefore need to take appropriate actions
        TileAnimationType animationType;
        RowCol from;
        RowCol to;

        // Recall that there is at least one combo
        hasCombo = true;

        if (combo.type == ComboType.three){
          animationType = TileAnimationType.chain;
        } else {
          animationType = TileAnimationType.collapse;
if (combo.commonTile == null){
print('Houston, we have a problem');
  //TODO: this should never happen
} else {
          // When we are collapsing, the tiles move to the position of the commonTile
          to = RowCol(row: combo.commonTile.row, col: combo.commonTile.col);
}
        }

        // We need to register the animations (combo)
        combo.tiles.forEach((Tile tile){
          
          from = RowCol(row: tile.row, col: tile.col);

          _registerAnimation(
              _identities[tile.row][tile.col],
              delay,
              TileAnimation(
                  animationType: animationType,
                  delay: delay,
                  from: from,
                  to: to,
                  tile: _tiles[tile.row][tile.col],
              ),
          );

          // Record the cells involved in the animation
          _involvedCells.add(from);

          // At the same time, we need to check the objectives
          gameBloc.pushTileEvent(_tiles[tile.row][tile.col]?.type, 1);
        });

        // ... the delay for the next move
        delay++;

        // Compute the longest delay
        longestDelay = math.max(longestDelay, delay);

        // Let's update the _state and _types at destination.
        // Except a potential common tile (combo of more than 3 tiles)
        // would remain
        combo.tiles.forEach((Tile tile){
          if (tile != combo.commonTile) {
            _state[tile.row][tile.col] = 0;
            _types[tile.row][tile.col] = TileType.empty;
            _tiles[tile.row][tile.col] = null;

            // Transfer the identity
            _identities[tile.row][tile.col] = -1;
          }
        });
      }
    });

    // If there is at least one combo,
    // wait for the combo to play before going any further
    // with the other animations
    return delay + (hasCombo ? 30 : 0);
  }

  //
  // Check if there is a vertical chain.
  //
  Chain checkVerticalChain(int row, int col) {
    Chain chain = Chain(type: ChainType.vertical);
    int minRow = math.max(0, row - 5);
    int maxRow = math.min(row + 5, rows - 1);
    int index = row;
    TileType type = _tiles[row][col]?.type;

    // By default the tested tile is part of the chain
    chain.addTile(_tiles[row][col]);

    // Search Down
    index = row - 1;
    while (index >= minRow && _tiles[index][col]?.type == type && _tiles[index][col]?.type != TileType.empty) {
      chain.addTile(_tiles[index][col]);
      index--;
    }

    // Search Up
    index = row + 1;
    while (index <= maxRow && _tiles[index][col]?.type == type && _tiles[index][col]?.type != TileType.empty) {
      chain.addTile(_tiles[index][col]);
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
    int maxCol = math.min(col + 5, cols - 1);
    int index = col;
    TileType type = _tiles[row][col]?.type;

    // By default the tested tile is part of the chain
    chain.addTile(_tiles[row][col]);

    // Search Left
    index = col - 1;
    while (index >= minCol && _tiles[row][index]?.type == type && _tiles[row][index]?.type != TileType.empty) {
      chain.addTile(_tiles[row][index]);
      index--;
    }

    // Search Right
    index = col + 1;
    while (index <= maxCol && _tiles[row][index]?.type == type && _tiles[row][index]?.type != TileType.empty) {
      chain.addTile(_tiles[row][index]);
      index++;
    }

    // If the chain counts at least 3 tiles => return it
    return chain.length > 2 ? chain : null;
  }

  //
  // Counts the number of "holes" (= empty cells) in a column
  // starting at a certain row
  //
  int _countNumberOfHolesAtColumStartingAtRow(int col, int row){
    int count = 0;

    while (row > 0 && _state[row][col] == 0 && _types[row][col] != TileType.forbidden){
      row--;
      count++;
    }

    return count;
  }

  //
  // Routine that checks if any avalanche effect could happen.
  // This happens when a tile reaches its destination but there is
  // a "hole" in an adjacent column.
  //
  bool _processAvalanches(int col, int delay){

    // Counter of moves caused by an avalanche effect
    int movesCounter = 0;

    final bool leftCol = (col > 0);
    final bool rightCol = (col < cols - 1);

    // Let's process all cases
    _avalanches[col].forEach((AvalancheTest avalancheTest){
      final int row = avalancheTest.row;

      // Count the number of "holes" on the left-hand side column
      final leftColHoles = leftCol ? _countNumberOfHolesAtColumStartingAtRow(col - 1, row -1): 0;

      // Count the number of "holes" on the right-hand side column
      final rightColHoles = rightCol ? _countNumberOfHolesAtColumStartingAtRow(col + 1, row -1): 0;
      int colOffset = 0;

      // Check if there is a hole.  If yes, the deeper wins
      if (leftColHoles + rightColHoles > 0){
        colOffset = (leftColHoles > rightColHoles) ? -1 : (rightCol ? 1 : 0);
      }

      // If there is a hole, slide the tile to the corresponding column
      if (colOffset != 0){
        RowCol from = RowCol(row: row, col: col);
        RowCol to = RowCol(row: row - 1, col: col + colOffset);

        // Register the avalanche animation
        _registerAnimation(
            _identities[row][col],
            delay,
            TileAnimation(
                animationType: TileAnimationType.avalanche,
                delay: delay,
                from: from,
                to: to,
                tileType: _types[row][col],
                tile: _tiles[row][col],
            ),
        );

        // Record the cells involved in the animation
        _involvedCells.addAll([from, to]);

        // Adapt _state, _types and _idenditities
        _state[row-1][col + colOffset] = _state[row][col];
        _types[row-1][col + colOffset] = _types[row][col];
        _tiles[row-1][col + colOffset] = _tiles[row][col];
        _identities[row-1][col + colOffset] = _identities[row][col];

        _state[row][col] = 0;
        _types[row][col] = TileType.empty;
        _tiles[row][col] = null;

        // As we are emptying a cell, the latter has no identity
        _identities[row][col] = -1;

        // record the move
        _lastMoves.add(RowCol(row: row-1, col: col + colOffset));

        // Increment the counter of moves
        movesCounter++;
      }
    });

    // As we processed all avalanches related to this column, we can remove them all
    _avalanches[col].clear();

    // Inform that some
    return (movesCounter > 0);
  }

  //
  // Look for all movements (down) that need to happen in a particular column
  //
  //  Returns the longest delay, resulting from moves
  //
  int _processColumn(int col, int startDelay){

      // Retrieve the entry row for this column
      int rowTop = _getEntryRowForColumn(col) + 1;

      // Count the number of moves
      int countMoves = 0;

      // The number of empty cells (resulting from a move)
      int empty = 0;

      // The current delay
      int delay = startDelay;

      // The next destination row for a tile
      int dest = -1;

      // Compute the longest delay related to this column
      int longestDelay = startDelay;

      // Start scanning each row.  No need to check the bottom row since the latter will never move
      for (int row = 0; row < rowTop; row++){
          //
          // Case were the tile is blocked or not existing
          //
          if (_state[row][col] == -1){
              // This one is blocked => skip
              delay = startDelay;

              // No empty cell will be added (as an assumption)
              if (row < (rowTop - 1)){
                empty = 0;
              }

              // We need to reset the destination row
              dest = -1;

              continue;
          }

          //
          // Case where there is no tile
          //
          if (_state[row][col] == 0){
              // There is no tile there, so this will most become the destination if not yet taken
              if (dest == -1){
                  dest = row;
                  delay = startDelay;
              }

              // In all cases, there will be a move which will lead to an empty cell at the top
              empty++;

              continue;
          }

          //
          // Case where there is a tile
          //
          if (_state[row][col] == 1 && dest != -1){
              RowCol from = RowCol(row: row, col: col);
              RowCol to = RowCol(row: dest, col: col);
              
              // There will be an animation (move down)
              _registerAnimation(
                  _identities[row][col],
                  delay,
                  TileAnimation(
                      animationType: TileAnimationType.moveDown,
                      delay: delay,
                      from: from,
                      to: to,
                      tileType: _types[row][col],
                      tile: _tiles[row][col],
                  ),
              );

              // Record the cells involved in the animation
              _involvedCells.addAll([from, to]);

              // ... the delay for the next move
              delay++;

              // Compute the longest delay
              longestDelay = math.max(longestDelay, delay);

              // Let's update the _state and _types at destination (destination will become this _state)
              _state[dest][col] = 1;
              _types[dest][col] = _types[row][col];
              _tiles[dest][col] = _tiles[row][col];

              // record the move
              _lastMoves.add(RowCol(row: dest, col: col));

              // Transfer the identity
              _identities[dest][col] = _identities[row][col];

              // We need to increment the destination
              dest++;

              // ... as we moved this tile down, its former cell is now empty and has no identity
              _state[row][col] = 0;
              _types[row][col] = TileType.empty;
              _tiles[row][col] = null;
              _identities[row][col] = -1;

              // It is time to check for the avalanche effects, which will only occur at the end of the first move
              // (where the tile arrives at destination)
              if (delay == (startDelay + 1)){
                  _avalanches[col].add(
                    AvalancheTest(
                      delay: delay,
                      row: dest,
                    ),
                  );
              }

              // Increment the number of moves
              countMoves++;
          }
      }

      //
      // We now need to fill the column with new tiles (if necessary)
      // This routine is very similar to moving the tiles down
      // Except that we can only do this if the toppest cell of the column
      // if not preventing from adding new tiles
      //
      if (empty > 0){
        int row = _getEntryRowForColumn(col);

        //
        // Only consider the case where there is an entry point
        //
        if (row != -1){
          // Here again, it is time to check for the avalanche effects, which will only occur at the end of the first move

          // In case the destination is not yet known, determine it
          if (dest == -1){
            do {
              dest++;
            } while(_types[dest][col] == TileType.forbidden && _state[dest][col] != 0 && dest < rows);
          }

          // Consider each empty
          for (int i = 0; i < empty; i++){
            TileType newTileType = Tile.random(math.Random());  // Generate a new random tile type
            _state[dest][col] = 1;
            _types[dest][col] = newTileType;
            _tiles[dest][col] = Tile(
                row: row,
                col: col,
                depth: 0,
                level: level,
                type: newTileType,
                visible: true,
              );   // We will build it later
            _tiles[dest][col].build();

            // Generate a new identity
            _identities[dest][col] = _nextIdentity++;

            // Record a new tile injection animation
            RowCol from = RowCol(row: row, col: col);
            RowCol to = RowCol(row: dest, col: col);

            _registerAnimation(
                  _identities[dest][col],
                  delay,
                  TileAnimation(
                      animationType: TileAnimationType.newTile,
                      delay: delay,
                      from: from,
                      to: to,
                      tileType: _types[dest][col],
                      tile: _tiles[dest][col],
                  ),
              );
            // record the move
            _lastMoves.add(to);

            // Record the cells involved in the animation
            _involvedCells.addAll([from, to]);

            // ... a new tile could also cause an avalanche
            if (delay == (startDelay + 1)){
              _avalanches[col].add(
                AvalancheTest(
                  delay: delay,
                  row: dest,
                ),
              );
            }

            // Increment the destination
            dest++;

            // ... and the delay
            delay++;

            // Compute the longest delay
            longestDelay = math.max(longestDelay, delay);

            // Increment the number of moves
            countMoves++;
          }
        }
      }
    return longestDelay;
  }

  //
  // Returns the row that corresponds to an entry for a new tile injection
  // Returns -1 if there is no entry
  //
  int _getEntryRowForColumn(int col){
    int row = rows - 1;

    //
    // First, skip the not existing cells
    //
    while (_types[row][col] == TileType.forbidden){
      row--;
    }

    //
    // Check if the top row allows new tiles injection
    // Warning, new tiles could also cause avalanches...
    //
    return (_types[row][col] == TileType.wall) ? -1 : row;
  }

  //
  // Returns the sequence of animation chains, per identity
  //
  // This is a tricky routine that needs to take several factors into consideration:
  //
  //  * the delay which is very important to have a correct sequence of animations
  //  * the identity which gives the sequence chain
  //
  // This routine returns a list of animations sequences, per identity, sorted per delay start
  //
  List<AnimationSequence> getAnimationsSequences(){
    List<AnimationSequence> sequences = <AnimationSequence>[];

    _animationsPerIdentityAndDelay.keys.forEach((int identity){
      // now that we have an identity, let's put all its animations, sorted by delay
      List<TileAnimation> animations = <TileAnimation>[];
      
      // Let's sort the animations related to a single identity
      List<int> delays = _animationsPerIdentityAndDelay[identity]
                        .keys
                        .toList();
      delays.sort();

      int startDelay = 0;
      int endDelay = 0;
      TileType tileType;
      TileAnimation tileAnimation;
      Tile tile;

      enumerate(delays).forEach((item){
        // Remember that start and end delays as well as the type of tile
        if (item.index == 0){
          startDelay = item.value;
          tileAnimation = _animationsPerIdentityAndDelay[identity][item.value];
          tileType = tileAnimation.tileType;

          // If the tile does not exist, create it
          tile = tileAnimation.tile;
          if (tile == null){
            tile = Tile(
                row: tileAnimation.from.row,
                col: tileAnimation.from.col,
                depth: 0,
                level: level,
                type: tileType,
                visible: true,
              );
            tile.build();
            tileAnimation.tile = tile;
          }
        }
        endDelay = math.max(endDelay, item.value);

        // add the animation
        animations.add(_animationsPerIdentityAndDelay[identity][item.value]);
      });

      // Record the sequence
      sequences.add(AnimationSequence(
        tileType: tileType,
        startDelay: startDelay,
        endDelay: endDelay,
        animations: animations,
      ));
    });

    return sequences;
  }
}

