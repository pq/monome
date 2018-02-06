import 'package:osc/osc.dart';

/// A grid.
class Grid {
  final List<Column> _column;

  /// Number of columns.
  final int columns;

  /// Number of rows.
  final int rows;

  /// Create a grid with [rows] rows and [columns] columns.
  Grid({this.rows: 8, this.columns: 16})
      : _column = new List.generate(columns, (_) => new Column(rows),
            growable: false);

  /// Run the given [cmd].
  void run(GridCommand cmd) {
    cmd.runOn(this);
  }

  /// Returns the column at the given [index] or throws a [RangeError] if
  /// [index] is out of bounds.
  Column operator [](int index) => _column[index];

  @override
  String toString() {
    final sb = new StringBuffer();

    final pad = 3;
    final edge = '${new List.filled(columns * pad, '-').join()}\n';
    sb.write(edge);

    for (var y = 0; y < rows; ++y) {
      for (var x = 0; x < columns; ++x) {
        sb.write('${this[x][y]}'.padLeft(pad));
        if (x + 1 >= columns) {
          sb.write('\n');
        }
      }
    }
    sb.write(edge);

    return sb.toString();
  }
}

/// A grid column.
class Column {
  final List<int> _values;

  Column(int n) : _values = new List.filled(n, 0, growable: false);

  /// Returns the column value at the given [index] or throws a [RangeError] if
  /// [index] is out of bounds.
  int operator [](int index) => _values[index];

  /// Sets the value at the given [index] in the column to [value]
  /// or throws a [RangeError] if [index] is out of bounds.
  void operator []=(int index, int value) {
    _values[index] = value;
  }

  /// Returns the number of leds in this column.
  int get length => _values.length;

  /// Sets the values in the range [start] inclusive to [end] exclusive
  /// to the given [fillValue].
  ///
  /// The provide range, given by [start] and [end], must be valid.
  /// A range from [start] to [end] is valid if `0 <= start <= end <= len`,
  /// where `len` is this column's `length`. The range starts at `start` and has
  /// length `end - start`. An empty range (with `end == start`) is valid.
  void fillRange(int start, int end, [int fillValue]) {
    _values.fillRange(start, end, fillValue);
  }
}

/// Abstract grid command.
abstract class GridCommand {
  void runOn(Grid grid);

  static GridCommand fromOSC(OSCMessage message) =>
      new OSCMessageParser(message).parse();
}

class OSCMessageParser {
  OSCMessage message;
  OSCMessageParser(this.message);

  GridCommand parse() {
    final address = message.address;
    switch (address) {
      case '/grid/led/level/set':
        return parseSet();
      case '/grid/led/level/all':
        return parseSetAll();
      case '/grid/led/level/row':
        return parseSetRow();
      case '/grid/led/level/col':
        return parseSetCol();
      case '/grid/led/level/map':
        return parseMap();
    }
    throw new ParseError('Unrecognized command: $address');
  }

  List<Object> get arguments => message.arguments;

  GridCommand parseSet() {
    assertArgs(3);
    var x = argToInt(0);
    var y = argToInt(1);
    var level = argToInt(2);
    return new SetCommand(x, y, level);
  }

  GridCommand parseSetAll() {
    assertArgs(1);
    var level = argToInt(0);
    return new SetAllCommand(level);
  }

  GridCommand parseSetRow() {
    if (arguments.length < 3) {
      throw new ParseError(
          'invalid arguments for row set, expected: `x_off y l[..]`, got: $arguments');
    }
    var x = argToInt(0);
    var y = argToInt(1);
    var levels = argToIntOctet(2);
    return new SetRowCommand(x, y, levels);
  }

  GridCommand parseSetCol() {
    if (arguments.length < 3) {
      throw new ParseError(
          'invalid arguments for col set, expected: `x y_off l[..]`, got: $arguments');
    }
    var x = argToInt(0);
    var yOffset = argToInt(1);
    var levels = argToIntOctet(2);
    return new SetColCommand(x, yOffset, levels);
  }

  GridCommand parseMap() {
    if (arguments.length < 3) {
      throw new ParseError(
          'invalid arguments for col set, expected: `x_off y_off l[64]`, got: $arguments');
    }
    var xOffset = argToInt(0);
    var yOffset = argToInt(1);
    var levels = argToIntQuad(2);
    return new MapCommand(xOffset, yOffset, levels);
  }

  int argToInt(int index) => toInt(arguments[index]);

  int toInt(Object argument) {
    if (argument is! int) {
      throw new ParseError('expected int, got: ${toTypeString(argument)}');
    }
    return argument;
  }

  List<int> argToIntOctet(int index) {
    final remaining = arguments.length - index;
    if (remaining % 8 != 0) {
      throw new ParseError('expected multiple of 8 values, got: $remaining}');
    }

    var octet = <int>[remaining];
    for (var value in arguments.sublist(index)) {
      octet.add(toInt(value));
    }

    return octet;
  }

  List<int> argToIntQuad(int index) {
    final remaining = arguments.length - index;
    if (remaining != 64) {
      throw new ParseError('expected quad (64) of values, got: $remaining}');
    }

    var octet = <int>[remaining];
    for (var value in arguments.sublist(index)) {
      octet.add(toInt(value));
    }

    return octet;
  }

  String toTypeString(Object argument) =>
      argument == null ? 'null' : argument.runtimeType.toString();

  void assertArgs(int length) {
    if (arguments.length != length) {
      throw new ParseError(
          'expected $length arguments, got: ${arguments.length}');
    }
  }
}

/// Thrown in case of parse error.
class ParseError extends Error {
  Object detail;

  ParseError(this.detail);

  @override
  String toString() => 'Parse Error: ${Error.safeToString(detail)}';
}

/// Set the value of a single led.
///
/// `/grid/led/level/set x y l`
class SetCommand extends GridCommand {
  final int x, y, level;

  /// Set led at ([x],[y]) to [level] in the range [0, 15].
  SetCommand(this.x, this.y, this.level);

  @override
  void runOn(Grid grid) {
    grid[x][y] = level;
  }
}

/// Set the value of all the leds in a single message.
///
/// `/grid/led/level/all l`
///
class SetAllCommand extends GridCommand {
  final int level;

  /// Set all leds to [level] in the range [0, 15].
  SetAllCommand(this.level);

  @override
  void runOn(Grid grid) {
    for (var col in grid._column) {
      col.fillRange(0, col.length, level);
    }
  }
}

/// Set a row in a quad in a single message.
///
/// `/grid/led/level/row x_off y l[..]`
///
class SetRowCommand extends GridCommand {
  final int xOffset, y;
  final List<int> level;

  /// Set values in row [y] from an offset [xOffset] (a multiple of 8) to
  /// [level] where [level] contains a multiple of 8 values in the range
  /// [0, 15].
  SetRowCommand(this.xOffset, this.y, this.level);

  @override
  void runOn(Grid grid) {
    for (var i = 0; i < level.length; ++i) {
      grid[i + xOffset][y] = level[i];
    }
  }
}

/// Set a column in a quad in a single message.
///
/// `/grid/led/level/col x y_off l[..]`
class SetColCommand extends GridCommand {
  final int x, yOffset;
  final List<int> level;

  /// Set values in column [x] from an offset [yOffset] (a multiple of 8) to
  /// [level] where [level] contains a multiple of 8 values in the range
  /// [0, 15].
  SetColCommand(this.x, this.yOffset, this.level);

  @override
  void runOn(Grid grid) {
    grid._column[x]._values.setRange(yOffset, yOffset + level.length, level);
  }
}

/// Set a quad (8×8, 64 buttons) in a single message.
///
/// `/grid/led/level/map x_off y_off l[64]`
///
class MapCommand extends GridCommand {
  final int xOffset, yOffset;
  final List<int> level;

  /// Set quad [level] of values at offset ([xOffset], [yOffset]) where [level]
  /// contains 64 values in the range [0, 15].
  MapCommand(this.xOffset, this.yOffset, this.level);

  @override
  void runOn(Grid grid) {
    var index = 0;
    for (var y = 0; y < 8; ++y) {
      for (var x = 0; x < 8; ++x) {
        grid[x][y] = level[index++];
      }
    }
  }
}
