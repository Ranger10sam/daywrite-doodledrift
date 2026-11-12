# DoodleDrift asset licenses

All assets are bundled locally. The game does not download fonts, music or graphics at runtime.

## Fonts

The following authentic, unmodified TrueType fonts were obtained from the official [Google Fonts repository](https://github.com/google/fonts) on 12 November 2026. Some local filenames were shortened; the font contents were not modified. All are licensed under the **SIL Open Font License 1.1**, which permits bundling and use in commercial software subject to its terms. The complete license and copyright notice accompany each font below; retain them when redistributing the project or its bundled fonts.

| Asset and use | Creator / copyright | Official source | License and notices | Attribution requirement |
|---|---|---|---|---|
| **Fredoka** variable font — DoodleDrift logo, headings and buttons. Local file: `assets/fonts/Fredoka-Variable.ttf` | Milena Brandão, Hafontia. Copyright 2016 The Fredoka Project Authors | [Google Fonts Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka), [upstream Fredoka](https://github.com/hafontia-zz/Fredoka-One) | [Fredoka-OFL.txt](assets/fonts/Fredoka-OFL.txt), SIL OFL 1.1 | Retain the copyright and OFL notice with the font; an on-screen credit is not required by that license |
| **Nunito** variable font — settings, descriptions, numerical indicators and general UI. Local file: `assets/fonts/Nunito-Variable.ttf` | Vernon Adams, Cyreal, Jacques Le Bailly. Copyright 2014 The Nunito Project Authors | [Google Fonts Nunito](https://github.com/google/fonts/tree/main/ofl/nunito), [upstream Nunito](https://github.com/googlefonts/nunito) | [Nunito-OFL.txt](assets/fonts/Nunito-OFL.txt), SIL OFL 1.1 | Retain the copyright and OFL notice with the font; an on-screen credit is not required by that license |
| **Noto Sans Symbols** variable font — offline arrow fallback. Local file: `assets/fonts/NotoSansSymbols-Variable.ttf` | Google / The Noto Project Authors. Copyright 2022 The Noto Project Authors | [Official Google Fonts source](https://github.com/google/fonts/tree/main/ofl/notosanssymbols), [upstream Noto symbols](https://github.com/notofonts/symbols) | [NotoSansSymbols-OFL.txt](assets/fonts/NotoSansSymbols-OFL.txt), SIL OFL 1.1 | Retain copyright and OFL notice with the font; no separate on-screen credit is required |
| **Noto Sans Symbols 2** — offline checkmark and mastery-symbol fallback. Local file: `assets/fonts/NotoSansSymbols2-Regular.ttf` | Google / The Noto Project Authors. Copyright 2022 The Noto Project Authors | [Official Google Fonts source](https://github.com/google/fonts/tree/main/ofl/notosanssymbols2), [upstream Noto symbols](https://github.com/notofonts/symbols) | [NotoSansSymbols2-OFL.txt](assets/fonts/NotoSansSymbols2-OFL.txt), SIL OFL 1.1 | Retain copyright and OFL notice with the font; no separate on-screen credit is required |

Downloaded files can be checked against these SHA-256 hashes:

```text
Fredoka-Variable.ttf  2ba02e68b152868aef9ba28e24b3648c7d457fe6f25c761f2c2c53fb61a73fc8
Fredoka-OFL.txt       5c9e7eee5c6b25f4b05b8d53b2e470ea4962f9ced742d044a98f7d95d1375bab
Nunito-Variable.ttf   bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207
Nunito-OFL.txt        580df76c95a1ec5ab878ceb25bb3d85c6a076804e9c970c8c6972aea775fdf65
NotoSansSymbols-Variable.ttf  f7e7e04b4a24b6c78893d50cbfd2b2f6cae49617ab047bfef668d252adb128f7
NotoSansSymbols2-Regular.ttf  7d5fb73b7ca67a6798101741f5d280a3d016a56a197afcd4199dbb57b4b82a21
NotoSansSymbols-OFL.txt      b118dd41337806a5d4797052c77caf3bd096aed783e5eb21b4d11154351e1ac0
NotoSansSymbols2-OFL.txt     b118dd41337806a5d4797052c77caf3bd096aed783e5eb21b4d11154351e1ac0
```

The UI includes both Noto symbol faces to render arrows, checkmarks and mastery marks without relying on Windows or Android system fonts. Godot's bundled font remains the final fallback if a font resource is unavailable. Normal offline play uses the bundled resources and needs no font service.

## Original audio

DoodleDrift's music, biome ambience and sound effects are original procedural project content, distributed under the project's [MIT license](LICENSE). No commercial music, streamed sound, third-party samples or generic "royalty-free" assets are included. See [DOODLEDRIFT_AUDIO.md](docs/DOODLEDRIFT_AUDIO.md) for synthesis, source files and validation details. There is no separate third-party attribution requirement for this original content.

## Original graphics

The rolling ball, menu illustration, ink glyphs and structures, landscapes, particles, icons and splash graphics are original programmatic project artwork under the project's [MIT license](LICENSE). No stock image pack or external texture library is required.
