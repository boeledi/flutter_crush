import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers/audio_cache.dart';
import 'package:flutter/foundation.dart';

class Audio {
  static AudioCache player = AudioCache();

  //
  // Initialization.  We pre-load all sounds.
  //
  static Future<dynamic> init() async {
    await player.loadAll([
      'audio/swap.wav',
      'audio/move_down.wav',
      'audio/bomb.wav',
      'audio/game_start.wav',
      'audio/win.wav',
      'audio/lost.wav',
    ]);
  }
  static play() async {
    AudioPlayer player = AudioPlayer();
    await player.play('assets/audio/swap.wav', isLocal: true);
  }

  static playAsset(AudioType audioType) {
    player.play('audio/${describeEnum(audioType)}.wav');
  }
}

enum AudioType {
  swap,
  move_down,
  bomb,
  game_start,
  win,
  lost,
}