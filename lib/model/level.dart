import 'package:flutter_crush/helpers/array_2d.dart';
import 'package:flutter_crush/model/objective.dart';
import 'package:quiver/iterables.dart';

///
/// Level
/// 
/// Definition of a level in terms of:
///  - grid template
///  - maximum number of moves
///  - number of columns
///  - number of rows
///  - list of objectives
///
class Level extends Object {
  final int _index;
  Array2d grid;
  final int _rows;
  final int _cols;
  List<Objective> _objectives;
  final int _maxMoves;
  int _movesLeft;

  //
  // Variables that depend on the physical layout of the device
  //
  double tileWidth = 0.0;
  double tileHeight = 0.0;
  double boardLeft = 0.0;
  double boardTop = 0.0;

  Level.fromJson(Map<String, dynamic> json)
    : _index = json["level"],
      _rows = json["rows"],
      _cols = json["cols"],
      _maxMoves = json["moves"]
    {
      // Initialize the grid to the dimensions
      grid = Array2d(_rows, _cols);

      // Populate the grid from the definition
        //
        // Trick
        //  As the definition in the JSON file defines the 
        //  rows (top-down) and also because we are recording
        //  the grid (bottom-up), we need to reverse the
        //  definition from the JSON file.
        //
      enumerate((json["grid"] as List).reversed).forEach((row){
        enumerate(row.value.split(',')).forEach((cell){
          grid[row.index][cell.index] = cell.value;
        });
      });

      // Retrieve the objectives
      _objectives = (json["objective"] as List).map((item){
        return Objective(item);
      }).toList();

      // First-time initialization
      resetObjectives();
  }

  @override
  String toString(){
    return "level: $index \n" + dumpArray2d(grid);
  }

  int get numberOfRows => _rows;
  int get numberOfCols => _cols;
  int get index => _index;
  int get maxMoves => _maxMoves;
  int get movesLeft => _movesLeft;
  List<Objective> get objectives => List.unmodifiable(_objectives);

  //
  // Reset the objectives
  //
  void resetObjectives(){
    _objectives.forEach((Objective objective) => objective.reset());
    _movesLeft = _maxMoves;
  }

  //
  // Decrement the number of moves left
  //
  int decrementMove(){
    return (--_movesLeft).clamp(0, _maxMoves);
  }
}