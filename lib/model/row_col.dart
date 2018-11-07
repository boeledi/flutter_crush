///
/// RowCol
///
/// Contains the position of a cell, in terms of row and col
/// 
class RowCol extends Object {
  int row;
  int col;

  RowCol({
    this.row,
    this.col,
  });

  @override
  bool operator==(dynamic other) => identical(this, other) || this.hashCode == other.hashCode;

  @override
  int get hashCode => row * 1000 + col;
  
  @override
  String toString(){
    return '[$row][$col]';
  }
}