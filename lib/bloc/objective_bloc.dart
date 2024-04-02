import 'dart:async';

import 'package:flutter_crush/bloc/bloc_provider.dart';
import 'package:flutter_crush/model/objective_event.dart';
import 'package:flutter_crush/model/tile.dart';
import 'package:rxdart/rxdart.dart';

class ObjectiveBloc implements BlocBase {
  ///
  /// A stream only meant to return whether THIS objective type is part of the Objective events
  ///
  final BehaviorSubject<int> _objectiveCounterController =
      BehaviorSubject<int>();
  Stream<int> get objectiveCounter => _objectiveCounterController.stream;

  ///
  /// Stream of all the Objective events
  ///
  final StreamController<ObjectiveEvent> _objectivesController =
      StreamController<ObjectiveEvent>();
  Function get sendObjectives => _objectivesController.sink.add;

  ///
  /// Constructor
  ///
  ObjectiveBloc(TileType tileType) {
    //
    // We are listening to all Objective events
    //
    _objectivesController.stream
        // but, we only consider the ones that matches THIS one
        .where((e) => e.type == tileType)
        // if any, we emit the corresponding counter
        .listen((event) => _objectiveCounterController.add(event.remaining));
  }

  @override
  void dispose() {
    _objectivesController.close();
    _objectiveCounterController.close();
  }
}
