import 'package:flutter_crush/bloc/game_bloc.dart';
import 'package:flutter_crush/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Application extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StatefulProvider<GameBloc>(
      valueBuilder: (BuildContext context, GameBloc old) => old ?? GameBloc(),
      onDispose: (BuildContext context, GameBloc bloc) {
        bloc?.dispose();
      },
      child: MaterialApp(
        title: 'Flutter Crush',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: HomePage(),
      ),
    );
  }
}
