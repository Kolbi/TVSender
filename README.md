# TVSender
TVSender ist im wesentlichen eher ein Macro bzw. Automatisierer für [FHEM](http://www.fhem.de).
Es übernimmt die notwendigen Schritte um mit dem [HTTPMOD Modul](https://wiki.fhem.de/wiki/HTTPMOD) von [StefanStrobel](https://forum.fhem.de/index.php?action=profile;u=3960) das TV-Programm für ausgewählte Sender abzufragen und anzuzeigen. Basis für die Automatisierung ist das Thema [Aktuelles TV Programm in FHEM](https://forum.fhem.de/index.php/topic,28123.0.html) im FHEM Forum.
Die durch die Automatisierung entstehenden Standards ermöglichen es gezielt und relativ einfach die entsprechenden userAttribute und Readings zu verändern.
Die optische Ausgabeformatierung soll kein Ersatz für die wesentlich flexibleren ReadingGroup Devices sein. In einem weiteren Schritt wäre auch die Anlage und Pflege der ReadingGroups denkbar.
## Definition
**define** < name> **TVSender** < Channel > \[< ChannelName > < FavoritNr > \]
Am Beispiel "Das Erste", da hier ein Leerzeichen im Suchbegriff = ChannelName ist, das über die Kommandozeile den folgenden Parameter kennzeichnet durch ein %20 ersetzt werden muss:

    define Das_Erste TVSender 161 Das%20Erste 1

Danach können/sollen/müssen zumindest die Attribute:

 - HarmonyDevice
 - SwitchCommand

individualisiert werden. Anschliessend kann mit 
**set** < name> **autoCreate** **1**
Bespiel:

    set Das_Erste autoCreate 1

die automatischen Erstellung bzw. Pflege der HTTPMOD Devices gestartet werden.
Nach ca. 3 Minuten werden die Readings der HTTPMOD Devices aktualisiert und die aktuellen Daten angezeigt.
![SCREENSHOT](https://github.com/supernova1963/TVSender/blob/master/Screenshot%202017-11-20%20um%2012.58.38.png)

## Was und wie wird automatisiert?
Basis ist ein TV Sender mit den zugeordneten Attributen (hier am Beispiel Das Erste)

 - Name: **Das_Erste** ($name)
 - Kanal (Nr. des TV Receivers): **161** ($Channel)
 - Suchbegriff des TV-Programm Anbieters:
   **Das%20Erste** ($ChannelName = "Das Erste")
 - Favoriten-Nr: **1** ($FavoritNr) 

Mit diesen Angaben werden die HTTPMOD Devices erstellt bzw. gepflegt.

 - TV_Program_NOW
 - TV_Program_NEXT
 - TV_Program_PT
 - TV_Program_PTNEXT
 
Hier werden für o.g. HTTPMOD Devices jeweils die Attribute erstellt:
**userattr** mit dem standardisierten Namensaufbau:
"**reading**"**.**\$ChannelNr(0000)**.**(00|01|..|05) angelegt

- reading0161 **00 = Sender Logo Link**
- reading0161 **01 = Titel**
- reading0161 **02 = Time**
- reading0161 **03 = Description**
- reading0161 **04 = DetailLink**
- reading0161 **05 = Image (Sendungsbild)**

Die daraus entstehenden UserAttribute werden jeweils mit den Wertepaaren "reading.\$Channel(0000).(01 - 05).**Name**“ und „reading.\$Channel(0000).(01 - 05).**Regex**“ belegt.

 - reading016100_Name = \$name."_Logo“  = **Das_Erste_Logo** 
 - reading016100_Regex = Logo_Regex 
 = Regex Filter Logo, Suchbegriff "Das Erste"
 - reading016101_Name = \$name."_Title“ = **Das_Erste_Title**
 - reading016101_Regex = (NOW|NEXT|PT|PTNEXT)_Titel_Regex 
 = Regex Filter Title, Suchbegriff "Das Erste"
 - reading016102_Name = \$name."_Time“ = **Das_Erste_Time**
 - reading016102_Regex = (NOW|NEXT|PT|PTNEXT)_Time_Regex 
 = Regex Filter Time, Suchbegriff "Das Erste"
 - reading016103_Name = \$name."_Description“ = **Das_Erste_Description**
 - reading016103_Regex = (NOW|NEXT|PT|PTNEXT)_Description_Regex 
 = Regex Filter Description, Suchbegriff "Das Erste"
 - reading016104_Name = \$name."_DetailLink“ = **Das_Erste_DetailLink**
 - reading016104_Regex = (NOW|NEXT|PT|PTNEXT)_DetailLink_Regex 
 = Regex Filter DetailLink, Suchbegriff "Das Erste"
 - reading016105_Name = \$name."_Image“ = **Das_Erste_Image**
 - reading016105_Regex = (NOW|NEXT|PT|PTNEXT)_Image_Regex 
 = Regex Filter Image, Suchbegriff "Das Erste"

Ergänzt um die direkt gesetzten Readings:
 - Das_Erste_Channel = AttrVal(\$name,'Channel','')
 - Das_Erste_Sort = AttrVal(\$name,'sortby','')
 - Das_Erste_SwitchCommand = AttrVal(\$name,'SwichtCommand','')

bilden sie entsprechend in den 4 HTTPMOD Devices folgende Readings:

    2017-11-18 12:59:56   Das_Erste_Channel 161 
         2017-11-20 10:39:50   Das_Erste_Description Telenovela, D 2017<br/>Folge: 2812<br/>Laufzeit: 49 Minuten<br/>Mit: Victoria Reich, Julia Alice Ludwig, Alexander Milz, Dirk Galuba, Mona Seefried, Marion Mitterhammer<br/>Regie: Sabine Landgraeber<br/><br/>Obwohl Viktor versucht, Alicias Verdacht zu zerstreuen, bleibt sie verunsichert. Sie fühlt sogar Boris auf den Zahn, doch der deckt seinen Bruder. 
         2017-11-20 10:39:50   Das_Erste_DetailLink /tv-programm/fernsehsendung/5164013/sturm-der-liebe.html 
         2017-11-20 10:39:50   Das_Erste_Image http://funke.images.dvbdata.com/5419647/5419647_176x120.jpg 
         2017-11-20 10:39:50   Das_Erste_Logo  http://images.klack.de/images/stories/stations/../stations-mobile/large/ard.png 
         2017-11-18 12:59:56   Das_Erste_Sort  0161 
         2017-11-18 12:59:56   Das_Erste_SwitchCommand set harmony_34915526 command Number1;set harmony_34915526 command Number6;set harmony_34915526 command Number1;set harmony_34915526 command Select; 
         2017-11-20 10:39:50   Das_Erste_Time  09:55 
         2017-11-20 10:39:50   Das_Erste_Title Sturm der Liebe 

Damit diese Inahlte auch im einzelnen TVSender Device zur Verfügung stehen werden die Ereignisse der 4 HTTPMOD Devices überwacht und bei Änderung die entsprechenden Readings dem TV-Sender Device gepflegt:
 - TV_Program_NEXT_Description 
 - TV_Program_NEXT_DetailLink
 - TV_Program_NEXT_Time
 - TV_Program_NEXT_Title
 - TV_Program_NOW_Description
 - TV_Program_NOW_DetailLink
 - TV_Program_NOW_Image
 - TV_Program_NOW_Time
 - TV_Program_NOW_Title
 - TV_Program_PTNEXT_Description
 - TV_Program_PTNEXT_DetailLink
 - TV_Program_PTNEXT_Image
 - TV_Program_PTNEXT_Time
 - TV_Program_PTNEXT_Title
 - TV_Program_PT_Description
 - TV_Program_PT_Image
 - TV_Program_PT_Time
 - TV_Program_PT_Title
 
 
 
