#!/usr/bin/env bash
# shellcheck disable=SC1090
#
# A FRITZ!-based HomeMatic presence detection script which can be regularly
# executed (e.g. via cron on a separate Linux system) and remotely queries a FRITZ!
# device about the registered LAN/WLAN devices.
#
# This script can be found at https://github.com/jens-maus/hm_pdetect
#
# Based on a device list specified in the config file (HM_USER_LIST) certain system
# variables are then set in the corresponding CCU so that users are being recognized
# as being present or away. In addition guests are being identified by also specifying
# other known devices in a separate list (HM_KNOWN_LIST) and if a device is found
# that is not either in the user list or known list it will be recognized as a
# guest device and the script will set a presence system variable for guests in the
# CCU as well.
#
# Copyright (C) 2015-2023 Jens Maus <mail@jens-maus.de>
#
# This script is based on similar functionality and combines the functionality of
# these projects into a single script:
#
# https://github.com/jollyjinx/homematic
# https://github.com/max2play/webinterface
#

VERSION="1.16"
VERSION_DATE="Jul 13 2023"

#####################################################
# Main script starts here, don't modify from here on

# before we read in default values we have to find
# out which HM_* variables the user might have specified
# on the command-line himself
USERVARS=$(set -o posix; set | grep "HM_.*=" 2>/dev/null)

# IP addresses/hostnames of FRITZ! devices
HM_FRITZ_IP=${HM_FRITZ_IP:-"fritz.box fritz.repeater"}

# IP address/hostname of CCU2
HM_CCU_IP=${HM_CCU_IP:-"homematic-raspi.fritz.box"}

# Port settings for ReGa communications
HM_CCU_REGAPORT=${HM_CCU_REGAPORT:-"8181"}

# Name of the CCU variable prefix used
HM_CCU_PRESENCE_VAR=${HM_CCU_PRESENCE_VAR:-"Anwesenheit"}

# used names (user definable)
HM_CCU_PRESENCE_USER=${HM_CCU_PRESENCE_USER:-"Nutzer"}
HM_CCU_PRESENCE_USER_ENABLED=${HM_CCU_PRESENCE_USER_ENABLED:-true}
HM_CCU_PRESENCE_GUEST=${HM_CCU_PRESENCE_GUEST:-"Gast"}
HM_CCU_PRESENCE_GUEST_ENABLED=${HM_CCU_PRESENCE_GUEST_ENABLED:-true}
HM_CCU_PRESENCE_LIST=${HM_CCU_PRESENCE_LIST:-"list"}
HM_CCU_PRESENCE_LIST_ENABLED=${HM_CCU_PRESENCE_LIST_ENABLED:-true}
HM_CCU_PRESENCE_STR=${HM_CCU_PRESENCE_STR:-"string"}
HM_CCU_PRESENCE_STR_ENABLED=${HM_CCU_PRESENCE_STR_ENABLED:-true}

# used names for variable values
HM_CCU_PRESENCE_NOBODY=${HM_CCU_PRESENCE_NOBODY:-"Niemand"}
HM_CCU_PRESENCE_PRESENT=${HM_CCU_PRESENCE_PRESENT:-"anwesend"}
HM_CCU_PRESENCE_AWAY=${HM_CCU_PRESENCE_AWAY:-"abwesend"}

# guest IP range in case device is not recognized by "guest" status
HM_CCU_PRESENCE_GUEST_IPRANGE=${HM_CCU_PRESENCE_GUEST_IPRANGE:-"192.168.179.*"}

# Specify mode of HM_KNOWN_LIST variable setting
#
# guest - apply known ignore list to devices in a dedicated
#         guest WiFi/LAN only (requireѕ enabled guest WiFi/LAN in
#         FRITZ! device)
# all   - apply known ignore list to all devices
# off   - disabled guest recognition
HM_KNOWN_LIST_MODE=${HM_KNOWN_LIST_MODE:-"guest"}

# MAC/IP addresses of other known devices (all others will be
# recognized as guest devices
HM_KNOWN_LIST=${HM_KNOWN_LIST:-""}

# number of seconds to wait between iterations
# (will run hm_pdetect in an endless loop)
HM_INTERVAL_TIME=${HM_INTERVAL_TIME:-}

# maximum number of iterations if running in interval mode
# (default: 0=unlimited)
HM_INTERVAL_MAX=${HM_INTERVAL_MAX:-0}

# where to save the process ID in case hm_pdetect runs as
# a daemon
HM_DAEMON_PIDFILE=${HM_DAEMON_PIDFILE:-"/var/run/hm_pdetect.pid"}

# Processing logfile output name
# (default: no output)
HM_PROCESSLOG_FILE=${HM_PROCESSLOG_FILE:-}

# maximum number of lines the logfile should contain
# (default: 500 lines)
HM_PROCESSLOG_MAXLINES=${HM_PROCESSLOG_MAXLINES:-500}

# the config file path
# (default: 'hm_pdetect.conf' in path where hm_pdetect.sh script resists)
CONFIG_FILE=${CONFIG_FILE:-"$(realpath "$(dirname "${BASH_SOURCE[0]}")")/hm_pdetect.conf"}

# separate file holding HM_DEVICE_LIST/HM_RULE_LIST, kept apart from
# CONFIG_FILE because the addon settings page rewrites CONFIG_FILE
# (default: 'hm_pdetect-rules.conf' next to CONFIG_FILE)
HM_RULES_FILE=${HM_RULES_FILE:-}

# seconds a user/device must stay unseen before it is reported as away
# (bridges short WiFi power-save drop-outs of phones; 0=disabled)
HM_AWAY_DELAY=${HM_AWAY_DELAY:-0}

# name infix of the CCU variables for monitored devices
# (results in e.g. 'Anwesenheit.Geraet.BueroPC')
HM_CCU_PRESENCE_DEVICE=${HM_CCU_PRESENCE_DEVICE:-"Geraet"}

# directory for persistent rule state (rule on/off + saved heating settings)
# (default: directory of CONFIG_FILE)
HM_STATE_DIR=${HM_STATE_DIR:-}

# if true, rule actions are only logged but not sent to the CCU
HM_RULES_DRYRUN=${HM_RULES_DRYRUN:-false}

# global return status variables
RETURN_FAILURE=1
RETURN_SUCCESS=0

###############################
# now we check all dependencies first. That means we
# check that we have the right bash version and third-party tools
# installed
#

# bash check
if [[ ${BASH_VERSINFO[0]} -lt 4 ]]; then
  echo "ERROR: this script requires a bash shell of version 4 or higher. Please install."
  exit ${RETURN_FAILURE}
fi

# wget check
if [[ ! -x $(which wget) ]]; then
  echo "ERROR: 'wget' tool missing. Please install."
  exit ${RETURN_FAILURE}
fi

# iconv check
if [[ ! -x $(which iconv) ]]; then
  echo "ERROR: 'iconv' tool missing. Please install."
  exit ${RETURN_FAILURE}
fi

# md5sum check
if [[ ! -x $(which md5sum) ]]; then
  echo "ERROR: 'md5sum' tool missing. Please install."
  exit ${RETURN_FAILURE}
fi

# declare all associative arrays first (bash v4+ required)
declare -A HM_USER_LIST     # username<>MAC/IP tuple
declare -A HM_DEVICE_LIST   # devicename<>MAC/IP/name: tuple
declare -A HM_RULE_LIST     # rulename<>'condition|enter actions|leave actions'
declare -A normalDeviceList # MAC<>IP tuple (normal-WiFi/LAN)
declare -A guestDeviceList  # MAC<>IP tuple (guest-WiFi/LAN)
declare -A activeNameList   # uppercased FRITZ! device name<>MAC (all active devices)
declare -A userState        # username<>true/false (after away delay)
declare -A deviceState      # devicename<>true/false (after away delay)
declare -A lastSeenList     # 'user:X'/'device:X'<>epoch of last sighting
fritzDeviceLines=()         # 'name|ip|mac|active|guest' of all devices known to the FRITZ! devices

###############################
# lets check if config file was specified as a cmdline arg
if [[ ${#} -gt 0        && \
      ${!#} != "child"  && \
      ${!#} != "daemon" && \
      ${!#} != "start"  && \
      ${!#} != "stop" ]]; then
  CONFIG_FILE="${!#}"
fi

if [[ ! -e ${CONFIG_FILE} ]]; then
  echo "WARNING: config file '${CONFIG_FILE}' doesn't exist. Using default values."
  CONFIG_FILE=
fi

# lets source the config file a first time
if [[ -n ${CONFIG_FILE} ]]; then
  if ! source "${CONFIG_FILE}"; then
    echo "ERROR: couldn't source config file '${CONFIG_FILE}'. Please check config file syntax."
    exit ${RETURN_FAILURE}
  fi

  # lets eval the user overridden variables
  # so that they take priority
  eval "${USERVARS}"
fi

# function sourcing the separate rules file (HM_DEVICE_LIST, HM_RULE_LIST, ...)
function sourceRulesFile()
{
  local cfgdir="."
  if [[ -n ${CONFIG_FILE} ]]; then
    cfgdir=$(dirname "${CONFIG_FILE}")
  fi
  RULES_FILE=${HM_RULES_FILE:-"${cfgdir}/hm_pdetect-rules.conf"}
  STATE_DIR=${HM_STATE_DIR:-"${cfgdir}"}

  # start from empty lists so that removed entries really disappear
  HM_DEVICE_LIST=()
  HM_RULE_LIST=()
  if [[ -e ${RULES_FILE} ]]; then
    if ! source "${RULES_FILE}"; then
      echo "ERROR: couldn't source rules file '${RULES_FILE}'. Please check its syntax."
      return ${RETURN_FAILURE}
    fi
    eval "${USERVARS}"
  fi
  return ${RETURN_SUCCESS}
}

if ! sourceRulesFile; then
  exit ${RETURN_FAILURE}
fi

###############################
# run hm_pdetect as a real daemon by using setsid
# to fork and deattach it from a terminal.
if [[ ${#} -gt 0 ]]; then
  FILE=${0##*/}
  DIR=$(realpath "$(dirname "${BASH_SOURCE[0]}")")

  # lets check the supplied command
  case "${1}" in

    start) # 1. lets start the child
      shift
      exec "${DIR}/${FILE}" child "${CONFIG_FILE}" &
      exit 0
    ;;

    child) # 2. We are the child. We need to fork the daemon now
      shift
      umask 0
      echo
      echo "Starting hm_pdetect in daemon mode."
      exec setsid "${DIR}/${FILE}" daemon "${CONFIG_FILE}" </dev/null >/dev/null 2>/dev/null &
      exit 0
    ;;

    daemon) # 3. We are the daemon. Lets continue with the real stuff
      shift
      # save the PID number in the specified PIDFILE so that we 
      # can kill it later on using this file
      if [[ -n ${HM_DAEMON_PIDFILE} ]]; then
        echo $$ >"${HM_DAEMON_PIDFILE}"
      fi

      # if we end up here we are in daemon mode and
      # can continue normally but make sure we don't allow any
      # input
      exec 0</dev/null
    ;;

    stop) # 4. stop the daemon if requested
      if [[ -f ${HM_DAEMON_PIDFILE} ]]; then
        echo "Stopping hm_pdetect (pid: $(cat "${HM_DAEMON_PIDFILE}"))"
        kill "$(cat "${HM_DAEMON_PIDFILE}")" >/dev/null 2>&1
        rm -f "${HM_DAEMON_PIDFILE}" >/dev/null 2>&1
      fi
      exit 0
    ;;

  esac
fi
 
###############################
# function returning the current state of a homematic variable
# and returning success/failure if the variable was found/not
function getVariableState()
{
  local name="$1"
  local result=""
  result=$(wget -T 5 -t 1 -q -O - "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/rega.exe?state=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${name}').Value()")
  if [[ ${result} =~ \<state\>(.*)\</state\> ]]; then
    result="${BASH_REMATCH[1]}"
    if [[ ${result} != "null" ]]; then
      echo "${result}"
      return ${RETURN_SUCCESS}
    fi
  fi

  echo "${result}"
  return ${RETURN_FAILURE}
}

# function setting the state of a homematic variable in case it
# it different to the current state and the variable exists
function setVariableState()
{
  local name="$1"
  local newstate="$2"

  # before we going to set the variable state we
  # query the current state and if the variable exists or not
  curstate=$(getVariableState "${name}")
  if [[ ${curstate} == "null" ]]; then
    return ${RETURN_FAILURE}
  fi

  # only continue if the current state is different to the new state
  if [[ ${curstate} == "${newstate//\'}" ]]; then
    return ${RETURN_SUCCESS}
  fi

  # the variable should be set to a new state, so lets do it
  echo -n "  Setting CCU variable '${name}': '${newstate//\'}'... "
  local result=""
  result=$(wget -T 5 -t 1 -q -O - "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/rega.exe?state=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${name}').State(${newstate})")
  if [[ ${result} =~ \<state\>(.*)\</state\> ]]; then
    result="${BASH_REMATCH[1]}"
  else
    result=""
  fi

  # if setting the variable succeeded the result will be always
  # 'true'
  if [[ ${result} == "true" ]]; then
    echo "ok."
    return ${RETURN_SUCCESS}
  fi

  echo "ERROR."
  return ${RETURN_FAILURE}
}

# function to check if a certain boolean system variable exists
# at a CCU and if not creates it accordingly
function createVariable()
{
  local vaname=$1
  local vatype=$2
  local comment=$3
  local valist=$4

  # first we find out if the variable already exists and if
  # the value name/list it contains matches the value name/list
  # we are expecting
  local postbody=""
  if [[ ${vatype} == "enum" ]]; then
    local result=""
    result=$(wget -T 5 -t 1 -q -O - "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/rega.exe?valueList=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueList()")
    if [[ ${result} =~ \<valueList\>(.*)\</valueList\> ]]; then
      result="${BASH_REMATCH[1]}"
    fi

    # make sure result is not empty and not null
    if [[ -n ${result} && ${result} != "null" ]]; then
      if [[ ${result} != "${valist}" ]]; then
        echo -n "  Modifying CCU variable '${vaname}' (${vatype})... "
        postbody="string v='${vaname}';dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueList('${valist}')"
      fi
    else
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtInteger);n.ValueSubType(istEnum);n.DPInfo('${comment}');n.ValueList('${valist}');n.State(0);dom.RTUpdate(false);}"
    fi
  elif [[ ${vatype} == "string" ]]; then
    getVariableState "${vaname}" >/dev/null
    if [[ $? -eq 1 ]]; then
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtString);n.ValueSubType(istChar8859);n.DPInfo('${comment}');n.State('');dom.RTUpdate(false);}"
    fi
  else
    local result=""
    result=$(wget -T 5 -t 1 -q -O - "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/rega.exe?valueName0=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueName0()&valueName1=dom.GetObject(ID_SYSTEM_VARIABLES).Get('${vaname}').ValueName1()")
    local valueName0="null"
    local valueName1="null"
    if [[ ${result} =~ \<valueName0\>(.*)\</valueName0\>\<valueName1\>(.*)\</valueName1\> ]]; then
      valueName0="${BASH_REMATCH[1]}"
      valueName1="${BASH_REMATCH[2]}"
    fi

    # make sure result is not empty and not null
    if [[ -n ${result} && \
          ${valueName0} != "null" && ${valueName1} != "null" ]]; then

       if [[ ${valueName0} != "${HM_CCU_PRESENCE_AWAY}" || \
             ${valueName1} != "${HM_CCU_PRESENCE_PRESENT}" ]]; then
         echo -n "  Modifying CCU variable '${vaname}' (${vatype})... "
         postbody="string v='${vaname}';dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueName0('${HM_CCU_PRESENCE_AWAY}');dom.GetObject(ID_SYSTEM_VARIABLES).Get(v).ValueName1('${HM_CCU_PRESENCE_PRESENT}')"
       fi
    else
      echo -n "  Creating CCU variable '${vaname}' (${vatype})... "
      postbody="string v='${vaname}';boolean f=true;string i;foreach(i,dom.GetObject(ID_SYSTEM_VARIABLES).EnumUsedIDs()){if(v==dom.GetObject(i).Name()){f=false;}};if(f){object s=dom.GetObject(ID_SYSTEM_VARIABLES);object n=dom.CreateObject(OT_VARDP);n.Name(v);s.Add(n.ID());n.ValueType(ivtBinary);n.ValueSubType(istBool);n.DPInfo('${comment}');n.ValueName1('${HM_CCU_PRESENCE_PRESENT}');n.ValueName0('${HM_CCU_PRESENCE_AWAY}');n.State(false);dom.RTUpdate(false);}"
    fi
  fi

  # if postbody is empty there is nothing to do
  # and the variable exists with correct value name/list
  if [[ -z ${postbody} ]]; then
    return ${RETURN_SUCCESS}
  fi

  # use wget to post the tcl script to tclrega.exe
  local result=""
  result=$(wget -T 5 -t 1 -q -O - --post-data "${postbody}" "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/tclrega.exe")
  if [[ ${result} =~ \<v\>${vaname}\</v\> ]]; then
    echo "ok."
    return ${RETURN_SUCCESS}
  else
    echo "ERROR: could not create system variable '${vaname}'."
    return ${RETURN_FAILURE}
  fi
}

# function that gets a new sessionID for connecting to a FRITZ! device
function getSessionID()
{
  local uri=$1

  # retrieve login challenge
  local challenge=""
  challenge=$(wget -T 5 -t 1 -q -O - --no-check-certificate "${uri}/login_sid.lua")
  if [[ ${challenge} =~ \<Challenge\>(.*)\</Challenge\> ]]; then
    challenge="${BASH_REMATCH[1]}"
  else
    challenge=""
  fi

  # check if we retrieved a valid challenge
  if [[ -z ${challenge} ]]; then
    echo
    echo "WARNING: could not connect to ${uri}. Please check hostname/ip or URI."
    return ${RETURN_FAILURE}
  fi

  # process login and hash it with our password
  local cpstr="${challenge}-${secret}"
  local md5=""
  md5=$(echo -n "${cpstr}" | iconv -f ISO8859-1 -t UTF-16LE | md5sum -b | cut -d' ' -f1)
  local response="${challenge}-${md5}"
  local url_params="username=${user}&response=${response}"
  
  # send login request and retrieve SID
  local sid=""
  sid=$(wget -T 5 -t 1 -q -O - --no-check-certificate "${uri}/login_sid.lua?${url_params}")
  if [[ ${sid} =~ \<SID\>(.*)\</SID\> ]]; then
    sid="${BASH_REMATCH[1]}"
  else
    sid=""
  fi
 
  # check if we got a valid SID
  if [[ -z ${sid} || ${sid} == "0000000000000000" ]]; then
    echo
    echo "ERROR: username or password incorrect."
    return ${RETURN_FAILURE}
  fi

  echo "${sid}"
  return ${RETURN_SUCCESS}
}

# function to retrieve the current device list registered
# with a FRITZ! devices. This is performed by using query.lua
# and will return the name, ip, mac, guest status and active status
# of devices registerd at the WiFi/LAN of a FRITZ! device
function getDeviceList()
{
  local uri=$1
  local sid=$2
  local devices=

  # NOTE: FRITZ!OS Version can be queried via following URL
  #
  # http://fritz.box/query.lua?sid=${sid}&fw=logic:status/nspver

  # retrieve the network device list from the fritzbox using a
  # specific call to query.lua so that we get our information without
  # having to parse HTML portions.
  devices=$(wget -T 5 -t 1 -q -O - --max-redirect=0 --no-check-certificate "${uri}/query.lua?sid=${sid}&network=landevice:settings/landevice/list(name,ip,mac,guest,wlan,speed,active)")
  if [[ $? -ne 0 || -z ${devices} ]]; then
    return ${RETURN_FAILURE}
  fi

  echo "${devices}"
  return ${RETURN_SUCCESS}
}

# function that logs into a FRITZ! device and stores the MAC and IP address of all devices
# in an associative array which have to bre created before calling this function
function retrieveFritzBoxDeviceList()
{
  local ip=$1
  local user=$2
  local secret=$3
  local uri=${ip}

  # check if "ip" starts with a "http(s)://" URL scheme
  # identifier or if we have to add it ourself
  if [[ ! ${ip} =~ ^http(s)?:\/\/ ]]; then
    uri="http://${ip}"
  else
    ip=$(echo "${ip}" | sed -E 's/^http(s)?:\/\///g')
  fi

  # retrieve the network device list from the fritzbox using a
  # specific call to query.lua so that we get our information without
  # having to parse HTML portions. we first try this with our
  local devices=
  local res=1
  local sid=""

  # get a previously existing session id and try that first
  sid=$(cat "/tmp/hm_pdetect-${ip}.sid" 2>/dev/null)
  if [[ -n ${sid} ]]; then
    devices=$(getDeviceList "${uri}" "${sid}")
    res=$?
  fi
  if [[ ${res} -ne 0 || -z ${devices} ]]; then
    # the first iteration with the sid of the
    # last iteration didn't work out so lets
    # generate a new one
    if ! sid=$(getSessionID "${uri}"); then
      return ${RETURN_FAILURE}
    fi

    # try to retrieve the device list again
    if devices=$(getDeviceList "${uri}" "${sid}"); then
      # the SID succeeded so lets make this SID the
      # new currently valid SID of this ip
      (umask 077; echo -n "${sid}" >"/tmp/hm_pdetect-${ip}.sid")
      echo -n " (fresh login)"
      res=0
    else
      res=1
    fi
  fi

  # perform a last check
  if [[ ${res} -ne 0 || -z ${devices} ]]; then
    echo
    echo "ERROR: Couldn't retrieve device list."
    return ${RETURN_FAILURE}
  fi

  # now we prepare the 'devices' variable to have all
  # parameters on separate lines
  # (some FRITZ!OS versions put everything on one line)
  devices="${devices//[\{/$'\n'[\{$'\n'}"
  devices="${devices//\},{/$'\n'\},{$'\n'}"
  devices="${devices//\}]/$'\n'\}]}"
  devices="${devices//\",/\",$'\n'}"
  devices=$(echo "${devices}" | grep '[^[:blank:]]')

  # DEBUG: uncomment for debugging purposes
  #echo
  #echo "${devices}"

  # prepare the regular expressions
  local re_name="\"name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  local re_ip="\"ip\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  local re_mac="\"mac\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  local re_guest="\"guest\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  #local re_wlan="\"wlan\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  #local re_speed="\"speed\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""
  local re_active="\"active\"[[:space:]]*:[[:space:]]*\"([^\"]*)\""

  local maclist_normal=()
  local iplist_normal=()
  local maclist_guest=()
  local iplist_guest=()
  local name=""
  local ipaddr=""
  local mac=""
  local guest=0
  #local wlan=0
  #local speed=0
  local active=0

  # parse the query.lua output line by line
  while read -r line; do

    # we collect data until we find a '}' character in one line
    # which should signal that we have parsed all parameters of a device
    if [[ $line =~ .*}.* ]]; then
      if [[ -n $ipaddr ]]; then
        # complete list (incl. inactive devices) for the settings page
        fritzDeviceLines+=("${name//|/_}|${ipaddr}|${mac^^}|${active}|${guest}")
        # DEBUG: output name+speed+active for debugging purposes
        #echo -n "${name}: ${active} @ ${speed} - wlan: ${wlan} - "

        # only add 'active' devices
        if [[ ${active} -eq 1 ]]; then
          if [[ -n ${name} ]]; then
            activeNameList[${name^^}]="${mac^^}"
          fi
          if [[ ${guest} -eq 1 ]] || [[ ${ipaddr} =~ ${HM_CCU_PRESENCE_GUEST_IPRANGE} ]]; then
            maclist_guest+=("${mac^^}") # add uppercased mac address
            iplist_guest+=("${ipaddr}")

            # DEBUG: debug statement
            #echo "active(GUEST)"
          else
            maclist_normal+=("${mac^^}") # add uppercased mac address
            iplist_normal+=("${ipaddr}")

            # DEBUG: debug statement
            #echo "active(NORMAL)"
          fi
        #else
          # DEBUG: debug statement
          #echo "NOT ACTIVE"
        fi

        # reset variables
        name=""
        ipaddr=""
        mac=""
        guest=0
        #wlan=0
        #speed=0
        active=0
      fi
    elif [[ $line =~ $re_name ]]; then
      name="${BASH_REMATCH[1]}"
    elif [[ $line =~ $re_ip ]]; then
      ipaddr="${BASH_REMATCH[1]}"
    elif [[ $line =~ $re_mac ]]; then
      mac="${BASH_REMATCH[1]}"
    elif [[ $line =~ $re_guest ]]; then
      guest="${BASH_REMATCH[1]}"
    #elif [[ $line =~ $re_wlan ]]; then
    #  wlan="${BASH_REMATCH[1]}"
    #elif [[ $line =~ $re_speed ]]; then
    #  speed="${BASH_REMATCH[1]}"
    elif [[ $line =~ $re_active ]]; then
      active="${BASH_REMATCH[1]}"
    fi
  done <<< "${devices}"

  # modify the global associative array for the normal-WiFi/LAN
  for (( i = 0; i < ${#maclist_normal[@]} ; i++ )); do
    if [[ -n "${iplist_normal[$i]}" ]]; then
      normalDeviceList[${iplist_normal[$i]}]=${maclist_normal[$i]}
    fi
  done

  # modify the global associative array for the guest-WiFi/LAN
  for (( i = 0; i < ${#maclist_guest[@]} ; i++ )); do
    if [[ -n "${iplist_guest[$i]}" ]]; then
      guestDeviceList[${iplist_guest[$i]}]=${maclist_guest[$i]}
    fi
  done

  return ${RETURN_SUCCESS}
}

# function that creates a list of tupels from an input string
# of individual users. This tuple list can then be used to be set for the
# presence.list variable type when constructing it
function createUserTupleList()
{
  local a="$1"

  # constract the brace expansion string from the input
  # string so that we end up with something like '{1,}{2,}{3,}', etc.
  local b=""
  local i=0
  IFS=';'
  # shellcheck disable=SC2034
  for Y in ${a}; do
    ((i = i + 1))
    b="$b{$i,}"
  done
  IFS=' '

  # lets apply the brace expansion string and sort it
  # according to numbers and not have it in the standard sorting
  local c=""
  c=$(for X in $(eval echo\ $b); do echo "${X}"; done | sort -n | tr '\n' ' ')

  # lets construct tupels for every number (1-9) in
  # the brace expansion
  local tuples=""
  for X in ${c}; do
    if [[ -n ${tuples} ]]; then
      tuples="${tuples};"
    fi
    folded=$(echo -n "${X}" | fold -w1 | tr '\n' ',')
    tuples="${tuples}${folded}"
  done

  # now we replace each number (1-9) with the appropriate
  # string of the input array
  local i=0
  IFS=';'
  for Z in ${a}; do
    ((i = i + 1))
    tuples=${tuples//${i}/${Z}}
  done
  IFS=' '

  # now add "Guest" to each tuple (if not disabled)
  local guestTuples=""
  if [[ -n ${HM_CCU_PRESENCE_GUEST} && \
        ${HM_KNOWN_LIST_MODE} != "off" && \
        ${HM_CCU_PRESENCE_GUEST_ENABLED} == true ]]; then
    IFS=';'
    guestTuples=";${HM_CCU_PRESENCE_GUEST}"
    for U in ${tuples}; do
      guestTuples="${guestTuples};${U},${HM_CCU_PRESENCE_GUEST}"
    done
    IFS=' '
  fi

  tuples="${HM_CCU_PRESENCE_NOBODY};${tuples}${guestTuples}"

  echo "${tuples}"
}

# function to count the position within the enum list
# where the presence list matches
function whichEnumID()
{
  local enumList="$1"
  local presenceList="$2"

  # now we iterate through the ;—separated enumList
  IFS=';'
  local i=0
  local result=0
  for id in ${enumList}; do
    if [[ ${presenceList} == "${id}" ]]; then
      result=$i
      break
    fi
    ((i = i + 1 ))
  done
  IFS=' '

  echo ${result}
}

# replaces 'name:<FRITZ! device name>' entries of a space separated device
# list by the MAC address of the currently active device carrying that name
function resolveDeviceEntries()
{
  local out=""
  local e=""
  for e in ${1}; do
    if [[ ${e,,} == name:* ]]; then
      local n="${e#*:}"
      if [[ -n ${activeNameList[${n^^}]} ]]; then
        e="${activeNameList[${n^^}]}"
      fi
    fi
    out+="${out:+ }${e}"
  done
  echo "${out}"
}

# returns success if any MAC/IP/name: entry of the space separated list
# is currently active in the normal or guest WiFi/LAN (exact match)
function isDeviceOnline()
{
  local e=""
  local d=""
  for e in $(resolveDeviceEntries "${1}"); do
    e="${e^^}"
    if [[ -n ${normalDeviceList[${e}]+x} || -n ${guestDeviceList[${e}]+x} ]]; then
      return ${RETURN_SUCCESS}
    fi
    for d in "${normalDeviceList[@]}" "${guestDeviceList[@]}"; do
      if [[ ${d} == "${e}" ]]; then
        return ${RETURN_SUCCESS}
      fi
    done
  done
  return ${RETURN_FAILURE}
}

# removes a single MAC/IP address from the normal/guest device lists so
# that it is not recognized as a guest device
function removeFromDeviceLists()
{
  local device="${1^^}"
  local dev=""
  unset "normalDeviceList[${device}]" "guestDeviceList[${device}]"
  for dev in "${!normalDeviceList[@]}"; do
    if [[ ${normalDeviceList[${dev}]} == "${device}" ]]; then
      unset "normalDeviceList[${dev}]"
    fi
  done
  for dev in "${!guestDeviceList[@]}"; do
    if [[ ${guestDeviceList[${dev}]} == "${device}" ]]; then
      unset "guestDeviceList[${dev}]"
    fi
  done
}

# last-seen timestamps are kept in a file because run_pdetect is executed
# in a subshell when logging to HM_PROCESSLOG_FILE
LASTSEEN_FILE="/tmp/hm_pdetect-lastseen"

function loadLastSeen()
{
  lastSeenList=()
  local k=""
  local v=""
  if [[ -r ${LASTSEEN_FILE} ]]; then
    while read -r k v; do
      if [[ -n ${k} ]]; then
        lastSeenList[${k}]="${v}"
      fi
    done <"${LASTSEEN_FILE}"
  fi
}

function saveLastSeen()
{
  local k=""
  (umask 077
   for k in "${!lastSeenList[@]}"; do
     echo "${k} ${lastSeenList[${k}]}"
   done >"${LASTSEEN_FILE}")
}

# sets PRESENCE_RESULT to 'true' if the user/device identified by key is
# online or was last seen less than HM_AWAY_DELAY seconds ago, else 'false'.
# Must not be called in a $(...) subshell, it updates lastSeenList.
function presentWithDelay()
{
  local key="${1// /_}"
  local online="$2"
  local now=""
  now=$(date +%s)
  if [[ ${online} == true ]]; then
    lastSeenList[${key}]=${now}
    PRESENCE_RESULT=true
  elif [[ ${HM_AWAY_DELAY} -gt 0 && -n ${lastSeenList[${key}]} &&           $((now - lastSeenList[${key}])) -lt ${HM_AWAY_DELAY} ]]; then
    PRESENCE_RESULT=true
  else
    PRESENCE_RESULT=false
  fi
}

# sends a HomeMatic script to the CCU and echos its output (everything
# the script writes via Write() before the trailing <xml> block)
function regaRun()
{
  local script="$1"
  local body=""
  # the CCU expects ISO-8859-1; keep the script as is if it is not valid UTF-8
  if ! body=$(printf '%s' "${script}" | iconv -f UTF-8 -t ISO-8859-1 2>/dev/null); then
    body="${script}"
  fi
  local result=""
  result=$(wget -T 15 -t 1 -q -O - --post-data "${body}" "http://${HM_CCU_IP}:${HM_CCU_REGAPORT}/tclrega.exe")
  echo "${result%%<xml>*}"
}

# evaluates a rule condition: terms separated by '&' (all must be true),
# each optionally prefixed by '!': device:<name>, user:<name>, anyone, nobody
function evalCondition()
{
  local cond="$1"
  local term=""
  local neg=""
  local res=""
  local IFS='&'
  for term in ${cond}; do
    term="${term#"${term%%[![:space:]]*}"}"
    term="${term%"${term##*[![:space:]]}"}"
    neg=false
    if [[ ${term} == '!'* ]]; then
      neg=true
      term="${term:1}"
    fi
    res=false
    case "${term,,}" in
      device:*) [[ ${deviceState[${term#*:}]} == true ]] && res=true ;;
      user:*)   [[ ${userState[${term#*:}]} == true ]] && res=true ;;
      anyone)   [[ -n ${presenceList} ]] && res=true ;;
      nobody)   [[ -z ${presenceList} ]] && res=true ;;
      *)
        echo -n " [unknown condition '${term}']"
        return ${RETURN_FAILURE}
      ;;
    esac
    if [[ ${neg} == true ]]; then
      if [[ ${res} == true ]]; then res=false; else res=true; fi
    fi
    if [[ ${res} == false ]]; then
      return ${RETURN_FAILURE}
    fi
  done
  return ${RETURN_SUCCESS}
}

# builds the HomeMatic script that applies a heating action to all
# HEATING_CLIMATECONTROL_TRANSCEIVER channels matching the target.
# mode: 1=manual temp, 2=manual but at most temp, 0=auto, -1=only list matches
# Every channel switched to manual mode reports its previous state as
# 'SAVE:<channel id>|<set point mode>|<set point temp>'.
function heatingScript()
{
  local ttype="$1"
  local targ="${2//\"/}"
  local mode="$3"
  local temp="$4"
  cat <<EOF
string sType = "${ttype}"; string sArg = "${targ}"; integer iMode = ${mode}; real rT = ${temp};
string sRoomIDs = "";
if (sType == "ROOM") { object oR = dom.GetObject(ID_ROOMS).Get(sArg); if (oR) { sRoomIDs = "\t" # oR.EnumUsedIDs() # "\t"; } }
string sList = "," # sArg # ",";
string sId; integer iCnt = 0;
foreach (sId, dom.GetObject(ID_CHANNELS).EnumUsedIDs()) {
  object ch = dom.GetObject(sId);
  if (ch.HssType() == "HEATING_CLIMATECONTROL_TRANSCEIVER") {
    boolean bHit = false;
    if (sType == "ALL") { bHit = true; }
    if ((sType == "ROOM") && (sRoomIDs.Find("\t" # sId # "\t") >= 0)) { bHit = true; }
    if ((sType == "LIST") && ((sList.Find("," # ch.Name() # ",") >= 0) || (sList.Find("," # ch.Address() # ",") >= 0))) { bHit = true; }
    if (bHit) {
      object oSp = ch.DPByHssDP("SET_POINT_TEMPERATURE");
      object oSm = ch.DPByHssDP("SET_POINT_MODE");
      object oCm = ch.DPByHssDP("CONTROL_MODE");
      if (oSp && oCm) {
        real rCur = oSp.Value();
        integer iCurMode = 0;
        if (oSm) { iCurMode = oSm.Value(); }
        if (iMode == 0) { oCm.State(0); }
        if (iMode > 0) {
          real rNeu = rT;
          if ((iMode == 2) && (rCur >= 4.5) && (rCur < rT)) { rNeu = rCur; }
          Write("SAVE:" # sId # "|" # iCurMode # "|" # rCur.ToString(1) # "\n");
          oCm.State(1);
          oSp.State(rNeu);
        }
        Write("OK:" # ch.Name() # " (" # rCur.ToString(1) # " -> mode " # iMode # ")\n");
        iCnt = iCnt + 1;
      }
    }
  }
}
Write("COUNT:" # iCnt # "\n");
EOF
}

# script restoring heating channels from a tab separated list of
# '<channel id>|<set point mode>|<set point temp>' entries
function restoreScript()
{
  cat <<EOF
string sL = "$1"; string sE;
foreach (sE, sL) {
  object ch = dom.GetObject(sE.StrValueByIndex("|", 0));
  if (ch) {
    object oCm = ch.DPByHssDP("CONTROL_MODE");
    object oSp = ch.DPByHssDP("SET_POINT_TEMPERATURE");
    if (sE.StrValueByIndex("|", 1) == "1") { oCm.State(1); oSp.State(sE.StrValueByIndex("|", 2).ToFloat()); }
    else { oCm.State(0); }
    Write("OK:" # ch.Name() # " restored\n");
  }
}
EOF
}

# formats a value for a HomeMatic script (numbers/booleans raw, rest quoted)
function regaValue()
{
  local v="$1"
  if [[ ${v} =~ ^-?[0-9]+(\.[0-9]+)?$ || ${v,,} == true || ${v,,} == false ]]; then
    echo "${v,,}"
  else
    echo "\"${v//\"/}\""
  fi
}

# executes the ';' separated actions of a rule:
#   temp:<target>=<degC>     heating to manual mode with given temperature
#   maxtemp:<target>=<degC>  heating to manual mode, at most given temperature
#   auto:<target>            heating back to automatic (week profile) mode
#   restore                  restore heating settings saved when the rule became active
#   set:<datapoint>=<value>  set any datapoint, e.g. set:HmIP-RF.00021709AECCAD:3.STATE=true
#   var:<sysvar>=<value>     set a system variable
#   prog:<program>           execute a CCU program
# <target>: ALL, room:<room name> or comma separated channel names/addresses
function runRuleActions()
{
  local rule="$1"
  local actions="$2"
  local phase="$3"
  local saveFile="${STATE_DIR}/hm_pdetect-rule-${rule//[^A-Za-z0-9_-]/_}.save"
  local dry=false
  if [[ ${HM_RULES_DRYRUN} == true ]]; then
    dry=true
  elif [[ ${phase} == enter ]]; then
    rm -f "${saveFile}"
  fi

  local action=""
  local -a actionList=()
  IFS=';' read -r -a actionList <<<"${actions}"
  for action in "${actionList[@]}"; do
    action="${action#"${action%%[![:space:]]*}"}"
    action="${action%"${action##*[![:space:]]}"}"
    if [[ -z ${action} ]]; then
      continue
    fi
    local type="${action%%:*}"
    local arg=""
    if [[ ${action} == *:* ]]; then
      arg="${action#*:}"
    fi
    echo -n "  ${action}"
    if [[ ${dry} == true ]]; then
      echo -n " [dry-run]"
    fi

    local out=""
    case "${type,,}" in
      temp|maxtemp|auto)
        local target="${arg}"
        local value="0"
        local mode=0
        if [[ ${type,,} != auto ]]; then
          target="${arg%=*}"
          value="${arg##*=}"
          value="${value/,/.}"
          if [[ ${arg} != *=* || ! ${value} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo ": ERROR: expected ${type}:<target>=<temperature>"
            continue
          fi
          mode=1
          if [[ ${type,,} == maxtemp ]]; then mode=2; fi
        fi
        local ttype="LIST"
        local targ="${target}"
        if [[ ${target^^} == ALL ]]; then
          ttype="ALL"
        elif [[ ${target,,} == room:* ]]; then
          ttype="ROOM"
          targ="${target#*:}"
        fi
        if [[ ${dry} == true ]]; then
          mode=-1
        fi
        out=$(regaRun "$(heatingScript "${ttype}" "${targ}" "${mode}" "${value}")")
        if [[ ${dry} == false ]]; then
          echo "${out}" | grep '^SAVE:' | cut -d: -f2- >>"${saveFile}"
        fi
      ;;
      restore)
        if [[ ! -s ${saveFile} ]]; then
          echo ": nothing saved"
          continue
        fi
        local list=""
        list=$(tr '\n' '\t' <"${saveFile}")
        list="${list%$'\t'}"
        if [[ ${dry} == true ]]; then
          out="would restore: ${list//$'\t'/, }"
        else
          out=$(regaRun "$(restoreScript "${list}")")
          rm -f "${saveFile}"
        fi
      ;;
      set|var)
        local name="${arg%%=*}"
        local val=""
        val=$(regaValue "${arg#*=}")
        local obj="dom.GetObject(\"${name//\"/}\")"
        if [[ ${type,,} == var ]]; then
          obj="dom.GetObject(ID_SYSTEM_VARIABLES).Get(\"${name//\"/}\")"
        fi
        if [[ ${dry} == true ]]; then
          out=$(regaRun "object o = ${obj}; if (o) { Write(\"OK:found\"); } else { Write(\"ERROR:not found\"); }")
        else
          out=$(regaRun "object o = ${obj}; if (o) { o.State(${val}); Write(\"OK:set\"); } else { Write(\"ERROR:not found\"); }")
        fi
      ;;
      prog)
        local obj="dom.GetObject(ID_PROGRAMS).Get(\"${arg//\"/}\")"
        if [[ ${dry} == true ]]; then
          out=$(regaRun "object o = ${obj}; if (o) { Write(\"OK:found\"); } else { Write(\"ERROR:not found\"); }")
        else
          out=$(regaRun "object o = ${obj}; if (o) { o.ProgramExecute(); Write(\"OK:executed\"); } else { Write(\"ERROR:not found\"); }")
        fi
      ;;
      *)
        echo ": ERROR: unknown action type '${type}'"
        continue
      ;;
    esac
    if [[ -z ${out} ]]; then
      echo ": ERROR: no answer from CCU"
    else
      echo ":"
      echo "${out}" | grep -v '^SAVE:' | sed 's/^/    /'
    fi
  done
}

# evaluates all HM_RULE_LIST entries ('condition|enter actions|leave actions')
# in alphabetical order and runs the enter/leave actions whenever the
# condition of a rule changes. Rule state survives restarts in STATE_DIR.
function evaluateRules()
{
  if [[ ${#HM_RULE_LIST[@]} -eq 0 ]]; then
    return ${RETURN_SUCCESS}
  fi

  local stateFile="${STATE_DIR}/hm_pdetect-rules.state"
  local -A ruleState=()
  local k=""
  local v=""
  if [[ -r ${stateFile} ]]; then
    while IFS='=' read -r k v; do
      if [[ -n ${k} ]]; then
        ruleState[${k}]="${v}"
      fi
    done <"${stateFile}"
  fi

  local -A newState=()
  local changed=false
  local rule=""
  echo "Checking rules:"
  while IFS= read -r rule; do
    local cond=""
    local enter=""
    local leave=""
    IFS='|' read -r cond enter leave <<<"${HM_RULE_LIST[${rule}]}"
    local cur=0
    echo -n " ${rule} (${cond}):"
    if evalCondition "${cond}"; then
      cur=1
      echo -n " true"
    else
      echo -n " false"
    fi
    local key="${rule//[^A-Za-z0-9_-]/_}"
    local prev="${ruleState[${key}]}"
    newState[${key}]=${cur}
    if [[ ${prev} == "${cur}" ]]; then
      echo
    elif [[ -z ${prev} ]]; then
      # first evaluation (new rule or lost state): only record the state
      echo " (initial state, no action)"
      changed=true
    elif [[ ${cur} -eq 1 ]]; then
      echo " -> enter"
      runRuleActions "${rule}" "${enter}" enter
      changed=true
    else
      echo " -> leave"
      runRuleActions "${rule}" "${leave}" leave
      changed=true
    fi
  done < <(printf '%s\n' "${!HM_RULE_LIST[@]}" | sort)

  if [[ ${#newState[@]} -ne ${#ruleState[@]} ]]; then
    changed=true
  fi
  if [[ ${changed} == true && ${HM_RULES_DRYRUN} != true ]]; then
    for k in "${!newState[@]}"; do
      echo "${k}=${newState[${k}]}"
    done >"${stateFile}"
  fi
  return ${RETURN_SUCCESS}
}

function run_pdetect()
{
  # output time/date of execution
  echo "== $(date) ==================================="

  # lets retrieve all mac<>ip addresses of currently
  # active devices in our network
  echo -n "Querying FRITZ! devices:"
  i=0
  for ip in ${HM_FRITZ_IP}; do
    if [[ ${i} -gt 0 ]]; then
      echo -n ","
    fi
    echo -n " ${ip}"
    if retrieveFritzBoxDeviceList "${ip}" "${HM_FRITZ_USER}" "${HM_FRITZ_SECRET}"; then
      ((i = i + 1))
    fi
  done
  
  # check that we were able to connect to at least one device
  if [[ ${i} -eq 0 ]]; then
    echo "ERROR: couldn't connect to any specified FRITZ! device."
    return ${RETURN_FAILURE}
  fi

  # device list for the settings page (written atomically, readable for the webserver)
  (umask 022
   printf '%s\n' "${fritzDeviceLines[@]}" >"/tmp/hm_pdetect-devices.tmp" && \
     mv -f "/tmp/hm_pdetect-devices.tmp" "/tmp/hm_pdetect-devices")

  # output some statistics
  echo
  echo " Normal-WiFi/LAN devices active: ${#normalDeviceList[@]}"
  echo " Guest-WiFi/LAN devices active: ${#guestDeviceList[@]}"
  
  # lets identify user presence
  presenceList=""
  loadLastSeen
  echo "Checking user presence: "
  # shellcheck disable=SC2068
  for user in ${!HM_USER_LIST[@]}; do
    echo -n " ${user}: "
    online="false"

    # match MAC address, IP address or FRITZ! device name in normal and guest WiFi/LAN
    if isDeviceOnline "${HM_USER_LIST[${user}]}"; then
      online="true"
    fi
    presentWithDelay "user:${user}" ${online}
    stat=${PRESENCE_RESULT}
    userState[${user}]=${stat}

    if [[ ${stat} == "true" ]]; then
      if [[ ${online} == "true" ]]; then
        echo present
      else
        echo "present (last seen less than ${HM_AWAY_DELAY}s ago)"
      fi
      if [[ -n ${presenceList} ]]; then
        presenceList+=","
      fi
      presenceList+="${user}"
    else
      echo away
    fi

    # remove checked user devices from deviceList so that
    # they are not recognized as guest devices
    for device in $(resolveDeviceEntries "${HM_USER_LIST[${user}]}"); do
      removeFromDeviceLists "${device}"
    done

    # set status in homematic CCU
    createVariable "${HM_CCU_PRESENCE_VAR}.${user}" bool "${user} @ home"
    setVariableState "${HM_CCU_PRESENCE_VAR}.${user}" ${stat}
  done

  # monitored devices (e.g. computers) get their own online variable but
  # are not counted as users and not recognized as guests
  if [[ ${#HM_DEVICE_LIST[@]} -gt 0 ]]; then
    echo "Checking device presence: "
    while IFS= read -r devname; do
      echo -n " ${devname}: "
      online="false"
      if isDeviceOnline "${HM_DEVICE_LIST[${devname}]}"; then
        online="true"
      fi
      presentWithDelay "device:${devname}" ${online}
      stat=${PRESENCE_RESULT}
      deviceState[${devname}]=${stat}
      if [[ ${stat} == "true" ]]; then
        if [[ ${online} == "true" ]]; then
          echo online
        else
          echo "online (last seen less than ${HM_AWAY_DELAY}s ago)"
        fi
      else
        echo offline
      fi
      for device in $(resolveDeviceEntries "${HM_DEVICE_LIST[${devname}]}"); do
        removeFromDeviceLists "${device}"
      done
      createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_DEVICE}.${devname}" bool "${devname} online"
      setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_DEVICE}.${devname}" ${stat}
    done < <(printf '%s\n' "${!HM_DEVICE_LIST[@]}" | sort)
  fi
  saveLastSeen
  
  # now we set a separate users presence variable to true/false in case
  # any defined user is present
  if [[ -n ${HM_CCU_PRESENCE_USER} && ${HM_CCU_PRESENCE_USER_ENABLED} == true ]]; then
    createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_USER}" bool "any user @ home"
    if [[ -n ${presenceList} ]]; then
      setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_USER}" true
    else
      setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_USER}" false
    fi
  fi
  
  # lets identify guests by checking the normal and guest
  # WiFi/LAN device list and comparing them to the HM_KNOWN_LIST
  # shellcheck disable=SC2206
  HM_KNOWN_LIST=( ${HM_KNOWN_LIST[@]^^} ) # uppercase array
  # shellcheck disable=SC2068
  for device in ${HM_KNOWN_LIST[@]}; do
  
    # try to match IP address first
    if [[ ${!normalDeviceList[*]} =~ ${device} ]]; then
      unset "normalDeviceList[${device}]"
    elif [[ ${!guestDeviceList[*]} =~ ${device} ]]; then
      unset "guestDeviceList[${device}]"
    else
      # now match the MAC address list instead
      if [[ ${normalDeviceList[*]} =~ ${device} ]]; then
        for dev in ${!normalDeviceList[@]}; do
          if [[ ${normalDeviceList[${dev}]} == "${device}" ]]; then
            unset "normalDeviceList[${dev}]"
            break
          fi
        done
      elif [[ ${guestDeviceList[*]} =~ ${device} ]]; then
        for dev in ${!guestDeviceList[@]}; do
          if [[ ${guestDeviceList[${dev}]} == "${device}" ]]; then
            unset "guestDeviceList[${dev}]"
            break
          fi
        done
      fi
    fi
  
  done
  
  # depending on the HM_KNOWN_LIST_MODE mode we populate the guestList
  # with devices from the normalDeviceList and guestDeviceList or
  # just from the guestDeviceList
  guestList=()
  if [[ ${HM_KNOWN_LIST_MODE} != "guest" ]]; then
    # shellcheck disable=SC2068
    for device in ${!normalDeviceList[@]}; do
      guestList+=("${device}")
    done
  fi
  # shellcheck disable=SC2068
  for device in ${!guestDeviceList[@]}; do
    guestList+=("${device}")
  done
  
  echo "Checking guest presence: "
  # create/set presence system variable in CCU if guest devices
  # were found
  echo -n " ${HM_CCU_PRESENCE_GUEST}: "
  if [[ ${HM_KNOWN_LIST_MODE} != "off" ]]; then
    if [[ ${#guestList[@]} -gt 0 ]]; then
      # set status in homematic CCU
      echo "present - ${#guestList[@]} (${guestList[*]})"
      createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_GUEST}" bool "${HM_CCU_PRESENCE_GUEST} @ home"
      setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_GUEST}" true
      if [[ -n ${presenceList} ]]; then
        presenceList+=","
      fi
      presenceList+="${HM_CCU_PRESENCE_GUEST}"
    else
      echo "away"
      createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_GUEST}" bool "${HM_CCU_PRESENCE_GUEST} @ home"
      setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_GUEST}" false
    fi
  else
    echo "disabled"
  fi
  
  # we create and set another global presence variable as an
  # enum of all possible presence combinations
  if [[ -n ${HM_CCU_PRESENCE_LIST} && ${HM_CCU_PRESENCE_LIST_ENABLED} == true ]]; then
    userList=""
    # shellcheck disable=SC2068
    for user in ${!HM_USER_LIST[@]}; do
      if [[ -n ${userList} ]]; then
        userList="${userList};${user}"
      else
        userList="${user}"
      fi
    done
    userTupleList=$(createUserTupleList "${userList}")
    createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_LIST}" enum "presence enum list @ home" "${userTupleList}"
    setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_LIST}" "$(whichEnumID "${userTupleList}" "${presenceList}")"
  fi
  
  # we create and set a global presence variable as a string
  # variable which users can query.
  if [[ -n ${HM_CCU_PRESENCE_STR} && ${HM_CCU_PRESENCE_STR_ENABLED} == true ]]; then
    if [[ -z ${presenceList} ]]; then
      userList="${HM_CCU_PRESENCE_NOBODY}"
    else
      userList="${presenceList}"
    fi
    createVariable "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_STR}" string "presence list @ home"
    setVariableState "${HM_CCU_PRESENCE_VAR}.${HM_CCU_PRESENCE_STR}" "'${userList}'"
  fi
  
  # set the global presence variable to true/false depending
  # on the general presence of people in the house
  createVariable "${HM_CCU_PRESENCE_VAR}" bool "global presence @ home"
  if [[ -z ${presenceList} ]]; then
    setVariableState "${HM_CCU_PRESENCE_VAR}" false
  else
    setVariableState "${HM_CCU_PRESENCE_VAR}" true
  fi

  # run enter/leave actions of rules whose condition changed
  evaluateRules

  echo "== $(date) ==================================="
  echo
  
  return ${RETURN_SUCCESS}
}

################################################
# main processing starts here
#
echo "hm_pdetect ${VERSION} - a FRITZ!-based HomeMatic presence detection script"
echo "(${VERSION_DATE}) Copyright (C) 2015-2023 Jens Maus <mail@jens-maus.de>"
echo

# lets enter an endless loop to implement a
# daemon-like behaviour
result=-1
iteration=0
while true; do

  # lets source the config file again
  if [[ -n ${CONFIG_FILE} ]]; then
    if ! source "${CONFIG_FILE}"; then
      echo "ERROR: couldn't source config file '${CONFIG_FILE}'. Please check config file syntax."
      result=${RETURN_FAILURE}
    fi

    # lets eval the user overridden variables
    # so that they take priority
    eval "${USERVARS}"
  fi
  if ! sourceRulesFile; then
    result=${RETURN_FAILURE}
  fi

  # lets wait until the next execution round in case
  # the user wants to run it as a daemon
  if [[ ${result} -ge 0 ]]; then
    ((iteration = iteration + 1))
    if [[ -n ${HM_INTERVAL_TIME}    && \
          ${HM_INTERVAL_TIME} -gt 0 && \
          ( -z ${HM_INTERVAL_MAX} || ${HM_INTERVAL_MAX} -eq 0 || ${iteration} -lt ${HM_INTERVAL_MAX} ) ]]; then
      sleep "${HM_INTERVAL_TIME}"
      if [[ $? -eq 1 ]]; then
        result=${RETURN_FAILURE}
        break
      fi
    else 
      break
    fi
  fi

  # perform one pdetect run and in case we are running in daemon
  # mode and having the processlogfile enabled output to the logfile instead.
  if [[ -n ${HM_PROCESSLOG_FILE} ]]; then
    output=$(run_pdetect)
    result=$?
    echo "${output}" | cat - "${HM_PROCESSLOG_FILE}" | head -n "${HM_PROCESSLOG_MAXLINES}" >/tmp/hm_pdetect-$$.tmp && mv /tmp/hm_pdetect-$$.tmp "${HM_PROCESSLOG_FILE}"
  else
    # run pdetect with normal stdout processing
    run_pdetect
    result=$?
  fi

done

exit ${result}
