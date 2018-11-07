import 'package:flutter/material.dart';

class DoubleCurvedContainer extends StatelessWidget {
  DoubleCurvedContainer({
    Key key,
    @required this.width,
    @required this.height,
    @required this.child,
    @required this.outerColor,
    @required this.innerColor,
  }) : super(key: key);

  final double width;
  final double height;
  final Widget child;
  final Color outerColor;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedClipper(),
      child: Container(
        width: width,
        height: 150.0,
        color: Colors.black.withOpacity(0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: ClipPath(
            clipper: _CurvedClipper(),
            child: Container(
              color: outerColor,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ClipPath(
                  clipper: _CurvedClipper(),
                  child: Container(
                    color: innerColor,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double heightStart = size.height / 4.0;
    double heightEnd = size.height - heightStart;

    Path path = Path();

    path.moveTo(0.0, heightStart);
    path.quadraticBezierTo(size.width / 2.0, 0.0, size.width, heightStart);
    path.lineTo(size.width, heightEnd);
    path.quadraticBezierTo(size.width / 2.0, size.height, 0.0, heightEnd);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
