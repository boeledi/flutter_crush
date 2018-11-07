import 'package:flutter/material.dart';

class GameLevelButton extends StatelessWidget {
  GameLevelButton({
    Key key,
    this.text: '',
    this.width: 60.0,
    this.height: 60.0,
    this.borderRadius: 50.0,
    @required this.onTap,
  }) : super(key: key);

  final String text;
  final VoidCallback onTap;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    LinearGradient gradient = LinearGradient(
      begin: Alignment.topCenter, // new
      end: Alignment.bottomCenter, // new
      // Add one stop for each color.
      // Stops should increase
      // from 0 to 1
      stops: [0.1, 0.5, 0.7, 0.9],
      colors: [
        // Colors are easy thanks to Flutter's
        // Colors class.
        Colors.white,
        Colors.grey[100],
        Colors.grey[200],
        Colors.grey[300],
      ],
    );

    return InkWell(
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(
            top: 50.0,
          ),
          child: Container(
            padding: const EdgeInsets.all(3.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: 0.3,
                color: Colors.black38,
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10.0,
                  offset: Offset(5.0, 5.0),
                  color: Color.fromRGBO(0, 0, 0, 0.3),
                ),
              ],
              gradient: gradient,
            ),
            width: width,
            height: height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  width: 0.3,
                  color: Colors.black26,
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 1.0,
                    offset: Offset(1.0, 1.5),
                    color: Color.fromRGBO(0, 0, 0, 0.3),
                  ),
                ],
                gradient: gradient,
              ),
              child: Center(
                child: Text(
                  text,
                  style: TextStyle(color: Colors.black, fontSize: 16.0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
