# configuration values are inserted with string map and HTML-escaped: regsub would
# interpret '&' and '\' in the values (e.g. a password containing '&')
set content [string map [list <%HM_FRITZ_IP%> [html-escape [string trim $HM_FRITZ_IP]]] $content]
set content [string map [list <%HM_FRITZ_USER%> [html-escape [string trim $HM_FRITZ_USER]]] $content]
set content [string map [list <%HM_FRITZ_SECRET%> [html-escape [string trim $HM_FRITZ_SECRET]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_VAR%> [html-escape [string trim $HM_CCU_PRESENCE_VAR]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_LIST%> [html-escape [string trim $HM_CCU_PRESENCE_LIST]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_STR%> [html-escape [string trim $HM_CCU_PRESENCE_STR]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_GUEST%> [html-escape [string trim $HM_CCU_PRESENCE_GUEST]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_NOBODY%> [html-escape [string trim $HM_CCU_PRESENCE_NOBODY]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_USER%> [html-escape [string trim $HM_CCU_PRESENCE_USER]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_PRESENT%> [html-escape [string trim $HM_CCU_PRESENCE_PRESENT]]] $content]
set content [string map [list <%HM_CCU_PRESENCE_AWAY%> [html-escape [string trim $HM_CCU_PRESENCE_AWAY]]] $content]
set content [string map [list <%HM_USER_LIST%> [html-escape [string trim $HM_USER_LIST]]] $content]
set content [string map [list <%HM_KNOWN_LIST%> [html-escape [string trim $HM_KNOWN_LIST]]] $content]
set content [string map [list <%HM_INTERVAL_TIME%> [html-escape [string trim $HM_INTERVAL_TIME]]] $content]

if {[string equal "all" $HM_KNOWN_LIST_MODE]} {
  set HM_KNOWN_LIST_MODE1 ""
  set HM_KNOWN_LIST_MODE2 "checked"
  set HM_KNOWN_LIST_MODE3 ""
} elseif {[string equal "off" $HM_KNOWN_LIST_MODE]} {
  set HM_KNOWN_LIST_MODE1 ""
  set HM_KNOWN_LIST_MODE2 ""
  set HM_KNOWN_LIST_MODE3 "checked"
} else {
  set HM_KNOWN_LIST_MODE1 "checked"
  set HM_KNOWN_LIST_MODE2 ""
  set HM_KNOWN_LIST_MODE3 ""
}

regsub -all {<%HM_KNOWN_LIST_MODE1%>} $content [string trim $HM_KNOWN_LIST_MODE1] content
regsub -all {<%HM_KNOWN_LIST_MODE2%>} $content [string trim $HM_KNOWN_LIST_MODE2] content
regsub -all {<%HM_KNOWN_LIST_MODE3%>} $content [string trim $HM_KNOWN_LIST_MODE3] content

if {[string equal "false" $HM_CCU_PRESENCE_LIST_ENABLED]} {
  set HM_CCU_PRESENCE_LIST_ENABLED ""
} else {
  set HM_CCU_PRESENCE_LIST_ENABLED "checked"
}
regsub -all {<%HM_CCU_PRESENCE_LIST_ENABLED%>} $content [string trim $HM_CCU_PRESENCE_LIST_ENABLED] content

if {[string equal "false" $HM_CCU_PRESENCE_STR_ENABLED]} {
  set HM_CCU_PRESENCE_STR_ENABLED ""
} else {
  set HM_CCU_PRESENCE_STR_ENABLED "checked"
}
regsub -all {<%HM_CCU_PRESENCE_STR_ENABLED%>} $content [string trim $HM_CCU_PRESENCE_STR_ENABLED] content

if {[string equal "false" $HM_CCU_PRESENCE_GUEST_ENABLED]} {
  set HM_CCU_PRESENCE_GUEST_ENABLED ""
} else {
  set HM_CCU_PRESENCE_GUEST_ENABLED "checked"
}
regsub -all {<%HM_CCU_PRESENCE_GUEST_ENABLED%>} $content [string trim $HM_CCU_PRESENCE_GUEST_ENABLED] content
set content [string map [list <%HM_CCU_PRESENCE_GUEST_IPRANGE%> [html-escape [string trim $HM_CCU_PRESENCE_GUEST_IPRANGE]]] $content]

if {[string equal "false" $HM_CCU_PRESENCE_USER_ENABLED]} {
  set HM_CCU_PRESENCE_USER_ENABLED ""
} else {
  set HM_CCU_PRESENCE_USER_ENABLED "checked"
}
regsub -all {<%HM_CCU_PRESENCE_USER_ENABLED%>} $content [string trim $HM_CCU_PRESENCE_USER_ENABLED] content

# string map instead of regsub: rule text contains '&', which regsub would
# treat as a back reference
set content [string map [list \
  <%RULES_MSG%> $RULES_MSG \
  <%RULES_INFO%> $RULES_INFO \
  <%STATUS%> $STATUS_HTML \
  <%RULES_DATA%> $RULES_DATA \
  <%HM_AWAY_DELAY%> [html-escape [string trim $RULES_AWAY_DELAY]] \
  <%HM_DEVICE_LIST%> [html-escape [string trim $RULES_DEVICES]] \
  <%HM_RULE_LIST%> [html-escape [string trim $RULES_RULES]] \
  ] $content]

puts $content
