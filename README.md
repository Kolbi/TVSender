# TVSender
TVSender ist im wesentlichen eher ein Macro bzw. Automatisierer für [FHEM](http://www.fhem.de).
Es übernimmt die notwendigen Schritte um mit dem [HTTPMOD Modul](https://wiki.fhem.de/wiki/HTTPMOD) von [StefanStrobel](https://forum.fhem.de/index.php?action=profile;u=3960) das TV-Programm für ausgewählte Sender abzufragen und anzuzeigen. Basis für die Automatisierung ist das Thema [Aktuelles TV Programm in FHEM](https://forum.fhem.de/index.php/topic,28123.0.html) im FHEM Forum.
Die durch die Automatisierung entstehenden Standards ermöglichen es gezielt und relativ einfach die entsprechenden userAttribute und Readings zu verändern.
Die optische Ausgabeformatierung soll kein Ersatz für die wesentlich flexibleren ReadingGroup Devices sein. In einem weiteren Schritt wäre auch die Anlage und Pflege der ReadingGroups denkbar.

Eine ausführlichere Beschreibung befindet sich im **[Wiki](https://github.com/supernova1963/TVSender/wiki)**.

A C H T U N G: 

Die automatische Sortierung der Sender in den HTTPMOD Devices funktioniert jetzt.

H I N W E I S:

Bei *Sendernamen mit Sonderzeichen:*
Definition mit Sonderzeichen bereinigten Device-Name OHNE Angabe des ChannelName. Nachdem der Sender angelegt wurde, diesen in der Detailansicht öffnen und mit dem angebotenen SET - Befehl ChannelName den Sender in der DropDown Liste auswählen und mit dem Knopf set speichern. Wenn danach der SET - Befehl AutoCreate ausgeführt wird wird der korrekte Suchbegriff für die Suche in der HTML Seite erfolgreich umgesetzt.

## Installation
update add https://raw.githubusercontent.com/supernova1963/TVSender/master/controls_TVSender.txt

## Definition
**define** < name> **TVSender** < Channel > \[< ChannelName > < FavoritNr > \]
Am Beispiel "Das Erste", da hier ein Leerzeichen im Suchbegriff (siehe [Aktuelle Suchliste](https://github.com/supernova1963/TVSender/wiki/Aktuelle-Sendersuchliste) )= ChannelName ist, das über die Kommandozeile den folgenden Parameter kennzeichnet durch ein %20 ersetzt werden muss:

    define Das_Erste TVSender 161 Das%20Erste 1

Danach können/sollen/müssen zumindest die Attribute:

 - HarmonyDevice
 - SwitchCommand

individualisiert werden. Anschliessend kann mit 
**set** < name> **autoCreate** **1**
Bespiel:

    set Das_Erste autoCreate 1

die automatischen Erstellung bzw. Pflege der HTTPMOD Devices gestartet werden.
Nach ca. 3 Minuten werden die Readings der HTTPMOD Devices aktualisiert und die aktuellen Daten angezeigt. Über den Raum "TV-Progamm" werden alle automatisch angelegte Devices angezeigt:

![SCREENSHOT](https://github.com/supernova1963/TVSender/blob/master/Screenshot%202017-11-20%20um%2012.58.38.png)

