# Take Measure

App Android (Flutter) per il **rilievo delle misure di una stanza**. Consente di
creare una sessione per ogni stanza, disegnare la sua pianta poligonale con angoli
a 90°/45°, registrare la misura in centimetri di ogni lato e l'altezza da terra di
ogni angolo, e visualizzare la forma in scala reale con perimetro e area calcolati
automaticamente.

## Funzionalità

- **Sessioni per stanza** con nome, salvate localmente sul dispositivo.
- **Disegno a griglia**: si tocca la griglia per aggiungere gli angoli; ogni lato
  viene automaticamente vincolato a 90° o 45° rispetto al precedente.
- **Snap-to-close**: toccando il primo angolo la forma si chiude.
- **Misure dei lati** in centimetri e **altezza da terra** per ogni angolo.
- **Vista in scala reale**: il disegno rispetta le misure inserite.
- **Perimetro e area** (m / m²) calcolati automaticamente (area con formula di Gauss).
- **Sposta/elimina** un singolo angolo (trascina per spostare, tieni premuto per
  eliminare).
- **Esportazione** come immagine **PNG** (con intestazione: nome, data, perimetro,
  area) e come file **JSON** dei dati, condivisibili con il menu di sistema.

## Requisiti

- [Flutter](https://docs.flutter.dev/get-started/install) 3.41 o superiore (Dart 3.11+)
- Android SDK / un dispositivo o emulatore Android

## Avvio

```bash
flutter pub get
flutter run
```

## Build APK

```bash
flutter build apk --release
```

L'APK viene generato in `build/app/outputs/flutter-apk/`.

## Struttura del progetto

```
lib/
  main.dart                     # Entry point e tema
  models/
    measure_session.dart        # Modelli: MeasureSession, Vertex
  services/
    session_repository.dart     # Persistenza locale (shared_preferences, JSON)
    geometry.dart               # Layout schematico/scala, perimetro e area
    export_service.dart         # Esportazione e condivisione PNG / JSON
  widgets/
    measure_painter.dart        # Disegno del poligono e render PNG
  screens/
    home_screen.dart            # Elenco delle sessioni
    editor_screen.dart          # Editor: disegno, misure, altezze, esportazione
```

## Modello dati

Una `MeasureSession` contiene un elenco ordinato di `Vertex`. Ogni vertice ha:

- `gx`, `gy`: posizione sulla griglia (definisce la forma schematica);
- `lengthToNextCm`: misura in cm del lato verso il vertice successivo;
- `heightCm`: altezza da terra registrata su quell'angolo.

Il flag `closed` indica se il poligono è chiuso (ultimo vertice collegato al primo).

## Stato

Progetto in sviluppo. Salvataggio ed esportazione funzionano; possibili estensioni
future: export PDF, tema scuro, modifica delle misure da elenco testuale.
