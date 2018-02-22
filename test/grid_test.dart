import 'package:monome/src/grid.dart';
import 'package:osc/osc.dart';
import 'package:test/test.dart';

void main() {
  Grid grid;

  setUp(() {
    grid = new Grid();
  });

  group('grid', () {
    test('[][]', () {
      grid[0][0] = 13;
      expect(grid[0][0], 13);
    });
    test('toString', () {
      var col = [0, 1, 2, 3, 4, 5, 6, 7];
      grid.run(new SetColCommand(0, 0, col));
      for (var i = 0; i < col.length; ++i) {
        expect(grid.toString(), r'''
------------------------------------------------
  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  2  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  3  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  4  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  5  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  6  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
  7  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
------------------------------------------------
''');
      }
    });
  });

  group('commands', () {
    test('level set', () {
      grid.run(new LevelSetCommand(3, 3, 1));
      expect(grid[3][3], 1);
    });
    test('level set all', () {
      grid.run(new LevelSetAllCommand(1));
      for (var m = 0; m < 16; ++m) {
        for (var n = 0; n < 8; ++n) {
          expect(grid[m][n], 1);
        }
      }

      grid.run(new LevelSetAllCommand(0));
      for (var m = 0; m < 16; ++m) {
        for (var n = 0; n < 8; ++n) {
          expect(grid[m][n], 0);
        }
      }
    });
    test('set row', () {
      var row = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
      grid.run(new SetRowCommand(0, 0, row));
      for (var i = 0; i < row.length; ++i) {
        expect(grid[i][0], row[i]);
      }
    });
    test('set col', () {
      var col = [0, 1, 2, 3, 4, 5, 6, 7];
      grid.run(new SetColCommand(0, 0, col));
      for (var i = 0; i < col.length; ++i) {
        expect(grid[0][i], col[i]);
      }
    });
    test('map', () {
      var row1 = [0, 1, 2, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0];
      var row2 = [8, 9, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0];
      grid.run(new MapCommand(0, 0, [
        0, 1, 2, 3, 4, 5, 6, 7, //
        8, 9, 10, 11, 12, 13, 14, 15, //
        0, 1, 2, 3, 4, 5, 6, 7, //
        8, 9, 10, 11, 12, 13, 14, 15, //
        0, 1, 2, 3, 4, 5, 6, 7, //
        8, 9, 10, 11, 12, 13, 14, 15, //
        0, 1, 2, 3, 4, 5, 6, 7, //
        8, 9, 10, 11, 12, 13, 14, 15, //
      ]));
      for (var y = 0; y < 4; ++y) {
        for (var i = 0; i < row1.length; ++i) {
          expect(grid[i][y * 2], row1[i]);
        }
        for (var i = 0; i < row2.length; ++i) {
          expect(grid[i][y * 2 + 1], row2[i]);
        }
      }
    });

    group('events', () {
      group('key', () {
        test('command', () {
          expect(new DeviceEvent.keyDown(0, 0).command, '/grid/key');
        });
        test('toOSC', () {
          expect(new DeviceEvent.keyDown(0, 0).toOSC(),
              new OSCMessage('/grid/key', arguments: <int>[0, 0, 1]));
        });
        test('toOSC (prefixed)', () {
          expect(new DeviceEvent.keyDown(0, 0).toOSC(prefix: '/monome'),
              new OSCMessage('/monome/grid/key', arguments: <int>[0, 0, 1]));
        });
        test('toString', () {
          expect(new DeviceEvent.keyDown(0, 0).toString(), '/grid/key 0 0 1');
        });
      });
    });

    group('fromOSC', () {
      test('parse error', () {
        var msg = new OSCMessage('/grid/led/level/set',
            arguments: <int>[0, 0 /* missing level */]);
        expect(() => GridCommand.fromOSC(msg),
            throwsA(const isInstanceOf<ParseError>()));
      });
      test('parse error (message)', () {
        expect(new ParseError('detail message').toString(),
            'Parse Error: "detail message"');
      });
      test('level set', () {
        var msg =
            new OSCMessage('/grid/led/level/set', arguments: <int>[0, 0, 3]);
        expect(GridCommand.fromOSC(msg), const isInstanceOf<LevelSetCommand>());
      });
      test('state set', () {
        var msg = new OSCMessage('/grid/led/set', arguments: <int>[0, 0, 1]);
        expect(GridCommand.fromOSC(msg), const isInstanceOf<StateSetCommand>());
      });
      test('level set all', () {
        var msg = new OSCMessage('/grid/led/all', arguments: <int>[0]);
        expect(
            GridCommand.fromOSC(msg), const isInstanceOf<StateSetAllCommand>());
      });
      test('state set all', () {
        var msg = new OSCMessage('/grid/led/level/all', arguments: <int>[0]);
        expect(
            GridCommand.fromOSC(msg), const isInstanceOf<LevelSetAllCommand>());
      });
      test('set row', () {
        var msg = new OSCMessage('/grid/led/level/row',
            arguments: <int>[0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
        expect(GridCommand.fromOSC(msg), const isInstanceOf<SetRowCommand>());
      });
      test('set col', () {
        var msg = new OSCMessage('/grid/led/level/col',
            arguments: <int>[0, 0, 1, 2, 3, 4, 5, 6, 7, 8]);
        expect(GridCommand.fromOSC(msg), const isInstanceOf<SetColCommand>());
      });
      test('map', () {
        var quad = [
          0, 1, 2, 3, 4, 5, 6, 7, //
          8, 9, 10, 11, 12, 13, 14, 15, //
          0, 1, 2, 3, 4, 5, 6, 7, //
          8, 9, 10, 11, 12, 13, 14, 15, //
          0, 1, 2, 3, 4, 5, 6, 7, //
          8, 9, 10, 11, 12, 13, 14, 15, //
          0, 1, 2, 3, 4, 5, 6, 7, //
          8, 9, 10, 11, 12, 13, 14, 15, //
        ];
        var msg = new OSCMessage('/grid/led/level/map',
            arguments: [0, 0]..addAll(quad));
        expect(GridCommand.fromOSC(msg), const isInstanceOf<MapCommand>());
      });
    });
  });
}
