#!/bin/tclsh
source inc/settings.tcl
source inc/session.tcl
set PAGE_LANG "en"

puts "Content-Type: text/html; charset=utf-8"
puts ""

if {[info exists sid] && [check_session $sid]} {

  parseQuery

  if { $args(command) == "defaults" } {
    set args(HM_FRITZ_IP) ""
    set args(HM_FRITZ_USER) ""
    set args(HM_FRITZ_SECRET) ""
    set args(HM_CCU_PRESENCE_VAR) ""
    set args(HM_CCU_PRESENCE_LIST) ""
    set args(HM_CCU_PRESENCE_LIST_ENABLED) ""
    set args(HM_CCU_PRESENCE_STR) ""
    set args(HM_CCU_PRESENCE_STR_ENABLED) ""
    set args(HM_CCU_PRESENCE_GUEST) ""
    set args(HM_CCU_PRESENCE_GUEST_ENABLED) ""
    set args(HM_CCU_PRESENCE_GUEST_IPRANGE) ""
    set args(HM_CCU_PRESENCE_NOBODY) ""
    set args(HM_CCU_PRESENCE_USER) ""
    set args(HM_CCU_PRESENCE_USER_ENABLED) ""
    set args(HM_CCU_PRESENCE_PRESENT) ""
    set args(HM_CCU_PRESENCE_AWAY) ""
    set args(HM_USER_LIST) ""
    set args(HM_KNOWN_LIST_MODE) ""
    set args(HM_KNOWN_LIST) ""
    set args(HM_INTERVAL_TIME) ""

    # force save of data
    set args(command) "save"
  }

  set rulesKeep 0
  if { $args(command) == "save" } {
    # the rule editor fields are only present when RULES_FORM was sent
    if { $args(RULES_FORM) == "1" && ![saveRulesFile] } {
      set rulesKeep 1
    }
    saveConfigFile
  }

  set HM_FRITZ_IP ""
  set HM_FRITZ_USER ""
  set HM_FRITZ_SECRET ""
  set HM_CCU_PRESENCE_VAR ""
  set HM_CCU_PRESENCE_LIST ""
  set HM_CCU_PRESENCE_LIST_ENABLED ""
  set HM_CCU_PRESENCE_STR ""
  set HM_CCU_PRESENCE_STR_ENABLED ""
  set HM_CCU_PRESENCE_GUEST ""
  set HM_CCU_PRESENCE_GUEST_ENABLED ""
  set HM_CCU_PRESENCE_GUEST_IPRANGE ""
  set HM_CCU_PRESENCE_NOBODY ""
  set HM_CCU_PRESENCE_USER ""
  set HM_CCU_PRESENCE_USER_ENABLED ""
  set HM_CCU_PRESENCE_PRESENT ""
  set HM_CCU_PRESENCE_AWAY ""
  set HM_USER_LIST ""
  set HM_KNOWN_LIST_MODE ""
  set HM_KNOWN_LIST ""
  set HM_INTERVAL_TIME ""

  loadConfigFile
  if { !$rulesKeep } {
    loadRulesFile
  }
  set RULES_INFO [targetsHtml]
  set STATUS_HTML [statusHtml]
  set RULES_DATA [rulesDataScript]

  set content [subst {
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
      <meta http-equiv="X-UA-Compatible" content="IE=edge">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <meta name="description" content="settings">
      <meta name="author" content="mail@jens-maus.de">
      <meta name="language" content="en, english">
      <!-- Bootstrap core CSS -->
      <link href="css/bootstrap.min.css" rel="stylesheet">
      <link href="css/bootstrap-slider.min.css" rel="stylesheet">
      <!-- Custom styles for this template -->
      <link href="css/custombootstrap.css" rel="stylesheet">
      <link href="css/custom.css" rel="stylesheet">
      <title>HM-pdetect Addon</title>
      <style>
        details.cfg { border:1px solid #ddd; border-radius:4px; margin-bottom:10px; background:#fff; }
        details.cfg > summary { cursor:pointer; padding:8px 12px; font-weight:bold; background:#f5f5f5; border-radius:4px; }
        details.cfg\[open\] > summary { border-bottom:1px solid #ddd; border-radius:4px 4px 0 0; margin-bottom:12px; }
      </style>
    </head>
    <body  style="zoom: 1; margin-top: 60px;">
    <div class="navbar navbar-default navbar-fixed-top" role="navigation">
      <div class="container">
        <div class="navbar-header">
          <button type="button" class="navbar-toggle" data-toggle="collapse" data-target=".navbar-collapse">
            <span class="sr-only">Toggle navigation</span>
             <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="en.index.cgi?sid=$sid"  target="_blank"><img src="img/logo.png" alt=""> &nbsp;
     &nbsp;</a>
          </div>
       <div class="collapse navbar-collapse">
          <ul class="nav navbar-nav ">
            <li><a href="en.index.cgi?sid=$sid">About</a></li>
            <li><a href="en.logoutput.cgi?sid=$sid">Logfile</a></li>
            <li class="active"><a href="en.settings.cgi?sid=$sid">Configuration</a></li>
          </ul>
          <ul class="nav navbar-nav navbar-right">
            <li><a href="settings.cgi?sid=$sid">Deutsch</a></li>
          </ul>
         </div><!--/.nav-collapse -->
      </div><!-- class="container" -->
    </div><!-- class="navbar ..." -->
    <div class="container center1 col-md-8" id="content">
    <legend>FRITZ!-based Presence Detection - Configuration</legend>
    <div class="well well-s">

    <form class='form-horizontal' name='f_edit' id='f_edit' action="en.settings.cgi?sid=$sid" method="post">
    <fieldset>

    <%RULES_MSG%>
    <%STATUS%>
    <details class="cfg" open><summary>Users and guests</summary>
    <div class="editor-only" style="display:none;padding:0 15px;margin-bottom:15px">
      <h4 style="margin-top:18px">Users</h4>
      <p class="help-block">Choose the device (e.g. phone) of each user from the list of FRITZ! devices. Its MAC address is stored automatically.</p>
      <div id="user-editor"></div>
    </div>
    <div class="expert-only">
    <!-- Text area-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_USER_LIST" id="HM_USER_LIST-Label">Unique user devices<br>(MAC/IP-List):</label>
      <div class="col-md-8">
        <textarea id="HM_USER_LIST" name="HM_USER_LIST" type="text" rows="4" placeholder="e.g. \[John\]=AA:BB:CC:DD:EE:FF \[Jane\]='192.168.178.10 192.168.178.20'" class="form-control input-md"><%HM_USER_LIST%></textarea>
        <span class="help-block">Default: empty (no user devices configured)</span>
      </div>
    </div>
    </div>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_KNOWN_LIST" id="HM_KNOWN_LIST-Label">Known WiFi/LAN devices<br>(MAC/IP-List):</label>
      <div class="col-md-8">
        <textarea id="HM_KNOWN_LIST" name="HM_KNOWN_LIST" type="text" rows="4" placeholder="e.g. 'AA:BB:CC:DD:EE:FF 192.168.178.30'" class="form-control input-md"><%HM_KNOWN_LIST%></textarea>
        <label class="radio-inline"><input id="HM_KNOWN_LIST_MODE1" name="HM_KNOWN_LIST_MODE" type="radio" value="guest" <%HM_KNOWN_LIST_MODE1%>>apply to Guest-WiFi</label>
        <label class="radio-inline"><input id="HM_KNOWN_LIST_MODE2" name="HM_KNOWN_LIST_MODE" type="radio" value="all" <%HM_KNOWN_LIST_MODE2%>>apply to whole WiFi/LAN</label>
        <label class="radio-inline"><input id="HM_KNOWN_LIST_MODE3" name="HM_KNOWN_LIST_MODE" type="radio" value="off" <%HM_KNOWN_LIST_MODE3%>>guest detection disabled</label>
        <span class="help-block">Default: empty (all unknown devices in selected WiFi/LAN will be classified as guest devices)</span>
      </div>
    </div>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_GUEST_IPRANGE" id="HM_CCU_PRESENCE_GUEST_IPRANGE-Label">Guest network:</label>
      <div class="col-md-4">
        <input id="HM_CCU_PRESENCE_GUEST_IPRANGE" name="HM_CCU_PRESENCE_GUEST_IPRANGE" type="text" placeholder="z.B. '192.168.179.*'" class="form-control input-md" value="<%HM_CCU_PRESENCE_GUEST_IPRANGE%>">
        <span class="help-block">Default: '192.168.179.*'</span>
      </div>
    </div>
    </details>
    <details class="cfg" open><summary>Devices &amp; rules</summary>
    <p class="help-block" style="padding:0 15px">Controls CCU devices depending on who or what is in the network. Stored in a separate file and applied without restart in the next run.</p>
    <input type="hidden" name="RULES_FORM" value="1">
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_AWAY_DELAY">Away delay (s):</label>
      <div class="col-md-4">
        <input id="HM_AWAY_DELAY" name="HM_AWAY_DELAY" type="number" min="0" max="86400" step="1" class="form-control input-md" value="<%HM_AWAY_DELAY%>">
        <span class="help-block">Users and devices count as away only after not being seen for this long (bridges short WiFi drop-outs). Recommended: 600</span>
      </div>
    </div>
    <div class="editor-only" style="display:none;padding:0 15px;margin-bottom:15px">
      <h4 style="margin-top:18px">Monitored devices</h4>
      <p class="help-block">Devices do not count as users. Each device gets the variable &lt;variable prefix&gt;.Geraet.&lt;Name&gt;.</p>
      <div id="device-editor"></div>
    </div>
    <div class="editor-only" style="display:none;padding:0 15px;margin-bottom:15px">
      <h4 style="margin-top:18px">Rules</h4>
      <p class="help-block">Actions only run when the condition changes. If several rules control the same heating, the alphabetically last one wins.</p>
      <div id="rule-editor"></div>
    </div>
    <div class="expert-only">
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_DEVICE_LIST">Monitored devices:</label>
      <div class="col-md-8">
        <textarea id="HM_DEVICE_LIST" name="HM_DEVICE_LIST" rows="3" spellcheck="false" wrap="off" style="font-family:monospace" class="form-control input-md"><%HM_DEVICE_LIST%></textarea>
        <span class="help-block">One line per device: <code>Name = entries</code> (MAC, IP or <code>name:&lt;FRITZ! device name&gt;</code>).</span>
      </div>
    </div>
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_RULE_LIST">Rules:</label>
      <div class="col-md-8">
        <textarea id="HM_RULE_LIST" name="HM_RULE_LIST" rows="6" spellcheck="false" wrap="off" style="font-family:monospace" class="form-control input-md"><%HM_RULE_LIST%></textarea>
        <span class="help-block">One line per rule: <code>Name | condition | actions on enter | actions on leave</code>. Conditions: <code>device:&lt;Name&gt;</code>, <code>user:&lt;Name&gt;</code>, <code>anyone</code>, <code>nobody</code> (combine with <code>&amp;</code>, <code>!</code> negates). Actions (separate with <code>;</code>): <code>temp:&lt;target&gt;=&lt;°C&gt;</code>, <code>maxtemp:&lt;target&gt;=&lt;°C&gt;</code>, <code>auto:&lt;target&gt;</code>, <code>restore</code>, <code>set:&lt;datapoint&gt;=&lt;value&gt;</code>, <code>var:&lt;system variable&gt;=&lt;value&gt;</code>, <code>prog:&lt;program&gt;</code>. Targets: <code>ALL</code>, <code>room:&lt;room&gt;</code> or comma separated channel names.</span>
      </div>
    </div>
    <div class="form-group">
      <label class="col-md-3 control-label">Possible targets:</label>
      <div class="col-md-8"><%RULES_INFO%></div>
    </div>
    </div>
    <div class="form-group">
      <label class="col-md-3 control-label"></label>
      <div class="col-md-8"><label class="checkbox-inline"><input type="checkbox" id="expert-toggle"> Text view (advanced)</label></div>
    </div>
    </details>
    <details class="cfg"><summary>FRITZ! access</summary>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_FRITZ_IP" id="HM_FRITZ_IP-Label">FRITZ! Hostnames/IPs:</label>
      <div class="col-md-4">
      <input id="HM_FRITZ_IP" name="HM_FRITZ_IP" type="text" placeholder="e.g. 'fritz.box fritz.repeater'" class="form-control input-md" value="<%HM_FRITZ_IP%>">
      <span class="help-block">Default: 'fritz.box fritz.repeater'</span>
      </div>
    </div>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_FRITZ_USER" id="HM_FRITZ_USER-Label">FRITZ! Login Credentials:</label>
      <div class="col-md-4">
      <input id="HM_FRITZ_USER" name="HM_FRITZ_USER" type="text" placeholder="Username" class="form-control input-md" value="<%HM_FRITZ_USER%>">
      <span class="help-block">Default: empty (no username required)</span>
      </div>
      <div class="col-md-3">
      <input id="HM_FRITZ_SECRET" name="HM_FRITZ_SECRET" type="password" placeholder="Password" class="form-control input-md" value="<%HM_FRITZ_SECRET%>">
      <span class="help-block">Default: empty (no password required)</span>
      </div>
    </div>
    </details>
    <details class="cfg"><summary>Execution</summary>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_INTERVAL_TIME" id="HM_INTERVAL_TIME-Label">Automatic Execution:</label>
      <div class="col-md-8">
        <input id="HM_INTERVAL_TIME" name="HM_INTERVAL_TIME" type="text" style="width:100%" data-slider-min="0" data-slider-max="1800" data-slider-step="5" data-slider-value="<%HM_INTERVAL_TIME%>" data-slider-enabled="true"/>
        <span class="help-block">Default: 15s (Execution every 15 seconds)</span>
      </div>
    </div>
    </details>
    <details class="cfg"><summary>CCU variables</summary>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_VAR" id="HM_CCU_PRESENCE_VAR-Label">Variableprefix:</label>
      <div class="col-md-4">
        <input id="HM_CCU_PRESENCE_VAR" name="HM_CCU_PRESENCE_VAR" type="text" placeholder="e.g. 'Presence'" class="form-control input-md" value="<%HM_CCU_PRESENCE_VAR%>">
        <span class="help-block">Default: 'Anwesenheit'</span>
      </div>
    </div>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_PRESENT" id="HM_CCU_PRESENCE_PRESENT-Label">Variable values:</label>
      <div class="col-md-4">
        <input id="HM_CCU_PRESENCE_PRESENT" name="HM_CCU_PRESENCE_PRESENT" type="text" placeholder="e.g. 'present'" class="form-control input-md" value="<%HM_CCU_PRESENCE_PRESENT%>">
        <span class="help-block">Default: 'anwesend'</span>
      </div>
      <div class="col-md-3">
        <input id="HM_CCU_PRESENCE_AWAY" name="HM_CCU_PRESENCE_AWAY" type="text" placeholder="e.g. 'away'" class="form-control input-md" value="<%HM_CCU_PRESENCE_AWAY%>">
        <span class="help-block">Default: 'abwesend'</span>
      </div>
    </div>
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_NOBODY" id="HM_CCU_PRESENCE_NOBODY-Label"></label>
      <div class="col-md-4">
        <input id="HM_CCU_PRESENCE_NOBODY" name="HM_CCU_PRESENCE_NOBODY" type="text" placeholder="e.g. 'Nobody'" class="form-control input-md" value="<%HM_CCU_PRESENCE_NOBODY%>">
        <span class="help-block">Default: 'Niemand'</span>
      </div>
    </div>
    <!-- Text input-->
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_USER" id="HM_CCU_PRESENCE_USER-Label">Variablepostfixes:</label>
      <div class="col-md-4">
        <div class="input-group">
          <span class="input-group-addon">
            <input id="HM_CCU_PRESENCE_USER_ENABLED" name="HM_CCU_PRESENCE_USER_ENABLED" type="checkbox" <%HM_CCU_PRESENCE_USER_ENABLED%>>
          </span>
          <input id="HM_CCU_PRESENCE_USER" name="HM_CCU_PRESENCE_USER" type="text" placeholder="e.g. 'User'" class="form-control input-md" value="<%HM_CCU_PRESENCE_USER%>">
        </div>
        <span class="help-block">Default: 'Nutzer' (Anwesenheit.Nutzer)'</span>
      </div>
      <div class="col-md-3">
        <div class="input-group">
          <span class="input-group-addon">
            <input id="HM_CCU_PRESENCE_GUEST_ENABLED" name="HM_CCU_PRESENCE_GUEST_ENABLED" type="checkbox" <%HM_CCU_PRESENCE_GUEST_ENABLED%>>
          </span>
          <input id="HM_CCU_PRESENCE_GUEST" name="HM_CCU_PRESENCE_GUEST" type="text" placeholder="e.g. 'Guest'" class="form-control input-md" value="<%HM_CCU_PRESENCE_GUEST%>">
        </div>
        <span class="help-block">Default: 'Gast' (Anwesenheit.Gast)</span>
      </div>
    </div>
    <div class="form-group">
      <label class="col-md-3 control-label" for="HM_CCU_PRESENCE_LIST" id="HM_CCU_PRESENCE_LIST-Label"></label>
      <div class="col-md-4">
        <div class="input-group">
          <span class="input-group-addon">
            <input id="HM_CCU_PRESENCE_LIST_ENABLED" name="HM_CCU_PRESENCE_LIST_ENABLED" type="checkbox" <%HM_CCU_PRESENCE_LIST_ENABLED%>>
          </span>
          <input id="HM_CCU_PRESENCE_LIST" name="HM_CCU_PRESENCE_LIST" type="text" placeholder="e.g. 'list'" class="form-control input-md" value="<%HM_CCU_PRESENCE_LIST%>">
        </div>
        <span class="help-block">Default: 'list' (Anwesenheit.list)</span>
      </div>
      <div class="col-md-3">
        <div class="input-group">
          <span class="input-group-addon">
            <input id="HM_CCU_PRESENCE_STR_ENABLED" name="HM_CCU_PRESENCE_STR_ENABLED" type="checkbox" <%HM_CCU_PRESENCE_STR_ENABLED%>>
          </span>
          <input id="HM_CCU_PRESENCE_STR" name="HM_CCU_PRESENCE_STR" type="text" placeholder="e.g. 'string'" class="form-control input-md" value="<%HM_CCU_PRESENCE_STR%>">
        </div>
        <span class="help-block">Default: 'string' (Anwesenheit.string)</span>
      </div>
    </div>
    </details>
    <!-- Button -->
    <div class="form-group">
      <label class="control-label col-md-3" for="button1id"> </label>
    <div class="controls">
        <button type="submit" id="save" name="command" value="save" class="btn btn-default btn-customedit custom1" >
          <span class="glyphicon glyphicon-ok"></span>   Save</button>
         <noscript>
        <button type="submit" id="defaults" name="command" value="defaults" class="btn btn-default btn-customdelete custom1">
        </noscript>
        <script type="text/javascript">document.write("<button type='button' id='defaults' name='defaults' value='defaults' class='btn btn-default btn-customdelete custom1' onclick='check()'>");
        </script> Reset to defaults</button>
        <script type="text/javascript">document.write("<button type='reset' id='reset' name='reset' value='reset' class='btn btn-default btn-customdelete custom1' onclick=''>  Abort</button>");</script>
    </div>
    </div>
    </fieldset>
    </form>

    </div><!--div class="well"-->
    </div><!--div class="container"-->
    <script src="js/jquery.min.js"></script>
    <script src="js/bootstrap.min.js"></script>
    <script src="js/bootstrap-slider.min.js"></script>
    <script type="text/javascript">

    \$('#HM_INTERVAL_TIME').slider({
      formatter: function(value) {
        if(value == 0) {
          return "Off";
        } else {
          if(value >= 60) {
            return "Every " + new Date(value * 1000).toISOString().substr(14, 5) + " min";
          } else {
            return "Every " + value + " s";
          }
        }
      },
      tooltip: 'always',
      focus: true,
      scale: 'logarithmic',
    });

    // a slider initialised inside a collapsed section has no width until relayout
    \$('details.cfg').on('toggle', function() {
      try { \$('#HM_INTERVAL_TIME').slider('relayout'); } catch (e) {}
    });

    function check () {
      \$('#HM_FRITZ_IP').val("");
      \$('#HM_FRITZ_USER').val("");
      \$('#HM_FRITZ_SECRET').val("");
      \$('#HM_USER_LIST').val("");
      \$('#HM_KNOWN_LIST').val("");
      \$('#HM_INTERVAL_TIME').slider('setValue', 15);
      \$('#HM_KNOWN_LIST_MODE1').prop("checked", true);
      \$('#HM_KNOWN_LIST_MODE2').prop("checked", false);
      \$('#HM_KNOWN_LIST_MODE3').prop("checked", false);
      \$('#HM_CCU_PRESENCE_VAR').val("");
      \$('#HM_CCU_PRESENCE_LIST').val("");
      \$('#HM_CCU_PRESENCE_LIST_ENABLED').prop("checked", true);
      \$('#HM_CCU_PRESENCE_STR').val("");
      \$('#HM_CCU_PRESENCE_STR_ENABLED').prop("checked", true);
      \$('#HM_CCU_PRESENCE_GUEST').val("");
      \$('#HM_CCU_PRESENCE_GUEST_ENABLED').prop("checked", true);
      \$('#HM_CCU_PRESENCE_NOBODY').val("");
      \$('#HM_CCU_PRESENCE_USER').val("");
      \$('#HM_CCU_PRESENCE_USER_ENABLED').prop("checked", true);
      \$('#HM_CCU_PRESENCE_PRESENT').val("");
      \$('#HM_CCU_PRESENCE_AWAY').val("");
    }
    </script>
    <%RULES_DATA%>
    <script src="js/rules-editor.js" charset="utf-8"></script>
    </body>
    </html>
  }]

  # load common settings replace
  source inc/settings1.tcl

} else {
  puts "not authenticated"
}
