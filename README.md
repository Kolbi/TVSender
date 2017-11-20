# TVSender
TVSender ist im wesentlichen eher ein Macro bzw. Automatisierer für [FHEM](http://www.fhem.de).
Es übernimmt die notwendigen Schritte um mit dem [HTTPMOD Modul](https://wiki.fhem.de/wiki/HTTPMOD) von [StefanStrobel](https://forum.fhem.de/index.php?action=profile;u=3960) das TV-Programm für ausgewählte Sender abzufragen und anzuzeigen. Basis für die Automatisierung ist das Thema [Aktuelles TV Programm in FHEM](https://forum.fhem.de/index.php/topic,28123.0.html) im FHEM Forum.
Die durch die Automatisierung entstehenden Standards ermöglichen es gezielt und relativ einfach die entsprechenden userAttribute und Readings zu verändern.
Die optische Ausgabeformatierung soll kein Ersatz für die wesentlich flexibleren ReadingGroup Devices sein. In einem weiteren Schritt wäre auch die Anlage und Pflege der ReadingGroups denkbar.
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

 - reading016100_Name = $name."_Logo“  = **Das_Erste_Logo** 
 - reading016100_Regex = Logo_Regex 
 = Regex Filter Logo, Suchbegriff "Das Erste"
 - reading016101_Name = $name."_Title“ = **Das_Erste_Title**
 - reading016101_Regex = (NOW|NEXT|PT|PTNEXT)_Titel_Regex 
 = Regex Filter Title, Suchbegriff "Das Erste"
 - reading016102_Name = $name."_Time“ = **Das_Erste_Time**
 - reading016102_Regex = (NOW|NEXT|PT|PTNEXT)_Time_Regex 
 = Regex Filter Time, Suchbegriff "Das Erste"
 - reading016103_Name = $name."_Description“ = **Das_Erste_Description**
 - reading016103_Regex = (NOW|NEXT|PT|PTNEXT)_Description_Regex 
 = Regex Filter Description, Suchbegriff "Das Erste"
 - reading016104_Name = $name."_DetailLink“ = **Das_Erste_DetailLink**
 - reading016104_Regex = (NOW|NEXT|PT|PTNEXT)_DetailLink_Regex 
 = Regex Filter DetailLink, Suchbegriff "Das Erste"
 - reading016105_Name = $name."_Image“ = **Das_Erste_Image**
 - reading016105_Regex = (NOW|NEXT|PT|PTNEXT)_Image_Regex 
 = Regex Filter Image, Suchbegriff "Das Erste"

Das TVSender Device stellt die folgenden Internals für die Anlage bzw. Erweiterung der HTTMOD Devices zur Verfügung:

    Internals:
    DEF        161 Das%20Erste
    Logo_Regex title="Das Erste"><img[\w\W]*?src="\s*[\w\W]*?\s*(.*?)\s*" alt= 
    NAME       Das_Erste 
    NEXT_Description_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img 
    NEXT_DetailLink_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title= 
    NEXT_Image_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt= 
    NEXT_Time_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div 
    NEXT_Title_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a> 
    NOTIFYDEV  global,TV_Program_NOW,TV_Program_NEXT,TV_Program_PT,TV_Program_PTNEXT 
    NOW_Description_Regex title="Das Erste"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img 
    NOW_DetailLink_Regex title="Das Erste"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title= 
    NOW_Image_Regex title="Das Erste"><img[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt= 
    NOW_Time_Regex title="Das Erste"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/> 
    NOW_Title_Regex title="Das Erste"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a> 
    NR         36 
    NTFY_ORDER 50-Das_Erste 
    PTNEXT_Description_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img 
    PTNEXT_DetailLink_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title= 
    PTNEXT_Image_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt= 
    PTNEXT_Time_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div 
    PTNEXT_Title_Regex title="Das Erste"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a> 
    PT_Description_Regex title="Das Erste"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img 
    PT_DetailLink_Regex title="Das Erste"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title= 
    PT_Image_Regex title="Das Erste"><img[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt= 
    PT_Time_Regex title="Das Erste"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/> 
    PT_Title_Regex title="Das Erste"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a> 
    STATE      <table width=100% ><tr><td style="text-align: center;background-color: #e0e0e0" colspan=3 >A  K  T  U  E  L  L</td></tr><tr><td style="vertical-align: top;width: 50px;font-size: larger" >09:55</td><td style="vertical-align: top"><p><a href="/fhem?cmd=set%20Das_Erste%20Switch2Channel%201" style="font-weight: bold;font-size: larger">Sturm der Liebe</a></p>Telenovela, D 2017<br/>Folge: 2812<br/>Laufzeit: 49 Minuten<br/>Mit: Victoria Reich, Julia Alice Ludwig, Alexander Milz, Dirk Galuba, Mona Seefried, Marion Mitterhammer<br/>Regie: Sabine Landgraeber<br/><br/>Obwohl Viktor versucht, Alicias Verdacht zu zerstreuen, bleibt sie verunsichert. Sie fühlt sogar Boris auf den Zahn, doch der deckt seinen Bruder.</td><td style="vertical-align: top;width: 200px" ><html><a href='http://www.klack.de/tv-programm/fernsehsendung/5164013/sturm-der-liebe.html'><img src='http://funke.images.dvbdata.com/5419647/5419647_176x120.jpg'></a></html></td></tr><tr><td style="text-align: center;background-color: #e0e0e0" colspan=3 >A  N  S  C  H  L  I  E  S  S  E  N  D</td></tr><tr><td style="vertical-align: top;width:50px;font-size: larger" >10:44</td><td style="vertical-align: top"><p style="font-weight: bold;font-size: larger" >Tagesschau - Mit Wetter</p>Nachrichten, D 2017<br/>Laufzeit: 1 Minuten<br/>Original-Titel: Tagesschau<br/><br/>Die beste Adresse um an tagesaktuelle Nachrichten und Information zu kommen. An 365 Tagen im Jahr rund um die Uhr aktualisiert bietet tagesschau.</td><td style="vertical-align: top;width: 200px" ><html><a href='http://www.klack.de/tv-programm/fernsehsendung/5164053/tagesschau-mit-wetter.html'><img src='http://funke.images.dvbdata.com/1056561/1056561_176x120.jpg'></a></html></td></tr><tr><td style="text-align: center;background-color: #e0e0e0" colspan=3 >P  R  I  M  E    T  I  M  E</td></tr><tr><td style="vertical-align: top;width: 50px;font-size: larger" >20:15</td><td style="vertical-align: top"><p style="font-weight: bold;font-size: larger">Boris Becker - Der Spieler</p>Porträt, D 2017<br/>Laufzeit: 90 Minuten<br/><br/>Am Mittwoch wird Deutschlands größter Tennisspieler Boris Becker 50. Seit seinem Wimbledon-Triumph 1985 schreibt er Schlagzeilen, oft leider auch...</td><td style="vertical-align: top;width: 200px" ><html><a href='http://www.klack.de/tv-programm/fernsehsendung/5164011/boris-becker-der-spieler.html'><img src='http://funke.images.dvbdata.com/5263702/5263702_176x120.jpg'></a></html></td></tr><tr><td style="text-align: center;background-color: #e0e0e0" colspan=3 >D  A  N  A  C  H</td></tr><tr><td style="vertical-align:top;width: 50px;font-size: larger" >21:45</td><td style="vertical-align: top" ><p style="font-weight: bold;font-size: larger" >Tagesthemen - Mit Wetter</p>Nachrichten, D 2017<br/>Laufzeit: 30 Minuten<br/>Original-Titel: Tagesthemen<br/><br/>Aktuelle Themen aus Politik, Wirtschaft, Kultur, Sport, Gesellschaft und Wissenschaft aus dem In- und Ausland werden in ausführlichen...</td><td style="vertical-align: top;width: 200px" ><html><a href='http://www.klack.de/tv-programm/fernsehsendung/5164047/tagesthemen-mit-wetter.html'><img src='http://funke.images.dvbdata.com/1056587/1056587_176x120.jpg'></a></html></td></tr></table> 
    TV_Program_NEXT TV_Program_NEXT 
    TV_Program_NEXT_URL http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html 
    TV_Program_NOW TV_Program_NOW 
    TV_Program_NOW_URL http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html 
    TV_Program_PT TV_Program_PT 
    TV_Program_PTNEXT TV_Program_PTNEXT 
    TV_Program_PTNEXT_URL http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html 
    TV_Program_PT_URL http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html 
    TYPE       TVSender

  
