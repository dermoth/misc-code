# UTF-8 Codecs

These scripts are a POC to encode and decode Unicode using underscore-encoded
(`_`) UTF-8 hex values.

The encoded values can be 1–4 bytes long (2–8 hex characters in 2-character
increments). The length is determined by the UTF-8 standard.

## Scripts

* [`utf8encode`](utf8encode): encodes each argument and prints it on its own
  line. ASCII letters, digits and `.` are kept as-is; every other character,
  including `_`, becomes `_` followed by its UTF-8 bytes in hex.
* [`utf8decode`](utf8decode): decodes each argument back to UTF-8 and prints
  it on its own line.

```console
$ utf8encode '_foo⁽™⁾bar🐍'
_5ffoo_e281bd_e284a2_e281bebar_f09f908d
$ utf8decode _5ffoo_e281bd_e284a2_e281bebar_f09f908d
_foo⁽™⁾bar🐍
```

The source repo is on GitHub: <https://github.com/dermoth/misc-code>

## References

[UTF-8 on Wikipedia](https://en.wikipedia.org/wiki/UTF-8)
