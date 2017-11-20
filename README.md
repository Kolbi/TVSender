# TVSender
TVSender ist im wesentlichen eher ein Macro bzw. Automatisierer.
Es übernimmt die notwendigen Schritte um mit dem HTTPMOD Modul das TV-Programm für ausgewählte Sender abzufragen und anzuzeigen.
Die daraus entstehenden Standards ermöglichen es gezielt und relativ einfach die entsprechenden userAttribute und Readings zu verändern.
Die optische Ausgabeformatierung soll kein Ersatz für die wesentlich flexibleren ReadingGroup Devices sein. In einem weiteren Schritt wäre auch die Anlage und Pflege der ReadingGroups denkbar.
## Was und wie wird automatisiert?
Basis ist ein TV Sender mit den zugeordneten Attributen (hier am Beispiel Das Erste)
* Name: **Das_Erste**
* Kanal (Nr. des TV Receivers): **161** ($Channel)
* Suchbegriff des TV-Programm Anbieters: **Das%20Erste** ($ChannelName = "Das Erste")
* Favoriten-Nr: **1** ($FavoritNr)
Mit diesen Angaben werden die HTTPMOD Devices erstellt bzw. gepflegt.
* TV_Program_NOW
* TV_Program_NEXT
* TV_Program_PT
* TV_Program_PTNEXT
Hier werden für o.g. HTTPMOD Devices jeweils die Attribute erstellt:
* **userattr** mit dem standardisierten Namensaufbau, "reading".ChannelNr(0000).ErgebnisID(00) angelegt
    * reading016100 = Sender Logo Link
    * reading016101 = Titel
    * reading016102 = Time
    * reading016103 = Description 
    * reading016104 = DetailLink
    * reading016105 = Image (Sendungsbild)
* Die daraus entstehenden UserAttribute werden jeweils mit den Wertepaaren „reading.$Channel(0000).(01 - 05).**Name**“ und „reading$Channel(0000).(01 - 05).**Regex**“ belegt.
    * reading016100_Name = (Sendermodulname)$name."_Logo“ = **Das_Erste_Logo** 
    * reading016100_Regex = Logo_Regex = Regex Filter Logo, Suchbegriff "Das Erste"
    * reading016101_Name = $name."_Title“ = **Das_Erste_Title**
    * reading016101_Regex = (NOW|NEXT|PT|PTNEXT)_Titel_Regex = Regex Filter Title, Suchbegriff "Das Erste"
    * reading016102_Name = $name."_Time“ = **Das_Erste_Time**
    * reading016102_Regex = (NOW|NEXT|PT|PTNEXT)_Time_Regex = Regex Filter Time, Suchbegriff "Das Erste"
    * reading016103_Name = $Sendermodulname."_Description“ = **Das_Erste_Description**
    * reading016103_Regex = (NOW|NEXT|PT|PTNEXT)_Description_Regex = Regex Filter Description, Suchbegriff "Das Erste"
    * reading016104_Name = $name."_DetailLink“ = **Das_Erste_DetailLink**
    * reading016104_Regex = (NOW|NEXT|PT|PTNEXT)_DetailLink_Regex = Regex Filter DetailLink, Suchbegriff "Das Erste"
    * reading016105_Name = $name."_Image“ = **Das_Erste_Image**
    * reading016105_Regex = (NOW|NEXT|PT|PTNEXT)_Image_Regex = Regex Filter Image, Suchbegriff "Das Erste"
  


