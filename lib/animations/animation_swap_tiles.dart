import 'package:flutter_crush/model/tile.dart';
import 'package:flutter/material.dart';

class AnimationSwapTiles extends StatefulWidget {
  AnimationSwapTiles({
    Key key,
    this.upTile,
    this.downTile,
    this.onComplete,
    this.swapAllowed,
  }): super(key: key);

  final Tile upTile;
  final Tile downTile;
  final VoidCallback onComplete;
  final bool swapAllowed;

  @override
  _AnimationSwapTilesState createState() => _AnimationSwapTilesState();
}

class _AnimationSwapTilesState extends State<AnimationSwapTiles> with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState(){
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    )..addListener(() {
      setState(() {});
    })..addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        if (!widget.swapAllowed){
          _controller.reverse();
        } else {
          if (widget.onComplete != null) {
            widget.onComplete();
          }
        }
      }

      if (status == AnimationStatus.dismissed){
          if (widget.onComplete != null) {
            widget.onComplete();
          }
      }
    });

    _controller.forward();
  }

  @override
  void dispose(){
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double deltaX = widget.upTile.x - widget.downTile.x;
    final double deltaY = widget.upTile.y - widget.downTile.y;

    return Stack(
      children: <Widget>[
        Positioned(
          left: widget.downTile.x + deltaX * _controller.value,
          top: widget.downTile.y + deltaY * _controller.value,
          child: widget.downTile.widget,
        ),
        Positioned(
          left: widget.upTile.x - deltaX * _controller.value,
          top: widget.upTile.y - deltaY * _controller.value,
          child: widget.upTile.widget,
        ),
      ],
    );
  }
}