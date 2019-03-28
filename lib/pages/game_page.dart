import 'dart:async';

import 'package:flutter_crush/animations/animation_chain.dart';
import 'package:flutter_crush/animations/animation_combo_collapse.dart';
import 'package:flutter_crush/animations/animation_combo_three.dart';
import 'package:flutter_crush/animations/animation_swap_tiles.dart';
import 'package:flutter_crush/bloc/bloc_provider.dart';
import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter_crush/game_widgets/board.dart';
import 'package:flutter_crush/game_widgets/game_moves_left_panel.dart';
import 'package:flutter_crush/game_widgets/game_over_splash.dart';
import 'package:flutter_crush/game_widgets/game_splash.dart';
import 'package:flutter_crush/game_widgets/objective_panel.dart';
import 'package:flutter_crush/game_widgets/shadowed_text.dart';
import 'package:flutter_crush/helpers/animations_resolver.dart';
import 'package:flutter_crush/helpers/array_2d.dart';
import 'package:flutter_crush/helpers/audio.dart';
import 'package:flutter_crush/model/animation_sequence.dart';
import 'package:flutter_crush/model/combo.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter_crush/model/row_col.dart';
import 'package:flutter_crush/model/tile.dart';
import 'package:flutter/material.dart';

class GamePage extends StatefulWidget {
  static Route<dynamic> route(Level level) {
    return MaterialPageRoute(
        builder: (BuildContext context) => GamePage(level: level));
  }

  final Level level;

  GamePage({
    Key key,
    this.level,
  }) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  OverlayEntry _gameSplash;
  GameBloc gameBloc;
  bool _allowGesture;
  StreamSubscription _gameOverSubscription;
  bool _gameOverReceived;

  Tile gestureFromTile;
  RowCol gestureFromRowCol;
  Offset gestureOffsetStart;
  bool gestureStarted;
  static const double _MIN_GESTURE_DELTA = 2.0;
  OverlayEntry _overlayEntryFromTile;
  OverlayEntry _overlayEntryAnimateSwapTiles;

  @override
  void initState() {
    super.initState();
    _gameOverReceived = false;
    WidgetsBinding.instance.addPostFrameCallback(_showGameStartSplash);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Now that the context is available, retrieve the gameBloc
    gameBloc = BlocProvider.of<GameBloc>(context);

    // Reset the objectives
    gameBloc.reset();

    // Listen to "game over" notification
    _gameOverSubscription = gameBloc.gameIsOver.listen(_onGameOver);
  }

  @override
  void dispose() {
    _gameOverSubscription?.cancel();
    _gameOverSubscription = null;
    _overlayEntryAnimateSwapTiles?.remove();
    _overlayEntryFromTile?.remove();
    _gameSplash?.remove();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Orientation orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.close),
        onPressed: () {
          Navigator.of(context).pop();
        },
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/background.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: GestureDetector(
          onPanDown: (DragDownDetails details) => _onPanDown(details),
          onPanStart: _onPanStart,
          onPanEnd: _onPanEnd,
          onPanUpdate: (DragUpdateDetails details) => _onPanUpdate(details),
          onTap: _onTap,
          onTapUp: _onPanEnd,
          child: Stack(
            children: <Widget>[
              _buildAuthor(),
              _buildMovesLeftPanel(orientation),
              _buildObjectivePanel(orientation),
              _buildBoard(),
              _buildTiles(),
            ],
          ),
        ),
      ),
    );
  }

  //
  // Puts the author text
  //
  Widget _buildAuthor() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ShadowedText(
          text: 'by Didier Boelens',
          color: Colors.white,
          fontSize: 12.0,
          offset: Offset(1.0, 1.0),
        ),
      ),
    );
  }

  //
  // Builds the score panel
  //
  Widget _buildMovesLeftPanel(Orientation orientation) {
    Alignment alignment = orientation == Orientation.portrait
        ? Alignment.topLeft
        : Alignment.topLeft;

    return Align(
      alignment: alignment,
      child: GameMovesLeftPanel(),
    );
  }

  //
  // Builds the objective panel
  //
  Widget _buildObjectivePanel(Orientation orientation) {
    Alignment alignment = orientation == Orientation.portrait
        ? Alignment.topRight
        : Alignment.bottomLeft;

    return Align(
      alignment: alignment,
      child: ObjectivePanel(),
    );
  }

  //
  // Builds the game board
  //
  Widget _buildBoard() {
    return Align(
      alignment: Alignment.center,
      child: Board(
        rows: widget.level.numberOfRows,
        cols: widget.level.numberOfCols,
        level: widget.level,
      ),
    );
  }

  //
  // Builds the tiles
  //
  Widget _buildTiles() {
    return StreamBuilder<bool>(
      stream: gameBloc.outReadyToDisplayTiles,
      initialData: null,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (snapshot.data != null && snapshot.hasData) {
          List<Widget> tiles = <Widget>[];
          Array2d<Tile> grid = gameBloc.gameController.grid;

          for (int row = 0; row < widget.level.numberOfRows; row++) {
            for (int col = 0; col < widget.level.numberOfCols; col++) {
              final Tile tile = grid[row][col];
              if (tile.type != TileType.empty &&
                  tile.type != TileType.forbidden &&
                  tile.visible) {
                //
                // Make sure the widget is correctly positioned
                //
                tile.setPosition();
                tiles.add(Positioned(
                  left: tile.x,
                  top: tile.y,
                  child: tile.widget,
                ));
              }
            }
          }

          return Stack(
            children: tiles,
          );
        }
        // If nothing is ready, simply return an empty container
        return Container();
      },
    );
  }

  //
  // Gesture
  //

  RowCol _rowColFromGlobalPosition(Offset globalPosition) {
    final double top = globalPosition.dy - widget.level.boardTop;
    final double left = globalPosition.dx - widget.level.boardLeft;
    return RowCol(
      col: (left / widget.level.tileWidth).floor(),
      row: widget.level.numberOfRows -
          (top / widget.level.tileHeight).floor() -
          1,
    );
  }

  //
  // The pointer touches the screen
  //
  void _onPanDown(DragDownDetails details) {
    if (!_allowGesture) return;

    // Determine the [row,col] from touch position
    RowCol rowCol = _rowColFromGlobalPosition(details.globalPosition);

    // Ignore if we touched outside the grid
    if (rowCol.row < 0 ||
        rowCol.row >= widget.level.numberOfRows ||
        rowCol.col < 0 ||
        rowCol.col >= widget.level.numberOfCols) return;

    // Check if the [row,col] corresponds to a possible swap
    Tile selectedTile = gameBloc.gameController.grid[rowCol.row][rowCol.col];
    bool canBePlayed = false;

    // Reset
    gestureFromTile = null;
    gestureStarted = false;
    gestureOffsetStart = null;
    gestureFromRowCol = null;

    if (selectedTile != null) {
      //TODO: Condition no longer necessary
      canBePlayed = selectedTile.canMove;
    }

    if (canBePlayed) {
      gestureFromTile = selectedTile;
      gestureFromRowCol = rowCol;

      //
      // Let's position the tile on the Overlay and inflate it a bit to make it more visible
      //
      _overlayEntryFromTile = OverlayEntry(
          opaque: false,
          builder: (BuildContext context) {
            return Positioned(
              left: gestureFromTile.x,
              top: gestureFromTile.y,
              child: Transform.scale(
                scale: 1.1,
                child: gestureFromTile.widget,
              ),
            );
          });
      Overlay.of(context).insert(_overlayEntryFromTile);
    }
  }

  //
  // The pointer starts to move
  //
  void _onPanStart(DragStartDetails details) {
    if (!_allowGesture) return;
    if (gestureFromTile != null) {
      gestureStarted = true;
      gestureOffsetStart = details.globalPosition;
    }
  }

  //
  // The user releases the pointer from the screen
  //
  void _onPanEnd(_) {
    if (!_allowGesture) return;

    gestureStarted = false;
    gestureOffsetStart = null;
    _overlayEntryFromTile?.remove();
    _overlayEntryFromTile = null;
  }

  //
  // The pointer has been moved since its last "start"
  //
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_allowGesture) return;

    if (gestureStarted) {
      // Try to determine the move type (up, down, left, right)
      Offset delta = details.globalPosition - gestureOffsetStart;
      int deltaRow = 0;
      int deltaCol = 0;
      bool test = false;
      if (delta.dx.abs() > delta.dy.abs() &&
          delta.dx.abs() > _MIN_GESTURE_DELTA) {
        // horizontal move
        deltaCol = delta.dx.floor().sign;
        test = true;
      } else if (delta.dy.abs() > _MIN_GESTURE_DELTA) {
        // vertical move
        deltaRow = -delta.dy.floor().sign;
        test = true;
      }

      if (test == true) {
        RowCol rowCol = RowCol(
            row: gestureFromRowCol.row + deltaRow,
            col: gestureFromRowCol.col + deltaCol);
        if (rowCol.col < 0 ||
            rowCol.col == widget.level.numberOfCols ||
            rowCol.row < 0 ||
            rowCol.row == widget.level.numberOfRows) {
          // Not possible, outside the boundaries
        } else {
          Tile destTile = gameBloc.gameController.grid[rowCol.row][rowCol.col];
          bool canBePlayed = false;

          if (destTile != null) {
            //TODO:  Condition no longer necessary
            canBePlayed = destTile.canMove || destTile.type == TileType.empty;
          }

          if (canBePlayed) {
            // We need to test the swap
            bool swapAllowed =
                gameBloc.gameController.swapContains(gestureFromTile, destTile);

            // Do not allow the gesture recognition during the animation
            _allowGesture = false;

            // 1. Remove the expanded tile
            _overlayEntryFromTile?.remove();
            _overlayEntryFromTile = null;

            // 2. Generate the up/down tiles
            Tile upTile = gestureFromTile.cloneForAnimation();
            Tile downTile = destTile.cloneForAnimation();

            // 3. Remove both tiles from the game grid
            gameBloc.gameController.grid[rowCol.row][rowCol.col].visible =
                false;
            gameBloc
                .gameController
                .grid[gestureFromRowCol.row][gestureFromRowCol.col]
                .visible = false;

            setState(() {});

            // 4. Animate both tiles
            _overlayEntryAnimateSwapTiles = OverlayEntry(
                opaque: false,
                builder: (BuildContext context) {
                  return AnimationSwapTiles(
                    upTile: upTile,
                    downTile: downTile,
                    swapAllowed: swapAllowed,
                    onComplete: () async {
                      // 5. Put back the tiles in the game grid
                      gameBloc.gameController.grid[rowCol.row][rowCol.col]
                          .visible = true;
                      gameBloc
                          .gameController
                          .grid[gestureFromRowCol.row][gestureFromRowCol.col]
                          .visible = true;

                      // 6. Remove the overlay Entry
                      _overlayEntryAnimateSwapTiles?.remove();
                      _overlayEntryAnimateSwapTiles = null;

                      if (swapAllowed == true) {
                        // Remember if the tile we move is a bomb
                        bool isSourceTileABomb =
                            Tile.isBomb(gestureFromTile.type);

                        // Swap the 2 tiles
                        gameBloc.gameController
                            .swapTiles(gestureFromTile, destTile);

                        // Get the tiles that need to be removed, following the swap
                        // We need to get the tiles from all possible combos
                        Combo comboOne = gameBloc.gameController
                            .getCombo(gestureFromTile.row, gestureFromTile.col);
                        Combo comboTwo = gameBloc.gameController
                            .getCombo(destTile.row, destTile.col);

                        // Wait for both animations to complete
                        await Future.wait(
                            [_animateCombo(comboOne), _animateCombo(comboTwo)]);

                        // Resolve the combos
                        gameBloc.gameController
                            .resolveCombo(comboOne, gameBloc);
                        gameBloc.gameController
                            .resolveCombo(comboTwo, gameBloc);

                        // If the tile we moved is a bomb, we need to process the explosion
                        if (isSourceTileABomb) {
                          gameBloc.gameController.proceedWithExplosion(
                              Tile(
                                  row: destTile.row,
                                  col: destTile.row,
                                  type: gestureFromTile.type),
                              gameBloc);
                        }

                        // Proceed with the falling tiles
                        await _playAllAnimations();

                        // Once this is all done, we need to recalculate all the possible swaps
                        gameBloc.gameController.identifySwaps();

                        // Record the fact that we have played a move
                        gameBloc.playMove();
                      }

                      // 7. Reset
                      _allowGesture = true;
                      _onPanEnd(null);
                      setState(() {});
                    },
                  );
                });
            Overlay.of(context).insert(_overlayEntryAnimateSwapTiles);
          }
        }
      }
    }
  }

  //
  // The user tap on a tile, is this a bomb ?
  // If yes make it explode
  //
  void _onTap() {
    if (!_allowGesture) return;
    if (gestureFromTile != null && Tile.isBomb(gestureFromTile.type)) {
      // Prevent the user from playing during the animation
      _allowGesture = false;

      // Play explosion
      Audio.playAsset(AudioType.bomb);

      // Proceed with explosion
      gameBloc.gameController.proceedWithExplosion(gestureFromTile, gameBloc);

      // Rebuild the board and proceed with animations
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        // Proceed with the falling tiles
        await _playAllAnimations();

        // Once this is all done, we need to recalculate all the possible swaps
        gameBloc.gameController.identifySwaps();

        // The user may now play
        _allowGesture = true;

        // Record the fact that we have played a move
        gameBloc.playMove();
      });
    }
  }

  //
  // Show/hide the tiles related to a Combo.
  // This is used just before starting an animation
  //
  void _showComboTilesForAnimation(Combo combo, bool visible) {
    combo.tiles.forEach((Tile tile) => tile.visible = visible);
    setState(() {});
  }

  //
  // Launch an Animation which returns a Future when completed
  //
  Future<dynamic> _animateCombo(Combo combo) async {
    var completer = Completer();
    OverlayEntry overlayEntry;

    switch (combo.type) {
      case ComboType.three:
        // Hide the tiles before starting the animation
        _showComboTilesForAnimation(combo, false);

        // Launch the animation for a chain of 3 tiles
        overlayEntry = OverlayEntry(
          opaque: false,
          builder: (BuildContext context) {
            return AnimationComboThree(
              combo: combo,
              onComplete: () {
                overlayEntry?.remove();
                overlayEntry = null;
                completer.complete(null);
              },
            );
          },
        );

        // Play sound
        await Audio.playAsset(AudioType.move_down);

        Overlay.of(context).insert(overlayEntry);
        break;

      case ComboType.none:
      case ComboType.one:
      case ComboType.two:
        // These type of combos are not possible, therefore directly return
        completer.complete(null);
        break;

      default:
        // Hide the tiles before starting the animation
        _showComboTilesForAnimation(combo, false);

        // We need to create the resulting tile
        Tile resultingTile = Tile(
          col: combo.commonTile.col,
          row: combo.commonTile.row,
          type: combo.resultingTileType,
          level: widget.level,
          depth: 0,
        );
        resultingTile.build();

        // Launch the animation for a chain more than 3 tiles
        overlayEntry = OverlayEntry(
          opaque: false,
          builder: (BuildContext context) {
            return AnimationComboCollapse(
              combo: combo,
              resultingTile: resultingTile,
              onComplete: () {
                resultingTile = null;
                overlayEntry?.remove();
                overlayEntry = null;

                completer.complete(null);
              },
            );
          },
        );

        // Play sound
        await Audio.playAsset(AudioType.swap);

        Overlay.of(context).insert(overlayEntry);
        break;
    }
    return completer.future;
  }

  //
  // Routine that launches all animations, resulting from a combo
  //
  Future<dynamic> _playAllAnimations() async {
    var completer = Completer();

    //
    // Determine all animations (and sequence of animations) that
    // need to be played as a consequence of a combo
    //
    AnimationsResolver animationResolver =
        AnimationsResolver(gameBloc: gameBloc, level: widget.level);
    animationResolver.resolve();

    // Determine the list of cells that are involved in the animation(s)
    // and make them invisible
    if (animationResolver.involvedCells.length == 0) {
      // At first glance, there is no animations... so directly return
      completer.complete(null);
    }

    // Obtain the animation sequences
    List<AnimationSequence> sequences =
        animationResolver.getAnimationsSequences();
    int pendingSequences = sequences.length;

    // Make all involved cells invisible
    animationResolver.involvedCells.forEach((RowCol rowCol) {
      gameBloc.gameController.grid[rowCol.row][rowCol.col].visible = false;
    });

    // Make a refresh of the board and the end of which we will play the animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      //
      // As the board is now refreshed, it is time to start playing
      // all the animations
      //
      List<OverlayEntry> overlayEntries = <OverlayEntry>[];

      sequences.forEach((AnimationSequence animationSequence) {
        //
        // Prepare all the animations at once.
        // This is important to avoid having multiple rebuild
        // when we are going to put them all on the Overlay
        //
        overlayEntries.add(
          OverlayEntry(
            opaque: false,
            builder: (BuildContext context) {
              return AnimationChain(
                level: widget.level,
                animationSequence: animationSequence,
                onComplete: () {
                  // Decrement the number of pending animations
                  pendingSequences--;

                  //
                  // When all have finished, we need to "rebuild" the board,
                  // refresh the screen and yied the hand back
                  //
                  if (pendingSequences == 0) {
                    // Remove all OverlayEntries
                    overlayEntries.forEach((OverlayEntry entry) {
                      entry?.remove();
                      entry = null;
                    });

                    gameBloc.gameController.refreshGridAfterAnimations(
                        animationResolver.resultingGridInTermsOfTileTypes,
                        animationResolver.involvedCells);

                    // We now need to proceed with a final rebuild and yield the hand
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Finally, yield the hand
                      completer.complete(null);
                    });

                    setState(() {});
                  }
                },
              );
            },
          ),
        );
      });
      Overlay.of(context).insertAll(overlayEntries);
    });

    setState(() {});

    return completer.future;
  }

  //
  // The game is over
  //
  // We need to show the adequate splash (win/lost)
  //
  void _onGameOver(bool success) async {
    // Prevent from bubbling
    if (_gameOverReceived) {
      return;
    }
    _gameOverReceived = true;

    // Since some animations could still be ongoing, let's wait a bit
    // before showing the user that the game is won
    await Future.delayed(const Duration(seconds: 1));

    // No gesture detection during the splash
    _allowGesture = false;

    // Show the splash
    _gameSplash = OverlayEntry(
        opaque: false,
        builder: (BuildContext context) {
          return GameOverSplash(
            success: success,
            level: widget.level,
            onComplete: () {
              _gameSplash.remove();
              _gameSplash = null;

              // as the game is over, let's leave the game
              Navigator.of(context).pop();
            },
          );
        });

    Overlay.of(context).insert(_gameSplash);
  }

  //
  // SplashScreen to be displayed when the game starts
  // to show the user the objectives
  //
  void _showGameStartSplash(_) {
    // No gesture detection during the splash
    _allowGesture = false;

    // Show the splash
    _gameSplash = OverlayEntry(
        opaque: false,
        builder: (BuildContext context) {
          return GameSplash(
            level: widget.level,
            onComplete: () {
              _gameSplash.remove();
              _gameSplash = null;

              // allow gesture detection
              _allowGesture = true;
            },
          );
        });

    Overlay.of(context).insert(_gameSplash);
  }
}
