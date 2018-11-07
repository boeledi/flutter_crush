
import 'package:flutter_crush/application.dart';
import 'package:flutter_crush/helpers/audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  //
  // Initialize the audio
  //
  await Audio.init();

  //
  // Remove the status bar
  //
  SystemChrome.setEnabledSystemUIOverlays([]);

  return runApp(
    Application(),
  );
}