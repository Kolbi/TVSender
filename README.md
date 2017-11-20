#TVSender
TVSender ist im wesentlichen eher ein Macro bzw. Automatisierer.
Es übernimmt die notwendigen Schritte um mit dem HTTPMOD Modul das TV-Programm für ausgewählte Sender abzufragen und anzuzeigen.
Die daraus entstehenden Standards ermöglichen es gezielt und relativ einfach die entsprechenden userAttribute und Readings zu verändern.
Die optische Ausgabeformatierung soll kein Ersatz für die wesentlich flexibleren ReadingGroup Devices sein. In einem weiteren Schritt wäre auch die Anlage und Pflege der ReadingGroups denkbar.
## Was und wie wird automatisiert?
Basis ist ein TV Sender mit den zugeordneten Attributen 
* Name
* Kanal (Nr. des TV Receivers)
* Suchbegriff des TV-Programm Anbieters
* Favoriten-Nr
Mit diesen Angaben werden die HTTPMOD Devices erstellt bzw. gepflegt.
* TV_Program_NOW
* TV_Program_NEXT
* TV_Program_PT
* TV_Program_PTNEXT
Hier werden jeweils die Attribute 
* **userattr** mit dem standardisierten Namensaufbau, "reading".ChannelNr(0000).ErgebnisID(00) angelegt:
    * reading016100 = Sender Logo Link
    * reading016101 = Titel
    * reading016102 = Time
    * reading016103 = Description 
    * reading016104 = DetailLink
    * reading016105 = Image (Sendungsbild)
* Die daraus entstehenden UserAttribute werden jeweils mit den Wertepaaren „reading......Name“ und „reading......Regex“ belegt.
    * reading016100_Name = $Sendermodulname."_Logo“
    * reading016100_Regex = Regex aus Internal (TVSender) für das Logo
    * reading016101_Name = $Sendermodulname."_Title“
    * reading016101_Regex = Regex aus Internal (TVSender) für den Titel
    * reading016102_Name = $Sendermodulname."_Time“
    * reading016102_Regex = Regex aus Internal (TVSender) für den Time
    * reading016103_Name = $Sendermodulname."_Description“
    * reading016103_Regex = Regex aus Internal (TVSender) für Description
    * reading016104_Name = $Sendermodulname."_DetailLink“
    * reading016104_Regex = Regex aus Internal (TVSender) für den DetailLink
    * reading016105_Name = $Sendermodulname."_Image“
    * reading016105_Regex = Regex aus Internal (TVSender) für das Image
    * reading016102 = Time
    * reading016103 = Description 
    * reading016104 = DetailLink
    * reading016105 = Image (Sendungsbild)


