import 'dart:async';
import 'dart:convert';
import 'package:flutter_crush/bloc/bloc_provider.dart';
import 'package:flutter_crush/controllers/game_controller.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter_crush/model/objective.dart';
import 'package:flutter_crush/model/objective_event.dart';
import 'package:flutter/services.dart';
import 'package:flutter_crush/model/tile.dart';
import 'package:quiver/iterables.dart';
import 'package:rxdart/rxdart.dart';

class GameBloc implements BlocBase {
  // Max number of tiles per row (and per column)
  static double kMaxTilesPerRowAndColumn = 12.0;
  static double kMaxTilesSize = 28.0;

  //
  // Controller that emits a boolean value to trigger the display of the tiles
  // at game load is ready.  This is done as soon as this BLoC receives the
  // dimensions/position of the board as well as the dimensions of a tile
  //
  BehaviorSubject<bool> _readyToDisplayTilesController = BehaviorSubject<bool>();
  Function get setReadyToDisplayTiles => _readyToDisplayTilesController.sink.add;
  Stream<bool> get outReadyToDisplayTiles => _readyToDisplayTilesController.stream;

  //
  // Controller aimed at processing the Objective events
  //
  PublishSubject<ObjectiveEvent> _objectiveEventsController = PublishSubject<ObjectiveEvent>();
  Function get sendObjectiveEvent => _objectiveEventsController.sink.add;
  Stream<ObjectiveEvent> get outObjectiveEvents => _objectiveEventsController.stream;

  //
  // Controller that emits a boolean value to notify that a game is over
  // the boolean value indicates whether the game is won (=true) or lost (=false)
  //
  PublishSubject<bool> _gameIsOverController = PublishSubject<bool>();
  Stream<bool> get gameIsOver => _gameIsOverController.stream;

  //
  // Controller that emits the number of moves left for the game
  //
  PublishSubject<int> _movesLeftController = PublishSubject<int>();
  Stream<int> get movesLeftCount => _movesLeftController.stream;

  //
  // List of all level definitions
  //
  List<Level> _levels = <Level>[];
  int _maxLevel = 0;
  int _levelNumber = 0;
  int get levelNumber => _levelNumber;
  int get numberOfLevels => _maxLevel;

  //
  // The Controller for the Game being played
  //
  GameController _gameController;
  GameController get gameController => _gameController;

  //
  // Constructor
  //
  GameBloc(){
    // Load all levels definitions
    _loadLevels();
  }

  //
  // The user wants to select a level.
  // We validate the level number and emit the requested Level
  //
  // We use the [async] keyword to allow the caller to use a Future
  //
  //  e.g.  bloc.setLevel(1).then(() => )
  //
  Future<Level> setLevel(int levelIndex) async {
    _levelNumber = (levelIndex - 1).clamp(0, _maxLevel);

    //
    // Initialize the Game
    //
    _gameController = GameController(level: _levels[_levelNumber]);

    //
    // Fill the Game with Tile and make sure there are possible Swaps
    //
    _gameController.shuffle();

    return _levels[_levelNumber];
  }

  //
  // Load the levels definitions from assets
  //
  _loadLevels() async {
    String jsonContent = await rootBundle.loadString("assets/levels.json");
    Map<dynamic, dynamic> list = json.decode(jsonContent);
    enumerate(list["levels"] as List).forEach((levelItem){
      _levels.add(Level.fromJson(levelItem.value));
      _maxLevel++;
    });
  }

  //
  // A certain number of tiles have been removed (or created)
  // We need to notify anyone who might be interested in
  // knowing it so that actions can be taken
  //
  void pushTileEvent(TileType tileType, int counter){
    // We first need to decrement the objective by the counter
    Objective objective = gameController.level.objectives.firstWhere((o) => o.type == tileType, orElse: () => null);
    if (objective == null) { return; }

    objective.decrement(counter);

    // Send a notification
    sendObjectiveEvent(ObjectiveEvent(type: tileType, remaining: objective.count));

    // Check if the game is won
    bool isWon = true;
    gameController.level.objectives.forEach((Objective objective){
      if (objective.count > 0){
        isWon = false;
      }
    });

    // If the game is won, send a notification
    if (isWon){
      _gameIsOverController.sink.add(true);
    }
  }

  //
  // A move has been played, let's decrement the number of moves
  // left and check if the game is over
  //
  void playMove(){
    int movesLeft = gameController.level.decrementMove();

    // Emit the number of moves left (to refresh the moves left panel)
    _movesLeftController.sink.add(movesLeft);

    // There is no move left, so inform that the game is over
    if (movesLeft == 0){
      _gameIsOverController.sink.add(false);
    }
  }

  //
  // When a game starts, we need to reset everything
  //
  void reset(){
    gameController.level.resetObjectives();
  }

  @override
  void dispose() {
    _readyToDisplayTilesController?.close();
    _objectiveEventsController?.close();
    _gameIsOverController?.close();
    _movesLeftController?.close();
  }
}