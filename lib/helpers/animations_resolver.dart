// ignore_for_file: unused_local_variable

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
  late GameController gameController;
  late int rows;
  late int cols;

  AnimationsResolver({
    required this.gameBloc,
    required this.level,
  }) {
    rows = level.numberOfRows;
    cols = level.numberOfCols;
    gameController = gameBloc.gameController;
  }

  // _state contains the states of the grid after each move
  // 0:  empty cell (no tiles)
  // -1: forbidden (no cell or not movable tile)
  // 1:  tile is present
  late Array2d<CellState> _state;
  //Array2d<int> get resultingGridInTermsOfUse => _state;

  // _type contains the types of tiles in the grid after each move
  late Array2d<TileType> _types;
  Array2d<TileType> get resultingGridInTermsOfTileTypes => _types;

  // _tiles contains the definitions of the tiles (type, depth, widget)
  late Array2d<Tile> _tiles;
  Array2d<Tile> get resultingGridInTermsOfTiles => _tiles;

  // _names contains the tiles identities
  // Identities are important since animations will be played in sequence
  // for a same identity
  late Array2d<int> _identities;
  int _nextIdentity = 0;

  // _avalanches contains a list of possible avalanches per column
  late List<List<AvalancheTest>> _avalanches;

  // List of all animations, per identity and per delay
  late Map<int, Map<int, TileAnimation>> _animationsPerIdentityAndDelay;
  late Map<int, List<int>> _animationsIdentitiesPerDelay;

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
  void _registerAnimation(int identity, int delay, TileAnimation animation) {
    // First register per identity, then per delay
    if (_animationsPerIdentityAndDelay[identity] == null) {
      _animationsPerIdentityAndDelay[identity] = Map<int, TileAnimation>();
    }

    _animationsPerIdentityAndDelay[identity]![delay] = animation;

    // Then the list of identities per delay
    if (_animationsIdentitiesPerDelay[delay] == null) {
      _animationsIdentitiesPerDelay[delay] = <int>[];
    }
    _animationsIdentitiesPerDelay[delay]!.add(identity);
  }

  void resolve() {
//Stopwatch stopwatch = new Stopwatch()..start();
    //
    // Fill both arrays based on the current definition
    //
    _state = Array2d<CellState>(rows, cols);
    _types = Array2d<TileType>(rows, cols);
    _tiles = Array2d<Tile>(rows, cols);
    _identities = Array2d<int>(rows, cols);
    _nextIdentity = 0;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        if (level.grid[row][col] == "X") {
          _state[row][col] = CellState.forbidden;
          _types[row][col] = TileType.forbidden;
          _tiles[row][col] = null;
        } else {
          Tile tile = gameController.grid[row][col];
          if (tile.type == TileType.empty) {
            _state[row][col] = CellState.empty;
            _types[row][col] = TileType.empty;
          } else if (tile.canMove) {
            _state[row][col] = CellState.occupied;
            _types[row][col] = tile.type;
          } else {
            _state[row][col] = CellState.forbidden;
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
    bool loopBasedOnAvalanche;

    do {
      do {
//  print('Before Combos');
//  dumpArray2d(_tiles, true);
        //
        // Check for combos
        //
        delay = _resolveCombos(delay);
//  print('After Combos');
//  dumpArray2d(_tiles, true);
        //
        // Once the combos have been resolved,
        // look for the moves
        //
        continueLoop = false;

        //
        // Process all the columns
        //
        _lastMoves.clear();

        for (int column = 0; column < cols; column++) {
          // Start by processing the avalanches
          bool somethingHappens = _processAvalanches(column, delay);

          // Then process the moves inside a column
          int newDelay = _processColumn(column, delay);
          somethingHappens |= (newDelay != delay);

          // If something happens, we need to continue
          if (somethingHappens) {
            // Compute the longest delay
            longestDelay = math.max(longestDelay, newDelay);

            // As something happened, we need to continue looping
            continueLoop = true;
          }
        }

        // Adapt the delay to the longest one
        delay = longestDelay;
      } while (continueLoop);

      // Once we have resolved everything (straightforward), we still
      // need to consider all the remaining holes and see if we could not
      // consider an avalanche

      loopBasedOnAvalanche = false;

      int newDelay = _postAvalanches(delay);
      if (newDelay != delay) {
        // yes, some post avalanche(s) is(are) possible
        // Compute the longest delay
        longestDelay = math.max(longestDelay, newDelay);

        // As something happened, we need to continue looping
        loopBasedOnAvalanche = true;
      }
    } while (loopBasedOnAvalanche);
// print('executed in ${stopwatch.elapsed}');
  }

  //
  // Post-Avalanches
  //
  int _postAvalanches(int startDelay) {
    int newDelay = startDelay;
    bool leaveLoops = false;

    for (int row = 0; row < rows - 1 && !leaveLoops; row++) {
      for (int col = 0; col < cols && !leaveLoops; col++) {
        if (_state[row][col] == CellState.empty) {
          // This cell is empty.  Is there an available occupied cell that could fill this one ?
          final bool leftCol = (col > 0);
          final bool rightCol = (col < cols - 1);
          RowCol? from;

          if (leftCol && _state[row + 1][col - 1] == CellState.occupied) {
            // There is an available cell on the top-left hand of this cell
            from = RowCol(row: row + 1, col: col - 1);
          } else if (rightCol &&
              _state[row + 1][col + 1] == CellState.occupied) {
            // There is an available cell on the top-right hand of this cell
            from = RowCol(row: row + 1, col: col + 1);
          }

          if (from != null) {
            // Register the avalanche animation
            Tile newTile = Tile.clone(_tiles[from.row][from.col]);
            RowCol to = RowCol(row: row, col: col);

            _registerAnimation(
              _identities[from.row][from.col],
              newDelay,
              TileAnimation(
                animationType: TileAnimationType.avalanche,
                delay: newDelay,
                from: from,
                to: to,
                tileType: _types[from.row][from.col],
                tile: _tiles[from.row][from.col],
              ),
            );

            // Register the last move
            _lastMoves.add(to);

            // We now need to re-align the post-avalanche status
            newTile.row = row;
            newTile.col = col;
            newTile.build();
//print('Before post-avalanche: $from');
//dumpArray2d(_tiles, true);

            _tiles[row][col] = newTile;
            _state[row][col] = CellState.occupied;
            _types[row][col] = newTile.type;

            _tiles[from.row][from.col] = null;
            _state[from.row][from.col] = CellState.empty;
            _types[from.row][from.col] = TileType.empty;

            // increase the next delay
            newDelay += 10;

//print('After post-avalanche');
//dumpArray2d(_tiles, true);

            // Leave all the loops
            leaveLoops = true;
          }
        }
      }
    }

    return newDelay;
  }

  //
  // Resolves any potential combos
  //
  int _resolveCombos(int startDelay) {
    int delay = startDelay;
    bool hasCombo = false;
    ChainHelper chainHelper = ChainHelper();

    _lastMoves.forEach((RowCol rowCol) {
//print('Combo: testing: $rowCol');
      Chain? verticalChain =
          chainHelper.checkVerticalChain(rowCol.row, rowCol.col, _tiles);
      Chain? horizontalChain =
          chainHelper.checkHorizontalChain(rowCol.row, rowCol.col, _tiles);

      // Check if there is a combo
      Combo combo =
          Combo(horizontalChain, verticalChain, rowCol.row, rowCol.col);
      if (combo.type != ComboType.none) {
        // We found a combo.  We therefore need to take appropriate actions
        TileAnimationType animationType;
        RowCol? from;
        RowCol? to;

        // Recall that there is at least one combo
        hasCombo = true;

        if (combo.type == ComboType.three) {
          animationType = TileAnimationType.chain;
        } else {
          animationType = TileAnimationType.collapse;

          if (combo.commonTile == null) {
            // We assume the common tile is the one, present at current location
            to = RowCol(row: rowCol.row, col: rowCol.col);
          } else {
            // When we are collapsing, the tiles move to the position of the commonTile
            to = RowCol(row: combo.commonTile!.row, col: combo.commonTile!.col);
          }
        }

        // We need to register the animations (combo)
        combo.tiles.forEach((Tile tile) {
          from = RowCol(row: tile.row, col: tile.col);

          if (to != null) {
            _registerAnimation(
              _identities[tile.row][tile.col],
              delay,
              TileAnimation(
                animationType: animationType,
                delay: delay,
                from: from!,
                to: to,
                tile: _tiles[tile.row][tile.col]!,
              ),
            );
          }

          // Record the cells involved in the animation
          _involvedCells.add(from!);

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
        combo.tiles.forEach((Tile tile) {
          if (tile != combo.commonTile) {
            _state[tile.row][tile.col] = CellState.empty;
            _types[tile.row][tile.col] = TileType.empty;
            _tiles[tile.row][tile.col] = null;

            // Transfer the identity
            _identities[tile.row][tile.col] = -1;
          } else {
            _state[tile.row][tile.col] = CellState.occupied;
            _types[tile.row][tile.col] = combo.resultingTileType;
            (_tiles[tile.row][tile.col] as Tile).type =
                combo.resultingTileType!;
            (_tiles[tile.row][tile.col] as Tile).build();
          }
        });

// print('After Combo resolution: ${combo.type}');
// dumpArray2d(_tiles, true);
      }
    });

    // If there is at least one combo,
    // wait for the combo to play before going any further
    // with the other animations
    return delay + (hasCombo ? 30 : 0);
  }

  //
  // Counts the number of "holes" (= empty cells) in a column
  // starting at a certain row
  //
  int _countNumberOfHolesAtColumStartingAtRow(int col, int row) {
    int count = 0;

    while (row > 0 &&
        _state[row][col] == CellState.empty &&
        _types[row][col] != TileType.forbidden) {
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
  bool _processAvalanches(int col, int delay) {
    // Counter of moves caused by an avalanche effect
    int movesCounter = 0;

    final bool leftCol = (col > 0);
    final bool rightCol = (col < cols - 1);

    // Let's process all cases
    _avalanches[col].forEach((AvalancheTest avalancheTest) {
      final int row = avalancheTest.row;

      // Count the number of "holes" on the left-hand side column
      final leftColHoles = leftCol
          ? _countNumberOfHolesAtColumStartingAtRow(col - 1, row - 1)
          : 0;

      // Count the number of "holes" on the right-hand side column
      final rightColHoles = rightCol
          ? _countNumberOfHolesAtColumStartingAtRow(col + 1, row - 1)
          : 0;
      int colOffset = 0;

      // Check if there is a hole.  If yes, the deeper wins
      if (leftColHoles + rightColHoles > 0) {
        colOffset = (leftColHoles > rightColHoles) ? -1 : (rightCol ? 1 : 0);
      }

      // If there is a hole, slide the tile to the corresponding column
      if (colOffset != 0) {
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
        _state[row - 1][col + colOffset] = _state[row][col];
        _types[row - 1][col + colOffset] = _types[row][col];
        _tiles[row - 1][col + colOffset] = _tiles[row][col];
        _tiles[row - 1][col + colOffset]?.row = row - 1;

        _identities[row - 1][col + colOffset] = _identities[row][col];

        _state[row][col] = CellState.empty;
        _types[row][col] = TileType.empty;
        _tiles[row][col] = null;

        // As we are emptying a cell, the latter has no identity
        _identities[row][col] = -1;

        // record the move
        _lastMoves.add(RowCol(row: row - 1, col: col + colOffset));

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
  int _processColumn(int col, int startDelay) {
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
    for (int row = 0; row < rowTop; row++) {
      //
      // Case were the tile is blocked or not existing
      //
      if (_state[row][col] == CellState.forbidden) {
        // This one is blocked => skip
        delay = startDelay;

        // No empty cell will be added (as an assumption)
        if (row < (rowTop - 1)) {
          empty = 0;
        }

        // We need to reset the destination row
        dest = -1;

        continue;
      }

      //
      // Case where there is no tile
      //
      if (_state[row][col] == CellState.empty) {
        // There is no tile there, so this will most become the destination if not yet taken
        if (dest == -1) {
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
      if (_state[row][col] == CellState.occupied && dest != -1) {
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
        _state[dest][col] = CellState.occupied;
        _types[dest][col] = _types[row][col];
        _tiles[dest][col] = Tile.clone(_tiles[row][col]);
        _tiles[dest][col].row = dest;

        // record the move
        _lastMoves.add(to);

        // Transfer the identity
        _identities[dest][col] = _identities[row][col];

        // We need to increment the destination
        dest++;

        // ... as we moved this tile down, its former cell is now empty and has no identity
        _state[row][col] = CellState.empty;
        _types[row][col] = TileType.empty;
        _tiles[row][col] = null;
        _identities[row][col] = -1;

        // It is time to check for the avalanche effects, which will only occur at the end of the first move
        // (where the tile arrives at destination)
        if (delay == (startDelay + 1)) {
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
    if (empty > 0) {
      int row = _getEntryRowForColumn(col);

      //
      // Only consider the case where there is an entry point
      //
      if (row != -1) {
        // Here again, it is time to check for the avalanche effects, which will only occur at the end of the first move

        // In case the destination is not yet known, determine it
        if (dest == -1) {
          do {
            dest++;
          } while (_types[dest][col] == TileType.forbidden &&
              _state[dest][col] != CellState.empty &&
              dest < rows);
        }

        TileType? previousInsertedTileType;

        // Consider each empty
        for (int i = 0; i < empty; i++) {
          TileType? newTileType;

          // Make sure not to inject a direct combo
          while (
              newTileType == null || newTileType == previousInsertedTileType) {
            newTileType =
                Tile.random(math.Random()); // Generate a new random tile type
          }
          previousInsertedTileType = newTileType;

          _state[dest][col] = CellState.occupied;
          _types[dest][col] = newTileType;
          _tiles[dest][col] = Tile(
            row: row,
            col: col,
            depth: 0,
            level: level,
            type: newTileType,
            visible: true,
          ); // We will build it later
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
              tileType: newTileType,
              tile: _tiles[dest][col],
            ),
          );
          // record the move
          _lastMoves.add(to);

          // re-align the row
          _tiles[dest][col].row = dest;

          // Record the cells involved in the animation
          _involvedCells.addAll([from, to]);

          // ... a new tile could also cause an avalanche
          if (delay == (startDelay + 1)) {
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
  int _getEntryRowForColumn(int col) {
    int row = rows - 1;

    //
    // First, skip the not existing cells
    //
    while (_types[row][col] == TileType.forbidden) {
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
  List<AnimationSequence> getAnimationsSequences() {
    List<AnimationSequence> sequences = <AnimationSequence>[];

    _animationsPerIdentityAndDelay.keys.forEach((int identity) {
      // now that we have an identity, let's put all its animations, sorted by delay
      List<TileAnimation> animations = <TileAnimation>[];

      // Let's sort the animations related to a single identity
      List<int> delays =
          _animationsPerIdentityAndDelay[identity]!.keys.toList();
      delays.sort();

      int startDelay = 0;
      int endDelay = 0;
      TileType? tileType;
      TileAnimation tileAnimation;
      Tile? tile;

      enumerate(delays).forEach((item) {
        // Remember that start and end delays as well as the type of tile
        if (item.index == 0) {
          startDelay = item.value;
          tileAnimation =
              _animationsPerIdentityAndDelay[identity]![item.value]!;
          tileType = tileAnimation.tileType;

          // If the tile does not exist, create it
          tile = tileAnimation.tile;
          if (tile == null) {
            tile = Tile(
              row: tileAnimation.from.row,
              col: tileAnimation.from.col,
              depth: 0,
              level: level,
              type: tileType,
              visible: true,
            );
            tile!.build();
            tileAnimation.tile = tile!;
          }
        }
        endDelay = math.max(endDelay, item.value);

        // add the animation
        animations.add(_animationsPerIdentityAndDelay[identity]![item.value]!);
      });

      // Record the sequence
      sequences.add(AnimationSequence(
        tileType: tileType!,
        startDelay: startDelay,
        endDelay: endDelay,
        animations: animations,
      ));
    });

    return sequences;
  }
}

enum CellState {
  forbidden,
  empty,
  occupied,
}
