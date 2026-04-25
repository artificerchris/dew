import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:dart_console/dart_console.dart';
import 'package:dew_core/dew_core.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';

import '../kanban_config.dart';
import '../ticket.dart';
import '../ticket_store.dart';

enum _Mode { board, detail }

// ── TUI event bus ────────────────────────────────────────────────────────────

sealed class _TuiEvent {
  const _TuiEvent();
}

final class _TuiKey extends _TuiEvent {
  final Key key;
  const _TuiKey(this.key);
}

final class _TuiRefresh extends _TuiEvent {
  const _TuiRefresh();
}

/// Parses raw terminal bytes into [Key] values without blocking.
///
/// Mirrors [Console.readKey] but works on a pre-read byte batch so the event
/// loop stays async-friendly. An escape byte followed by more bytes in the
/// same batch is an escape sequence; a lone 0x1b is a plain Escape keypress.
Iterable<Key> _parseKeys(List<int> bytes) sync* {
  var i = 0;
  while (i < bytes.length) {
    final c = bytes[i++];

    if (c >= 0x01 && c <= 0x1a) {
      // Ctrl+A … Ctrl+Z map 1:1 to ControlCharacter enum indices
      yield Key.control(ControlCharacter.values[c]);
    } else if (c == 0x1b) {
      if (i >= bytes.length) {
        // Lone escape byte → plain Escape key
        yield Key.control(ControlCharacter.escape);
      } else if (bytes[i] == 0x7f) {
        i++;
        yield Key.control(ControlCharacter.wordBackspace);
      } else if (bytes[i] == 0x5b) {
        // ESC [ …
        i++;
        if (i >= bytes.length) {
          yield Key.control(ControlCharacter.unknown);
        } else {
          final seq = String.fromCharCode(bytes[i++]);
          switch (seq) {
            case 'A':
              yield Key.control(ControlCharacter.arrowUp);
            case 'B':
              yield Key.control(ControlCharacter.arrowDown);
            case 'C':
              yield Key.control(ControlCharacter.arrowRight);
            case 'D':
              yield Key.control(ControlCharacter.arrowLeft);
            case 'H':
              yield Key.control(ControlCharacter.home);
            case 'F':
              yield Key.control(ControlCharacter.end);
            default:
              final code = seq.codeUnitAt(0);
              if (code > '0'.codeUnitAt(0) && code < '9'.codeUnitAt(0)) {
                // ESC [ N ~ extended sequence
                if (i < bytes.length && bytes[i] == 0x7e) i++;
                yield Key.control(switch (seq) {
                  '1' || '7' => ControlCharacter.home,
                  '3' => ControlCharacter.delete,
                  '4' || '8' => ControlCharacter.end,
                  '5' => ControlCharacter.pageUp,
                  '6' => ControlCharacter.pageDown,
                  _ => ControlCharacter.unknown,
                });
              } else {
                yield Key.control(ControlCharacter.unknown);
              }
          }
        }
      } else if (bytes[i] == 0x4f) {
        // ESC O …
        i++;
        if (i >= bytes.length) {
          yield Key.control(ControlCharacter.unknown);
        } else {
          final seq = String.fromCharCode(bytes[i++]);
          yield Key.control(switch (seq) {
            'H' => ControlCharacter.home,
            'F' => ControlCharacter.end,
            'P' => ControlCharacter.F1,
            'Q' => ControlCharacter.F2,
            'R' => ControlCharacter.F3,
            'S' => ControlCharacter.F4,
            _ => ControlCharacter.unknown,
          });
        }
      } else if (bytes[i] == 0x62) {
        i++;
        yield Key.control(ControlCharacter.wordLeft);
      } else if (bytes[i] == 0x66) {
        i++;
        yield Key.control(ControlCharacter.wordRight);
      } else {
        yield Key.control(ControlCharacter.unknown);
      }
    } else if (c == 0x7f) {
      yield Key.control(ControlCharacter.backspace);
    } else if (c == 0x00 || (c >= 0x1c && c <= 0x1f)) {
      yield Key.control(ControlCharacter.unknown);
    } else {
      yield Key.printable(String.fromCharCode(c));
    }
  }
}

/// A single rendered cell: text + optional styling.
class _Cell {
  final String text;
  final ConsoleColor? fg;
  final ConsoleColor? bg;
  final bool bold;

  const _Cell(this.text, {this.fg, this.bg, this.bold = false});
}

/// Interactive Trello-style kanban TUI.
class TuiCommand extends DewCommand {
  final FileSystem _fs;

  TuiCommand({FileSystem fs = const LocalFileSystem()}) : _fs = fs;

  @override
  final String name = 'tui';

  @override
  final String description = 'Launch the interactive kanban board TUI.';

  // Layout constants
  static const _colSep = 1; // gap between columns (chars)
  static const _minColW = 26; // minimum column width
  static const _colHeaderH = 3; // rows used by column header box
  static const _ticketH = 3; // rows per ticket card
  static const _indicatorRows = 2; // rows reserved for scroll indicators

  @override
  Future<void> run() async {
    final context = await ProjectContext.find(fs: _fs);
    final config = context.config.kanban;
    final store = TicketStore(
      kanbanDir: context.dirs.kanban,
      prefix: config.prefix,
      fs: context.fs,
    );
    final kanbanDirPath = context.dirs.kanban;

    final console = Console();
    if (!console.hasTerminal) {
      print('dew kanban tui requires an interactive terminal.');
      return;
    }

    var tickets = await store.list();
    var byColumn = _groupByColumn(tickets, config);

    var colIdx = 0;
    var ticketIdx = 0;
    var mode = _Mode.board;
    var detailScroll = 0;
    var statusMsg = '';
    var searchQuery = '';
    var searchMode = false;

    console.hideCursor();
    console.rawMode = true;

    void redraw() {
      final w = max(console.windowWidth, 40);
      final h = max(console.windowHeight, 12);
      console.clearScreen();
      console.resetCursorPosition();

      if (mode == _Mode.board) {
        _renderBoard(
          console: console,
          config: config,
          byColumn: byColumn,
          colIdx: colIdx,
          ticketIdx: ticketIdx,
          statusMsg: statusMsg,
          searchQuery: searchQuery,
          searchMode: searchMode,
          w: w,
          h: h,
        );
      } else {
        final col = config.columns[colIdx];
        final colTickets = _filtered(byColumn[col.id] ?? [], searchQuery);
        if (colTickets.isEmpty) {
          mode = _Mode.board;
        } else {
          _renderDetail(
            console: console,
            ticket: colTickets[ticketIdx.clamp(0, colTickets.length - 1)],
            config: config,
            scroll: detailScroll,
            w: w,
            h: h,
          );
        }
      }
    }

    // ── Event bus ────────────────────────────────────────────────────────────
    final events = StreamController<_TuiEvent>();
    Timer? debounce;
    StreamSubscription<dynamic>? watchSub;

    // File-system watcher — auto-refresh on any change in the kanban folder.
    try {
      watchSub = io.Directory(kanbanDirPath).watch(recursive: true).listen(
        (_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 350), () {
            if (!events.isClosed) events.add(const _TuiRefresh());
          });
        },
        onError: (_) {}, // ignore watch errors (e.g. unsupported platform)
      );
    } catch (_) {
      // watch() throws on some platforms / missing dirs — auto-refresh disabled
    }

    // Key stream — raw bytes converted to Key values without blocking.
    final keySub = io.stdin.listen((bytes) {
      for (final key in _parseKeys(bytes)) {
        if (!events.isClosed) events.add(_TuiKey(key));
      }
    });

    try {
      redraw();

      loop:
      await for (final event in events.stream) {
        // ── File changed ──────────────────────────────────────────────────
        if (event is _TuiRefresh) {
          tickets = await store.list();
          byColumn = _groupByColumn(tickets, config);
          redraw();
          continue;
        }

        final key = (event as _TuiKey).key;

        // ── Search mode ────────────────────────────────────────────────────
        if (searchMode) {
          if (key.isControl) {
            switch (key.controlChar) {
              case ControlCharacter.enter:
                searchMode = false;
                ticketIdx = 0;
              case ControlCharacter.escape:
                searchMode = false;
                searchQuery = '';
                ticketIdx = 0;
              case ControlCharacter.backspace:
                if (searchQuery.isNotEmpty) {
                  searchQuery = searchQuery.substring(0, searchQuery.length - 1);
                }
              default:
                continue loop; // skip redraw
            }
          } else {
            searchQuery += key.char;
          }
          redraw();
          continue loop;
        }

        // ── Board mode ─────────────────────────────────────────────────────
        if (mode == _Mode.board) {
          final col = config.columns[colIdx];
          final colTickets = _filtered(byColumn[col.id] ?? [], searchQuery);

          if (!key.isControl) {
            switch (key.char) {
              case 'q':
                break loop;
              case 'j':
                if (ticketIdx < colTickets.length - 1) ticketIdx++;
              case 'k':
                if (ticketIdx > 0) ticketIdx--;
              case 'h':
                if (colIdx > 0) {
                  colIdx--;
                  ticketIdx = 0;
                }
              case 'l':
                if (colIdx < config.columns.length - 1) {
                  colIdx++;
                  ticketIdx = 0;
                }
              case '<':
                if (colIdx > 0 && colTickets.isNotEmpty) {
                  final t = colTickets[ticketIdx];
                  final newColId = config.columns[colIdx - 1].id;
                  try {
                    await store.update(t.id, column: newColId);
                    tickets = await store.list();
                    byColumn = _groupByColumn(tickets, config);
                    colIdx--;
                    final nt = _filtered(byColumn[newColId] ?? [], searchQuery);
                    ticketIdx = max(0, nt.length - 1);
                    statusMsg = 'Moved ${t.id} → ${config.columns[colIdx].name}';
                  } on ArgumentError catch (e) {
                    statusMsg = 'Error: ${e.message ?? e}';
                  }
                }
              case '>':
                if (colIdx < config.columns.length - 1 && colTickets.isNotEmpty) {
                  final t = colTickets[ticketIdx];
                  final newColId = config.columns[colIdx + 1].id;
                  try {
                    await store.update(t.id, column: newColId);
                    tickets = await store.list();
                    byColumn = _groupByColumn(tickets, config);
                    colIdx++;
                    final nt = _filtered(byColumn[newColId] ?? [], searchQuery);
                    ticketIdx = max(0, nt.length - 1);
                    statusMsg = 'Moved ${t.id} → ${config.columns[colIdx].name}';
                  } on ArgumentError catch (e) {
                    statusMsg = 'Error: ${e.message ?? e}';
                  }
                }
              case '?':
                searchMode = true;
                searchQuery = '';
                ticketIdx = 0;
              default:
                continue loop; // skip redraw
            }
          } else {
            switch (key.controlChar) {
              case ControlCharacter.ctrlC:
                break loop;
              case ControlCharacter.arrowUp:
                if (ticketIdx > 0) ticketIdx--;
              case ControlCharacter.arrowDown:
                if (ticketIdx < colTickets.length - 1) ticketIdx++;
              case ControlCharacter.arrowLeft:
                if (colIdx > 0) {
                  colIdx--;
                  ticketIdx = 0;
                }
              case ControlCharacter.arrowRight:
                if (colIdx < config.columns.length - 1) {
                  colIdx++;
                  ticketIdx = 0;
                }
              case ControlCharacter.enter:
                if (colTickets.isNotEmpty) {
                  mode = _Mode.detail;
                  detailScroll = 0;
                }
              case ControlCharacter.escape:
                if (searchQuery.isNotEmpty || statusMsg.isNotEmpty) {
                  searchQuery = '';
                  statusMsg = '';
                } else {
                  break loop;
                }
              default:
                continue loop; // skip redraw
            }
          }
        }
        // ── Detail mode ────────────────────────────────────────────────────
        else {
          if (!key.isControl) {
            switch (key.char) {
              case 'q':
                break loop;
              case 'b':
                mode = _Mode.board;
                detailScroll = 0;
              case 'j':
                detailScroll++;
              case 'k':
                if (detailScroll > 0) detailScroll--;
              default:
                continue loop; // skip redraw
            }
          } else {
            switch (key.controlChar) {
              case ControlCharacter.ctrlC:
                break loop;
              case ControlCharacter.escape:
                mode = _Mode.board;
                detailScroll = 0;
              case ControlCharacter.arrowUp:
                if (detailScroll > 0) detailScroll--;
              case ControlCharacter.arrowDown:
                detailScroll++;
              default:
                continue loop; // skip redraw
            }
          }
        }

        redraw();
      }
    } finally {
      await keySub.cancel();
      await watchSub?.cancel();
      debounce?.cancel();
      await events.close();
      console.rawMode = false;
      console.showCursor();
      console.clearScreen();
      console.resetCursorPosition();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Board rendering
  // ══════════════════════════════════════════════════════════════════════════

  static void _renderBoard({
    required Console console,
    required KanbanConfig config,
    required Map<String, List<Ticket>> byColumn,
    required int colIdx,
    required int ticketIdx,
    required String statusMsg,
    required String searchQuery,
    required bool searchMode,
    required int w,
    required int h,
  }) {
    _writeHeaderBar(console, config, searchQuery, searchMode, w);
    console.writeLine(); // blank line after header

    final numCols = config.columns.length;
    // How many columns fit side-by-side?
    final numVisible = max(1, min(numCols, (w + _colSep) ~/ (_minColW + _colSep)));
    final colW = (w - (numVisible - 1) * _colSep) ~/ numVisible;

    // Keep selected column in viewport
    var viewStart = colIdx - numVisible ~/ 2;
    viewStart = viewStart.clamp(0, max(0, numCols - numVisible));
    if (colIdx < viewStart) viewStart = colIdx;
    if (colIdx >= viewStart + numVisible) viewStart = colIdx - numVisible + 1;
    viewStart = viewStart.clamp(0, max(0, numCols - numVisible));

    final viewCols = config.columns.sublist(viewStart, min(viewStart + numVisible, numCols));

    // h - 2 (header+blank) - 2 (footer separator+help) = content height
    final colAreaH = h - 4;

    // Build column cell buffers (one list per column, each list has colAreaH cells)
    final colCells = <List<_Cell>>[];
    for (int i = 0; i < viewCols.length; i++) {
      final col = viewCols[i];
      final isSelected = (viewStart + i) == colIdx;
      final tickets = _filtered(byColumn[col.id] ?? [], searchQuery);
      colCells.add(
        _buildColumnCells(
          col: col,
          tickets: tickets,
          colW: colW,
          areaH: colAreaH,
          isSelected: isSelected,
          selectedIdx: isSelected ? ticketIdx : -1,
        ),
      );
    }

    // Render side-by-side, row by row
    for (int row = 0; row < colAreaH; row++) {
      for (int ci = 0; ci < colCells.length; ci++) {
        if (ci > 0) console.write(' ' * _colSep);
        final cell = colCells[ci][row];
        _applyCell(console, cell);
        console.resetColorAttributes();
      }
      if (row < colAreaH - 1) {
        console.writeLine();
      }
    }

    _writeFooterBar(
      console: console,
      statusMsg: statusMsg,
      searchMode: searchMode,
      searchQuery: searchQuery,
      w: w,
      colIdx: colIdx,
      numCols: numCols,
      numVisible: numVisible,
      columns: config.columns,
    );
  }

  static List<_Cell> _buildColumnCells({
    required ColumnConfig col,
    required List<Ticket> tickets,
    required int colW,
    required int areaH,
    required bool isSelected,
    required int selectedIdx,
  }) {
    final cells = <_Cell>[];
    final color = _colColor(col.color);
    final innerW = colW - 2;

    // ── Column header (3 rows) ─────────────────────────────────────────────

    // Top border
    cells.add(_Cell(
      '┌${'─' * innerW}┐',
      fg: isSelected ? color : ConsoleColor.brightBlack,
    ));

    // Name + count
    final count = tickets.length;
    final label = _trunc(' ${col.name.toUpperCase()} ($count) ', innerW);
    cells.add(_Cell(
      '│${label.padRight(innerW)}│',
      fg: isSelected ? ConsoleColor.black : color,
      bg: isSelected ? color : null,
      bold: isSelected,
    ));

    // Separator (double line for selected, single for others)
    cells.add(_Cell(
      isSelected ? '╞${'═' * innerW}╡' : '└${'─' * innerW}┘',
      fg: isSelected ? color : ConsoleColor.brightBlack,
    ));

    // ── Ticket area ────────────────────────────────────────────────────────

    final ticketAreaH = areaH - _colHeaderH - 1; // reserve 1 for bottom border
    final maxVisible = max(1, (ticketAreaH - _indicatorRows) ~/ _ticketH);

    // Compute scroll to keep selectedIdx in view
    var scroll = 0;
    if (isSelected && selectedIdx >= 0 && tickets.isNotEmpty) {
      scroll = (selectedIdx - maxVisible + 1).clamp(0, max(0, tickets.length - maxVisible));
      if (selectedIdx < scroll) scroll = selectedIdx;
    }

    final showAbove = scroll > 0;
    final showBelow = tickets.isNotEmpty && (scroll + maxVisible) < tickets.length;

    // "More above" indicator
    if (showAbove) {
      final msg = _trunc('  ↑ $scroll above', innerW);
      cells.add(_Cell('│${msg.padRight(innerW)}│', fg: ConsoleColor.brightYellow));
    } else {
      cells.add(_Cell('│${' ' * innerW}│', fg: isSelected ? color : ConsoleColor.brightBlack));
    }

    // Visible tickets
    final visEnd = min(scroll + maxVisible, tickets.length);
    for (int ti = scroll; ti < visEnd; ti++) {
      _addTicketCells(cells, tickets[ti], innerW, ti == selectedIdx && isSelected);
    }

    // Empty state
    if (tickets.isEmpty) {
      final borderFg = isSelected ? color : ConsoleColor.brightBlack;
      cells.add(_Cell('│${' ' * innerW}│', fg: borderFg));
      final hint = _trunc('  ··· empty ···', innerW).padRight(innerW);
      cells.add(_Cell(
        '│$hint│',
        fg: isSelected ? color : ConsoleColor.white,
        bold: isSelected,
      ));
      cells.add(_Cell('│${' ' * innerW}│', fg: borderFg));
    }

    // "More below" indicator
    if (showBelow) {
      final remaining = tickets.length - scroll - maxVisible;
      final msg = _trunc('  ↓ $remaining below', innerW);
      cells.add(_Cell('│${msg.padRight(innerW)}│', fg: ConsoleColor.brightYellow));
    } else {
      cells.add(_Cell('│${' ' * innerW}│', fg: isSelected ? color : ConsoleColor.brightBlack));
    }

    // Fill remaining space before bottom border
    while (cells.length < areaH - 1) {
      cells.add(_Cell('│${' ' * innerW}│', fg: isSelected ? color : ConsoleColor.brightBlack));
    }

    // Bottom border (always at areaH - 1)
    if (cells.length > areaH - 1) cells.length = areaH - 1;
    cells.add(_Cell(
      isSelected ? '╘${'═' * innerW}╛' : '└${'─' * innerW}┘',
      fg: isSelected ? color : ConsoleColor.brightBlack,
    ));

    // Pad to exact height
    while (cells.length < areaH) {
      cells.add(_Cell(' ' * colW));
    }

    return cells;
  }

  static void _addTicketCells(List<_Cell> cells, Ticket ticket, int innerW, bool isSel) {
    final bg = isSel ? ConsoleColor.blue : null;
    final titleFg = isSel ? ConsoleColor.brightWhite : null;
    final bullet = isSel ? '▶' : ' ';
    final typeColor = _typeColor(ticket.type);

    // Row 1: bullet + ID + type badge
    final badge = ' [${_trunc(ticket.type, 7)}]';
    final idLine = '$bullet ${ticket.id}$badge';
    cells.add(_Cell(
      '│${_trunc(idLine, innerW).padRight(innerW)}│',
      fg: isSel ? ConsoleColor.brightWhite : typeColor,
      bg: bg,
      bold: isSel,
    ));

    // Row 2: title
    final titleLine = '  ${_trunc(ticket.title, innerW - 2)}';
    cells.add(_Cell(
      '│${titleLine.padRight(innerW)}│',
      fg: titleFg,
      bg: bg,
    ));

    // Row 3: labels / milestone / blank
    final String tagLine;
    if (ticket.labels.isNotEmpty) {
      tagLine = '  ${ticket.labels.take(3).map((l) => '#$l').join(' ')}';
    } else if (ticket.milestones.isNotEmpty) {
      tagLine = '  @ ${ticket.milestones.first}';
    } else {
      tagLine = '';
    }
    cells.add(_Cell(
      '│${_trunc(tagLine, innerW).padRight(innerW)}│',
      fg: isSel ? ConsoleColor.brightCyan : ConsoleColor.brightBlack,
      bg: bg,
    ));
  }

  static void _writeHeaderBar(
    Console console,
    KanbanConfig config,
    String searchQuery,
    bool searchMode,
    int w,
  ) {
    console.setBackgroundColor(ConsoleColor.blue);
    console.setForegroundColor(ConsoleColor.brightWhite);
    console.setTextStyle(bold: true);

    final left = ' DEW Kanban  [${config.prefix}]';
    final right = searchMode
        ? '  ? ${searchQuery}_  '
        : (searchQuery.isNotEmpty ? '  filter: "$searchQuery"  ' : '');
    final line = '$left${right.padLeft(max(0, w - left.length))}';
    console.write(_trunc(line, w).padRight(w));
    console.resetColorAttributes();
  }

  static void _writeFooterBar({
    required Console console,
    required String statusMsg,
    required bool searchMode,
    required String searchQuery,
    required int w,
    required int colIdx,
    required int numCols,
    required int numVisible,
    required List<ColumnConfig> columns,
  }) {
    console.writeLine();

    // Separator
    console.setForegroundColor(ConsoleColor.brightBlack);
    console.write('─' * w);
    console.resetColorAttributes();
    console.writeLine();

    if (statusMsg.isNotEmpty) {
      console.setForegroundColor(ConsoleColor.brightYellow);
      console.write(' $statusMsg');
      console.resetColorAttributes();
    } else if (searchMode) {
      console.setForegroundColor(ConsoleColor.brightCyan);
      console.write(' Search: ${searchQuery}_  (Enter to apply, Esc to clear)');
      console.resetColorAttributes();
    } else {
      // Column position indicator + help
      console.setForegroundColor(ConsoleColor.brightBlack);
      final pos = numCols > numVisible ? ' [${colIdx + 1}/$numCols cols]' : '';
      const help = ' [j/k] nav  [h/l] col  [</>] move  [enter] detail  [?] filter  [q] quit';
      console.write(_trunc('$pos$help', w).padRight(w));
      console.resetColorAttributes();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Detail rendering
  // ══════════════════════════════════════════════════════════════════════════

  static void _renderDetail({
    required Console console,
    required Ticket ticket,
    required KanbanConfig config,
    required int scroll,
    required int w,
    required int h,
  }) {
    _writeHeaderBar(console, config, '', false, w);
    console.writeLine();

    // Ticket title bar
    console.setBackgroundColor(ConsoleColor.blue);
    console.setForegroundColor(ConsoleColor.brightWhite);
    console.setTextStyle(bold: true);
    final titleBar = '  ${ticket.id}  ${_trunc(ticket.title, w - ticket.id.length - 6)}';
    console.write(titleBar.padRight(w));
    console.resetColorAttributes();
    console.writeLine();

    // Build scrollable content lines
    final lines = _buildDetailLines(ticket, w - 4);
    final contentH = h - 5; // header + blank + title + separator + footer
    final maxScroll = max(0, lines.length - contentH);
    final s = scroll.clamp(0, maxScroll);

    final visible = lines.sublist(s, min(s + contentH, lines.length));

    for (final line in visible) {
      _applyCell(console, line);
      console.resetColorAttributes();
      console.writeLine();
    }
    for (int i = visible.length; i < contentH; i++) {
      console.writeLine();
    }

    // Footer
    console.setForegroundColor(ConsoleColor.brightBlack);
    console.write('─' * w);
    console.resetColorAttributes();
    console.writeLine();
    console.setForegroundColor(ConsoleColor.brightBlack);
    final scrollInfo = lines.isNotEmpty
        ? ' [${s + 1}-${min(s + contentH, lines.length)}/${lines.length}]'
        : '';
    console.write(' [j/k↑↓] scroll$scrollInfo  [b/Esc] back  [q] quit'.padRight(w));
    console.resetColorAttributes();
  }

  static List<_Cell> _buildDetailLines(Ticket ticket, int w) {
    final lines = <_Cell>[];

    void hr([String? label]) {
      if (label != null) {
        final tag = ' $label ';
        final dashes = max(0, w - tag.length + 2);
        lines.add(_Cell('  ─$tag${'─' * dashes}', fg: ConsoleColor.brightBlue, bold: true));
      } else {
        lines.add(_Cell('  ${'─' * w}', fg: ConsoleColor.brightBlack));
      }
    }

    void kv(String key, String value) {
      lines.add(
        _Cell(
          '  ${key.padRight(12)}: ${_trunc(value, w - 16)}',
          fg: ConsoleColor.white,
        ),
      );
    }

    void blank() => lines.add(const _Cell(''));

    // Metadata section
    hr('INFO');
    kv('Type', ticket.type);
    kv('Column', ticket.column);
    kv('Created', _fmtDate(ticket.created));
    if (ticket.milestones.isNotEmpty) kv('Milestones', ticket.milestones.join(', '));
    if (ticket.labels.isNotEmpty) kv('Labels', ticket.labels.map((l) => '#$l').join('  '));
    if (ticket.links.isNotEmpty) {
      for (final link in ticket.links) {
        kv(link.type, link.targetId);
      }
    }

    // Body
    if (ticket.body.isNotEmpty) {
      blank();
      hr('BODY');
      blank();
      for (final para in ticket.body.split('\n')) {
        for (final wl in _wordWrap(para, w)) {
          lines.add(_Cell('  $wl', fg: ConsoleColor.white));
        }
      }
    }

    // Comments
    for (int ci = 0; ci < ticket.comments.length; ci++) {
      blank();
      hr('COMMENT ${ci + 1}');
      blank();
      for (final para in ticket.comments[ci].split('\n')) {
        for (final wl in _wordWrap(para, w)) {
          lines.add(_Cell('  $wl', fg: ConsoleColor.white));
        }
      }
    }

    blank();
    return lines;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Utilities
  // ══════════════════════════════════════════════════════════════════════════

  static void _applyCell(Console console, _Cell cell) {
    if (cell.bg != null) console.setBackgroundColor(cell.bg!);
    if (cell.fg != null) console.setForegroundColor(cell.fg!);
    if (cell.bold) console.setTextStyle(bold: true);
    console.write(cell.text);
  }

  static Map<String, List<Ticket>> _groupByColumn(
    List<Ticket> tickets,
    KanbanConfig config,
  ) {
    final map = <String, List<Ticket>>{};
    for (final col in config.columns) {
      map[col.id] = [];
    }
    for (final t in tickets) {
      (map[t.column] ??= []).add(t);
    }
    return map;
  }

  static List<Ticket> _filtered(List<Ticket> tickets, String query) {
    if (query.isEmpty) return tickets;
    final q = query.toLowerCase();
    return tickets
        .where(
          (t) =>
              t.id.toLowerCase().contains(q) ||
              t.title.toLowerCase().contains(q) ||
              t.type.toLowerCase().contains(q) ||
              t.labels.any((l) => l.toLowerCase().contains(q)) ||
              t.body.toLowerCase().contains(q),
        )
        .toList();
  }

  static ConsoleColor _colColor(String color) => switch (color.toLowerCase()) {
    'red' => ConsoleColor.red,
    'green' => ConsoleColor.green,
    'yellow' => ConsoleColor.yellow,
    'blue' => ConsoleColor.blue,
    'magenta' || 'purple' => ConsoleColor.magenta,
    'cyan' || 'teal' => ConsoleColor.cyan,
    'white' => ConsoleColor.white,
    'brightred' || 'bright_red' => ConsoleColor.brightRed,
    'brightgreen' || 'bright_green' => ConsoleColor.brightGreen,
    'brightyellow' || 'bright_yellow' => ConsoleColor.brightYellow,
    'brightblue' || 'bright_blue' => ConsoleColor.brightBlue,
    'brightmagenta' || 'bright_magenta' => ConsoleColor.brightMagenta,
    'brightcyan' || 'bright_cyan' => ConsoleColor.brightCyan,
    'brightwhite' || 'bright_white' => ConsoleColor.brightWhite,
    _ => ConsoleColor.cyan,
  };

  static ConsoleColor _typeColor(String type) => switch (type.toLowerCase()) {
    'bug' => ConsoleColor.red,
    'task' => ConsoleColor.blue,
    'feature' || 'feat' => ConsoleColor.green,
    'chore' || 'spike' => ConsoleColor.yellow,
    'epic' => ConsoleColor.magenta,
    'story' => ConsoleColor.cyan,
    _ => ConsoleColor.white,
  };

  static String _trunc(String s, int maxLen) {
    if (maxLen <= 0) return '';
    if (s.length <= maxLen) return s;
    if (maxLen == 1) return s[0];
    return '${s.substring(0, maxLen - 1)}…';
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static List<String> _wordWrap(String text, int width) {
    if (text.isEmpty) return [''];
    if (text.length <= width) return [text];
    final words = text.split(' ');
    final result = <String>[];
    final buf = StringBuffer();
    for (final word in words) {
      if (buf.isNotEmpty && buf.length + 1 + word.length > width) {
        result.add(buf.toString());
        buf.clear();
      }
      if (buf.isNotEmpty) buf.write(' ');
      buf.write(word);
    }
    if (buf.isNotEmpty) result.add(buf.toString());
    return result;
  }
}
