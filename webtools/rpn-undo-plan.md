# RPN calculator: error recovery, undo/redo and clear/reset plan

Priority: error recovery first, then undo/redo. Click-to-restore and
formula export are options built on the same model.

## Current behavior

* The stack lives in the DOM (`#stack-list` `<li>` text, top first); history
  (`#hist-list`) is a human-readable log, not the commands typed: `pop: 5`
  logs the popped value, `exch: 1<=>2` the swapped values, `sum: 3` a count
  that came from the stack.
* `calc()` runs the input tokens one by one. On the first error it sets
  `fatalErr`, logs "Fatal error", pushes `ERR`, puts `clear` in the input and
  re-throws. Tokens before the failing one stay applied, and everything is
  ignored until `clear`.
* `clear`, `cl`, `reset`, `rst` and the Clear button all wipe stack, history
  and input. In rpn(1), `clear` only deletes the stack elements.

## Data model

Move state from the DOM into JS and render the DOM from it:

* `stack`: array of numbers, top last (or first, matching the display).
* `history`: array of entries `{ label, token, line, stack }`:
  * `label`: the text shown today (`push: 12`, `op: /`, ...).
  * `token`: the token as typed (`0x10`, `/`, `exch`), for export/replay.
  * `line`: input line number, grouping the entries of one Enter.
  * `stack`: copy of the stack _after_ this entry (snapshot).
* `cursor`: index of the current history entry.

DOM nodes could carry the same data instead (`li.dataset.token` for strings,
or a JS property such as `li.snapshot` for arrays), but reading state back
from the DOM is what makes the current code awkward; arrays also make saving
the session to `localStorage` trivial later.

Snapshots are a few numbers each; one per entry costs nothing measurable
(cap history at e.g. 1000 entries anyway).

## 1. Error recovery (most important)

Each input line is applied entirely or not at all:

* Snapshot the stack (and history length) before running the line.
* On error: restore them, show the error in red under the input until a
  line succeeds (not in history or on the stack), and leave the line in
  the input with the failing token selected (`setSelectionRange`) so it can
  be fixed and resubmitted.
* Remove `fatalErr`, the `ERR` push, the "Clear calculator to continue"
  message and the re-throw.

No new button is needed: there is no error state left to clear.

## 2. Undo/redo

With the model above, undo/redo only move `cursor` and restore the
snapshot of the entry it lands on; nothing is recomputed, so no operation
needs an inverse (impossible for `pop`, `sum`, `sqr`, ...).

* Undo: move the cursor back one step and restore that snapshot.
* Redo: move it forward one step.
* Entries after the cursor are shown greyed; new input drops them first, as
  in editors.
* Step size: one input line (recommended: one Enter is one user action,
  `2 3 + 4 *` is one undo instead of five, and it matches HP-48 `UNDO` and
  the all-or-nothing error rule above) or one token. Implemented as a
  hardcoded constant (e.g. `undoStep = 'line'` or `'token'`) so it can be
  switched easily, and exposed in a settings UI later.
* Buttons: pictograms only, `↶` (U+21B6) and `↷` (U+21B7), with
  `title`/`aria-label` "Undo (Ctrl+Z)" / "Redo (Ctrl+Y)"; disabled when
  there is nothing to undo/redo.
* Keyboard: Ctrl+Z undo; Ctrl+Y and Ctrl+Shift+Z redo; Cmd instead of Ctrl
  on macOS (`metaKey`). Shared with the input's text undo (`undoKeys =
  'shared'`; `'calc'` and `'off'` also available, hardcoded): Ctrl+Z undoes
  the text until the input is empty, then the calculator, counting those
  calculator undos; Ctrl+Y redoes the counted calculator undos first, then
  the text. When the browser has nothing to undo/redo (input value
  unchanged on the next tick), the calculator acts instead. A new line,
  Clear or Reset resets the count.
* Commands `undo` and `redo` for typed use.

Approx. +35 lines on top of step 1.

## 3. Option: click a history entry to restore

Click (or tap) an entry: move `cursor` to it and restore its snapshot. Gives
per-token access even with per-line undo steps, and undo/redo keep working
from the new position. Approx. +10 lines on the same model; needs entries
tall enough to tap on mobile (see the mobile plan and the BUGS.md TODO).

## 4. Option: export the formula

With `token` recorded per entry:

* RPN export: the tokens from the last `reset` (or `clear`) up to the cursor,
  joined with spaces, e.g. `12 4 / 7 2 * +`, copied to the clipboard. A few
  lines.
* Infix export, e.g. `12 / 4 + 7 * 2`: keep a second stack of formula strings
  updated by each operator, alongside the values (parenthesize by operator
  precedence). Moderate: each command needs a formatting rule, and stack
  ops (`exch`, `dup`, `r`, `sum`) must move strings too.

### Replay (dropped as a mechanism)

Replay means re-running the recorded tokens from the start instead of
restoring stored snapshots. It gives the same result as options 2 and 3
with more code, so it isn't needed for them. It would only matter for
editing an earlier token and recomputing everything after it, which isn't
wanted.

## Clear vs reset

Hardware references:

* HP classic RPN (12C, 15C, 16C): `CLx` clears the X register (top of
  stack), `←` deletes the last digit typed, `LSTx` recalls X from before the
  last operation.
* HP-42S: `CLX`, `CLST` (clear stack), `CLRG` (registers), `CLALL`.
* HP-48/49/50 (RPL): `CLEAR` (clear stack), `DROP`, `UNDO`, `LASTARG`; an
  error doesn't consume the arguments, like step 1.

Agreed:

* `×` button inside the input (Bootstrap input-group) and the Esc key: clear
  the input text only. Not `type="search"`, whose built-in `×` isn't shown
  in Firefox.
* `clear` / `cl` command and Clear button: clear the stack only (rpn(1), HP
  `CLST` / `CLEAR`). It is a history entry, so it can be undone.
* `reset` / `rst` command and Reset button: wipe stack, history and undo,
  i.e. start over (today's Clear).
* No `CLx`: it's `pop`, already aliased as `=`.

## Implementation steps (one commit each)

1. Done (`887cdbd`). Refactor: state in JS arrays, DOM rendered from it,
   history entries carry `token`. No behavior change; verified by running
   every command before and after (same harness as the eval refactor).
2. Done (`abba83a`). Error recovery: atomic input lines, error in red under
   the input until a line succeeds, line kept for editing with the failing
   token selected, fatal mode removed.
3. Done (`2c9888b`). Undo/redo: cursor model, greyed entries, buttons,
   Ctrl+Z/Ctrl+Y, `undo`/`redo` commands.
4. Done (`fecdb43`). Clear vs reset split, `×` and Esc for the input.
5. Done (`596321b`). Update the instructions text.
6. Options, if wanted: click-to-restore, RPN export, infix export.

Verification: scripted browser checks for an error mid-line (stack and
history unchanged, input kept, token selected), undo/redo sequences
including new input after undo, Ctrl+Z with and without text in the input,
`clear` then undo, `reset`; screenshots on desktop and mobile for the
greyed entries and pictogram buttons, light and dark.
