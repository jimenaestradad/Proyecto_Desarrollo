# Bundled fonts

Fredoka (headlines) and Karla (body and labels), the two families in
`lib/theme/app_text_styles.dart`. They are bundled so text never falls back to Roboto when
the phone is offline or slow on first launch: the `google_fonts` package looks for files named
`<Family>-<Weight>.ttf` in the app's assets before it tries the network.

- Static instances downloaded from `fonts.gstatic.com` using the exact URLs and SHA-256 hashes
  listed in `google_fonts` 8.2.1 (`lib/src/google_fonts_parts/part_f.dart` and the Karla part),
  so these are byte-identical to what the package would fetch.
- Weights: Regular, Medium, SemiBold, Bold. The app uses Fredoka 600/700 and Karla 400/700; the
  rest are here so an unusual weight (a Material default) doesn't trigger a network fetch.
- Licence: SIL Open Font License 1.1 (both families), which allows bundling.
- Adding a family or weight: download it the same way and keep the `<Family>-<Weight>.ttf` name.
