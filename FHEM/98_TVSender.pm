package main;
use strict;
use warnings;


#### Leon hat die Set Liste gelöscht.

my %TVSender_gets = (
"na"    => "1"
#"Aktuell"    => "NOW",
#"Danach"    => "NEXT",
#"PrimeTime"    => "PT",
#"Später"  => "PTNEXT"
);

use vars qw{$TVSender_version};
$TVSender_version="0.1.0patch1Leon";      # Leon Patch 1

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

    $hash->{AttrList} = " Channel".     # Kanal-Nr. zum umschalten
    " ChannelName".                     # Sendername für die Suche im TV-Programm
    " Description".                     # Beschreibung allgemein
    " Logo".                            # relativ zu opt/fhem/www/images
    " HarmonyDevice".                   # TV/Receiver device in FHEM
    " SwitchCommand".                   # Vollständiger Befehl zum Sender umschalten
    " NrFavorit".                       # Favoriten Nr = sortby
    # " TV_Program_NOW_URL".              # Absolute URL für das TV-Programm Jetzt
    # " TV_Program_NEXT_URL".             # Absolute URL für das TV-Programm Danach
    # " TV_Program_PT_URL".               # Absolute URL für das TV-Programm PrimeTime
    #    " TV_Program_PTNEXT_URL".           # Absolute URL für das TV-Programm PrimeTime
    # " TV_Program_NOW".                  # Absolute URL für das TV-Programm Jetzt
    # " TV_Program_NEXT".                 # Absolute URL für das TV-Programm Danach
    # " TV_Program_PT".                   # Absolute URL für das TV-Programm PrimeTime
    # " TV_Program_PTNEXT".               # Absolute URL für das TV-Programm PrimeTime
    # " Regex_Logo".                      # Vollständige RegEx für das Sender Logo
    # " Regex_NOW".                       # Vollständige RegEx für Sendung Jetzt
    # " Regex_NOWTime".                   # Vollständige RegEx für Beginn Sendung Jetzt
    # " Regex_NOWDescription".            # Vollständige RegEx für Beschreibung Sendung Jetzt
    # " Regex_NOWImage".                  # Vollständige RegEx für den Link zum Bild/Logo der Sendung Jetzt
    # " Regex_NOWDetailLink".             # Vollständige Regex für den Link zu den Sendungsdetails Jetzt
    # " Regex_NEXT".                      # Vollständige RegEx für Sendung Danach
    # " Regex_NEXTTime".                  # Vollständige RegEx für Beginn Sendung Danach
    # " Regex_NEXTDescription".           # Vollständige RegEx für Beschreibung Sendung Danach
    # " Regex_NEXTImage".                 # Vollständige RegEx für den Link zum Bild/Logo der Sendung Danach
    # " Regex_NEXTDetailLink".            # Vollständige Regex für den Link zu den Sendungsdetails Danach
    # " Regex_PT".                        # Vollständige RegEx für Sendung PrimeTime
    # " Regex_PTTime".                    # Vollständige RegEx für Beginn Sendung PrimeTime
    # " Regex_PTDescription".             # Vollständige RegEx für Beschreibung Sendung PrimeTime
    # " Regex_PTImage".                   # Vollständige RegEx für den Link zum Bild/Logo der Sendung PrimeTime
    # " Regex_PTDetailLink".              # Vollständige Regex für den Link zu den Sendungsdetails PrimeTime
    # " Regex_PTNEXT".                    # Vollständige RegEx für Sendung PrimeTime Danach
    # " Regex_PTNEXTTime".                # Vollständige RegEx für Beginn Sendung PrimeTime Danach
    # " Regex_PTNEXTDescription".         # Vollständige RegEx für Beschreibung Sendung PrimeTime Danach
    # " Regex_PTNEXTImage".               # Vollständige RegEx für den Link zum Bild/Logo der Sendung PrimeTime Danach
    # " Regex_PTNEXTDetailLink".          # Vollständige Regex für den Link zu den Sendungsdetails PrimeTime Danach
    " ".$readingFnAttributes;
}

sub TVSender_Define($$) {
  my ($hash, $def) = @_;
  my @param = split('[ \t]+', $def);
  my ($name, $type, $Channel, $ChannelName, $NrFavorit) = @param;
  my $Senderwechselbefehl = "";
  my $i = 0;
  my $httpmoddevice = "";
  my $httpmoddevice_url = "";
  my $errors = "";
  my $cmds = "";
  my $regex = "";
  my $subst = '';
  ### Parameter mindesten 4
  if(int(@param) < 3) {
    return "Zu weninge Parameter: define <name> TVSender <Channel> [<ChannelName>] [<NrFavorit>]";
  }
  ### ChannelAttribute_setzten ###
  if (!defined($ChannelName)) {
    $ChannelName = $name;
  }
  $regex = qr/%20/p;
  $subst = ' ';
  $ChannelName = $ChannelName =~ s/$regex/$subst/rg;
  $attr{$name}{"Channel"} = $Channel if (!defined($attr{$name}{"Channel"}));
  $attr{$name}{"ChannelName"} = $ChannelName if (!defined($attr{$name}{"ChannelName"}));
  $attr{$name}{"Description"} = $name." = ".$ChannelName if (!defined($attr{$name}{"Description"}));
  $attr{$name}{"Logo"} = "default/tvlogos/".$name.".png" if (!defined($attr{$name}{"Logo"}));
  $hash->{Logo_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?src="\s*[\w\W]*?\s*(.*?)\s*" alt=';
  $attr{$name}{"HarmonyDevice"} = "harmony_34915526" if (!defined($attr{$name}{"HarmonyDevice"}));
  ### SenderwechselBefehl_setzen ###
  $Senderwechselbefehl = "";
  foreach $i (0..length($Channel)-1) {
    $Senderwechselbefehl = $Senderwechselbefehl.'set '.AttrVal($name,"HarmonyDevice","").' command Number'.substr($Channel, $i,0).';;';
  }
  $Senderwechselbefehl = $Senderwechselbefehl.'set '.AttrVal($name,"HarmonyDevice","").' command Select;;';
  $attr{$name}{"SwitchCommand"} = $Senderwechselbefehl; #if (!defined($attr{$name}{"SwitchCommand"}));
  ### FavoritenNummerierungSortierung_setzten ###
  $NrFavorit = $Channel if (!defined($NrFavorit));
  if (defined($NrFavorit) or ($NrFavorit > 0)) {
    $attr{$name}{"NrFavorit"} = $NrFavorit;
    $attr{$name}{"sortby"} = substr("0000".$NrFavorit, -4, 4);
  }
  else {
    $attr{$name}{"sortby"} = substr("0000".$Channel, -4, 4) if (!defined($attr{$name}{"sortby"}) or $attr{$name}{"sortby"} != substr("0000".$Channel, -4, 4));
  }
  $attr{$name}{"group"} = "TV-Sender" if (!defined($attr{$name}{"group"}));
  $attr{$name}{"room"} = "TV-Programm" if (!defined($attr{$name}{"room"}));
  ### HTTPMODDevices_setzten ### Namen für TV_Program_NOW, TV_Program_NEXT, TV_Program_PT, TV_Program_PTNEXT
  $hash->{TV_Program_NOW} = "TV_Program_NOW";
  $hash->{TV_Program_NEXT} = "TV_Program_NEXT";
  $hash->{TV_Program_PT} = "TV_Program_PT";
  $hash->{TV_Program_PTNEXT} = "TV_Program_PTNEXT";
  ### HTTPMOD_URL_setzen ### URLs für TV_Program_NOW, TV_Program_NEXT, TV_Program_PT, TV_Program_PTNEXT
  $hash->{TV_Program_NOW_URL} = "http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html";
  $hash->{TV_Program_NEXT_URL} = "http://www.klack.de/fernsehprogramm/was-laeuft-gerade/0/0/all.html";
  $hash->{TV_Program_PT_URL} = "http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html";
  $hash->{TV_Program_PTNEXT_URL} = "http://www.klack.de/fernsehprogramm/2015-im-tv/0/0/all.html";
  ### RegexVorgabenNOW_setzen ### für aktuelle laufende Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
  $hash->{NOW_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
  $hash->{NOW_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/>';
  $hash->{NOW_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
  $hash->{NOW_Image_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt=';
  $hash->{NOW_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
  ### RegexVorgabenNEXT_setzen ### für anschliessend laufende Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
  $hash->{NEXT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
  $hash->{NEXT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div';
  $hash->{NEXT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
  $hash->{NEXT_Image_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt=';
  $hash->{NEXT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
  ### RegexVorgabenPT_setzten ### für zur PrimeTime laufenden Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
  $hash->{PT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
  $hash->{PT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time"\s*[\w\W]*?\s*(.*?)\s*\t<br\/>';
  $hash->{PT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
  $hash->{PT_Image_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt=';
  $hash->{PT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';
  ### RegexVorgabenPTNEXT_setzen ### für nach der PrimeTime laufenden Sendung: Sendungsbezeichnung, Uhrzeit Beginn, Beschreibung, Bild, Detail-Link
  $hash->{PTNEXT_Title_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?>\s*(.*?)\s*<\/a>';
  $hash->{PTNEXT_Time_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">\s*(.*?)\s*<div';
  $hash->{PTNEXT_Description_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content"\s*[\w\W]*?\s*(.*?)\s*<br\/><img';
  $hash->{PTNEXT_Image_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<img class="epgImage"\s*src="[\w\W]*?\s*(.*?)\s*" alt=';
  $hash->{PTNEXT_DetailLink_Regex} = 'title="'.$ChannelName.'"><img[\w\W]*?<td class="time[\w\W]*?Row">[\w\W]*?<div[\w\W]*?<div class="content">\s*<a[\w\W]*?ref="\s*(.*?)\s*" title=';

  ### stateFormat ###
  TVSender_stateFormat($hash);

  my $notifiedDevices = 'global';
  $notifiedDevices = $notifiedDevices.','
      .InternalVal($name,"TV_Program_NOW","TV_Program_NOW").','
      .InternalVal($name,"TV_Program_NEXT","TV_Program_NEXT").','
      .InternalVal($name,"TV_Program_PT","TV_Program_PT").','
      .InternalVal($name,"TV_Program_PTNEXT","TV_Program_PTNEXT");
  $hash->{NOTIFYDEV} = $notifiedDevices;
  return undef;
}

sub TVSender_Sort_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  my $regex = qr/<tr id = "$name.*$name\_Title<\/td><\/tr>/p;
  my $stateformat_exists = $stateformat =~ /$regex/g;
  my %sorter = '';

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
  TVSender_stateFormat($hash);
}
# Überwachung der 4 HTTPMOD Devices zur Pflege der Readings in TVSender Device
sub TVSender_Notify($$) {
    my ($own_hash, $dev_hash) = @_;
    my $ownName = $own_hash->{NAME}; # own name / hash
    my $daytime = "";
    return "" if(IsDisabled($ownName)); # Return without any further action if the module is disabled
    my $devName = $dev_hash->{NAME}; # Device that created the events
    my $events = deviceEvents($dev_hash,1);
    my $cmd = '';
    my $errors = '';
    return if( !$events );
    if($devName eq "global" && grep(m/^INITIALIZED|REREADCFG$/, @{$events}))
    {
      Log3($ownName, 5, "Abschluss aller Intitialisierungen festgestellt ...");
    }
    foreach my $event (@{$events}) {
      $event = "" if(!defined($event));
      if ($devName eq InternalVal($ownName,"TV_Program_NOW","TV_Program_NOW")) {
        $daytime = "_NOW";
        $cmd = 'setreading '.$ownName.' '.$devName.'_Time '.ReadingsVal($devName,$ownName.'_Time','na').';'
          .'setreading '.$ownName.' '.$devName.'_Title '.ReadingsVal($devName,$ownName.'_Title','na').';'
          .'setreading '.$ownName.' '.$devName.'_Description '.ReadingsVal($devName,$ownName.'_Description','na').';'
          .'setreading '.$ownName.' '.$devName.'_DetailLink <html><a href=\''.ReadingsVal($devName,$ownName.'_DetailLink','na').'</a></html>;'
          .'setreading '.$ownName.' '.$devName.'_Image <html><a href=\'http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','na').'\'><img src=\''.ReadingsVal($devName,$ownName.'_Image','na').'\'></a></html>;';
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
      if ($devName eq InternalVal($ownName,"TV_Program_NEXT","TV_Program_NEXT")) {
        $daytime = "_NEXT";
        $cmd = 'setreading '.$ownName.' '.$devName.'_Time '.ReadingsVal($devName,$ownName.'_Time','na').';'
          .'setreading '.$ownName.' '.$devName.'_Title '.ReadingsVal($devName,$ownName.'_Title','na').';'
          .'setreading '.$ownName.' '.$devName.'_Description '.ReadingsVal($devName,$ownName.'_Description','na').';'
          .'setreading '.$ownName.' '.$devName.'_DetailLink <html><a href=\''.ReadingsVal($devName,$ownName.'_DetailLink','na').'</a></html>;'
          .'setreading '.$ownName.' '.$devName.'_Image <html><a href=\'http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','na').'\'><img src=\''.ReadingsVal($devName,$ownName.'_Image','na').'\'></a></html>;';
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
      if ($devName eq InternalVal($ownName,"TV_Program_PT","TV_Program_PT")) {
        $daytime = "_PT";
        $cmd = 'setreading '.$ownName.' '.$devName.'_Time '.ReadingsVal($devName,$ownName.'_Time','na').';'
          .'setreading '.$ownName.' '.$devName.'_Title '.ReadingsVal($devName,$ownName.'_Title','na').';'
          .'setreading '.$ownName.' '.$devName.'_Description '.ReadingsVal($devName,$ownName.'_Description','na').';'
          .'setreading '.$ownName.' '.$devName.'_DetailLink <html><a href=\''.ReadingsVal($devName,$ownName.'_DetailLink','na').'</a></html>;'
          .'setreading '.$ownName.' '.$devName.'_Image <html><a href=\'http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','na').'\'><img src=\''.ReadingsVal($devName,$ownName.'_Image','na').'\'></a></html>;';
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
      if ($devName eq InternalVal($ownName,"TV_Program_PTNEXT","TV_Program_PTNEXT")) {
        $daytime = "_PTNEXT";
        $cmd = 'setreading '.$ownName.' '.$devName.'_Time '.ReadingsVal($devName,$ownName.'_Time','na').';'
          .'setreading '.$ownName.' '.$devName.'_Title '.ReadingsVal($devName,$ownName.'_Title','na').';'
          .'setreading '.$ownName.' '.$devName.'_Description '.ReadingsVal($devName,$ownName.'_Description','na').';'
          .'setreading '.$ownName.' '.$devName.'_DetailLink <html><a href=\''.ReadingsVal($devName,$ownName.'_DetailLink','na').'</a></html>;'
          .'setreading '.$ownName.' '.$devName.'_Image <html><a href=\'http://www.klack.de'.ReadingsVal($devName,$ownName.'_DetailLink','na').'\'><img src=\''.ReadingsVal($devName,$ownName.'_Image','na').'\'></a></html>;';
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
    .'<tr><td style="text-align: center;;background-color: #e0e0e0" colspan=3 >A  K  T  U  E  L  L</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: left;;width: 50px;;font-size: larger" >'.$nameNOW.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left"><p><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201" style="text-align: left;;font-weight: bold;;font-size: larger">'.$nameNOW.'_Title</a></p>'.$nameNOW.'_Description</td>'
    .'<td style="vertical-align: top;;width: 200px" >'.$nameNOW.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0" colspan=3 >A  N  S  C  H  L  I  E  S  S  E  N  D</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;width:50px;;font-size: larger" >'.$nameNEXT.'_Time</td>'
    .'<td style="vertical-align: top;;text-align: left"><p style="text-align: left;;font-weight: bold;;font-size: larger" >'.$nameNEXT.'_Title</p>'.$nameNEXT.'_Description</td>'
    .'<td style="vertical-align: top;;width: 200px" >'.$nameNEXT.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0" colspan=3 >P  R  I  M  E    T  I  M  E</td></tr>'
    .'<tr><td style="vertical-align: top;;text-align: right;;width: 50px;;font-size: larger" >'.$namePT.'_Time</td>'
    .'<td style="vertical-align: top;; text-align: left"><p style="text-align: left;;font-weight: bold;;font-size: larger">'.$namePT.'_Title</p>'.$namePT.'_Description</td>'
    .'<td style="vertical-align: top;;width: 200px" >'.$namePT.'_Image</td></tr>'
    .'<tr><td style="text-align: center;;background-color: #e0e0e0" colspan=3 >D  A  N  A  C  H</td></tr>'
    .'<tr><td style="vertical-align:top;;text-align: right;;width: 50px;;font-size: larger" >'.$namePTNEXT.'_Time</td>'
    .'<td style="vertical-align: top;; text-align: left" ><p style="text-align: left;;font-weight: bold;;font-size: larger" >'.$namePTNEXT.'_Title</p>'.$namePTNEXT.'_Description</td>'
    .'<td style="vertical-align: top;;width: 200px" >'.$namePTNEXT.'_Image</td></tr></table>';
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
    $cmds = 'defmod '.$httpmoddevice.' HTTPMOD '.$httpmoddevice_url.' 120; '
      .'attr '.$httpmoddevice.' timeout 20;'
      .'attr '.$httpmoddevice.' alias '.$alias.':;'
      .'attr '.$httpmoddevice.' sortby '.$sort.';'
      .'attr '.$httpmoddevice.' verbose 3;'
      .'attr '.$httpmoddevice.' enableControlSet 1;'
      .'attr '.$httpmoddevice.' event-on-update-reading .*_Title;'
      .'attr '.$httpmoddevice.' room TV-Programm;';

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
    .$readingsnamepart.'05Regex';       # 05: Image Wertepaar für NEXT_Image Regex definieren

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
    Log3($name, 3, 'Sucsessfully new/changed attributs to '.$httpmoddevice.'!');
  }
  else {
    Log3($name, 3, 'Definition new/changed attributs to/of '.$httpmoddevice.' cause error: '.$errors.'!');
    Log3($name, 3, $cmd);
  }
}
# stateFormat der HTTPMOD Devices des Senders festlegen
sub TVSender_Change_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  my $regex = qr/<tr id = "$name.*$name\_Title<\/td><\/tr>/p;
  my $subst = '';
  my $stateformat_exists = $stateformat =~ /$regex/g;

  if ($stateformat eq '') {
    ### Das stateFormat Attribut des HTTPMOD Devive ist noch nicht gesetzt => stateFormat erstmalig setzen
    $stateformat = '<table width=100% >'
    .'<tr id = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;width: 50px;;text-align: center;;font-size: larger"><a href="/fhem?cmd=set%20.'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;font-size: larger">'.$name.'_Title</td>'
    .'</tr></table>';
  }
  elsif ($stateformat_exists){
    ### Das stateFormat Attribut des HTTPMOD Devive enthält bereits einen Eintrag zu diesem Sender => löschen + anhängen
    $regex = qr/<tr id = "$name.*$name\_Title<\/td><\/tr>/p;
    $subst = '';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $regex = qr/<\/table>/p;
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $regex = qr/;/p;
    $subst = ';;';
    $stateformat = $stateformat =~ s/$regex/$subst/rg;
    $stateformat = $stateformat.'<tr id = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;text-align: left;;width: 50px;;text-align: center;;font-size: larger"><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;text-align: left;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;text-align: left;;font-size: larger">'.$name.'_Title</td>'
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
    $stateformat = $stateformat.'<tr id = "'.$name.'"> '
      .'<td width=100px ><a href="/fhem?detail='.$name.'"><img src='.$name.'_Logo width=96px ></a></td>'
      .'<td style="vertical-align: middle;;text-align: left;;width: 50px;;text-align: center;;font-size: larger"><a href="/fhem?cmd=set%20'.$name.'%20Switch2Channel%201">'.$name.'_Channel</a></td>'
      .'<td style="vertical-align: middle;;text-align: left;;width: 50px;;font-size: larger">'.$name.'_Time</td>'
      .'<td style="vertical-align: middle;;text-align: left;;font-size: larger">'.$name.'_Title</td>'
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
  my $readingsnamepart = 'reading'.AttrVal($name,'sortby',''); # Nummerierung der userAttribute: reading+sortby= Channel mit führenden 0000
  my $code = 0;
  my $clock = '';
  my $daytime = '';
  my $regex = '';
  my $subst = '';
  my $userattribut = AttrVal($httpmoddevice,'userattr','');
  my $userattributdelete = ''
    .$readingsnamepart.'00Name '        # 00: Senderlogo Wertepaar für _Logo Name definieren
    .$readingsnamepart.'00Regex '        # 00: Senderlogo Wertepaar für _Logo Regex definieren
    .$readingsnamepart.'01Name '        # 01: Titel Wertepaar für NEXT_Titel Name definieren
    .$readingsnamepart.'01Regex '       # 01: Titel Wertepaar für NEXT_Titel Regex definieren
    .$readingsnamepart.'02Name '        # 02: Time Wertepaar für NEXT_Time Name definieren
    .$readingsnamepart.'02Regex '       # 02: Time Wertepaar für NEXT_Time Regex definieren
    .$readingsnamepart.'03Name '        # 03: Description Wertepaar für NEXT_Description Name definieren
    .$readingsnamepart.'03Regex '       # 03: Description Wertepaar für NEXT_Description Regex definieren
    .$readingsnamepart.'04Name '        # 04: DetailLink Wertepaar für NEXT_DetailLink Name definieren
    .$readingsnamepart.'04Regex '       # 04: DetailLink Wertepaar für NEXT_DetailLink Regex definieren
    .$readingsnamepart.'05Name '        # 05: Image Wertepaar für NEXT_Image Name definieren
    .$readingsnamepart.'05Regex';       # 05: Image Wertepaar für NEXT_Image Regex definieren

  if (index($userattributdelete,$userattribut) != -1) {
    #userattr wird ergänzt, wenn die neuen nicht oder nur teilweise enthalten sind
    $regex = qr/$readingsnamepart\d\d(?:Name\s|Regex\s|Regex|Name)/p;
    $subst = '';
    $userattribut = $userattribut =~ s/$regex/$subst/rg;
    $errors = '';
    $errors = AnalyzeCommandChain (undef, 'attr '.$httpmoddevice.' userattr '.$userattribut.' '.$userattributdelete.';');
    if (!defined($errors)) {
        #Log3($name, 3, 'Sucsessfully update userattr to '.$httpmoddevice.'!');
    }
    else {
        Log3($name, 5, 'Update of useratrr to '.$httpmoddevice.' causes an error: '.$errors.'!');
    }
    $cmd = ''
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'00Name;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'00Regex;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'01Name;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'01Regex;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'02Name;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'02Regex;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Name'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Regex;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'04Name;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'03Regex;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'05Name;'
      .'deleteattr '.$httpmoddevice.' '.$readingsnamepart.'05Regex;'
      .'deletereading '.$httpmoddevice.' '.$name.'_SwitchCommand;'
      .'deletereading '.$httpmoddevice.' '.$name.'_Channel;'
      .'deletereading '.$httpmoddevice.' '.$name.'_Sort;'
      .'deletereading '.$httpmoddevice.' '.$name.'.*;';
    $errors = '';
    $errors = AnalyzeCommandChain (undef, $cmd);
    if (!defined($errors)) {
      #Log3($name, 3, 'Sucsessfully deleted attributs to '.$httpmoddevice.'!');
    }
    else {
      Log3($name, 5, 'Delete attributs to/of '.$httpmoddevice.' cause error: '.$errors.'!');
      Log3($name, 5, $cmd);
    }
  }
}
# stateFormat der HTTPMOD Devices des Senders entfernen
sub TVSender_Delete_HTTPMOD_Device_stateformat($$) {
  my ($hash,$httpmoddevice) = @_;
  my $name = $hash->{"NAME"};
  my $cmd = '';
  my $errors = '';
  my $regex = '';
  my $subst = '';
  my $stateformat = AttrVal($httpmoddevice,'stateFormat','');
  $regex = qr/<tr id = "$name.*$name\_Title<\/td><\/tr>/p;
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

  #  my $userattribut = AttrVal("TV_Program_PT","userattr","");
    # nothing to do
  #  $regex = $readingsnamepart.qr/\d\d(?:Name\s|Regex\s|Regex|Name)/p;
  #  $subst = '';
  #  $userattribut = $userattribut =~ s/$regex/$subst/rg;
  #  $errors = "";
  #  $errors = AnalyzeCommandChain (undef, "attr TV_Program_PT userattr ".$userattribut.";"
  #  ."deleteattr TV_Program_PT ".$readingsnamepart.".*;"
  #  ."deletereading TV_Program_NOW ".$name.".*;");             # userAttribute,Attribute undReadings löschen
  #  if (!defined($errors)) {
  #      Log3($name, 3, "Sucsessfully update userattr to TV_Program_PT!");
  #  }
  #  else {
  #      Log3($name, 3, "Update of useratrr to TV_Program_PT causes an error: ".$errors."!");
  #  }
    return "";
}
# Umbenennung ist nicht möglich
sub TVSender_Rename($$) {
  my ( $new_name, $old_name) = @_;
  return "Diese Funtion ist z.Zt. nicht möglich, bitte Device: $old_name löschen und als $new_name neu anlegen!"
}
#
sub TVSender_Get($@) {
    my ($hash, @param) = @_;
    return 'get TVSender needs at least one argument' if (int(@param) < 2);

    my $name = shift @param;
    my $opt = shift @param;
    if(!$TVSender_gets{$opt}) {
        my @cList = keys %TVSender_gets;
        return "Unknown argument $opt, choose one of " . join(" ", @cList);
    }

    if($attr{$name}{formal} eq 'yes') {
        return $TVSender_gets{$opt}.', sir';
    }
    return $TVSender_gets{$opt};
}

sub TVSender_Set($@) {

    my ($hash, $name, $cmd, @args) = @_;
    my ($arg, @params) = @args;
    
    
    my $httpmoddevice = '';
    my $errors = '';
    my $regex = "";
    my $subst = "";

    
    if ($cmd eq 'AutoCreate') {
        if ($arg eq '1') {
          $httpmoddevice = InternalVal($name,'TV_Program_NOW','TV_Program_NOW');
          my $TV_Program_hash = $defs{$httpmoddevice};
          TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Es läuft",1);
          TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
          TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
          ### TV_Program_NEXT ###
          $httpmoddevice = InternalVal($name,'TV_Program_NEXT','TV_Program_NEXT');
          $TV_Program_hash = $defs{$httpmoddevice};
          TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Anschliessend",2);
          TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
          TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
          ### TV_Program_PT ###
          $httpmoddevice = InternalVal($name,'TV_Program_PT','TV_Program_PT');
          $TV_Program_hash = $defs{$httpmoddevice};
          TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Zur PrimeTime",3);
          TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
          TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
          ### TV_Program_PTNEXT ###
          $httpmoddevice = InternalVal($name,'TV_Program_PTNEXT','TV_Program_PTNEXT');
          $TV_Program_hash = $defs{$httpmoddevice};
          TVSender_Add_HTTPMOD_Device($hash,$httpmoddevice,"Danach",4);
          TVSender_Change_HTTPMOD_Device_userattr($hash,$httpmoddevice);
          TVSender_Change_HTTPMOD_Device_stateformat($hash,$httpmoddevice);
        }
    }
    
    elsif ($cmd eq 'Switch2Channel') {
      if ($arg eq "1") {
        #fhem ('"'.AttrVal($name,"SwitchCommand","").'"');
        $cmd = AttrVal($name,"SwitchCommand","");
        $regex = qr/;/p;
        $subst = ';;';
        $cmd = $cmd =~ s/$regex/$subst/rg;
        $errors = '';
        $errors = AnalyzeCommandChain (undef, $cmd);
        if (!defined($errors)) {
          #Log3($name, 3,'Sucsessfully deleted row of stateFormat to '.$httpmoddevice.'!');
        }
        else {
          Log3($name, 5, 'SwitchCommand from '.$name.'cause error: '.$errors.'!');
          Log3($name, 5, $cmd);
        }
      }
    }
    
    elsif ($cmd eq 'UpdateAll') {
      if ($arg eq "1") {
        #fhem ('"'.AttrVal($name,"SwitchCommand","").'"');
        TVSender_Parameter_update ($hash);
      }
      
    } else {
        my $list = "AutoCreate:0,1 Switch2Channel:1 UpdateAll:1";
        return "Unknown argument $cmd, choose one of $list";
    }

    return undef;
}

sub TVSender_Attr(@) {
    my ($cmd,$name,$attr_name,$attr_value) = @_;
    my $hash = $defs{$name};

    if ($cmd eq "set") {
        $attr{$name}{$attr_name} = $attr_value;
        Log3($name, 3, "$attr_name: value set to $attr_value!");
    }

    return undef;
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
 <br><br>
 <a name="TVSenderdefine"></a>
 <b>Define</b>
 <ul>
 <code>define &lt;name&gt; TVSender Channel &lt;ChannelName&gt; &lt;NrFavorit&gt;</code>
 <br><br>
 Example: <code>define Das_Erste TVSender 161 Das%20Erste 1</code>
 <br><br><ul>
 "Channel" parameter must be the Program-Channel from the TV-Receiver,
 "ChannelName" parameter must be the search term from klack.de without whitespaces (%20), if it is defferent to the name of the device,
 "NrFavorit" prameter can be the given to sort the channels in the readingsGroup
 </ul>
 <br>

 <a name="TVSenderset"></a>
 <b>Set</b><br>
 <ul>
 <code>set &lt;name&gt; &lt;option&gt; &lt;value&gt;</code>
 <br><br>
 Not yet implemented.
 <br><br>
 Options:
 Not yet implemented.
 </ul>
 <br>

 <a name="TVSenderget"></a>
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
 Device name of your HarmonyDevice/TV-Receiver to switch channel
 </li>
 <li><i>SwitchCommand</i> <br>
 Perl Code to switch Channel of your HarmonyDevice/TV-Receiver { fhem("set ReceiverDevice switchcommand") }
 </li>
 <li><i>NrFavorit</i> 1 - 9999<br>
 Sorting number stored in sortby attribute of the TV_Program_xx HTTPMOD modueles
 </li>
 </ul>
 </ul>
 </ul>

 =end html

 =cut
