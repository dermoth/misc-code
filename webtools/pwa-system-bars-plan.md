# Installed apps: bottom bar color

Plan only, not committed. Untested: it needs a real Android phone, since
DevTools can't emulate the system bars of an installed app.

## Problem

In the installed apps (Chrome on Android), the area of the bottom gesture
navigation bar is always white, even in dark mode. A dark bar would look
better in both themes: the phone's screen edge is dark, so white makes a
dark-light-dark transition in dark mode.

## Likely cause

* Both manifests hard-code `"theme_color": "#ffffff"` and
  `"background_color": "#ffffff"`, with no dark variant. White regardless of
  the theme matches that.
* Installed apps don't use the page's `theme-color` meta tag for the bottom
  bar ([Chromium bug 40759522](https://issues.chromium.org/issues/40759522)).
  Chrome 146 also reportedly keeps the manifest's install-time colors and
  ignores runtime `theme-color` changes
  ([Chromium bug 554055703](https://issues.chromium.org/issues/554055703)).
* The earlier `theme-color` fix (`c456f52`) only swapped the meta values for
  the top status bar; the manifests have been white since they were added. It
  is unlikely to be the cause.

## Options, in order

### 1. Draw under the bar (follows the theme)

Since Chrome 135, Chrome on Android can draw the page up to the bottom edge
when the page opts in
([edge-to-edge guide](https://developer.chrome.com/docs/css-ui/edge-to-edge)).
The page background, light or dark, would then fill the bar area. The guide
covers the browser tab; whether installed apps get it too is unconfirmed.

In both `nato.html` and `rpn.html`, add `viewport-fit=cover`:

```html
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no, viewport-fit=cover">
```

Keep the last line of the RPN history and the NATO output clear of the
gesture handle, in each page's small-screen media query (`env()` is 0 where
there is no inset, so desktop is unaffected):

```css
/* rpn.html, in @media (max-width: 991.98px) */
.rpn-page { padding-bottom: env(safe-area-inset-bottom, 0px); }

/* nato.html, in @media (max-width: 991.98px) */
.nato-page { padding-bottom: env(safe-area-inset-bottom, 0px); }
```

On iOS, the installed apps already draw under the status bar: with Liquid
Glass (iOS 26, transparency on), the top of the title is blurred under the
Dynamic Island. `viewport-fit=cover` makes iOS report the real insets, so the
same media queries can also keep the title below the island and, in
landscape, the content clear of the notch side:

```css
/* rpn.html: the h2 keeps its own mt-2 margin */
.rpn-page {
  padding-top: env(safe-area-inset-top, 0px);
  padding-left: max(.75rem, env(safe-area-inset-left, 0px));
  padding-right: max(.75rem, env(safe-area-inset-right, 0px));
}

/* nato.html: replaces the existing padding-top: .5rem */
.nato-page {
  padding-top: calc(.5rem + env(safe-area-inset-top, 0px));
  padding-left: max(.75rem, env(safe-area-inset-left, 0px));
  padding-right: max(.75rem, env(safe-area-inset-right, 0px));
}
```

Notes:

* `max(.75rem, …)` keeps `container-fluid`'s own side padding where there is
  no inset (portrait, Android), instead of dropping it to 0.
* In a browser tab, Chrome won't slide its bottom "chin" away when it detects
  padding based on `safe-area-inset-bottom`. These pages don't scroll on
  phones, so it shouldn't matter.
* Without `viewport-fit=cover`, iOS reports insets of 0, so the padding alone
  does nothing there.
* Test the iPhone with transparency on (Settings › Accessibility › Display &
  Text Size › Reduce Transparency off), or the blur doesn't show.

### 2. Dark colors in the manifest for dark mode

The W3C manifest spec defines a dark-mode override
([Web Application Manifest](https://www.w3.org/TR/appmanifest/), "themeable
members"). Chrome on Android may not support it yet; it's ignored if not. Add
to both manifests:

```json
"user_preferences": {
  "color_scheme_dark": {
    "theme_color": "#222222",
    "background_color": "#222222"
  }
}
```

### 3. Force dark (fallback)

If the bar stays white after 1 and 2, set both manifest colors dark:

```json
"background_color": "#222222",
"theme_color": "#222222",
```

This should give a dark bottom bar in both themes, if the bar color comes
from the manifest. Side effects to check:

* The launch screen is dark in light mode too.
* The top status bar may turn dark in light mode, if Chrome now pins it to
  the manifest color (Chromium bug 554055703).

## Testing

1. Apply 1 and 2 together, push, and wait for GitHub Pages to deploy.
2. Manifest changes only reach an installed app when Chrome refreshes it,
   which can take a day or more. Quickest: uninstall and reinstall the app.
   `chrome://webapks` in Chrome on Android lists installed apps with their
   colors and should have a button to request an update.
3. Open each app in light and dark mode and check:
   * the bottom bar area color;
   * the last line of the RPN history and the NATO output isn't under the
     gesture handle (type enough to fill them);
   * the top status bar color;
   * the launch screen color;
   * on an iPhone (transparency on): the title is fully below the Dynamic
     Island in portrait, and the content is clear of the notch side in
     landscape.
4. If the bar is still white, try 3 and repeat.

## Results

* Option 1:
* Option 2:
* Option 3:
