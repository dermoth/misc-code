# RPN calculator: mobile layout plan

## Current problems (390px wide viewport)

* The page can't scroll: the `position-fixed min-vh-100 min-vw-100` wrapper
  plus fixed `vh-100` / `h-75` heights lock it, so the instructions are cut
  off and unreachable.
* The three `col` columns squeeze to ~90px each: buttons wrap, the result box
  is clipped ("14 (Sta").
* Phone keyboards auto-capitalize the first letter, so `pi` / `sin` become
  `Pi` / `Sin` and trigger the "Unknown operator" fatal error.

## Proposal

* Below lg (992px): natural, scrollable single column, ordered:
  input + buttons, result, Stack (max ~40vh, scrolls internally), History,
  Instructions.
* lg and up: keep the current 3-column, fixed-height layout.
* Implementation:
  * Split column 1 into an "input" block and a "help" block.
  * Place blocks with a small `<style>` using CSS grid `grid-template-areas`
    and one media query. Bootstrap 5.1 has no responsive height utilities,
    and `order-*` can't put two blocks in one column on desktop.
  * Drop the `position-fixed` wrapper (fixed heights only within the lg
    media query).
* Input: `autocapitalize="off" autocorrect="off" spellcheck="false"`, and
  wrap it in a `<form>` so the phone keyboard's Go/Enter key submits.
* Optional, larger: on-screen operator keypad.

## Verification

Screenshot at 390px and 1280px, light and dark; desktop should be visually
unchanged; check the page scrolls on mobile and every section is reachable.

## Status

Implemented differently from the proposal above, after review:

* Done in `ea5c86f`: below lg the page is a 100dvh flex column instead of a
  scrolling grid; history fills the remaining height at the bottom (under
  the keyboard) and stays anchored to the newest entry. Desktop unchanged
  (pixel-identical).
* Done in `17c4b56`: instructions in a `<dialog>` from a "?" button.
* Done in `be3a2aa`: stack shows 3 entries; "N more" expands it in place
  (chosen over an overlay so the input stays usable).
* Done in `3dee6bb`: autocapitalize/autocorrect/spellcheck off, placeholder
  instead of the label.
* Not done: `<form>` wrapper (the keyboard's Enter key already sends Enter
  to `inputCheck`; untested on a real device), on-screen keypad (dropped:
  device keyboard only).
* Open: history doesn't jump back to the newest entry when a line is added
  after scrolling up (desktop doesn't either).
