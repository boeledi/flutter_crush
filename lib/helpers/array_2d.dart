import 'package:colorize/colorize.dart';
import 'package:flutter_crush/model/tile.dart';

class Array2d<T> {
  late List<List<T?>> array;
  T? defaultValue;
  late int _width;
  late int _height;

  Array2d(int width, int height, {this.defaultValue}) {
    array = List<List<T?>>.filled(0, [], growable: true);

    this.width = width;
    this.height = height;
  }

  operator [](int x) => array[x];

  set width(int v) {
    _width = v;
    while (array.length > v) array.removeLast();
    while (array.length < v) {
      List<T?> newList = List<T?>.empty(growable: true);
      if (array.length > 0) {
        for (int y = 0; y < array.first.length; y++) newList.add(defaultValue);
      }
      array.add(newList);
    }
  }

  set height(int v) {
    _height = v;
    while (array.first.length > v) {
      for (int x = 0; x < array.length; x++) array[x].removeLast();
    }
    while (array.first.length < v) {
      for (int x = 0; x < array.length; x++) array[x].add(defaultValue);
    }
  }

  int get width => _width;
  int get height => _height;

  //
  // Clone this Array2d
  //
  Array2d<T> clone<T>() {
    Array2d<T> newArray2d = Array2d<T>(_height, _width);

    for (int row = 0; row < _height; row++) {
      for (int col = 0; col < _width; col++) {
        newArray2d[row][col] = array[row][col];
      }
    }

    return newArray2d;
  }
}

String dumpArray2d(Array2d grid, [bool coloredDebug = false]) {
  String string = "";
  for (int row = grid.height; row > 0; row--) {
    List<String> values = <String>[];
    for (int col = 0; col < grid.width; col++) {
      var cell = grid[row - 1][col];
      if (coloredDebug) {
        final Tile? tile = cell == null ? null : (cell as Tile);
        final TileType? tileType = tile?.type;
        Styles? styles;
        String text = ' ';

        switch (tileType) {
          case TileType.red:
            styles = Styles.BG_RED;
            break;
          case TileType.green:
            styles = Styles.BG_GREEN;
            break;
          case TileType.blue:
            styles = Styles.BG_BLUE;
            break;
          case TileType.orange:
            styles = Styles.BG_YELLOW;
            break;
          case TileType.purple:
            styles = Styles.BG_MAGENTA;
            break;
          case TileType.yellow:
            styles = Styles.BG_YELLOW;
            break;
          case TileType.forbidden:
            styles = Styles.BG_BLACK;
            text = 'X';
            break;
          case TileType.empty:
            text = '.';
            break;
          default:
            text = 'X';
            break;
        }
        if (styles != null) {
          values.add(Colorize(text).apply(styles).toString());
        } else {
          values.add(text);
        }
      } else {
        values.add(cell == null ? " " : cell.toString());
      }
    }
    string += (values.join(" | ") + "\n");
  }
  if (coloredDebug) {
    print('================================');
    print(string);
    print('================================');
  }

  return string;
}
