import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

// Prepara le sorgenti icona a partire da assets/icon/measure.png:
//   assets/icon/app_icon.png             (1024 quadrata, sfondo pieno -> legacy)
//   assets/icon/app_icon_foreground.png  (disegno bianco su trasparente -> adattiva)
//   assets/icon/app_icon_background.png  (sfumatura blu coordinata -> adattiva)
//
// Esegui con:  dart run tool/prepare_measure_icon.dart
void main() {
  const s = 1024;
  final src = img.decodePng(File('assets/icon/measure.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('measure.png non trovato/decodificabile');
    exit(1);
  }

  // 1) Master quadrata full-bleed.
  final master = img.copyResize(src,
      width: s, height: s, interpolation: img.Interpolation.cubic);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(master));

  // 2) Foreground: bianco dove c'è il disegno, trasparente sullo sfondo blu.
  //    Chiave sul "quanto è bianco" il pixel (min dei canali alto = bianco).
  final fg = img.Image(width: s, height: s, numChannels: 4);
  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      final p = master.getPixel(x, y);
      final mn = min(p.r, min(p.g, p.b)).toDouble();
      final a = (((mn - 110) / 70).clamp(0.0, 1.0) * 255).round();
      fg.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }
  File('assets/icon/app_icon_foreground.png').writeAsBytesSync(img.encodePng(fg));

  // 3) Background: sfumatura diagonale campionata dagli angoli (senza disegno).
  final tl = _avgPatch(master, 12, 12);
  final br = _avgPatch(master, s - 24, s - 24);
  final bg = img.Image(width: s, height: s, numChannels: 4);
  for (int y = 0; y < s; y++) {
    for (int x = 0; x < s; x++) {
      final t = ((x + y) / (2 * (s - 1))).clamp(0.0, 1.0);
      final r = (tl[0] + (br[0] - tl[0]) * t).round();
      final g = (tl[1] + (br[1] - tl[1]) * t).round();
      final b = (tl[2] + (br[2] - tl[2]) * t).round();
      bg.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  File('assets/icon/app_icon_background.png').writeAsBytesSync(img.encodePng(bg));

  // ignore: avoid_print
  print('Generati: app_icon.png, app_icon_foreground.png, app_icon_background.png');
  // ignore: avoid_print
  print('bg tl=$tl br=$br');
}

List<double> _avgPatch(img.Image im, int cx, int cy) {
  double r = 0, g = 0, b = 0;
  int n = 0;
  for (int y = cy - 6; y <= cy + 6; y++) {
    for (int x = cx - 6; x <= cx + 6; x++) {
      if (x < 0 || y < 0 || x >= im.width || y >= im.height) continue;
      final p = im.getPixel(x, y);
      r += p.r;
      g += p.g;
      b += p.b;
      n++;
    }
  }
  return [r / n, g / n, b / n];
}
