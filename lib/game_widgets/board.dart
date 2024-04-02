import 'dart:math' as math;
import 'package:flutter_crush/bloc/bloc_provider.dart';
import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter_crush/helpers/array_2d.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter/material.dart';

class Board extends StatefulWidget {
  Board({
    Key? key,
    required this.cols,
    required this.rows,
    required this.level,
  }) : super(key: key);

  final int rows;
  final int cols;
  final Level level;

  @override
  _BoardState createState() => _BoardState();
}

class _BoardState extends State<Board> {
  Array2d<BoxDecoration>? _decorations;
  Array2d<Color>? _checker;
  GlobalKey _keyChecker = GlobalKey();
  GlobalKey _keyCheckerCell = GlobalKey();
  late GameBloc gameBloc;

  void _buildDecorations() {
    if (_decorations != null) return;

    _decorations = Array2d<BoxDecoration>(widget.cols + 1, widget.rows + 1);

    for (int row = 0; row <= widget.rows; row++) {
      for (int col = 0; col <= widget.cols; col++) {
        // If there is nothing at (row, col) => no decoration
        int topLeft = 0;
        int bottomLeft = 0;
        int topRight = 0;
        int bottomRight = 0;
        BoxDecoration? boxDecoration;

        if (col > 0) {
          if (row < widget.rows) {
            if (widget.level.grid[row][col - 1] != 'X') {
              topLeft = 1;
            }
          }
          if (row > 0) {
            if (widget.level.grid[row - 1][col - 1] != 'X') {
              bottomLeft = 1;
            }
          }
        }

        if (col < widget.cols) {
          if (row < widget.rows) {
            if (widget.level.grid[row][col] != 'X') {
              topRight = 1;
            }
          }
          if (row > 0) {
            if (widget.level.grid[row - 1][col] != 'X') {
              bottomRight = 1;
            }
          }
        }

        int value = topLeft;
        value |= (topRight << 1);
        value |= (bottomLeft << 2);
        value |= (bottomRight << 3);

        if (value != 0 && value != 6 && value != 9) {
          boxDecoration = BoxDecoration(
            image: DecorationImage(
                image: AssetImage('assets/images/borders/border_$value.png'),
                fit: BoxFit.cover),
          );
        }
        _decorations![row][col] = boxDecoration;
      }
    }
  }

  void _buildChecker() {
    if (_checker != null) return;

    _checker = Array2d<Color>(widget.rows, widget.cols);
    int counter = 0;

    for (int row = 0; row < widget.rows; row++) {
      counter = (row % 2 == 1) ? 0 : 1;
      for (int col = 0; col < widget.cols; col++) {
        final double opacity = ((counter + col) % 2 == 1) ? 0.3 : 0.1;

        Color color = (widget.level.grid[row][col] == 'X')
            ? Colors.transparent
            : Colors.white.withOpacity(opacity);

        _checker![row][col] = color;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    gameBloc = BlocProvider.of<GameBloc>(context)!.bloc;
    final Size screenSize = MediaQuery.of(context).size;
    final double maxDimension = math.min(screenSize.width, screenSize.height);
    final double maxTileWidth = math.min(
        maxDimension / GameBloc.kMaxTilesPerRowAndColumn,
        GameBloc.kMaxTilesSize);

    WidgetsBinding.instance.addPostFrameCallback((_) => _afterBuild());

    // As the GridView.builder builds top to bottom
    // and we need to compute the decorations bottom up
    // we need to do it at first
    _buildDecorations();
    _buildChecker();

    //
    // Dimensions of the board
    //
    final double width = maxTileWidth * (widget.cols + 1) * 1.1;
    final double height = maxTileWidth * (widget.rows + 1) * 1.1;

    return Container(
      padding: const EdgeInsets.all(0.0),
      width: width,
      height: height,
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          _showDecorations(maxTileWidth),
          _showGrid(maxTileWidth,
              gameBloc), // We pass the gameBloc since we will need to use it to pass the dimensions and coordinates
        ],
      ),
    );
  }

  Widget _showDecorations(double width) {
    return GridView.builder(
      padding: const EdgeInsets.all(0.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.cols + 1,
        childAspectRatio: 1.01,
      ),
      itemCount: (widget.cols + 1) * (widget.rows + 1),
      itemBuilder: (BuildContext context, int index) {
        final int col = index % (widget.cols + 1);
        final int row = (index / (widget.cols + 1)).floor();

        //
        // Use the decoration from bottom up during this build
        //
        return Container(decoration: _decorations![widget.rows - row][col]);
      },
    );
  }

  Widget _showGrid(double width, GameBloc gameBloc) {
    bool isFirst = true;

    return Padding(
      padding: EdgeInsets.all(width * 0.6),
      child: GridView.builder(
        key: _keyChecker,
        padding: const EdgeInsets.all(0.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: widget.cols,
          childAspectRatio: 1.01, // 1.01 solves an issue with floating numbers
        ),
        itemCount: widget.cols * widget.rows,
        itemBuilder: (BuildContext context, int index) {
          final int col = index % widget.cols;
          final int row = (index / widget.cols).floor();

          return Container(
            color: _checker![widget.rows - row - 1][col],
            child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              if (isFirst) {
                isFirst = false;
                return Container(key: _keyCheckerCell);
              }
              return Container();
            }),
          );
        },
      ),
    );
  }

  Rect _getDimensionsFromContext(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;

    final Offset topLeft = box.size.topLeft(box.localToGlobal(Offset.zero));
    final Offset bottomRight =
        box.size.bottomRight(box.localToGlobal(Offset.zero));
    return Rect.fromLTRB(
        topLeft.dx, topLeft.dy, bottomRight.dx, bottomRight.dy);
  }

  void _afterBuild() {
    //
    // Let's get the dimensions and position of the exact position of the board
    //
    if (_keyChecker.currentContext != null) {
      final Rect rectBoard =
          _getDimensionsFromContext(_keyChecker.currentContext!);

      //
      // Save the position of the board
      //
      widget.level.boardLeft = rectBoard.left;
      widget.level.boardTop = rectBoard.top;

      //
      // Let's get the dimensions of one cell of the board
      //
      final Rect rectBoardSquare =
          _getDimensionsFromContext(_keyCheckerCell.currentContext!);

      //
      // Save it for later reuse
      //
      widget.level.tileWidth = rectBoardSquare.width;
      widget.level.tileHeight = rectBoardSquare.height;

      //
      // Send a notification to inform that we are ready to display the tiles from now on
      //
      gameBloc.setReadyToDisplayTiles(true);
    }
  }
}
