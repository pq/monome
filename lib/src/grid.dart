import 'package:osc/osc.dart';

/// A grid.
class Grid {
  final List<Column> _column;

  /// Number of columns.
  final int columns;

  /// Number of rows.
  final int rows;

  /// Create a grid with [rows] rows and [columns] columns.
  Grid({this.rows = 8, this.columns = 16})
      : _column = List.generate(columns, (_) => Column(rows), growable: false);

  /// Run the given [cmd].
  void run(GridCommand cmd) {
    cmd.runOn(this);
  }

  /// Returns the column at the given [index] or throws a [RangeError] if
  /// [index] is out of bounds.
  Column operator [](int index) => _column[index];

  @override
  String toString() {
    final sb = StringBuffer();

    final pad = 3;
    final edge = '${List.filled(columns * pad, '-').join()}\n';
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

  Column(int n) : _values = List.filled(n, 0, growable: false);

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

/// A command that when run changes the state of a grid.
abstract class GridCommand {
  void runOn(Grid grid);

  static GridCommand fromOSC(OSCMessage message, {String prefix}) =>
      OSCMessageParser(message, prefix: prefix).parse();

  int _toLevel(int state) => state == 1 ? 15 : 0;
}

/// An event produced by a device.
abstract class DeviceEvent {
  final String command;

  const DeviceEvent(this.command);

  factory DeviceEvent.keyDown(int x, int y) => KeyEvent(x, y, 1);

  factory DeviceEvent.keyUp(int x, int y) => KeyEvent(x, y, 0);

  /// Event arguments (for use in producing OSC messages).
  List<Object> get _args;

  /// Convert this event to an OSC message, with an optional [prefix].
  OSCMessage toOSC({String prefix}) =>
      OSCMessage(_prefix(command, prefix: prefix), arguments: _args);

  String _prefix(String command, {String prefix}) => '${prefix ?? ""}$command';
}

/// Device key state change.
///
/// `/grid/key x y s`
class KeyEvent extends DeviceEvent {
  /// Key coordinates.
  final int x, y;

  /// Key state (1: down, 0: up).
  final int state;

  /// Key state change at ([x],[y]) to [state] (0 or 1, 1 = key down,
  /// 0 = key up).
  const KeyEvent(this.x, this.y, this.state) : super('/grid/key');

  @override
  String toString() => '$command $x $y $state';

  @override
  List<Object> get _args => <int>[x, y, state];
}

class ConnectEvent extends DeviceEvent {
  ConnectEvent() : super('/sys/connect');

  @override
  List<Object> get _args => [];
}

class OSCMessageParser {
  final OSCMessage message;
  final String prefix;
  OSCMessageParser(this.message, {this.prefix});

  GridCommand parse() {
    final address = _applyPrefix();
    switch (address) {
      case '/grid/led/set':
        return parseStateSet();
      case '/grid/led/level/set':
        return parseLevelSet();
      case '/grid/led/all':
        return parseStateSetAll();
      case '/grid/led/level/all':
        return parseSetAll();
      case '/grid/led/level/row':
        return parseSetRow();
      case '/grid/led/level/col':
        return parseSetCol();
      case '/grid/led/level/map':
        return parseMap();
    }
    throw ParseError('Unrecognized command: $address');
  }

  String _applyPrefix() {
    var address = message.address;
    if (prefix != null && address.startsWith(prefix)) {
      address = address.substring(prefix.length);
    }
    return address;
  }

  List<Object> get arguments => message.arguments;

  GridCommand parseLevelSet() {
    assertArgs(3);
    final x = argToInt(0);
    final y = argToInt(1);
    final level = argToInt(2);
    return LevelSetCommand(x, y, level);
  }

  GridCommand parseStateSet() {
    assertArgs(3);
    final x = argToInt(0);
    final y = argToInt(1);
    final state = argToInt(2);
    return StateSetCommand(x, y, state);
  }

  GridCommand parseSetAll() {
    assertArgs(1);
    final level = argToInt(0);
    return LevelSetAllCommand(level);
  }

  GridCommand parseStateSetAll() {
    assertArgs(1);
    final state = argToInt(0);
    return StateSetAllCommand(state);
  }

  GridCommand parseSetRow() {
    if (arguments.length < 3) {
      throw ParseError(
          'invalid arguments for row set, expected: `x_off y l[..]`, got: $arguments');
    }
    final x = argToInt(0);
    final y = argToInt(1);
    final levels = argToIntOctet(2);
    return SetRowCommand(x, y, levels);
  }

  GridCommand parseSetCol() {
    if (arguments.length < 3) {
      throw ParseError(
          'invalid arguments for col set, expected: `x y_off l[..]`, got: $arguments');
    }
    final x = argToInt(0);
    final yOffset = argToInt(1);
    final levels = argToIntOctet(2);
    return SetColCommand(x, yOffset, levels);
  }

  GridCommand parseMap() {
    if (arguments.length < 3) {
      throw ParseError(
          'invalid arguments for col set, expected: `x_off y_off l[64]`, got: $arguments');
    }
    final xOffset = argToInt(0);
    final yOffset = argToInt(1);
    final levels = argToIntQuad(2);
    return MapCommand(xOffset, yOffset, levels);
  }

  int argToInt(int index) => toInt(arguments[index]);

  int toInt(Object argument) {
    if (argument is! int) {
      throw ParseError('expected int, got: ${toTypeString(argument)}');
    }
    return argument;
  }

  List<int> argToIntOctet(int index) {
    final remaining = arguments.length - index;
    if (remaining % 8 != 0) {
      throw ParseError('expected multiple of 8 values, got: $remaining}');
    }

    final octet = <int>[remaining];
    for (var value in arguments.sublist(index)) {
      octet.add(toInt(value));
    }

    return octet;
  }

  List<int> argToIntQuad(int index) {
    final remaining = arguments.length - index;
    if (remaining != 64) {
      throw ParseError('expected quad (64) of values, got: $remaining}');
    }

    final octet = <int>[remaining];
    for (var value in arguments.sublist(index)) {
      octet.add(toInt(value));
    }

    return octet;
  }

  String toTypeString(Object argument) =>
      argument == null ? 'null' : argument.runtimeType.toString();

  void assertArgs(int length) {
    if (arguments.length != length) {
      throw ParseError('expected $length arguments, got: ${arguments.length}');
    }
  }
}

/// Thrown in case of parse error.
class ParseError extends Error {
  final Object detail;

  ParseError(this.detail);

  @override
  String toString() => 'Parse Error: ${Error.safeToString(detail)}';
}

/// Set the state of a single led.
///
/// `/grid/led/set x y s`
class StateSetCommand extends GridCommand {
  final int x, y, state;

  /// Set led at ([x],[y]) to [state] on (1) or off (0).
  StateSetCommand(this.x, this.y, this.state);

  @override
  void runOn(Grid grid) {
    grid[x][y] = _toLevel(state);
  }
}

/// Set the value of a single led.
///
/// `/grid/led/level/set x y l`
class LevelSetCommand extends GridCommand {
  final int x, y, level;

  /// Set led at ([x],[y]) to [level] in the range [0, 15].
  LevelSetCommand(this.x, this.y, this.level);

  @override
  void runOn(Grid grid) {
    grid[x][y] = level;
  }
}

/// Set the state of all the leds in a single message.
///
/// `/grid/led/all s`
///
class StateSetAllCommand extends GridCommand {
  final int state;

  /// Set all leds to [state] on (1) or off(0).
  StateSetAllCommand(this.state);

  @override
  void runOn(Grid grid) {
    for (var col in grid._column) {
      col.fillRange(0, col.length, _toLevel(state));
    }
  }
}

/// Set the value of all the leds in a single message.
///
/// `/grid/led/level/all l`
///
class LevelSetAllCommand extends GridCommand {
  final int level;

  /// Set all leds to [level] in the range [0, 15].
  LevelSetAllCommand(this.level);

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
