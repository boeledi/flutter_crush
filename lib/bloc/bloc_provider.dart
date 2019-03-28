import 'package:flutter/material.dart';

Type _typeOf<T>() => T;

abstract class BlocBase {
  void dispose();
}

class BlocProvider<T extends BlocBase> extends StatefulWidget {
  BlocProvider({
    Key key,
    @required this.child,
    @required this.bloc,
  }): super(key: key);

  final Widget child;
  final T bloc;

  @override
  _BlocProviderState<T> createState() => _BlocProviderState<T>();

  static T of<T extends BlocBase>(BuildContext context){
    final type = _typeOf<_BlocProviderInherited<T>>();
    _BlocProviderInherited<T> provider = context.ancestorInheritedElementForWidgetOfExactType(type)?.widget;
    return provider?.bloc;
  }
}

class _BlocProviderState<T extends BlocBase> extends State<BlocProvider<T>>{
  @override
  void dispose(){
    widget.bloc?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context){
    return new _BlocProviderInherited<T>(
      bloc: widget.bloc,
      child: widget.child,
    );
  }
}

class _BlocProviderInherited<T> extends InheritedWidget {
  _BlocProviderInherited({
    Key key,
    @required Widget child,
    @required this.bloc,
  }) : super(key: key, child: child);

  final T bloc;

  @override
  bool updateShouldNotify(_BlocProviderInherited oldWidget) => true;
}

/// -------------------------------------------------------------------
/// HELPERS
/// -------------------------------------------------------------------

/// -------------------------------------------------------------------
///  Allows to define a series of embedded blocs
/// 
///  Rather than writing:
/// 
///   BlocProvider<A>(
///     bloc: A(),
///     child: BlocProvider<B>(
///       bloc: B(),
///       child: BlocProvider<C>(
///         bloc: C(),
///         child: Container(),
///       ),
///     ),
///   )
/// 
///  We can write:
/// 
///   blocsTree(
///     [
///       blocTreeNode<A>(A()),
///       blocTreeNode<B>(B()),
///       blocTreeNode<C>(C()),
///     ],
///     child: Container(),
///   ),
/// 
///   This is much easier to read and to complement.
/// -------------------------------------------------------------------
typedef BlocProvider _BuildWithChild(Widget child);

Widget blocsTree(
  List<_BuildWithChild> childlessBlocs, {
  @required Widget child,
}) {
  return childlessBlocs.reversed.fold<Widget>(
    child,
    (Widget nextChild, _BuildWithChild childlessBloc) => childlessBloc(nextChild),
  );
}

_BuildWithChild blocTreeNode<T extends BlocBase>(T bloc) =>
    (Widget child) => BlocProvider<T>(bloc: bloc, child: child);