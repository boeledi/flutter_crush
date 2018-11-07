import 'package:flutter_crush/game_widgets/double_curved_container.dart';
import 'package:flutter_crush/game_widgets/objective_item.dart';
import 'package:flutter_crush/helpers/audio.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter_crush/model/objective.dart';
import 'package:flutter/material.dart';

class GameSplash extends StatefulWidget {
  GameSplash({
    Key key,
    this.level,
    this.onComplete,
  }) : super(key: key);

  final Level level;
  final VoidCallback onComplete;

  @override
  _GameSplashState createState() => _GameSplashState();
}

class _GameSplashState extends State<GameSplash>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _animationAppear;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: 4),
      vsync: this,
    )
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          if (widget.onComplete != null) {
            widget.onComplete();
          }
        }
      });

    _animationAppear = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          0.0,
          0.1,
          curve: Curves.easeIn,
        ),
      ),
    );

    // Play the intro
    Audio.playAsset(AudioType.game_start);

    // Launch the animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;

    //
    // Build the objectives
    //
    List<Widget> objectiveWidgets =
        widget.level.objectives.map((Objective obj) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ObjectiveItem(objective: obj, level: widget.level),
      );
    }).toList();

    return AnimatedBuilder(
      animation: _animationAppear,
      child: Material(
        color: Colors.transparent,
        child: DoubleCurvedContainer(
          width: screenSize.width,
          height: 150.0,
          outerColor: Colors.blue[700],
          innerColor: Colors.blue,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                    child: Text(
                  'Level:  ${widget.level.index}',
                  style: TextStyle(fontSize: 24.0, color: Colors.white),
                )),
                SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: objectiveWidgets,
                ),
              ],
            ),
          ),
        ),
      ),
      builder: (BuildContext context, Widget child) {
        return Positioned(
          left: 0.0,
          top: 150.0 + 100.0 * _animationAppear.value,
          child: child,
        );
      },
    );
  }
}
