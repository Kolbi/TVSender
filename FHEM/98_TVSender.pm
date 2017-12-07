package main;
use strict;
use warnings;




# my %TVSender_gets = (
# );


# Bitte pflegen, wird als Internal abgelegt
use vars qw{$TVSender_version};

$TVSender_version="0.3.3";


# FHEM Standard: x_Intitialisierung
sub TVSender_Initialize($) {
    my ($hash) = @_;
    $hash->{DefFn}      = 'TVSender_Define';
    $hash->{UndefFn}    = 'TVSender_Undef';
    $hash->{SetFn}      = 'TVSender_Set';
    $hash->{GetFn}      = 'TVSender_Get';
    $hash->{AttrFn}     = 'TVSender_Attr';
    $hash->{ReadFn}     = 'TVSender_Read';
    $hash->{RenameFn}   = "TVSender_Rename";
    $hash->{NotifyFn}   = 'TVSender_Notify';
    $hash->{AsyncOutputFn}   = 'TVSender_AsyncOutput';

    $hash->{AttrList} = " Channel".     # Kanal-Nr. zum umschalten
    " ChannelName".                     # Sendername für die Suche im TV-Programm
    " Description".                     # Beschreibung allgemein
    " Logo".                            # relativ zu opt/fhem/www/images
    " HarmonyDevice".                   # TV/Receiver device in FHEM
    " SwitchCommand".                   # Vollständiger Befehl zum Sender umschalten
    #" SwitchCommandTimer".              # Vollständiger Befehl zum Umschalten setzen
    #" RecordCommandTimer".              # Vollständiger Befehl zum Umschalten setzen
    " NrFavorit".                       # Favoriten Nr = sortby
    " tvCurrentlyUrl".
    " tv2015Url".
    " tvCurrentlyRegEx".
    " tv2015RegEx".
    " interval".
    " ".$readingFnAttributes;
}
# FHEM Standard: x_Define
sub TVSender_Define($$) {

    my ( $hash, $def ) = @_;
    
    my @a = split( "[ \t][ \t]*", $def );

    
    return "too few parameters: define <name> TVSender <Channel> [<ChannelName>] [<NrFavorit>]" if( $a[0] ne "TVSenderBridge" and @a < 3 and @a > 5 );
    
    my $name            = $a[0];
    my $Channel         = $a[2] if( defined($a[2]) );
    my $ChannelName     = $a[3] if( defined($a[3]) );
    my $NrFavorit       = $a[4] if( defined($a[4]) );
    $hash->{CHANNEL}    = $Channel if( defined($Channel) );
  
    if( not $hash->{CHANNEL} ) {
        return "there is already a TVSender Bridge, did you want to define a TVSender Client use: define <name> TVSender <Channel> [<ChannelName>] [<NrFavorit>]" if( $modules{TVSender}{defptr}{BRIDGE} );

        $hash->{BRIDGE}                     = 1;
        $modules{TVSender}{defptr}{BRIDGE}  = $hash;
        $hash->{INTERVAL}                   = 1800;
        $hash->{NOTIFYDEV}                  = "global";
        $hash->{actionQueue}                = [];
        
        CommandAttr(undef,$name.' room TV-Programm') if( AttrVal($name,'room','none') eq 'none');
        CommandAttr(undef,$name.' tvCurrentlyUrl was-laeuft-gerade/0/0/all.html') if( AttrVal($name,'tvCurrentlyUrl','none') eq 'none');
        CommandAttr(undef,$name.' tv2015Url 2015-im-tv/0/0/all.html') if( AttrVal($name,'tv2015Url','none') eq 'none');
        
        readingsSingleUpdate ( $hash, "state", "initialized", 1 );
    
        Log3 $name, 3, "TVSender ($name) - defined Bridge";

    } else {
        if( not $modules{TVSender}{defptr}{BRIDGE} and $init_done ) {
            CommandDefine( undef, "TVSenderBridge TVSender" );    
        }
        
        my $Senderwechselbefehl = "";
        my $i = 0;
        my $httpmoddevice = "";
        my $httpmoddevice_url = "";
        my $errors = "";
        my $cmds = "";
        my $regex = "";
        my $subst = '';
        ### Parameter mindesten 4
        
        ### TVSender_version aktualisieren ###
        $hash->{Version} = $TVSender_version;

        ### Attribut prüfen, setzen und pflegen ###
        ##### Attribut Chanel = Receiver Kanal darf nach erstem AutoCreate nicht verändert werden!
        ##### Ist Basis für userattr und readings der HTTPMOD Devices
        ##### Ist Pflicht - Parameter [2] bei der Erstellung
        $attr{$name}{"Channel"} = $Channel if (!defined($attr{$name}{"Channel"}));
        ##### Attribut: ChanelName = Sendersuchbegriffe in kl**k.de. Kann über TVSender Attribut gepflegt werden.
        ##### Optionaler Parameter [3] bei Erstellung. Wird nicht überschrieben, wenn vorhanden!
        if (!defined($ChannelName)) {
            $ChannelName = $name;
        }
        $regex = qr/%20/p;
        $subst = ' ';
        $ChannelName = $ChannelName =~ s/$regex/$subst/rg;
        $attr{$name}{"ChannelName"} = $ChannelName if (!defined($attr{$name}{"ChannelName"}));
        ##### Attribut: Description = derzeit nicht weiter genutzt, wird nicht überschrieben, wennVorhanden
        $attr{$name}{"Description"} = $name." = ".$ChannelName if (!defined($attr{$name}{"Description"}));
        ##### Attribut: Logo = Standardpfad zur Senderlogo Datei
        ##### Änderungen über das Attribut werden nicht überschrieben, wenn vorhanden
        $attr{$name}{"Logo"} = "/opt/fhem/www/images/default/tvlogos/".$name.".png" if (!defined($attr{$name}{"Logo"}));
        ##### Internal Variable: ermittelt in HTTPMOD Devices die URL für das Senderlogo
        $hash->{Logo_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?src="\s*[\w\W]*?\s*(.*?)\s*" alt=';
        ##### Attribut: HarmonyDevice = Besser in FHEM definiertes TV Receiver Devive, wird nicht überschrieben, wenn vorhanden
        ##### Soll für die automatisierte SwitchCommand Generierung verwendet werden, wird nicht überschrieben, wenn vorhanden
        $attr{$name}{"HarmonyDevice"} = "harmony_34915526" if (!defined($attr{$name}{"HarmonyDevice"}));
        ##### Attribut: SwitchCommand = FHEM Befehle für das umschalten auf einen Receiver-Kanal
        ##### Wird derzeit als Muster vorbelegt, muss individualisiert werden !!! Wird nicht überschrieben, wenn vorhanden
        $Senderwechselbefehl = "";
        foreach $i (0..length($Channel)-1) {
            $Senderwechselbefehl = $Senderwechselbefehl.'set '.AttrVal($name,"HarmonyDevice","").' command Number'.substr($Channel, $i,0).';;';
        }
        $Senderwechselbefehl = $Senderwechselbefehl.'set '.AttrVal($name,"HarmonyDevice","").' command Select;;';
        $attr{$name}{"SwitchCommand"} = $Senderwechselbefehl if (!defined($attr{$name}{"SwitchCommand"}));
        ##### Attribut: NrFavorit wird für die Sortierung der Sender in rooms, groups und stateFormat Tabellen der HTTPMOD Devices
        ##### Optionaler Parameter [4], wird nicht überschrieben, wenn vorhanden
        ##### FHEM Standard Attribut: sortby wird parallel (mit führenden Nullen) zu NrFavorit gepflegt
        $NrFavorit = $Channel if (!defined($NrFavorit));
        if (defined($NrFavorit) or ($NrFavorit > 0)) {
            $attr{$name}{"NrFavorit"} = $NrFavorit;
            $attr{$name}{"sortby"} = substr("0000".$NrFavorit, -4, 4);
        }
        else {
            $attr{$name}{"sortby"} = substr("0000".$Channel, -4, 4) if (!defined($attr{$name}{"sortby"}) or $attr{$name}{"sortby"} != substr("0000".$Channel, -4, 4));
        }
        
        CommandAttr(undef,$name.' room TV-Programm') if( AttrVal($name,'room','none') eq 'none');
        
        ### Vorgaben für Regex setzen
        TVSender_Change_Regex_Defaults($hash);
        ### stateFormat setzen  ###
        TVSender_stateFormat($hash);
        ### Überwachung ob FHEM Initialisierung abgeschlossen ist und auf Veränderungen in den HTTPMOD Devices
        my $notifiedDevices = 'global';
        $notifiedDevices = $notifiedDevices.','
            .InternalVal($name,"TV_Program_NOW","TV_Program_NOW").','
            .InternalVal($name,"TV_Program_NEXT","TV_Program_NEXT").','
            .InternalVal($name,"TV_Program_PT","TV_Program_PT").','
            .InternalVal($name,"TV_Program_PTNEXT","TV_Program_PTNEXT");
        $hash->{NOTIFYDEV} = $notifiedDevices;
        
        $modules{TVSender}{defptr}{$hash->{CHANNEL}} = $hash;
    }
    
    return undef;
}

### Hier beginnen die noch nicht umgesetzten Vorschläge für Prozeduren (wenn diese hier stehen: z.Zt. noch ohne Funktion)
# Pflege der userattr in den HTTPMOD Devices
sub TVSender_Update_HTTPMOD_Device_userattr($$) {
    my ($hash,$httpmoddevice) = @_;
    my $name = $hash->{"NAME"};
    my $cmd = '';
    my $errors = '';

}
# Pfege der _Name _Regex Wertepaare für die userReadings der HTTMOD Devices
sub TVSender_Update_HTTPMOD_Device_Regexes($$) {
    my ($hash,$httpmoddevice) = @_;
    my $name = $hash->{"NAME"};
    my $cmd = '';
    my $errors = '';

}
# Pflege des stateFormat Attributes des TVSender Devices
sub TVSender_Update_stateFormat($$) {
    my ($hash,$httpmoddevice) = @_;
    my $name = $hash->{"NAME"};
    my $cmd = '';
    my $errors = '';

}
# Offene Erweiterungen ...
###

# sub TV_Sender_Set_SwitchCommnand_Timer($$) {
    #   my ($hash,$time,$Channel) = @_;
    #   my $name = $hash->{"NAME"};
    #   my ($SWhour,$SWmin) = split($time,":");
    #   my $cmd = '';
    #   my $errors = '';
    #   my ($sec, $min, $hour, $mday, $month, $year) = TimeNow();
    #   my $timestamp = fhemTimeLocal(0, $SWmin, $SWhour, $mday, $month, $year);
    #   my $functionName = AttrVal($name,"SwitchCommand","");
    #   InternalTimer($timestamp, $functionName, $hash);
# }
# Regex Vorgaben setzen bzw. ändern
sub TVSender_Change_Regex_Defaults($) {
    my ($hash) = @_;
    
    if( $hash->{CHANNEL} ) {
        my $name = $hash->{"NAME"};
        my $cmd = '';
        my $errors = '';
        my $ChannelName = AttrVal($name,"ChannelName",undef);
        ##### Internal Variable: ermittelt in HTTPMOD Devices die URL für das Senderlogo
        ##### Sie können nur mit Versions-Updates gepflegt werden
        $hash->{Logo_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?src="\s*[\w\W]*?\s*(.*?)\s*" alt=';
        ##### Internal Variablen für die Namen der HTTPMOD Devices festlegen
        ##### Sie können nur mit Versions-Updates gepflegt werden
        $hash->{TV_Program_NOW} = "TV_Program_NOW";
        $hash->{TV_Program_NEXT} = "TV_Program_NEXT";
        $hash->{TV_Program_PT} = "TV_Program_PT";
        $hash->{TV_Program_PTNEXT} = "TV_Program_PTNEXT";
        ##### Internal Variable: Vorgabe URL für TV_Program_NOW, TV_Program_NEXT, TV_Program_PT, TV_Program_PTNEXT
        ##### Sie können nur mit Versions-Updates gepflegt werden
        $hash->{TV_Program_NOW_URL} = "http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html";
        $hash->{TV_Program_NEXT_URL} = "http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html";
        $hash->{TV_Program_PT_URL} = "http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html";
        $hash->{TV_Program_PTNEXT_URL} = "http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html";
        ##### Internal Variablen: Vorgabe Regex
        ##### Sie können nur mit Versions-Updates gepflegt werden
        $hash->{FindChannelList_Regex} = qr/<tr class="[\w\W]*?Row">[\w\W]*?<td class="station">[\w\W]*?title="\s*(.*?)\s*"><img class/p;
        ##### RegexVorgabenNOW_setzen
        ####### für aktuelle laufende Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
        $hash->{NOW_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
        $hash->{NOW_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/>';
        $hash->{NOW_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
        $hash->{NOW_Image_Regex} = '<td class="image left">[\s]*<a[\s]*href[^>]* title="'.$ChannelName.':[^>]*><img\s*class="epgImage" src="(.*?)"';
        $hash->{NOW_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
        ####### RegexVorgabenNEXT_setzen ### für anschliessend laufende Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
        $hash->{NEXT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
        $hash->{NEXT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div';
        $hash->{NEXT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
        $hash->{NEXT_Image_Regex} = '<td class="image">[\s]*<a[\s]*href[^>]* title="'.$ChannelName.':[^>]*><img\s*class="epgImage" src="(.*?)"';
        $hash->{NEXT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
        ####### RegexVorgabenPT_setzten ### für zur PrimeTime laufenden Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
        $hash->{PT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
        $hash->{PT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/>';
        $hash->{PT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
        $hash->{PT_Image_Regex} = '<td class="image left">[\s]*<a[\s]*href[^>]* title="'.$ChannelName.':[^>]*><img\s*class="epgImage" src="(.*?)"';
        $hash->{PT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
        ####### RegexVorgabenPTNEXT_setzen ### für nach der PrimeTime laufenden Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
        $hash->{PTNEXT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
        $hash->{PTNEXT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div';
        $hash->{PTNEXT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
        $hash->{PTNEXT_Image_Regex} = '<td class="image">[\s]*<a[\s]*href[^>]* title="'.$ChannelName.':[^>]*><img\s*class="epgImage" src="(.*?)"';
        $hash->{PTNEXT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
    }
}

# (NonBlocking) download des Senderlogos nach /opt/fhem/www/imgages/default/tvlogos
sub TVSender_WGET_SenderLogo($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $logofile = AttrVal($name,'Logo','/opt/fhem/www/images/default/tvlogos/'.$name.'\.png');
  my $regex = qr/\/opt/p;
  my $subst = '';
  my $logolocal = $logofile =~ s/$regex/$subst/rg;
  $regex = qr/\/$name\.png/p;
  $subst = '';
  my $logopath = $logofile =~ s/$regex/$subst/rg;
  my $cmd = '';
  my $errors = '';
  unless (-f "$logofile") {
    -e "mkdir($logopath)";
    $cmd = 'wget '.ReadingsVal($httpmoddevice,$name."_Logo","").' -O '.AttrVal($name,"Logo","/opt/fhem/www/images/default/tvlogos/$name\.png");
    $errors = `$cmd`;
    if (!defined($errors)) {
      #Log3($ownName, 3, 'Sucsessfully new defined/changed readings to '.$ownName.'!');
      $cmd = 'setreading '.$name.' Logo <html><img src="'.$logolocal.'" /></html>;'
      .'setreading '.$name.' Logo_URL '.$logolocal.';';
      $errors = AnalyzeCommandChain (undef, $cmd);
      if (!defined($errors)) {
        #Log3($ownName, 3, 'Sucsessfully new defined/changed readings to '.$ownName.'!');
      }
      else {
        Log3($name, 5, 'Change readings from TVSender_WGET_SenderLogo cause error: '.$errors.'!');
        Log3($name, 5, $cmd);
      }
    }
    else {
      Log3($name, 5, 'TVSender_WGET_SenderLogo cause an error: '.$errors.'!');
      Log3($name, 5, $cmd);
    }
  }
}
# Sortierfunktion für die Tabelle in den HTTPMOD Devices
sub TVSender_Sort_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $fav = substr("0000".AttrVal($name,"NrFavorit","9999"), -4, 4);
  my $cmd = '';
  my $errors = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  my $regex = qr/<tr id = [\w\W]*?_Title<\/a><\/td><\/tr>/p;  my $subst = '';
  my @senderrows = $stateformat =~ /$regex/g;
  #Log3($name, 3, "Anzahl: @senderrows");
  #Log3($name, 3, "stateFormat: $stateformat");
  @senderrows = sort @senderrows;
  my $sortedstateformat = join('',@senderrows);
  $sortedstateformat = '<table width=100% >'.$sortedstateformat.'</table>';
  $regex = qr/;/p;
  $subst = ';;';
  $sortedstateformat = $sortedstateformat =~ s/$regex/$subst/rg;
  $cmd = 'attr '.$httpmoddevice.' stateFormat '.$sortedstateformat.';';
  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  if (!defined($errors)) {
    #Log3($name, 3, 'Sucsessfully new defined/changed stateFormat to '.$httpmoddevice.'!');
    }
  else {
    Log3($name, 5, 'Sorting stateFormat from '.$httpmoddevice.' cause error: '.$errors.'!');
    Log3($name, 5, $cmd);
  }
}
# Alle Definitionen erneut ausführen
sub TVSender_Parameter_update ($) {
  my ($hash) = @_;
  my $name = $hash->{"NAME"};
  my $nameNOW = InternalVal($name,"TV_Program_NOW","TV_Program_NOW");
  my $nameNEXT = InternalVal($name,"TV_Program_NEXT","TV_Program_NEXT");
  my $namePT = InternalVal($name,"TV_Program_PT","TV_Program_PT");
  my $namePTNEXT = InternalVal($name,"TV_Program_PTNEXT","TV_Program_PTNEXT");

  TVSender_Add_HTTPMOD_Device($hash,$nameNOW,"Es läuft",1);
  TVSender_Add_HTTPMOD_Device($hash,$nameNOW,"Anschliessend",2);
  TVSender_Add_HTTPMOD_Device($hash,$nameNOW,"Zur PrimeTime",3);
  TVSender_Add_HTTPMOD_Device($hash,$nameNOW,"Danach",4);
  TVSender_Change_HTTPMOD_Device_userattr($hash,$nameNOW);
  TVSender_Change_HTTPMOD_Device_userattr($hash,$nameNEXT);
  TVSender_Change_HTTPMOD_Device_userattr($hash,$namePT);
  TVSender_Change_HTTPMOD_Device_userattr($hash,$namePTNEXT);
  TVSender_Change_HTTPMOD_Device_stateformat($hash,$nameNOW);
  TVSender_Change_HTTPMOD_Device_stateformat($hash,$nameNEXT);
  TVSender_Change_HTTPMOD_Device_stateformat($hash,$namePT);
  TVSender_Change_HTTPMOD_Device_stateformat($hash,$namePTNEXT);
  TVSender_Sort_HTTPMOD_Device_stateformat($hash,$nameNOW);
  TVSender_Sort_HTTPMOD_Device_stateformat($hash,$nameNEXT);
  TVSender_Sort_HTTPMOD_Device_stateformat($hash,$namePT);
  TVSender_Sort_HTTPMOD_Device_stateformat($hash,$namePTNEXT);

  TVSender_stateFormat($hash);
}
# Überwachung der 4 HTTPMOD Devices zur Pflege der Readings in TVSender Device
sub TVSender_Notify($$) {

    my ($own_hash, $dev_hash) = @_;
    
    my $bhash = $modules{TVSender}{defptr}{BRIDGE};         #ermitteln des korrekten Hash Wertes vom Bridge Device
    
    my $ownName = $own_hash->{NAME}; # own name / hash
    my $daytime = "";
    my $regex = "";
    my $subst = "";
    return if(IsDisabled($ownName)); # Return without any further action if the module is disabled
    my $devName = $dev_hash->{NAME}; # Device that created the events
    my $events = deviceEvents($dev_hash,1);
    my $logofile = AttrVal($ownName,'Logo','/opt/fhem/www/images/default/tvlogos/'.$ownName.'\.png');
    $regex = qr/\/opt/p;
    $subst = '';
    my $logolocal = $logofile =~ s/$regex/$subst/rg;
    $regex = qr/\/$ownName\.png/p;
    $subst = '';
    my $logopath = $logofile =~ s/$regex/$subst/rg;
    my $cmd = '';
    my $errors = '';
    return if( !$events );
    
    
    if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
    {
      #TVSender_StatusRequest($own_hash,InternalVal($ownName,"TV_Program_NOW","TV_Program_NOW"));

    }
    
    TVSender_TimerGetData($bhash) if( (grep /^INITIALIZED$/,@{$events}
                                                or grep /^DELETEATTR.$devName.disable$/,@{$events}
                                                or grep /^DELETEATTR.$devName.interval$/,@{$events}
                                                or grep /^MODIFIED.$devName$/,@{$events} 
                                                or (grep /^DEFINED.$devName$/,@{$events} and $init_done)) and $own_hash eq $bhash);
    
    
    
    foreach my $event (@{$events})
    {
      $event = "" if(!defined($event));
      if ($devName eq InternalVal($ownName,"TV_Program_NOW","TV_Program_NOW")) {
        $daytime = "_NOW";

        TVSender_WGET_SenderLogo($own_hash,$devName);
      }
      elsif ($devName eq InternalVal($ownName,"TV_Program_NEXT","TV_Program_NEXT")) {
        $daytime = "_NEXT";
      }
      elsif ($devName eq InternalVal($ownName,"TV_Program_PT","TV_Program_PT")) {
        $daytime = "_PT";
      }
      elsif ($devName eq InternalVal($ownName,"TV_Program_PTNEXT","TV_Program_PTNEXT")) {
        $daytime = "_PTNEXT";
      }
      else {

      }
      if ($devName eq InternalVal($ownName,"TV_Program_NOW","TV_Program_NOW") || $devName eq InternalVal($ownName,"TV_Program_NEXT","TV_Program_NEXT") || $devName eq InternalVal($ownName,"TV_Program_PT","TV_Program_PT") || $devName eq InternalVal($ownName,"TV_Program_PTNEXT","TV_Program_PTNEXT")) {
        $cmd = 'setreading '.$ownName.' Logo <html><img src="'.$logolocal.'" /></html>;'
        .'setreading '.$ownName.' Logo_URL '.$logolocal.';'
        .'setreading '.$ownName.' '.$devName.'_Time '.ReadingsVal($devName,$ownName.'_Time','00:00').';'
        .'setreading '.$ownName.' '.$devName.'_Title '.ReadingsVal($devName,$ownName.'_Title','Nicht vorhanden ...').';'
        .'setreading '.$ownName.' '.$devName.'_Description '.ReadingsVal($devName,$ownName.'_Description','Nicht vorhanden ...').';'
        .'setreading '.$ownName.' '.$devName.'_DetailLink <html><a href=\''.ReadingsVal($devName,$ownName.'_DetailLink','').'</a></html>;'
        .'setreading '.$ownName.' '.$devName.'_DetailLink_URL http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','').';'
        .'setreading '.$ownName.' '.$devName.'_Image_URL '.ReadingsVal($devName,$ownName.'_Image','./fhem/www/images/default/10px-kreis-rot.png').';'
        .'setreading '.$ownName.' '.$devName.'_Image <html><a href=\'http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','').'\'><img src=\''.ReadingsVal($devName,$ownName.'_Image','./fhem/www/images/default/10px-kreis-rot.png').'\'></a></html>;';
        $errors = '';
        $errors = AnalyzeCommandChain (undef, $cmd);
        if (!defined($errors)) {
          #Log3($ownName, 3, 'Sucsessfully new defined/changed readings to '.$ownName.'!');
        }
        else {
          Log3($ownName, 5, 'Notify '.$event.' changed readings to '.$ownName.' cause error: '.$errors.'!');
          Log3($ownName, 5, $cmd);
        }
      }
    }
    #TVSender_stateFormat($own_hash);
}
# StateFormat für den Sender setzen
sub TVSender_stateFormat($) {
  my ($hash) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $nameNOW = InternalVal($name,"TV_Program_NOW","TV_Program_NOW");
  my $nameNEXT = InternalVal($name,"TV_Program_NEXT","TV_Program_NEXT");
  my $namePT = InternalVal($name,"TV_Program_PT","TV_Program_PT");
  my $namePTNEXT = InternalVal($name,"TV_Program_PTNEXT","TV_Program_PTNEXT");
  my $stateformat = '<table width=100% >'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >A  K  T  U  E  L  L</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.$nameNOW.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger" ><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" >'.$nameNOW.'_Title</a><br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.$nameNOW.'_Description</div></td>'
    .'<td style="vertical-align: middle;;width: 200px;;text-align: center" >'.$nameNOW.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >A  N  S  C  H  L  I  E  S  S  E  N  D</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.$nameNEXT.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger">'.$nameNEXT.'_Title<br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.$nameNEXT.'_Description</div></td>'
    .'<td style="vertical-align: middle;;width: 200px;;text-align: center" >'.$nameNEXT.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >P  R  I  M  E    T  I  M  E</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.$namePT.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger" >'.$namePT.'_Title<br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.$namePT.'_Description</div></td>'
    .'<td style="vertical-align: middle;;width: 200px;;text-align: center" >'.$namePT.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >D  A  N  A  C  H</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.$namePTNEXT.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger" >'.$namePTNEXT.'_Title<br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.$namePTNEXT.'_Description</div></td>'
    .'<td style="vertical-align: middle;;width: 200px;;text-align: center" >'.$namePTNEXT.'_Image</td></tr></table>';
  $cmd = 'attr '.$name.' stateFormat '.$stateformat;
  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  if (!defined($errors)) {
    #Log3($name, 3, 'Sucsessfully new defined/changed stateFormat to '.$name.'!');
    }
  else {
    Log3($name, 5, 'Definition new attributs/changed stateFormat to '.$name.' cause error: '.$errors.'!');
    Log3($name, 5, $cmd);
  }
}
# HTTPMOD Devices TV_Program_NOW, TV_Program_NEXT, TV_Program_PT und TV_Program_PTNEXT anlegen
sub TVSender_Add_HTTPMOD_Device($$$$) {
  # Devive TVProgram_xxx noch nicht vorhanden?
  my ($hash,$httpmoddevice,$alias,$sort) = @_;
  my $name = $hash->{"NAME"};
  my $errors = "";
  my $cmds = "";
  my $httpmoddevice_url = InternalVal($name,$httpmoddevice."_URL","Fehler");
  my $TV_Program_hash = $defs{$httpmoddevice};
  if (!$TV_Program_hash) {
    $httpmoddevice_url = InternalVal($name,$httpmoddevice.'_URL',undef);
    $errors = '';
    if ($httpmoddevice eq InternalVal($name,"TV_Program_NOW","TV_Program_NOW") || $httpmoddevice eq InternalVal($name,"TV_Program_NEXT","TV_Program_NEXT")) {
      $cmds = 'defmod '.$httpmoddevice.' HTTPMOD '.$httpmoddevice_url.' 120; ';
    }
    if ($httpmoddevice eq InternalVal($name,"TV_Program_PT","TV_Program_PT") || $httpmoddevice eq InternalVal($name,"TV_Program_PTNEXT","TV_Program_PTNEXT")) {
      $cmds = 'defmod '.$httpmoddevice.' HTTPMOD '.$httpmoddevice_url.' 3600; ';
    }
    $cmds = $cmds.''
      .'attr '.$httpmoddevice.' timeout 30;'
      .'attr '.$httpmoddevice.' alias '.$alias.':;'
      .'attr '.$httpmoddevice.' sortby '.$sort.';'
      .'attr '.$httpmoddevice.' verbose 3;'
      .'attr '.$httpmoddevice.' enableControlSet 1;'
      .'attr '.$httpmoddevice.' event-on-update-reading .*_Title;'
      .'attr '.$httpmoddevice.' room TV-Programm;';
      #.'attr '.$httpmoddevice.' get1Name ReCallURL;'
      #.'attr '.$httpmoddevice.' get1URL '.InternalVal($name,$httpmoddevice."_URL","error").';';

    $errors = AnalyzeCommandChain ($hash,$cmds);
    if (!defined($errors)) {
      #Log3($name, 3, "Sucsessfully defined device $httpmoddevice!");
    }
    else {
      Log3($name, 5, "Definition device: $httpmoddevice cause error: $errors !");
      Log3($name, 5, $cmds);
      return "Fehler bei der Anlage des Devices $httpmoddevice !"
    }
  }
  else {
    $cmds = "";
    if (!defined(AttrVal($httpmoddevice,"timeout",undef))) {
      $cmds = 'attr '.$httpmoddevice.' timeout 20;';
    }
    if (!defined(AttrVal($httpmoddevice,"alias",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' alias Es läuft:;';
    }
    if (!defined(AttrVal($httpmoddevice,"sortby",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' sortby '.$sort.';';
    }
    if (!defined(AttrVal($httpmoddevice,"verbose",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' verbose 3;';
    }
    if (!defined(AttrVal($httpmoddevice,"enableControlSet",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' enableControlSet 1;';
    }
    if (!defined(AttrVal($httpmoddevice,"event-on-update-reading",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' event-on-update-reading .*_Title;;';
    }
    if (!defined(AttrVal($httpmoddevice,"room",undef))) {
      $cmds = $cmds.'attr '.$httpmoddevice.' room TV-Programm;';
    }
    if ($cmds ne '') {
      $errors = AnalyzeCommandChain ($hash,$cmds);
      if (!defined($errors)) {
        #Log3($name, 3, "Sucsessfully checked device $httpmoddevice!");
      }
      else {
        Log3($name, 5, "Check device: $httpmoddevice cause error: $errors !");
        Log3($name, 5, $cmds);
        return "Fehler bei der Prüfung des Devices $httpmoddevice !"
      }
    }

  }
}
# userattr der HTTMOD Devices des Senders anlegen oder ändern
sub TVSender_Change_HTTPMOD_Device_userattr($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $readingsnamepart = 'reading'.substr("0000".AttrVal($name,"Channel",undef), -4, 4); # Nummerierung der userAttribute: reading+Channel mit führenden 0000
  my $code = 0;
  my $clock = '';
  my $daytime = '';
  my $regex = '';
  my $subst = '';
  my $userattribut = AttrVal($httpmoddevice,'userattr','');
  my $userattributneu = ''
    .$readingsnamepart.'00Name '        # 00: Senderlogo Wertepaar für _Logo Name definieren
    .$readingsnamepart.'00Regex '       # 00: Senderlogo Wertepaar für _Logo Regex definieren
    .$readingsnamepart.'01Name '        # 01: Titel Wertepaar für NEXT_Titel Name definieren
    .$readingsnamepart.'01Regex '       # 01: Titel Wertepaar für NEXT_Titel Regex definieren
    .$readingsnamepart.'02Name '        # 02: Time Wertepaar für NEXT_Time Name definieren
    .$readingsnamepart.'02Regex '       # 02: Time Wertepaar für NEXT_Time Regex definieren
    .$readingsnamepart.'03Name '        # 03: Description Wertepaar für NEXT_Description Name definieren
    .$readingsnamepart.'03Regex '       # 03: Description Wertepaar für NEXT_Description Regex definieren
    .$readingsnamepart.'04Name '        # 04: DetailLink Wertepaar für NEXT_DetailLink Name definieren
    .$readingsnamepart.'04Regex '       # 04: DetailLink Wertepaar für NEXT_DetailLink Regex definieren
    .$readingsnamepart.'05Name '        # 05: Image Wertepaar für NEXT_Image Name definieren
    .$readingsnamepart.'05Regex ';       # 05: Image Wertepaar für NEXT_Image Regex definieren

  if (index($httpmoddevice,'_NOW') != -1) {
    $code = 0;
    $clock = 'NOW';
  }
  if (index($httpmoddevice,'_NEXT') != -1) {
    $code = 1;
    $clock = 'NEXT';
  }
  if (index($httpmoddevice,'_PT') != -1) {
    $code = 2;
    $clock = 'PT';
  }
  if (index($httpmoddevice,'_PTNEXT') != -1) {
    $code = 3;
    $clock = 'PTNEXT';
  }

  if (!defined(AttrVal($httpmoddevice,'userattr',undef))) {
    # userattr wird neu definiert
    $errors = '';
    $errors = AnalyzeCommandChain (undef,'attr '.$httpmoddevice.' userattr '.$userattributneu.';');
    if (!defined($errors)) {
      #Log3($name, 3, 'Sucsessfully set new userattr to '.$httpmoddevice.'!');
    }
    else {
      Log3($name, 5, 'Definition of new useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
      Log3($name, 5, 'attr '.$httpmoddevice.' userattr '.$userattributneu.';');
    }
  }
  elsif (index($userattribut,$userattributneu) != -1) {
    #userattr wird ergänzt, wenn die neuen nicht oder nur teilweise enthalten sind
    $regex = qr/$readingsnamepart\d\d(?:Name\s|Regex\s|Regex|Name)/p;
    $subst = '';
    $userattribut = $userattribut =~ s/$regex/$subst/rg;
    $errors = '';
    $errors = AnalyzeCommandChain (undef, 'attr '.$httpmoddevice.' userattr '.$userattribut.' '.$userattributneu.';');
    if (!defined($errors)) {
        #Log3($name, 3, 'Sucsessfully update userattr to '.$httpmoddevice.'!');
    }
    else {
        Log3($name, 5, 'Update of useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
        Log3($name, 5, 'attr '.$httpmoddevice.' userattr '.$userattribut.' '.$userattributneu.';');
    }
  }
  else {
    #userattr bleibt unverändert, da bereits vorhanden
    $errors = '';
    $errors = AnalyzeCommandChain (undef, 'attr '.$httpmoddevice.' userattr '.$userattribut.';');
    if (!defined($errors)) {
        #Log3($name, 3, 'Sucsessfully update userattr to '.$httpmoddevice.'!');
    }
    else {
        Log3($name, 5, 'Update of useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
        Log3($name, 5, 'attr '.$httpmoddevice.' userattr '.$userattribut.' '.$userattributneu.';');
    }
  }
  # Definition der Name/Regesx Wertepaare der userAttribute wir erstellt bzw. aktualisiert
  $cmd = ''
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'00Name '.$name.'_Logo'.';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'00Regex '.InternalVal($name,'Logo_Regex','').';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'01Name '.$name.'_Title;'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'01Regex '.InternalVal($name,$clock.'_Title_Regex','').';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'02Name '.$name.'_Time;'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'02Regex '.InternalVal($name,$clock.'_Time_Regex','').';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'03Name '.$name.'_Description;'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'03Regex '.InternalVal($name,$clock.'_Description_Regex','').';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'04Name '.$name.'_DetailLink;'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'04Regex '.InternalVal($name,$clock.'_DetailLink_Regex','').';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'05Name '.$name.'_Image'.';'
    .'attr '.$httpmoddevice.' '.$readingsnamepart.'05Regex '.InternalVal($name,$clock.'_Image_Regex','').';'
    .'setreading '.$httpmoddevice.' '.$name.'_Channel '.AttrVal($name,'Channel','').';'
    .'setreading '.$httpmoddevice.' '.$name.'_Sort '.AttrVal($name,'sortby','').';'
    .'setreading '.$httpmoddevice.' '.$name.'_SwitchCommand '.AttrVal($name,'SwitchCommand','').';';

  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  if (!defined($errors)) {
    #Log3($name, 5, 'Sucsessfully new/changed attributs to '.$httpmoddevice.'!');
  }
  else {
    Log3($name, 5, 'Definition new/changed attributs to/of '.$httpmoddevice.' cause error: '.$errors.'!');
    Log3($name, 5, $cmd);
  }
}
# stateFormat der HTTPMOD Devices des Senders festlegen
sub TVSender_Change_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $fav = substr("0000".AttrVal($name,"NrFavorit","9999"), -4, 4);
  my $cmd = '';
  my $errors = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  my $regex = qr/<tr id = "$fav" title = "$name">[\w\W]*?$name\_Title<\/a><\/td><\/tr>/p;
  my $subst = '';
  my $stateformat_exists = $stateformat =~ /$regex/g;
  my $getcmd = '';
  my $popup = '<a href="http://www.klack.de'.ReadingsVal($httpmoddevice,$name."_DetailLink","").'?popup=details">';
  if ($stateformat eq '') {
    ### Das stateFormat Attribut des HTTPMOD Devive ist noch nicht gesetzt => stateFormat erstmalig setzen
    $stateformat = '<table width=100% >'
    .'<tr id = "'.$fav.'" title = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;text-align: right;;width: 50px;;font-size: larger"><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;text-align: center;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;text-align: left;;font-size: larger">'.$popup.''.$name.'_Title</a></td>'
    .'</tr></table>';
  }
  elsif ($stateformat_exists){
    ### Das stateFormat Attribut des HTTPMOD Devive enthält bereits einen Eintrag zu diesem Sender => löschen + anhängen
    $regex = qr/<tr id = "[\d\d\d\d]*?" title = "$name">[\w\W]*?$name\_Title<\/a><\/td><\/tr>/p;
    $subst = '';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $regex = qr/<\/table>/p;
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $regex = qr/;/p;
    $subst = ';;';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $stateformat = $stateformat.'<tr id = "'.$fav.'" title = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;text-align: right;;width: 50px;;font-size: larger"><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;text-align: center;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;text-align: left;;font-size: larger">'.$popup.''.$name.'_Title</a></td>'
    .'</tr></table>';
  }
  else {
    ### Das stateFormat Attribut wurde gesetzt, enthält aber nicht diesen Sender => anhängen!
    my $regex = qr/<\/table>/p;
    my $subst = '';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $regex = qr/;/p;
    $subst = ';;';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $stateformat = $stateformat.'<tr id = "'.$fav.'" title = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;text-align: right;;width: 50px;;font-size: larger"><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;text-align: center;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;text-align: left;;font-size: larger">'.$popup.''.$name.'_Title</a></td>'
    .'</tr></table>';
  }
  $cmd = 'attr '.$httpmoddevice.' stateFormat '.$stateformat.';';
  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  if (!defined($errors)) {
    #Log3($name, 3, 'Sucsessfully new defined/changed stateFormat to '.$httpmoddevice.'!');
    }
  else {
    Log3($name, 5, 'Definition new attributs/changed stateFormat to '.$httpmoddevice.' cause error: '.$errors.'!');
    Log3($name, 5, $cmd);
  }
}
# userattr der HTTPMOD Devices des Senders löschen
sub TVSender_Delete_HTTPMOD_Device_userattr($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $readingsnamepart = 'reading'.substr("0000".AttrVal($name,'Channel','0000'), -4, 4); # Nummerierung der userAttribute: reading+sortby= Channel mit führenden 0000
  my $code = 0;
  my $clock = '';
  my $daytime = '';
  my $regex = '';
  my $subst = '';
  my $userattribut = AttrVal($httpmoddevice,'userattr','');
  my $userattrname = "";
  my $userattr = "";
  $cmd = "";
  for my $i (0..99){
    $userattrname = $readingsnamepart.substr("00".$i,-2,2);
    if (defined(AttrVal($httpmoddevice,$userattrname."Name",undef))) {
      #$userattribut = substr($userattribut,$userattrname." ","");
      $cmd = $cmd.'attr '.$httpmoddevice.' userattr '.$userattribut.';';
      $cmd = $cmd.'deleteattr '.$httpmoddevice.' '.$userattrname.'Name;';
    }
    if (defined(AttrVal($httpmoddevice,$userattrname."Regex",undef))){
      $cmd = $cmd.'deleteattr '.$httpmoddevice.' '.$userattrname.'Regex;';
    }
  }
  $regex = qr/$readingsnamepart\d\d[Regex |Name ]*/p;
  $subst = '';
  $userattribut = $userattribut =~ s/$regex/$subst/rg;
  $cmd = $cmd.'attr '.$httpmoddevice.' userattr '.$userattribut.';';
  $cmd = $cmd.'deletereading '.$httpmoddevice.' '.$name.'.*;';
  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  $errors = $errors.AnalyzeCommandChain (undef, 'deleteattr '.$userattrname.'Regex;');
  if (!defined($errors)) {
      #Log3($name, 3, 'Sucsessfully deleted userattr to '.$httpmoddevice.'!');
  }
  else {
      Log3($name, 5, 'Update deleted useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
  }

    # my $userattributdelete = ''
    #   .$readingsnamepart.'00Name '        # 00: Senderlogo Wertepaar für _Logo Name definieren
    #   .$readingsnamepart.'00Regex '        # 00: Senderlogo Wertepaar für _Logo Regex definieren
    #   .$readingsnamepart.'01Name '        # 01: Titel Wertepaar für NEXT_Titel Name definieren
    #   .$readingsnamepart.'01Regex '       # 01: Titel Wertepaar für NEXT_Titel Regex definieren
    #   .$readingsnamepart.'02Name '        # 02: Time Wertepaar für NEXT_Time Name definieren
    #   .$readingsnamepart.'02Regex '       # 02: Time Wertepaar für NEXT_Time Regex definieren
    #   .$readingsnamepart.'03Name '        # 03: Description Wertepaar für NEXT_Description Name definieren
    #   .$readingsnamepart.'03Regex '       # 03: Description Wertepaar für NEXT_Description Regex definieren
    #   .$readingsnamepart.'04Name '        # 04: DetailLink Wertepaar für NEXT_DetailLink Name definieren
    #   .$readingsnamepart.'04Regex '       # 04: DetailLink Wertepaar für NEXT_DetailLink Regex definieren
    #   .$readingsnamepart.'05Name '        # 05: Image Wertepaar für NEXT_Image Name definieren
    #   .$readingsnamepart.'05Regex';       # 05: Image Wertepaar für NEXT_Image Regex definieren
    #
    # if (index($userattributdelete,$userattribut) != -1) {
    #   #userattr wird ergänzt, wenn die neuen nicht oder nur teilweise enthalten sind
    #   $regex = qr/$readingsnamepart\d\d(?:Name\s|Regex\s|Regex|Name)/p;
    #   $subst = '';
    #   $userattribut = $userattribut =~ s/$regex/$subst/rg;
    #   $errors = '';
    #   $errors = AnalyzeCommandChain (undef, 'attr '.$httpmoddevice.' userattr '.$userattribut.';');
    #   if (!defined($errors)) {
    #       #Log3($name, 3, 'Sucsessfully update userattr to '.$httpmoddevice.'!');
    #   }
    #   else {
    #       Log3($name, 5, 'Update of useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
    #   }
    # $cmd = ''
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'00Name;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'00Regex;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'01Name;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'01Regex;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'02Name;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'02Regex;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Name'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Regex;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'04Name;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Regex;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'05Name;'
    #   .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'05Regex;'
    #   .'deletereading '.$httpmoddevice.' '.$name.'_SwitchCommand;'
    #   .'deletereading '.$httpmoddevice.' '.$name.'_Channel;'
    #   .'deletereading '.$httpmoddevice.' '.$name.'_Sort;'
    #   .'deletereading '.$httpmoddevice.' '.$name.'.*;';
    # $errors = '';
    # $errors = AnalyzeCommandChain (undef, $cmd);
    # if (!defined($errors)) {
    #   #Log3($name, 3, 'Sucsessfully deleted attributs to '.$httpmoddevice.'!');
    # }
    # else {
    #   Log3($name, 5, 'Delete attributs to/of '.$httpmoddevice.' cause error: '.$errors.'!');
    #   Log3($name, 5, $cmd);
    # }
}
# stateFormat der HTTPMOD Devices des Senders entfernen
sub TVSender_Delete_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $fav = substr("0000".AttrVal($name,"NrFavorit","9999"), -4, 4);
  my $cmd = '';
  my $errors = '';
  my $regex = '';
  my $subst = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  $regex = qr/<tr id = "$fav" title = "$name">[\w\W]*?$name\_Title<\/a><\/td><\/tr>/p;
  $subst = '';
  $stateformat = $stateformat =~ s/$regex/$subst/rg;
  $regex = qr/;/p;
  $subst = ';;';
  $stateformat = $stateformat =~ s/$regex/$subst/rg;
  $cmd = 'attr '.$httpmoddevice.' stateFormat '.$stateformat.';';
  $errors = '';
  $errors = AnalyzeCommandChain (undef, $cmd);
  if (!defined($errors)) {
    #Log3($name, 3, 'Sucsessfully deleted row of stateFormat to '.$httpmoddevice.'!');
    }
  else {
    Log3($name, 5, 'Delete row of stateFormat '.$httpmoddevice.' cause error: '.$errors.'!');
    Log3($name, 5, $cmd);
  }
}
# Löschen des Senders und entfernen der Einträge in den HTTPMOD Devices
sub TVSender_Undef($$) {
    my ($hash, $arg) = @_;
    my $name = $hash->{"NAME"};
    
    
    
    if( $hash->{BRIDGE} ) {
        RemoveInternalTimer( $hash );
        delete $modules{TVSender}{defptr}{BRIDGE} if( defined($modules{TVSender}{defptr}{BRIDGE}) and $hash->{BRIDGE} );
    } 
    
    elsif( $hash->{CHANNEL} ) {

        delete $modules{TVSender}{defptr}{$hash->{CHANNEL}};
    
        my $errors = "";
        my $cmd = "";
        my $readingsnamepart = "reading".AttrVal($name,"sortby","");
        my $regex = '';
        my $subst = '';
        my $httpmoddevice = '';
        $httpmoddevice = InternalVal($name,'TV_Program_NOW','TV_Program_NOW');
        TVSender_Delete_HTTPMOD_Device_userattr($hash,$httpmoddevice);
        TVSender_Delete_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
        $httpmoddevice = InternalVal($name,'TV_Program_NEXT','TV_Program_NEXT');
        TVSender_Delete_HTTPMOD_Device_userattr($hash,$httpmoddevice);
        TVSender_Delete_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
        $httpmoddevice = InternalVal($name,'TV_Program_PT','TV_Program_PT');
        TVSender_Delete_HTTPMOD_Device_userattr($hash,$httpmoddevice);
        TVSender_Delete_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
        $httpmoddevice = InternalVal($name,'TV_Program_PTNEXT','TV_Program_PTNEXT');
        TVSender_Delete_HTTPMOD_Device_userattr($hash,$httpmoddevice);
        TVSender_Delete_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
        $cmd = 'rm '.AttrVal($name,"Logo","");
        $errors = `$cmd`;
    
    
    
        foreach my $d(sort keys %{$modules{TVSender}{defptr}}) {
            my $hash = $modules{TVSender}{defptr}{$d};
            my $client = $hash->{CHANNEL};

            return if( $client );
            my $name = $hash->{NAME};
            CommandDelete( undef, $name );
        }
    }

    return undef;
}
# Umbenennung ist nicht möglich
sub TVSender_Rename($$) {
  my ( $new_name, $old_name) = @_;
  return "Diese Funtion ist z.Zt. nicht möglich, bitte Device: $old_name löschen und als $new_name neu anlegen!"
}
# Z.Zt. ohne Funktionen
sub TVSender_Get($@) {
  my ($hash, $name, $cmd, @args) = @_;
  my ($arg, @params) = @args;
  my $list = '';
  my $table = '';

  if ($cmd eq 'AktuelleSendung') {
    $table = '<html><table width=650px >'
      .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >A  K  T  U  E  L  L</td></tr>'
      .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.ReadingsVal($name,"TV_Program_NOW_Time","").'</td>'
      .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger;;width: 400px;;white-space: normal" ><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" >'.ReadingsVal($name,"TV_Program_NOW_Title","").'</a><br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.ReadingsVal($name,"TV_Program_NOW_Description","").'</div></td>'
      .'<td style="vertical-align: top;;width: 200px" >'.ReadingsVal($name,"TV_Program_NOW_Image","").'</td></tr>'.'</table></html>';
    return $table;
  }
  elsif ($cmd eq 'NächsteSendung') {
    $table = '<html><table width=650px >'
      .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >A  N  S  C  H  L  I  E  S  S  E  N  D</td></tr>'
      .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.ReadingsVal($name,"TV_Program_NEXT_Time","").'</td>'
      .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger;;width: 400px;;white-space: normal" ><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" >'.ReadingsVal($name,"TV_Program_NEXT_Title","").'</a><br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.ReadingsVal($name,"TV_Program_NEXT_Description","").'</div></td>'
      .'<td style="vertical-align: top;;width: 200px" >'.ReadingsVal($name,"TV_Program_NEXT_Image","").'</td></tr>'.'</table></html>';
    return $table;
  }
  elsif ($cmd eq 'PrimeTimeSendung') {
    $table = '<html><table width=650px >'
      .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >P  R  I  M  E    T  I  M  E</td></tr>'
      .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.ReadingsVal($name,"TV_Program_PT_Time","").'</td>'
      .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger;;width: 400px;;white-space: normal" ><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" >'.ReadingsVal($name,"TV_Program_PT_Title","").'</a><br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.ReadingsVal($name,"TV_Program_PT_Description","").'</div></td>'
      .'<td style="vertical-align: top;;width: 200px" >'.ReadingsVal($name,"TV_Program_PT_Image","").'</td></tr>'.'</table></html>';
    return $table;
   }
  elsif ($cmd eq 'PrimeTimeSendungfolgend') {
    $table = '<html><table width=650px >'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0;;color: black" colspan=3 >D  A  N  A  C  H</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;font-size: larger;;width: 50px" >'.ReadingsVal($name,"TV_Program_PTNEXT_Time","").'</td>'
    .'<td style="vertical-align: top;;text-align: left;;font-weight: bold;;font-size: larger;;width: 400px;;white-space: normal" ><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" >'.ReadingsVal($name,"TV_Program_PTNEXT_Title","").'</a><br /><div style="vertical-align: top;;text-align: left;;font-weight: initial;;font-size: smaller">'.ReadingsVal($name,"TV_Program_PTNEXT_Description","").'</div></td>'
    .'<td style="vertical-align: top;;width: 200px" >'.ReadingsVal($name,"TV_Program_PTNEXT_Image","").'</td></tr>'.'</table></html>';
    return $table;
    }
    
    elsif ($cmd eq 'update') {
        if( not IsDisabled($name) ) {
            unshift( @{$hash->{actionQueue}}, AttrVal($name,'tvCurrentlyUrl','none') );
            unshift( @{$hash->{actionQueue}}, AttrVal($name,'tv2015Url','none') );
            
            readingsSingleUpdate($hash,'state','run TVSender_MasterFetchProgramInformations',1);
            TVSender_MasterFetchProgramInformations($hash);
        }
    }
    else {
        $list = ""
        ."AktuelleSendung:noArg"
        ." NächsteSendung:noArg"
        ." PrimeTimeSendung:noArg"
        ." PrimeTimeSendungfolgend:noArg" if( not $hash->{BRIDGE} );
        $list .= "update:noArg" if( $hash->{BRIDGE} );

        return "Unknown argument $cmd, choose one of $list";
    }
}
# Set Befehle für das TVSender Device
sub TVSender_Set($@) {
    my ($hash, $name, $cmd, @args) = @_;
    my ($arg, @params) = @args;
    my $list = '';
    my $httpmoddevice = '';
    my $errors = '';
    my $regex = '';
    my $subst = '';
    my $fhemcmd = '';
    my $ChannelName = '';
    if ($cmd eq 'AutoCreate') {
      ### TV_Program_NEXT ###

      $httpmoddevice = InternalVal($name,'TV_Program_NOW','TV_Program_NOW');
      TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Es läuft",1);
      TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
      TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      TVSender_Sort_HTTPMOD_Device_stateformat($hash,$httpmoddevice);

      ### TV_Program_NEXT ###
      $httpmoddevice = InternalVal($name,'TV_Program_NEXT','TV_Program_NEXT');
      TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Anschliessend",2);
      TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
      TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      TVSender_Sort_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      ### TV_Program_PT ###
      $httpmoddevice = InternalVal($name,'TV_Program_PT','TV_Program_PT');
      #$TV_Program_hash = $defs{$httpmoddevice};
      TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Zur PrimeTime",3);
      TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
      TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      TVSender_Sort_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      ### TV_Program_PTNEXT ###
      $httpmoddevice = InternalVal($name,'TV_Program_PTNEXT','TV_Program_PTNEXT');
      TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Danach",4);
      TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
      TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
      TVSender_Sort_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
    }
    elsif ($cmd eq 'Switch2Channel') {
        $fhemcmd = AttrVal($name,"SwitchCommand","");
        $regex = qr/;/p;
        $subst = ';;';
        $fhemcmd = $fhemcmd =~ s/$regex/$subst/rg;
        $errors = '';
        $errors = AnalyzeCommandChain (undef, $fhemcmd);
        if (!defined($errors)) {
           #Log3($name, 3,'Sucsessfully deleted row of stateFormat to '.$httpmoddevice.'!');
        }
        else {
            Log3($name, 5, 'SwitchCommand from '.$name.'cause error: '.$errors.'!');
            Log3($name, 5, $fhemcmd);
        }
    }
    elsif ($cmd eq 'UpdateAll') {
        TVSender_Parameter_update ($hash);
     }
    elsif ($cmd eq 'StatusRequest') {
      if ($arg eq 'Aktuell') {
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_NOW","TV_Program_NOW"));
      }
      elsif ($arg eq 'Anschliessend') {
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_NEXT","TV_Program_NEXT"));
      }
      elsif ($arg eq 'PrimeTime') {
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_PT","TV_Program_PT"));
      }
      elsif ($arg eq 'Danach') {
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_PTNEXT","TV_Program_PTNEXT"));
      }
      else {
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_NOW","TV_Program_NOW"));
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_NEXT","TV_Program_NEXT"));
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_PT","TV_Program_PT"));
        TVSender_StatusRequest ($hash,InternalVal($hash,"TV_Program_PTNEXT","TV_Program_PTNEXT"));
      }
    }
    # elsif ($cmd eq 'SetTimerSwitch2Channel') {
    #   my ($SWhour,$SWmin) = split($arg,":");
    #   if ($SWhour gt 0 ) {
    #     TV_Sender_Set_SwitchCommnand_Timer($hash,$arg);
    #   }
    #   else {
    #     return "Uhrzeit als 00:00 eingeben!";
    #   }
    # }
    elsif ($cmd eq 'ChannelName') {
        $ChannelName = urlDecode($arg);
        $attr{$name}{"ChannelName"} = $ChannelName;
        TVSender_Change_Regex_Defaults($hash);
        TVSender_Parameter_update ($hash);

    }
    else {
      my @senderlist = ("13th Street","3sat","A&E","Animal Planet","Anixe HD","ARD ALPHA","ARTE","ATV 2","ATV","AXN","Bayern","BBC Entertainment","BBC World","Beate Uhse TV","Bibel TV","Boomerang","Cartoon Network","Classica","CNN","Comedy Central","Das Erste","Discovery Channel",
        "Disney Cinemagic","Disney Junior","Disney XD","Disney","DMAX","E!","Euronews","Eurosport 2","Eurosport","FOX","France 2","France 3","Franken TV","Goldstar TV","Hamburg1","Heimatkanal","history","HR","HSE24","Junior","Kabel 1 Doku","Kabel eins Classics","Kabel eins","KiKa",
        "Kinowelt","MDR","MTV","München TV","N24 Doku","N24","NAT GEO Wild","National Geographic","NDR","NICK","NITRO","N-TV","ONE","ORF 1","ORF 2","ORF 3","ORF Sport +","Phoenix","Planet","Playboy TV","Pro7 FUN","Pro7 MAXX","Pro7","Puls 4",
        "QVC","RBB","Romance TV","RTL 2","RTL Crime","RTL Living","RTL Passion","RTL plus","RTL","SAT.1 emotions","SAT.1 Gold","SAT.1","Schweiz 1","Schweiz 2","Servus TV","Silverline","sixx","Sky 1","Sky Arts","Sky Atlantic HD","Sky Cinema +1","Sky Cinema +24","Sky Cinema Action",
        "Sky Cinema Comedy","Sky Cinema Emotion","Sky Cinema Family","Sky Cinema Hits","Sky Cinema Nostalgie","Sky Cinema","Sky Fußball Bundesliga","Sky Krimi","Sky Sport 1","Sky Sport 2","Sky Sport Austria","Sky Sport News HD","Sonnenklar TV","Spiegel TV Geschichte","Spiegel TV Wissen",
        "Sport 1","Sport1+ US HD","Sport1+","Spreekanal","Super RTL","SWR BW","SWR RP","Syfy","Tagesschau24","TELE 5","Tide TV","TLC","TNT Comedy","TNT Film","TNT Serie","Toggo Plus","TV Berlin","Universal Channel","VIVA","VOX","WDR","ZDF info","ZDF neo","ZDF",
        "Zee One");
      @senderlist = TVSender_Get_ChannelList($hash);
      urlEncode($_) for @senderlist;
      $list = ""
      ."AutoCreate:noArg"
      ." Switch2Channel:noArg"
      ." UpdateAll:noArg"
      ." StatusRequest:Aktuell,Anschliessend,PrimeTime,Danach,Alle"
      ." SetTimerSwitch2Channel"
      ." ChannelName:".join(",",@senderlist) if( not $hash->{BRIDGE} );

      return "Unknown argument $cmd, choose one of $list";
    }
}
# Enlesen der gültigen Sendersuchbegriffe, Rückgabe = Array
sub TVSender_Get_ChannelList($) {
  my ($hash) = @_;
  my $name = $hash->{"NAME"};
  my $httpmoddevice = InternalVal($name,"TV_Program_NOW","TV_Program_NOW");
  my $cmd = '';
  my $errors = '';
  my $str = InternalVal($httpmoddevice,"buf",undef);
  my $regex = qr/<tr class="[\w\W]*?Row">[\w\W]*?<td class="station">[\w\W]*?title="\s*(.*?)\s*"><img class/p;
  my @ChannelListArray = $str =~ /$regex/g;
  @ChannelListArray = sort @ChannelListArray;
  $hash->{ChannelList} = join(",",@ChannelListArray);
  #print '"'.$_.'","' for @ChannelListArray;
  #Log3($name, 3, @ChannelListArray);
  return @ChannelListArray;
}
# Mauelle Ausführung eines StatusRequestes für die HTTMOD Devices
sub TVSender_StatusRequest($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  $cmd = 'set '.$httpmoddevice.' reread';
  $errors = AnalyzeCommand(undef, $cmd);
  if (!defined($errors)) {
    #Log3($ownName, 3, 'Sucsessfully start ReCallURL!');
  }
  else {
    Log3($name, 5, 'TVSender_StatusRequest error at ReCallURL: '.$errors.'!');
    Log3($name, 5, $cmd);
  }

}
# Übernahme der Attribut - Änderungen (z.Zt. kein automatisches update, please use set <devicename> UpdateAll)
sub TVSender_Attr(@) {
    my ($cmd,$name,$attr_name,$attr_value) = @_;
    my $hash = $defs{$name};

    if ($cmd eq "set") {
        $attr{$name}{$attr_name} = $attr_value;
        TVSender_Change_Regex_Defaults($hash);
        Log3($name, 5, "$attr_name: value set to $attr_value!");
    }

    return;
}

sub TVSender_MasterFetchProgramInformations($) {

    my ($hash)      = @_;                     # der Hash ist hier immer der Hash des Bridge Devices
    
    my $name        = $hash->{NAME};
    my $uri         = pop( @{$hash->{actionQueue}} );


    readingsSingleUpdate($hash,'state','fetch data - ' . scalar(@{$hash->{actionQueue}}) . ' entries in the Queue',1);

    my $param = {
            url         => "http://www.klack.de/fernsehprogramm/".$uri,
            uri         => "$uri",
            timeout     => 5,
            method      => 'GET',
            hash        => $hash,
            doTrigger   => 1,
            callback    => \&TVSender_MasterErrorHandling,
        };
        
    $param->{cl} = $hash->{CL} if( $hash->{BRIDGE} and ref($hash->{CL}) eq 'HASH' );
    
    HttpUtils_NonblockingGet($param);
    Log3 $name, 3, "TVSender ($name) - Send with URL: http://www.klack.de/fernsehprogramm/$uri";
}

sub TVSender_MasterErrorHandling($$$) {

    my ($param,$err,$data)  = @_;
    
    my $hash                = $param->{hash};
    my $name                = $hash->{NAME};


    #Log3 $name, 3, "TVSender ($name) - Recieve DATA: $data";
    #Log3 $name, 3, "TVSender ($name) - Recieve HTTP Code: $param->{code}";
    #Log3 $name, 3, "TVSender ($name) - Recieve Error: $err";

    ### Begin Error Handling
    
    if( defined( $err ) ) {
        if( $err ne "" ) {
            if( $param->{cl} && $param->{cl}{canAsyncOutput} ) {
                asyncOutput( $param->{cl}, "Request Error: $err\r\n" );
            }

            readingsBeginUpdate( $hash );
            readingsBulkUpdate( $hash, 'state', $err, 1);
            readingsBulkUpdate( $hash, 'lastRequestError', $err, 1 );
            readingsEndUpdate( $hash, 1 );
            
            Log3 $name, 3, "TVSender ($name) - RequestERROR: $err";

            return;
        }
    }

    if( $data eq "" and exists( $param->{code} ) && $param->{code} ne 200 ) {
        #if( $param->{cl} && $param->{cl}{canAsyncOutput} ) {
        #    asyncOutput( $param->{cl}, "Request Error: $param->{code}\r\n" );
        #}
    
        readingsBeginUpdate( $hash );
        readingsBulkUpdate( $hash, 'state', $param->{code}, 1 );

        readingsBulkUpdate( $hash, 'lastRequestError', $param->{code}, 1 );

        Log3 $name, 3, "TVSender ($name) - RequestERROR: ".$param->{code};

        readingsEndUpdate( $hash, 1 );
    
        Log3 $name, 3, "TVSender ($name) - RequestERROR: received http code ".$param->{code}." without any data after requesting";

        return;
    }

    if( ( $data =~ /Error/i ) and exists( $param->{code}) and $param->{code} ne 200 ) {
        #if( $param->{cl} && $param->{cl}{canAsyncOutput} ) {
        #    asyncOutput( $param->{cl}, "Request Error: $param->{code}\r\n" );
        #}
    
        readingsBeginUpdate( $hash );
        
        readingsBulkUpdate( $hash, 'state', $param->{code}, 1 );
        readingsBulkUpdate( $hash, "lastRequestError", $param->{code}, 1 );

        readingsEndUpdate( $hash, 1 );
    
        Log3 $name, 3, "TVSender ($name) - statusRequestERROR: http error ".$param->{code};

        return;
        ### End Error Handling
    }
    
    #Log3 $name, 3, "TVSender ($name) - Recieve DATA: $data";
    
    TVSender_MasterFetchProgramInformations($hash)
    if( defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) > 0 );
    
    TVSender_MasterResponseProcessing($hash,$data,$param);
}

sub TVSender_MasterResponseProcessing($$$) {

    my ($hash,$data,$param) = @_;
    
    my $name                = $hash->{NAME};

    Log3 $name, 5, "TVSender ($name) - Recieve DATA TVSender_ResponseProcessing: $data";
    
    
    
    ####### Hier werden die Daten kurz geprüft und dann in den entsprechenden Hash geschrieben.
    $hash->{helper}{bufCurrent} = $data if( $param->{uri} eq AttrVal($name,'tvCurrentlyUrl','none') );
    $hash->{helper}{buf2015}    = $data if( $param->{uri} eq AttrVal($name,'tv2015Url','none') );
    
    TVSender_MasterWriteReadings($hash);
}

sub TVSender_MasterWriteReadings($) {

    my $hash        = shift;
    
    
    readingsBeginUpdate($hash);
    
    readingsBulkUpdateIfChanged($hash,'actionQueue',scalar(@{$hash->{actionQueue}}) . ' entries in the Queue');
    readingsBulkUpdateIfChanged($hash,'state',(defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ? 'ready' : 'fetch data - ' . scalar(@{$hash->{actionQueue}}) . ' paths in actionQueue'));
    
    readingsEndUpdate($hash,1);
}

sub TVSender_TimerGetData($) {
    
    my $hash    = shift;                    # der Hash ist hier immer der Hash des Bridge Devices
    my $name    = $hash->{NAME};


    RemoveInternalTimer($hash);

    if( defined($hash->{actionQueue}) and scalar(@{$hash->{actionQueue}}) == 0 ) {
        if( not IsDisabled($name) ) {
            unshift( @{$hash->{actionQueue}}, AttrVal($name,'tvCurrentlyUrl','none') );
            unshift( @{$hash->{actionQueue}}, AttrVal($name,'tv2015Url','none') );
            
            readingsSingleUpdate($hash,'state','run TVSender_MasterFetchProgramInformations',1);
            
            TVSender_MasterFetchProgramInformations($hash);
        
        } else {
            readingsSingleUpdate($hash,'state','disabled',1);
        }
    }
    
    InternalTimer( gettimeofday()+$hash->{INTERVAL}, 'TVSender_TimerGetData', $hash );
    Log3 $name, 3, "TVSender ($name) - Call InternalTimer TVSender_TimerGetData";
}





1;

=pod
=item helper
=item summary TVSender
=item summary_DE TVSender

=begin html

 <a name="TVSender"></a>
 <h3>TVSender</h3>
 <ul>
 <i>TVSender</i> implements a TV - Channel and creates HTTPMOD Devices
 TV_Program_NOW, TV_Program_NEXT, TV_Program_PT and TV_Program_PTNEXT.
 (Details look at https://github.com/supernova1963/TVSender/wiki)
 <br><br>
 <a name="TVSenderdefine"></a>
 <b>Define</b>
 <ul>
 <code>define &lt;name&gt; TVSender Channel &lt;ChannelName&gt; &lt;NrFavorit&gt;</code>
 <br><br>
 Example: <code>define Das_Erste TVSender 161 Das%20Erste 1</code>
 <br><br><ul>
 "Channel" parameter must be the program-channel from the TV-Receiver,
 "ChannelName" parameter must be the search term from klack.de without whitespaces (%20), if it is defferent to the name of the device,
 "NrFavorit" parameter can be given to sort the channels in the in the new TV-Sender group
 </ul>
 <br>

 <a name="TVSenderset"></a>
 <b>Set</b><br>
 <ul>
 <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
 <br><br>
 <ul>
 <li><i>AutoCreate</i><br>
 Creates or modifies the HTTPMOD Devices and teh attributs of the TVSender Device
 </li>
 <li><i>ChannelName</i> <br>
 Modifies the Name of the channel for searching in kl**k.de in the HTTPMOD Devices
 </li>
 <li><i>Switch2Channel</i> <br>
 Run the fhem commands of the attribute SwitchCommand
 </li>
 <li><i>UpdateAll</i> <br>
 Update all devices and attributs and readings of the HTTPMOD Devices
 </li>
 </ul>.
 <br><br>
 Options:
 Not yet implemented.
 </ul>
 <br>

 <a name="TVSenderet"></a>
 <b>Get</b><br>
 <ul>
 <code>get &lt;name&gt; &lt;option&gt;</code>
 <br><br>
 Not yet implemented.
 </ul>
 <br>

 <a name="TVSenderattr"></a>
 <b>Attributes</b>
 <ul>
 <code>attr &lt;name&gt; &lt;attribute&gt; &lt;value&gt;</code>
 <br><br>
 See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about
 the attr command.
 <br><br>
 Attributes:
 <ul>
 <li><i>Channel</i> 1 - 9999<br>
 Channel number of your TV receiver
 </li>
 <li><i>ChannelName</i> <br>
 Name of the channel for searching in klack.de
 </li>
 <li><i>Description</i> <br>
 Channel description, with no further meaning
 </li>
 <li><i>Logo</i> <br>
 Channel logo local saved at /opt/fhem/www/images/...
 </li>
 <li><i>HarmonyDevice</i> <br>
 Device name of your HarmonyDevice/TV-Receiver to switch channel (without any use for now)
 </li>
 <li><i>SwitchCommand</i> <br>
 Perl Code to switch Channel of your HarmonyDevice/TV-Receiver "set < ReceiverDevice > < switchcommand > [;; set < ReceiverDevice > < switchcommand > ...]") }
 </li>
 <li><i>NrFavorit</i> 1 - 9999<br>
 Sorting number stored in sortby attribute of the TV_Program_xx HTTPMOD modueles
 </li>
 </ul>
 </ul>
 </ul>

 =end html

 =cut
