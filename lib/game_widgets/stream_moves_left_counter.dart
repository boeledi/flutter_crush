import 'package:flutter_crush/bloc/bloc_provider.dart';
import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter/material.dart';

///
/// StreamMovesLeftCounter
/// 
/// Displays the number of moves left for the game.
/// Listens to the "movesLeftCount" stream.
///
class StreamMovesLeftCounter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    GameBloc gameBloc = BlocProvider.of<GameBloc>(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const Icon(Icons.swap_horiz, color: Colors.black,),
        SizedBox(width: 8.0),
        StreamBuilder<int>(
          initialData: gameBloc.gameController.level.maxMoves,
          stream: gameBloc.movesLeftCount,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot){
            return Text('${snapshot.data}', style: TextStyle(color: Colors.black, fontSize: 16.0,),);
          }
        ),
      ],
    );
  }
}