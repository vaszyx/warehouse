# warehouse

Ein vollständiges Lagerhaus-Skript für das Chezza Inventory v3. Die Ressource erstellt private Lager für jeden Spieler, die automatisch mit dem bestehenden Inventar-System synchronisiert werden.

## Features

* Kompatibel mit ESX und Chezza Inventory v3.
* Individuelle Lagerhäuser pro Spieler mit frei konfigurierbarer Traglast.
* Zwei Beispielstandorte (Vespucci und Sandy Shores) inklusive Blips und Markern.
* Sichere Synchronisation der Lagerbestände (inkl. Datenbank-Backup) und automatische Aktualisierung offener Inventare.
* Server-Exports zum Hinzufügen oder Entfernen von Gegenständen aus beliebigen Lagern.

## Installation

1. Lege den Ressourcen-Ordner in deinem `resources`-Verzeichnis ab und ergänze deine `server.cfg` um `ensure warehouse`.
2. Stelle sicher, dass folgende Abhängigkeiten geladen sind:
   * `es_extended` (mindestens Legacy Version mit `imports.lua`)
   * `oxmysql`
   * Chezza Inventory v3
3. Importiere – sofern noch nicht vorhanden – folgende Tabelle in deine Datenbank:

   ```sql
   CREATE TABLE IF NOT EXISTS `inventories` (
     `type` varchar(50) NOT NULL,
     `identifier` varchar(60) NOT NULL,
     `data` longtext DEFAULT NULL,
     PRIMARY KEY (`type`, `identifier`)
   ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
   ```

## Konfiguration

Alle Einstellungen findest du in der `config.lua`:

* Passe `WarehouseConfig.Warehouses` an, um neue Lagerstandorte (Label, Koordinaten, Gewichtslimit) hinzuzufügen.
* Über `WarehouseConfig.Marker` und `WarehouseConfig.Blip` kannst du Darstellung und Verhalten der Markierungen verändern.
* Weitere Optionen für das Inventar (Blur, Hotbar, Gewichte usw.) sind bereits mit sinnvollen Standardwerten vorbelegt und können bei Bedarf angepasst werden.

## Nutzung

* Bewege dich zu einem markierten Lagerhaus und drücke die im Hilfetext angegebene Taste (`E`), um das Lager zu öffnen.
* Die Lager interagieren vollständig mit dem Chezza-Inventory-UI: Gegenstände lassen sich zwischen Spielerinventar und Lager verschieben, Gewichtsbegrenzungen werden berücksichtigt.
* Über die Exports `AddItemToInventory` und `RemoveItemFromInventory` können andere Ressourcen direkt mit Lagern interagieren.

## Hinweise

* Das Skript erzeugt bei Bedarf automatisch Datenbankeinträge für neue Lager eines Spielers.
* Alle offenen Lager werden beim Verlassen des Servers oder beim Stoppen der Ressource sauber geschlossen.