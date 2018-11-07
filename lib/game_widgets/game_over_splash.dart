import 'package:flutter_crush/game_widgets/double_curved_container.dart';
import 'package:flutter_crush/helpers/audio.dart';
import 'package:flutter_crush/model/level.dart';
import 'package:flutter/material.dart';

class GameOverSplash extends StatefulWidget {
  GameOverSplash({
    Key key,
    this.success,
    this.level,
    this.onComplete,
  }) : super(key: key);

  final Level level;
  final VoidCallback onComplete;
  final bool success;

  @override
  _GameOverSplashState createState() => _GameOverSplashState();
}

class _GameOverSplashState extends State<GameOverSplash>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;
  Animation<double> _animationAppear;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(seconds: 3),
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

    Color darkColor = widget.success ? Colors.green[700] : Colors.red[700];
    Color lightColor = widget.success ? Colors.green : Colors.red;
    String message = widget.success ? "You Win" : "Game Over";

    return AnimatedBuilder(
      animation: _animationAppear,
      child: Material(
        color: Colors.transparent,
        child: DoubleCurvedContainer(
          width: screenSize.width,
          height: 150.0,
          outerColor: darkColor,
          innerColor: lightColor,
          child: Container(
            color: lightColor,
            child: Center(
              child: Text(message,
                  style: TextStyle(
                    fontSize: 50.0,
                    color: Colors.white,
                  )),
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
