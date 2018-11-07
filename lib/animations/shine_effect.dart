import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShineEffect extends StatefulWidget {
  ShineEffect({
    Key key,
    this.offset: Offset.zero,
  }) : super(key: key);

  final Offset offset;

  @override
  _ShineEffectState createState() => _ShineEffectState();
}

class _ShineEffectState extends State<ShineEffect>
    with SingleTickerProviderStateMixin {
  AnimationController _shineController;

  @override
  void initState() {
    super.initState();

    //
    // Shine effect
    //
    _shineController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..addListener(() {
            setState(() {});
          })
          ..repeat();
  }

  @override
  void dispose() {
    _shineController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            Positioned(
                left: _shineController.value *
                        (constraints.maxHeight + widget.offset.dx * 2.0) -
                    widget.offset.dx,
                top: -widget.offset.dy / 2.0,
                child: Opacity(
                  opacity: 0.3,
                  child: Transform.rotate(
                    angle: 45.0 * math.pi / 180.0,
                    child: Container(
                      width: 50.0,
                      height: 350.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0.6),
                              Colors.white.withOpacity(0.4),
                              Colors.white.withOpacity(0.2),
                            ],
                            stops: [
                              0.1,
                              0.3,
                              0.5,
                              0.7,
                              0.9,
                            ]),
                      ),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
