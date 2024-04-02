import 'package:flutter/material.dart';

typedef BlocBuilder<T> = T Function();

abstract class BlocBase {
  void dispose();
}

///
/// BlocProvider
///
/// Usage:
///
/// BlocProvider<T>(
///   blocBuilder: () => Bloc(),
///   blocDispose: (T bloc) { bloc?.dispose();},
///   child:
/// )
///
/// Arguments:
///
///   [blocBuilder] Compulsory.
///   Function which is only called ONCE and requests to provide the instance of the BLoC
///   The instance of the BLoC can be initiazed at the level of this function or could
///   have been initialized somewhere else.
///
///   [child] Compulsory.
///   The Widget, child of this BlocProvider.
///
class BlocProvider<T> extends StatefulWidget {
  const BlocProvider({
    super.key,
    required this.child,
    required this.bloc,
  });

  final Widget child;
  final T bloc;

  @override
  State<BlocProvider<T>> createState() => BlocProviderState<T>();

  static BlocProviderInherited<T>? of<T>(BuildContext context,
      {bool listen = false}) {
    final InheritedElement? inheritedElement = context
        .getElementForInheritedWidgetOfExactType<BlocProviderInherited<T>>();
    if (inheritedElement == null) {
      return null;
    }

    if (listen == true) {
      ///
      /// If we are listening to changes to rebuild,
      /// let's register the context in the list of the ones
      /// to be rebuilt
      ///
      context.dependOnInheritedWidgetOfExactType<BlocProviderInherited<T>>();
    }

    final BlocProviderInherited<T>? provider =
        inheritedElement.widget as BlocProviderInherited<T>?;

    return provider;
  }
}

class BlocProviderState<T> extends State<BlocProvider<T>> {
  late T bloc;
  late T previousBloc;

  @override
  void initState() {
    super.initState();
    previousBloc = widget.bloc;
    bloc = widget.bloc;
  }

  void updateValue(T newBloc) {
    previousBloc = bloc;
    bloc = newBloc;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProviderInherited<T>(
      bloc: bloc,
      state: this,
      child: widget.child,
    );
  }
}

class BlocProviderInherited<T> extends InheritedWidget {
  const BlocProviderInherited({
    Key? key,
    required Widget child,
    required this.bloc,
    required this.state,
  }) : super(key: key, child: child);

  final T bloc;
  final BlocProviderState<T> state;

  @override
  bool updateShouldNotify(BlocProviderInherited<T> oldWidget) {
    return oldWidget.bloc != bloc;
  }
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
///     blocBuilder: () => A(),
///     child: BlocProvider<B>(
///       blocBuilder: () => B(),
///       child: BlocProvider<C>(
///         blocBuilder: () => C(),
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
typedef BlocBuildWithChild = BlocProvider Function(Widget child);

Widget blocsTree(
  List<BlocBuildWithChild> childlessBlocs, {
  required Widget child,
}) {
  return childlessBlocs.reversed.fold<Widget>(
    child,
    (Widget nextChild, BlocBuildWithChild childlessBloc) =>
        childlessBloc(nextChild),
  );
}

BlocBuildWithChild blocTreeNode<T>(T bloc) =>
    (Widget child) => BlocProvider<T>(bloc: bloc, child: child);

typedef BlocWhenCallback<T> = Widget? Function(T oldValue, T value);

extension BlocProviderContex on BuildContext {
  /// -------------------------------------------------------
  /// Replacement
  ///     T? bloc = BlocProvider.of<T>(context)?.bloc
  /// =>  T? bloc = context.blocRead<T>();
  ///
  ///  => No rebuild if bloc changes
  /// -------------------------------------------------------
  T? blocRead<T>() {
    return BlocProvider.of<T>(this, listen: false)?.bloc;
  }

  /// -------------------------------------------------------
  /// Replacement
  ///     T? bloc = BlocProvider.of<T>(context, listen: true)?.bloc
  /// =>  T? bloc = context.blocWatch<T>();
  ///
  /// => Rebuilds if bloc changes
  /// -------------------------------------------------------
  T? blocWatch<T>() {
    return BlocProvider.of<T>(this, listen: true)?.bloc;
  }

  /// -------------------------------------------------------
  /// Helper that simplifies the emitting of a new "value"
  ///     Rather than writing BlocProvider.of<T>(context, listen: false)?.state.updateValue(newValue);
  /// =>  context.blocUpdateValue<T>(newValue);
  ///
  /// WARNING: newValue MUST BE a NEW instance of T
  /// -------------------------------------------------------
  void blocUpdate<T>(T newValue) {
    BlocProvider.of<T>(this, listen: false)?.state.updateValue(newValue);
  }

  /// -------------------------------------------------------
  /// Listens to variations of T and gets both "old" and "new"
  /// values
  ///
  /// -------------------------------------------------------
  Widget? blocWhen<T>(BlocWhenCallback<T> callback, {bool listen = true}) {
    final BlocProviderInherited<T>? provider =
        BlocProvider.of<T>(this, listen: listen);
    if (provider != null) {
      return callback(
        provider.state.previousBloc,
        provider.state.bloc,
      );
    }
    return null;
  }
}
