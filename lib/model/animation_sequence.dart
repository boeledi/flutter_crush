import 'package:flutter_crush/model/tile.dart';
import 'package:flutter_crush/model/tile_animation.dart';

///
/// AnimationSequence
///
class AnimationSequence {
  // Range of time for this sequence of animations
  int startDelay;
  int endDelay;

  // Type of tile in the sequence of animations
  TileType tileType;

  // List of all animations, part of the sequence
  List<TileAnimation> animations;

  // Constructor
  AnimationSequence({
    this.tileType,
    this.startDelay,
    this.endDelay,
    this.animations,
  });
}