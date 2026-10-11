set ADDONNAME "hm_pdetect"
set FILENAME "/usr/local/addons/hm_pdetect/etc/hm_pdetect.conf"
set RULESFILE "/usr/local/addons/hm_pdetect/etc/hm_pdetect-rules.conf"
set RULESSTATEFILE "/usr/local/addons/hm_pdetect/etc/hm_pdetect-rules.state"

array set args { command INV HM_FRITZ_IP {} HM_FRITZ_USER {} HM_FRITZ_SECRET {} HM_CCU_PRESENCE_VAR {} HM_CCU_PRESENCE_LIST {} HM_CCU_PRESENCE_LIST_ENABLED {} HM_CCU_PRESENCE_STR {} HM_CCU_PRESENCE_STR_ENABLED {} HM_CCU_PRESENCE_GUEST {} HM_CCU_PRESENCE_GUEST_ENABLED {} HM_CCU_PRESENCE_GUEST_IPRANGE {} HM_CCU_PRESENCE_NOBODY {} HM_CCU_PRESENCE_USER {} HM_CCU_PRESENCE_USER_ENABLED {} HM_CCU_PRESENCE_PRESENT {} HM_CCU_PRESENCE_AWAY {} HM_USER_LIST {} HM_KNOWN_LIST_MODE {} HM_KNOWN_LIST {} HM_INTERVAL_TIME {} RULES_FORM {} HM_AWAY_DELAY {} HM_DEVICE_LIST {} HM_RULE_LIST {} }

# rule editor values shown in the page and the result of the last save
set RULES_AWAY_DELAY "0"
set RULES_DEVICES ""
set RULES_RULES ""
set RULES_MSG ""

proc utf8 {hex} {
    set hex [string map {% {}} $hex]
    return [encoding convertfrom utf-8 [binary format H* $hex]]
}

proc url-decode str {
    # rewrite "+" back to space
    # protect \ from quoting another '\'
    set str [string map [list + { } "\\" "\\\\" "\[" "\\\["] $str]

    # Replace UTF-8 sequences with calls to the utf8 decode proc...
    regsub -all {(%[0-9A-Fa-f0-9]{2})+} $str {[utf8 \0]} str

    # process \u unicode mapped chars and trim whitespaces
    return [encoding convertfrom identity [string trim [subst -novar $str]]]
}

proc str-escape str {
    set str [string map -nocase { 
              "\"" "\\\""
              "\$" "\\\$"
              "\\" "\\\\"
              "`"  "\\`"
             } $str]

    return $str
}

proc str-unescape str {
    set str [string map -nocase { 
              "\\\"" "\""
              "\\\$" "\$"
              "\\\\" "\\"
              "\\`"  "`"
             } $str]

    return $str
}


proc parseQuery { } {
    global args env
    
    set query [array names env]
    if { [info exists env(REQUEST_METHOD)] } {
      if { $env(REQUEST_METHOD) == "POST" } {
        set query [gets stdin]
      } else {
        set query $env(QUERY_STRING)
      }
    }
    
    foreach item [split $query &] {
        if { [regexp {([^=]+)=(.+)} $item dummy key value] } {
            set args($key) $value
        }
    }
}

proc loadFile { fileName } {
    set content ""
    set fd -1
    
    if { ![file exist $fileName] || [catch {open $fileName r} fd] } {
        set content ""
    } else {
        set content [read $fd]
        close $fd
    }
    
    return $content
}

proc loadConfigFile { } {
    global FILENAME HM_FRITZ_IP HM_FRITZ_USER HM_FRITZ_SECRET HM_CCU_PRESENCE_VAR HM_CCU_PRESENCE_LIST HM_CCU_PRESENCE_LIST_ENABLED HM_CCU_PRESENCE_STR HM_CCU_PRESENCE_STR_ENABLED HM_CCU_PRESENCE_GUEST HM_CCU_PRESENCE_GUEST_ENABLED HM_CCU_PRESENCE_GUEST_IPRANGE HM_CCU_PRESENCE_NOBODY HM_CCU_PRESENCE_USER HM_CCU_PRESENCE_USER_ENABLED HM_CCU_PRESENCE_PRESENT HM_CCU_PRESENCE_AWAY HM_USER_LIST HM_KNOWN_LIST_MODE HM_KNOWN_LIST HM_INTERVAL_TIME
    set conf ""

    if { [encoding system] != "identity" } {
        catch {set conf [encoding convertto utf-8 [loadFile $FILENAME]]}
    } else {
        catch {set conf [loadFile $FILENAME]}
    }

    if { [string trim "$conf"] != "" } {
        set HM_INTERVAL_MAX 0

        regexp -line {^HM_FRITZ_IP=\"(.*)\"$} $conf dummy HM_FRITZ_IP
        regexp -line {^HM_FRITZ_USER=\"(.*)\"$} $conf dummy HM_FRITZ_USER
        regexp -line {^HM_FRITZ_SECRET=\"(.*)\"$} $conf dummy HM_FRITZ_SECRET
        regexp -line {^HM_CCU_PRESENCE_VAR=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_VAR
        regexp -line {^HM_CCU_PRESENCE_LIST=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_LIST
        regexp -line {^HM_CCU_PRESENCE_LIST_ENABLED=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_LIST_ENABLED
        regexp -line {^HM_CCU_PRESENCE_STR=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_STR
        regexp -line {^HM_CCU_PRESENCE_STR_ENABLED=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_STR_ENABLED
        regexp -line {^HM_CCU_PRESENCE_GUEST=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_GUEST
        regexp -line {^HM_CCU_PRESENCE_GUEST_ENABLED=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_GUEST_ENABLED
        regexp -line {^HM_CCU_PRESENCE_GUEST_IPRANGE=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_GUEST_IPRANGE
        regexp -line {^HM_CCU_PRESENCE_NOBODY=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_NOBODY
        regexp -line {^HM_CCU_PRESENCE_USER=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_USER
        regexp -line {^HM_CCU_PRESENCE_USER_ENABLED=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_USER_ENABLED
        regexp -line {^HM_CCU_PRESENCE_PRESENT=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_PRESENT
        regexp -line {^HM_CCU_PRESENCE_AWAY=\"(.*)\"$} $conf dummy HM_CCU_PRESENCE_AWAY
        regexp -line {^HM_USER_LIST=\((.*)\)$} $conf dummy HM_USER_LIST
        regexp -line {^HM_KNOWN_LIST_MODE=\"(.*)\"$} $conf dummy HM_KNOWN_LIST_MODE
        regexp -line {^HM_KNOWN_LIST=\"(.*)\"$} $conf dummy HM_KNOWN_LIST
        regexp -line {^HM_INTERVAL_MAX=\"(.*)\"$} $conf dummy HM_INTERVAL_MAX
        regexp -line {^HM_INTERVAL_TIME=\"(.*)\"$} $conf dummy HM_INTERVAL_TIME

        # if HM_INTERVAL_MAX is 1 we have to uncheck the
        # checkbox to signal that the interval stuff is disabled.
        if { $HM_INTERVAL_MAX == 1 } {
          set HM_INTERVAL_TIME 0
        }
 
        # lets replace all spaces with newlines for the
        # textarea fields in the html code.
        regsub -all {\s+} $HM_KNOWN_LIST "\n" HM_KNOWN_LIST
        regsub -all {\s+\[} $HM_USER_LIST "\n\[" HM_USER_LIST

        # make sure to unescape variable content that was properly escaped
        # due to shell variable regulations
        set HM_FRITZ_USER [str-unescape $HM_FRITZ_USER]
        set HM_FRITZ_SECRET [str-unescape $HM_FRITZ_SECRET]
    }
}

proc saveConfigFile { } {
    global FILENAME args
        
    set fd [open $FILENAME w]

    set HM_FRITZ_IP [url-decode $args(HM_FRITZ_IP)]
    set HM_FRITZ_USER [url-decode $args(HM_FRITZ_USER)]
    set HM_FRITZ_SECRET [url-decode $args(HM_FRITZ_SECRET)]
    set HM_CCU_PRESENCE_VAR [url-decode $args(HM_CCU_PRESENCE_VAR)]
    set HM_CCU_PRESENCE_LIST [url-decode $args(HM_CCU_PRESENCE_LIST)]
    set HM_CCU_PRESENCE_LIST_ENABLED [url-decode $args(HM_CCU_PRESENCE_LIST_ENABLED)]
    set HM_CCU_PRESENCE_STR [url-decode $args(HM_CCU_PRESENCE_STR)]
    set HM_CCU_PRESENCE_STR_ENABLED [url-decode $args(HM_CCU_PRESENCE_STR_ENABLED)]
    set HM_CCU_PRESENCE_GUEST [url-decode $args(HM_CCU_PRESENCE_GUEST)]
    set HM_CCU_PRESENCE_GUEST_ENABLED [url-decode $args(HM_CCU_PRESENCE_GUEST_ENABLED)]
    set HM_CCU_PRESENCE_GUEST_IPRANGE [url-decode $args(HM_CCU_PRESENCE_GUEST_IPRANGE)]
    set HM_CCU_PRESENCE_NOBODY [url-decode $args(HM_CCU_PRESENCE_NOBODY)]
    set HM_CCU_PRESENCE_USER [url-decode $args(HM_CCU_PRESENCE_USER)]
    set HM_CCU_PRESENCE_USER_ENABLED [url-decode $args(HM_CCU_PRESENCE_USER_ENABLED)]
    set HM_CCU_PRESENCE_PRESENT [url-decode $args(HM_CCU_PRESENCE_PRESENT)]
    set HM_CCU_PRESENCE_AWAY [url-decode $args(HM_CCU_PRESENCE_AWAY)]
    set HM_USER_LIST [url-decode $args(HM_USER_LIST)]
    set HM_KNOWN_LIST_MODE [url-decode $args(HM_KNOWN_LIST_MODE)]
    set HM_KNOWN_LIST [url-decode $args(HM_KNOWN_LIST)]
    set HM_INTERVAL_TIME [url-decode $args(HM_INTERVAL_TIME)]

    # make sure to that HM_USER_LIST contains a valid associate array
    # expression or otherwise we might run into problems later on.

    # replace double-whitespaces to single ones
    regsub -all {\s+} $HM_USER_LIST " " HM_USER_LIST

    # replace "= " to "="
    regsub -all {=\s+} $HM_USER_LIST "=" HM_USER_LIST

    # replace " =" to "="
    regsub -all {\s+=} $HM_USER_LIST "=" HM_USER_LIST

    # replace " ]" to "]"
    regsub -all {\s+\]} $HM_USER_LIST "\]" HM_USER_LIST

    # replace "[ " to "["
    regsub -all {\[\s+} $HM_USER_LIST "\[" HM_USER_LIST

    # make sure HM_KNOWN_LIST doesn't contain double whitespaces
    regsub -all {\s+} $HM_KNOWN_LIST " " HM_KNOWN_LIST

    # make sure to escape variable content that may contain special
    # characters not allowed unescaped in shell variables.
    set HM_FRITZ_USER [str-escape $HM_FRITZ_USER]
    set HM_FRITZ_SECRET [str-escape $HM_FRITZ_SECRET]
    
    # we set config options that should not be changeable on the CCU
    puts $fd "HM_CCU_IP=127.0.0.1"
    puts $fd "HM_CCU_REGAPORT=8183"
    puts $fd "HM_PROCESSLOG_FILE=\"/var/log/hm_pdetect.log\""
    puts $fd "HM_DAEMON_PIDFILE=\"/var/run/hm_pdetect.pid\""

    # only add the following variables if they are NOT empty
    if { [string length $HM_FRITZ_IP] > 0 }              { puts $fd "HM_FRITZ_IP=\"$HM_FRITZ_IP\"" }
    if { [string length $HM_FRITZ_USER] > 0 }            { puts $fd "HM_FRITZ_USER=\"$HM_FRITZ_USER\"" }
    if { [string length $HM_FRITZ_SECRET] > 0 }          { puts $fd "HM_FRITZ_SECRET=\"$HM_FRITZ_SECRET\"" }
    if { [string length $HM_CCU_PRESENCE_VAR] > 0 }      { puts $fd "HM_CCU_PRESENCE_VAR=\"$HM_CCU_PRESENCE_VAR\"" }
    if { [string length $HM_CCU_PRESENCE_LIST] > 0 }     { puts $fd "HM_CCU_PRESENCE_LIST=\"$HM_CCU_PRESENCE_LIST\"" }
    if { [string length $HM_CCU_PRESENCE_STR] > 0 }      { puts $fd "HM_CCU_PRESENCE_STR=\"$HM_CCU_PRESENCE_STR\"" }
    if { [string length $HM_CCU_PRESENCE_GUEST] > 0 }    { puts $fd "HM_CCU_PRESENCE_GUEST=\"$HM_CCU_PRESENCE_GUEST\"" }
    if { [string length $HM_CCU_PRESENCE_GUEST_IPRANGE] > 0 }    { puts $fd "HM_CCU_PRESENCE_GUEST_IPRANGE=\"$HM_CCU_PRESENCE_GUEST_IPRANGE\"" }
    if { [string length $HM_CCU_PRESENCE_NOBODY] > 0 }   { puts $fd "HM_CCU_PRESENCE_NOBODY=\"$HM_CCU_PRESENCE_NOBODY\"" }
    if { [string length $HM_CCU_PRESENCE_USER] > 0 }     { puts $fd "HM_CCU_PRESENCE_USER=\"$HM_CCU_PRESENCE_USER\"" }
    if { [string length $HM_CCU_PRESENCE_PRESENT] > 0 }  { puts $fd "HM_CCU_PRESENCE_PRESENT=\"$HM_CCU_PRESENCE_PRESENT\"" }
    if { [string length $HM_CCU_PRESENCE_AWAY] > 0 }     { puts $fd "HM_CCU_PRESENCE_AWAY=\"$HM_CCU_PRESENCE_AWAY\"" }
    if { [string length $HM_KNOWN_LIST_MODE] > 0 }       { puts $fd "HM_KNOWN_LIST_MODE=\"$HM_KNOWN_LIST_MODE\"" }

    if { $HM_CCU_PRESENCE_LIST_ENABLED != "on" } {
      puts $fd "HM_CCU_PRESENCE_LIST_ENABLED=\"false\""
    }

    if { $HM_CCU_PRESENCE_STR_ENABLED != "on" } {
      puts $fd "HM_CCU_PRESENCE_STR_ENABLED=\"false\""
    }

    if { $HM_CCU_PRESENCE_GUEST_ENABLED != "on" } {
      puts $fd "HM_CCU_PRESENCE_GUEST_ENABLED=\"false\""
    }

    if { $HM_CCU_PRESENCE_USER_ENABLED != "on" } {
      puts $fd "HM_CCU_PRESENCE_USER_ENABLED=\"false\""
    }

    if { $HM_INTERVAL_TIME == 0 } { 
      puts $fd "HM_INTERVAL_MAX=\"1\""
    } else {
      puts $fd "HM_INTERVAL_TIME=\"$HM_INTERVAL_TIME\""
    }

    # also add empty variables on purpose
    puts $fd "HM_USER_LIST=($HM_USER_LIST)"
    puts $fd "HM_KNOWN_LIST=\"$HM_KNOWN_LIST\""
    
    close $fd

    # we have updated our configuration so lets
    # stop/restart hm_pdetect
    if { $HM_INTERVAL_TIME == 0 } { 
      exec /usr/local/etc/config/rc.d/hm_pdetect stop &
    } else {
      exec /usr/local/etc/config/rc.d/hm_pdetect restart &
    }
}

#############################################################
# device/rule editor (hm_pdetect-rules.conf) and status panel
#
# Strings in these procs are real unicode (non-ASCII characters written as
# \u escapes); they are converted to the byte representation used by the
# rest of the page (see loadConfigFile) only when handed to the HTML output.

# page language, set to "en" by en.settings.cgi
set PAGE_LANG "de"

proc L { de en } {
    global PAGE_LANG
    if { $PAGE_LANG == "en" } { return $en }
    return $de
}

proc html-escape { str } {
    return [string map {& &amp; < &lt; > &gt; \" &quot; ' &#39;} $str]
}

proc to-page { str } {
    if { [encoding system] != "identity" } {
        return [encoding convertto utf-8 $str]
    }
    return $str
}

# fills RULES_AWAY_DELAY/RULES_DEVICES/RULES_RULES (page representation)
# with the text representation of the rules file:
#   devices: one 'Name = entries' per line
#   rules:   one 'Name | condition | enter actions | leave actions' per line
proc loadRulesFile { } {
    global RULESFILE RULES_AWAY_DELAY RULES_DEVICES RULES_RULES
    set conf ""
    catch {set conf [loadFile $RULESFILE]}

    set delay 0
    regexp -line {^HM_AWAY_DELAY="?([0-9]+)"?\s*$} $conf -> delay

    set devices ""
    if { [regexp {HM_DEVICE_LIST=\(([^)]*)\)} $conf -> block] } {
        foreach {all key val} [regexp -all -inline {\[([^\]]+)\]='([^']*)'} $block] {
            append devices "$key = $val\n"
        }
    }

    set rules ""
    if { [regexp {HM_RULE_LIST=\(([^)]*)\)} $conf -> block] } {
        foreach {all key val} [regexp -all -inline {\[([^\]]+)\]='([^']*)'} $block] {
            append rules "$key | [join [split $val |] { | }]\n"
        }
    }

    set RULES_AWAY_DELAY [to-page $delay]
    set RULES_DEVICES [to-page $devices]
    set RULES_RULES [to-page $rules]
}

proc checkDeviceEntries { entries } {
    foreach e [regexp -all -inline {\S+} $entries] {
        if { [regexp -nocase {^name:[^\s'()|&;]+$} $e] } { continue }
        if { [regexp {^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$} $e] } { continue }
        if { [regexp {^[0-9]{1,3}(\.[0-9]{1,3}){3}$} $e] } { continue }
        return [L "ung\u00fcltiger Eintrag '$e' (erlaubt: MAC-Adresse, IP-Adresse oder name:<FRITZ!-Ger\u00e4tename>)" \
                  "invalid entry '$e' (allowed: MAC address, IP address or name:<FRITZ! device name>)"]
    }
    return ""
}

proc checkActions { text } {
    foreach a [split $text ";"] {
        set a [string trim $a]
        if { $a == "" } { continue }
        set type [string tolower [lindex [split $a :] 0]]
        set arg ""
        set pos [string first : $a]
        if { $pos >= 0 } {
            set arg [string trim [string range $a [expr {$pos + 1}] end]]
        }
        switch -- $type {
            temp - maxtemp {
                if { ![regexp {^.+=\s*[0-9]+([.,][0-9]+)?$} $arg] } {
                    return [L "'$a': erwartet $type:<Ziel>=<Temperatur>" "'$a': expected $type:<target>=<temperature>"]
                }
            }
            auto - prog {
                if { $arg == "" } { return [L "'$a': Ziel bzw. Programmname fehlt" "'$a': target or program name missing"] }
            }
            set - var {
                if { ![regexp {^[^=]+=.+$} $arg] } { return [L "'$a': erwartet $type:<Name>=<Wert>" "'$a': expected $type:<name>=<value>"] }
            }
            restore { }
            default {
                return [L "unbekannte Aktion '$a' (erlaubt: temp, maxtemp, auto, restore, set, var, prog)" \
                          "unknown action '$a' (allowed: temp, maxtemp, auto, restore, set, var, prog)"]
            }
        }
    }
    return ""
}

# validates the submitted editor fields. On success returns the content of the
# new rules file, otherwise an empty string and the error list in RULES_ERRORS
proc buildRulesFile { awayDelay devicesText rulesText } {
    global RULES_ERRORS
    set RULES_ERRORS {}

    set awayDelay [string trim $awayDelay]
    if { $awayDelay == "" } { set awayDelay 0 }
    if { ![regexp {^[0-9]+$} $awayDelay] || $awayDelay > 86400 } {
        lappend RULES_ERRORS [L "Abmeldeverz\u00f6gerung: ganze Sekunden zwischen 0 und 86400 angeben" \
                                "Away delay: enter whole seconds between 0 and 86400"]
    }

    set devNames {}
    set devOut ""
    set n 0
    foreach line [split $devicesText "\n"] {
        incr n
        set line [string trim $line]
        if { $line == "" || [string index $line 0] == "#" } { continue }
        if { ![regexp {^([A-Za-z0-9_-]+)\s*=\s*(.+)$} $line -> name entries] } {
            lappend RULES_ERRORS [L "Ger\u00e4te, Zeile $n: Format 'Name = Eintr\u00e4ge' erwartet (Name nur aus Buchstaben, Ziffern, _ und -)" \
                                    "Devices, line $n: expected 'Name = entries' (name only letters, digits, _ and -)"]
            continue
        }
        set err [checkDeviceEntries $entries]
        if { $err != "" } {
            lappend RULES_ERRORS "[L Ger\u00e4te Devices], [L Zeile line] $n ($name): $err"
            continue
        }
        if { [lsearch -exact $devNames $name] >= 0 } {
            lappend RULES_ERRORS [L "Ger\u00e4te, Zeile $n: Name '$name' ist doppelt" "Devices, line $n: duplicate name '$name'"]
            continue
        }
        lappend devNames $name
        append devOut "  \[$name\]='[join [regexp -all -inline {\S+} $entries] { }]'\n"
    }

    set ruleNames {}
    set ruleOut ""
    set n 0
    foreach line [split $rulesText "\n"] {
        incr n
        set line [string trim $line]
        if { $line == "" || [string index $line 0] == "#" } { continue }
        set where "[L Regeln Rules], [L Zeile line] $n"
        if { [regexp {['()]} $line] } {
            lappend RULES_ERRORS "$where: [L {die Zeichen ' ( ) sind nicht erlaubt} {the characters ' ( ) are not allowed}]"
            continue
        }
        set parts [split $line |]
        if { [llength $parts] < 3 || [llength $parts] > 4 } {
            lappend RULES_ERRORS "$where: [L {Format 'Name | Bedingung | Aktionen beim Eintreten | Aktionen beim Verlassen' erwartet} \
                                              {expected 'Name | condition | actions on enter | actions on leave'}]"
            continue
        }
        set name [string trim [lindex $parts 0]]
        set cond [string trim [lindex $parts 1]]
        set enter [string trim [lindex $parts 2]]
        set leave [string trim [lindex $parts 3]]
        if { ![regexp {^[A-Za-z0-9_-]+$} $name] } {
            lappend RULES_ERRORS "$where: [L "Name '$name' darf nur Buchstaben, Ziffern, _ und - enthalten" "name '$name' may only contain letters, digits, _ and -"]"
            continue
        }
        if { [lsearch -exact $ruleNames $name] >= 0 } {
            lappend RULES_ERRORS "$where: [L "Name '$name' ist doppelt" "duplicate name '$name'"]"
            continue
        }
        set where "$where ($name)"
        if { $cond == "" } {
            lappend RULES_ERRORS "$where: [L {Bedingung fehlt} {condition missing}]"
            continue
        }
        set ok 1
        set terms {}
        foreach term [split $cond &] {
            set term [string trim $term]
            set t [string trimleft $term "! "]
            if { [regexp -nocase {^device:(.+)$} $t -> dev] } {
                if { [lsearch -exact $devNames $dev] < 0 } {
                    lappend RULES_ERRORS "$where: [L "Ger\u00e4t '$dev' steht nicht in der Ger\u00e4teliste" "device '$dev' is not in the device list"]"
                    set ok 0
                }
            } elseif { ![regexp -nocase {^user:.+$} $t] && [lsearch -exact {anyone nobody} [string tolower $t]] < 0 } {
                lappend RULES_ERRORS "$where: [L "unbekannte Bedingung '$term'" "unknown condition '$term'"] (device:<Name>, user:<Name>, anyone, nobody)"
                set ok 0
            }
            lappend terms $term
        }
        foreach {label text} [list [L Eintreten enter] $enter [L Verlassen leave] $leave] {
            set err [checkActions $text]
            if { $err != "" } {
                lappend RULES_ERRORS "$where, $label: $err"
                set ok 0
            }
        }
        if { !$ok } { continue }
        lappend ruleNames $name
        set acts {}
        foreach text [list $enter $leave] {
            set alist {}
            foreach a [split $text ";"] {
                set a [string trim $a]
                if { $a != "" } { lappend alist $a }
            }
            lappend acts [join $alist ";"]
        }
        append ruleOut "  \[$name\]='[join $terms &]|[lindex $acts 0]|[lindex $acts 1]'\n"
    }

    if { [llength $RULES_ERRORS] > 0 } {
        return ""
    }

    set out ""
    append out "# hm_pdetect devices and rules (written by the addon settings page)\n"
    append out "# Re-read by the daemon in every run. See hm_pdetect-rules.conf.sample.\n\n"
    append out "HM_AWAY_DELAY=$awayDelay\n\n"
    append out "HM_DEVICE_LIST=(\n$devOut)\n\n"
    append out "HM_RULE_LIST=(\n$ruleOut)\n"
    return $out
}

# validates and writes the rules file from the submitted form. On errors the
# submitted text is kept in the editor fields and the file stays untouched.
proc saveRulesFile { } {
    global RULESFILE args RULES_ERRORS RULES_MSG RULES_AWAY_DELAY RULES_DEVICES RULES_RULES

    set awayDelay [url-decode $args(HM_AWAY_DELAY)]
    set devicesText [url-decode $args(HM_DEVICE_LIST)]
    set rulesText [url-decode $args(HM_RULE_LIST)]

    set content [buildRulesFile $awayDelay $devicesText $rulesText]
    if { $content == "" } {
        set RULES_AWAY_DELAY [to-page $awayDelay]
        set RULES_DEVICES [to-page $devicesText]
        set RULES_RULES [to-page $rulesText]
        set msg "<div class=\"alert alert-danger\"><b>[L "Ger\u00e4te und Regeln wurden NICHT gespeichert:" {Devices and rules were NOT saved:}]</b><ul>"
        foreach e $RULES_ERRORS {
            append msg "<li>[html-escape $e]</li>"
        }
        append msg "</ul>[L "Die \u00fcbrigen Einstellungen wurden gespeichert." {All other settings were saved.}]</div>"
        set RULES_MSG [to-page $msg]
        return 0
    }

    set tmp "$RULESFILE.new"
    set fd [open $tmp w]
    puts -nonewline $fd $content
    close $fd
    file rename -force $tmp $RULESFILE
    set RULES_MSG [to-page "<div class=\"alert alert-success\">[L "Einstellungen, Ger\u00e4te und Regeln gespeichert." {Settings, devices and rules saved.}]</div>"]
    return 1
}

proc presencePrefix { } {
    global HM_CCU_PRESENCE_VAR
    if { [info exists HM_CCU_PRESENCE_VAR] && $HM_CCU_PRESENCE_VAR != "" } { return $HM_CCU_PRESENCE_VAR }
    return "Anwesenheit"
}

# queries presence variables, heating channels, rooms (with heating) and
# programs from the CCU once per page view; result lines:
# V|name|value, H|channel|actual|setpoint|mode, R|room, P|program
proc ccuStatus { } {
    global CCU_STATUS
    if { [info exists CCU_STATUS] } { return $CCU_STATUS }
    set CCU_STATUS ""
    set prefix "[string map {\\ {} \" {}} [presencePrefix]]."
    catch {
        load tclrega.so
        array set r [rega_script [string map [list @PREFIX@ $prefix] {
            string s; string sOut = ""; string sPrefix = "@PREFIX@"; integer iPl = sPrefix.Length();
            foreach (s, dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()) {
              object o = dom.GetObject(s);
              string n = o.Name();
              if ((n.Find(sPrefix) == 0) && (o.ValueType() == ivtBinary)) {
                sOut = sOut # "V|" # n.Substr(iPl) # "|" # o.Value() # "\n";
              }
            }
            foreach (s, dom.GetObject(ID_CHANNELS).EnumUsedIDs()) {
              object c = dom.GetObject(s);
              if (c.HssType() == "HEATING_CLIMATECONTROL_TRANSCEIVER") {
                object oA = c.DPByHssDP("ACTUAL_TEMPERATURE");
                object oS = c.DPByHssDP("SET_POINT_TEMPERATURE");
                object oM = c.DPByHssDP("SET_POINT_MODE");
                string sA = "-"; string sS = "-"; string sM = "-";
                if (oA) { sA = oA.Value().ToString(1); }
                if (oS) { sS = oS.Value().ToString(1); }
                if (oM) { sM = oM.Value(); }
                sOut = sOut # "H|" # c.Name() # "|" # sA # "|" # sS # "|" # sM # "\n";
              }
            }
            foreach (s, dom.GetObject(ID_ROOMS).EnumUsedIDs()) {
              object rm = dom.GetObject(s);
              boolean bHeat = false;
              string sRc;
              foreach (sRc, rm.EnumUsedIDs()) {
                object oRc = dom.GetObject(sRc);
                if (oRc && (oRc.HssType() == "HEATING_CLIMATECONTROL_TRANSCEIVER")) { bHeat = true; }
              }
              if (bHeat) { sOut = sOut # "R|" # rm.Name() # "\n"; }
            }
            foreach (s, dom.GetObject(ID_PROGRAMS).EnumUsedIDs()) {
              object p = dom.GetObject(s);
              if (p.Visible() && (p.Name().Substr(0, 1) != "$")) { sOut = sOut # "P|" # p.Name() # "\n"; }
            }
        }]]
        set CCU_STATUS $r(sOut)
    }
    return $CCU_STATUS
}

proc badge { ok text {title ""} } {
    set cls [expr {$ok ? "label-success" : "label-default"}]
    set t ""
    if { $title != "" } { set t " title=\"[html-escape $title]\"" }
    return "<span class=\"label $cls\" style=\"display:inline-block;margin:2px\"$t>[html-escape $text]</span> "
}

# 'key epoch' lines written by hm_pdetect (keys: user:<name>, device:<name>)
proc lastSeenTimes { } {
    set result {}
    catch {
        set fd [open "/tmp/hm_pdetect-lastseen" r]
        foreach line [split [read $fd] "\n"] {
            if { [regexp {^(\S+)\s+([0-9]+)$} $line -> key ts] } { lappend result $key $ts }
        }
        close $fd
    }
    return $result
}

proc seenText { key seen } {
    array set s $seen
    if { ![info exists s($key)] } { return "" }
    set age [expr {[clock seconds] - $s($key)}]
    if { $age < 60 } { return [L "im WLAN" "in WiFi/LAN"] }
    set fmt "%H:%M"
    if { $age > 86400 } { set fmt "%d.%m. %H:%M" }
    return "[L {zuletzt gesehen} {last seen}] [clock format $s($key) -format $fmt]"
}

# maps MAC/IP/name: entries of the user list and the device list to a label
proc deviceAssignments { } {
    global HM_USER_LIST RULESFILE
    set map {}
    foreach {all key val} [regexp -all -inline {\[([^\]]+)\]=('[^']*'|"[^"]*"|\S+)} $HM_USER_LIST] {
        foreach e [regexp -all -inline {\S+} [string trim $val "'\""]] { lappend map [string toupper $e] "[L Person User] $key" }
    }
    set conf ""
    catch {set conf [loadFile $RULESFILE]}
    if { [regexp {HM_DEVICE_LIST=\(([^)]*)\)} $conf -> block] } {
        foreach {all key val} [regexp -all -inline {\[([^\]]+)\]='([^']*)'} $block] {
            foreach e [regexp -all -inline {\S+} $val] { lappend map [string toupper $e] "[L Ger\u00e4t Device] $key" }
        }
    }
    return $map
}

# status panel (page representation): presence, rule state, heating
# channels and the device list of the FRITZ! devices
proc statusHtml { } {
    global RULESSTATEFILE HM_KNOWN_LIST_MODE HM_CCU_PRESENCE_USER HM_CCU_PRESENCE_GUEST
    set userAll [expr {$HM_CCU_PRESENCE_USER != "" ? $HM_CCU_PRESENCE_USER : "Nutzer"}]
    set guest [expr {$HM_CCU_PRESENCE_GUEST != "" ? $HM_CCU_PRESENCE_GUEST : "Gast"}]
    set seen [lastSeenTimes]
    set anyone ""
    set persons ""
    set devices ""
    set heating ""
    foreach line [split [ccuStatus] "\n"] {
        set f [split $line |]
        switch -- [lindex $f 0] {
            V {
                set name [lindex $f 1]
                set on [expr {[lindex $f 2] == "true"}]
                if { [regexp {^[^.]+\.(.+)$} $name -> dev] } {
                    set txt "$dev: [expr {$on ? "online" : "offline"}]"
                    set st [seenText "device:$dev" $seen]
                    if { $st != "" } { append txt " ($st)" }
                    append devices [badge $on $txt]
                } elseif { $name == $userAll } {
                    set anyone [badge $on [expr {$on ? [L "Jemand da" "Someone home"] : [L "Niemand da" "Nobody home"]}] \
                                    [L "mindestens eine Person aus der Nutzerliste ist da" "at least one user from the user list is home"]]
                } elseif { $name != $guest || $HM_KNOWN_LIST_MODE != "off" } {
                    set txt "$name: [expr {$on ? [L da home] : [L weg away]}]"
                    set st [seenText "user:$name" $seen]
                    if { $st != "" } { append txt " ($st)" }
                    append persons [badge $on $txt]
                }
            }
            H {
                set mode [lindex $f 4]
                switch -- $mode { 0 { set mode "Auto" } 1 { set mode [L Manuell Manual] } 2 { set mode [L Urlaub Holiday] } }
                append heating "<tr><td>[html-escape [lindex $f 1]]</td><td class=\"text-right\">[html-escape [lindex $f 2]] \u00b0C</td><td class=\"text-right\"><b>[html-escape [lindex $f 3]] \u00b0C</b></td><td>[html-escape $mode]</td></tr>"
            }
        }
    }
    if { $persons == "" } { set persons "<i>[L {keine Daten} {no data}]</i>" }
    if { $devices == "" } { set devices "<i>[L "keine \u00fcberwachten Ger\u00e4te" {no monitored devices}]</i>" }

    set rules ""
    catch {
        set fd [open $RULESSTATEFILE r]
        foreach line [split [read $fd] "\n"] {
            if { [regexp {^([^=]+)=([01])$} [string trim $line] -> name val] } {
                append rules [badge $val "$name: [expr {$val ? [L aktiv active] : [L inaktiv inactive]}]"]
            }
        }
        close $fd
    }
    if { $rules == "" } { set rules "<i>[L {noch keine Auswertung} {not evaluated yet}]</i>" }

    set lastrun ""
    catch {
        set fd [open "/var/log/hm_pdetect.log" r]
        set first [gets $fd]
        close $fd
        if { [regexp {^== (.+?) =+$} $first -> ts] } { set lastrun $ts }
    }

    # device list of the FRITZ! devices (active first, then by name)
    set fritz ""
    set nActive 0
    set nAll 0
    catch {
        set fd [open "/tmp/hm_pdetect-devices" r]
        set rows {}
        foreach line [split [read $fd] "\n"] {
            set f [split $line |]
            if { [llength $f] < 4 } { continue }
            lappend rows [list [expr {[lindex $f 3] == 1 ? 0 : 1}] [string tolower [lindex $f 0]] $f]
        }
        close $fd
        array set assign [deviceAssignments]
        foreach row [lsort -integer -index 0 [lsort -index 1 $rows]] {
            lassign [lindex $row 2] name ip mac active guestflag
            incr nAll
            set act [expr {$active == 1}]
            if { $act } { incr nActive }
            set who {}
            foreach k [list "NAME:[string toupper $name]" [string toupper $mac] $ip] {
                if { [info exists assign($k)] && [lsearch -exact $who $assign($k)] < 0 } { lappend who $assign($k) }
            }
            set cls [expr {$act ? "" : " class=\"text-muted\""}]
            set state [expr {$act ? "<span class=\"label label-success\">[L aktiv active]</span>" : [L inaktiv inactive]}]
            if { $guestflag == 1 } { append state " <small>([L Gast guest])</small>" }
            append fritz "<tr$cls><td>[html-escape $name]</td><td>[html-escape $ip]</td><td><code>[html-escape $mac]</code></td><td>$state</td><td>[html-escape [join $who {, }]]</td></tr>"
        }
    }

    set html "<div class=\"panel panel-default\"><div class=\"panel-heading\"><b>[L {Aktueller Stand} {Current state}]</b>"
    if { $lastrun != "" } { append html " <small class=\"text-muted\">\u2013 [L "letzte Abfrage der FRITZ!-Ger\u00e4te" {last query of the FRITZ! devices}]: [html-escape $lastrun]</small>" }
    append html " <a href=\"\" class=\"pull-right\">[L aktualisieren refresh]</a></div><div class=\"panel-body\">"
    append html "<p><b>[L Personen Users]:</b> $anyone $persons</p>"
    append html "<p><b>[L Ger\u00e4te Devices]:</b> $devices</p>"
    append html "<p><b>[L Regeln Rules]:</b> $rules</p>"
    if { $heating != "" } {
        append html "<details><summary style=\"cursor:pointer\"><b>[L Heizungen Heating]</b></summary>"
        append html "<table class=\"table table-condensed\" style=\"margin-top:6px\"><tr><th>[L Kanal Channel]</th><th class=\"text-right\">[L Ist Actual]</th><th class=\"text-right\">[L Soll {Set point}]</th><th>[L Modus Mode]</th></tr>$heating</table></details>"
    }
    if { $fritz != "" } {
        append html "<details><summary style=\"cursor:pointer\"><b>[L "FRITZ!-Ger\u00e4te" {FRITZ! devices}]</b> ($nActive [L {aktiv von} {active of}] $nAll)</summary>"
        append html "<p class=\"help-block\" style=\"margin-top:6px\">[L "Den Namen aus der ersten Spalte kann man als <code>name:&lt;Name&gt;</code> in der Nutzer- oder Ger\u00e4teliste verwenden." {The name in the first column can be used as <code>name:&lt;name&gt;</code> in the user or device list.}]</p>"
        append html "<div style=\"overflow-x:auto\"><table class=\"table table-condensed\"><tr><th>Name</th><th>IP</th><th>MAC</th><th>Status</th><th>[L Zuordnung Assignment]</th></tr>$fritz</table></div></details>"
    }
    append html "</div></div>"
    return [to-page $html]
}

# heating channels and rooms usable as rule targets (page representation)
proc targetsHtml { } {
    set channels ""
    set rooms ""
    foreach line [split [ccuStatus] "\n"] {
        set f [split $line |]
        switch -- [lindex $f 0] {
            H { append channels "<code>[html-escape [lindex $f 1]]</code> " }
            R { append rooms "<code>room:[html-escape [lindex $f 1]]</code> " }
        }
    }
    set html ""
    if { $channels != "" } { append html "<p><b>[L Heizungskan\u00e4le {Heating channels}]:</b> <code>ALL</code> $channels</p>" }
    if { $rooms != "" } { append html "<p><b>[L R\u00e4ume Rooms]:</b> $rooms</p>" }
    return [to-page $html]
}

proc json-str { str } {
    set str [string map {\\ \\\\ \" \\\" \n \\n \r \\r \t \\t </ <\\/} $str]
    return "\"$str\""
}

proc json-list { items } {
    set out {}
    foreach i $items { lappend out [json-str $i] }
    return "\[[join $out ,]\]"
}

# data for the rule editor (page representation): heating channels, rooms,
# programs and the device list of the FRITZ! devices
proc rulesDataScript { } {
    global PAGE_LANG
    set channels {}
    set rooms {}
    set programs {}
    foreach line [split [ccuStatus] "\n"] {
        set f [split $line |]
        switch -- [lindex $f 0] {
            H { lappend channels [lindex $f 1] }
            R { lappend rooms [lindex $f 1] }
            P { lappend programs [lindex $f 1] }
        }
    }
    set fritz {}
    catch {
        set fd [open "/tmp/hm_pdetect-devices" r]
        foreach line [split [read $fd] "\n"] {
            set f [split $line |]
            if { [llength $f] < 4 || [lindex $f 0] == "" } { continue }
            lappend fritz "\{\"name\":[json-str [lindex $f 0]],\"ip\":[json-str [lindex $f 1]],\"mac\":[json-str [lindex $f 2]],\"active\":[expr {[lindex $f 3] == 1 ? "true" : "false"}]\}"
        }
        close $fd
    }
    set json "\{\"lang\":[json-str $PAGE_LANG],\"channels\":[json-list $channels],\"rooms\":[json-list $rooms],\"programs\":[json-list [lsort -dictionary $programs]],\"fritz\":\[[join $fritz ,]\]\}"
    return [to-page "<script>window.PDETECT_DATA = $json;</script>"]
}
