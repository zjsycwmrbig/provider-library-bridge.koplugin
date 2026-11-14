# Third-party notices

## LXGW WenKai Lite

- Upstream: https://github.com/lxgw/LxgwWenKai-Lite
- Distributed file: assets/fonts/LXGWWenKaiLite-Regular.ttf
- License: SIL Open Font License 1.1; see [the bundled OFL](assets/fonts/OFL.txt).
- The original font is redistributed without modification. Its copyright and
  reserved font names are recorded in that license.

The font remains under OFL; the plugin's AGPL license does not replace it.

## KOReader and provider plugins

This plugin runs inside [KOReader](https://github.com/koreader/koreader)
(AGPL-3.0) and calls its Lua modules. KOReader itself is not bundled.

The FanQie and WeRead adapters call installed provider plugin instances; those
plugins, their credentials, cached books and official book covers are not bundled
in this repository or the release archive. Their own licenses and content rights
continue to apply.

The SVG fallback artwork and Lua bridge implementation are distributed under the
root [AGPL-3.0 license](LICENSE). Documentation examples do not contain book text.
