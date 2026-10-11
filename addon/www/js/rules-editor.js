/*
 * hm_pdetect - form editor for users, devices and rules.
 *
 * The editor works on the unchanged text fields HM_USER_LIST, HM_DEVICE_LIST
 * and HM_RULE_LIST: it parses them on load and writes every change back
 * immediately. Saving and validation still happen server-side from these
 * text fields, so without JavaScript the text fields stay usable.
 */
(function () {
  'use strict';

  var DATA = window.PDETECT_DATA || { channels: [], rooms: [], programs: [], fritz: [] };

  // English texts, keyed by the German original
  var EN = {
    '— Gerät aus der FRITZ!Box wählen —': '— choose a FRITZ! device —',
    ', aktiv': ', active',
    ' (derzeit nicht in der FRITZ!Box)': ' (currently not known to the FRITZ! device)',
    'Person': 'User',
    'Name': 'Name',
    'Gerät in der FRITZ!Box': 'FRITZ! device',
    'weitere MAC/IP (optional)': 'additional MAC/IP (optional)',
    'z.B. Hans': 'e.g. John',
    'z.B. BueroPC': 'e.g. OfficePC',
    'z.B. AA:BB:CC:DD:EE:FF': 'e.g. AA:BB:CC:DD:EE:FF',
    'entfernen': 'remove',
    '+ Person': '+ User',
    '+ Gerät': '+ Device',
    'Gerät ist online': 'Device is online',
    'Gerät ist offline': 'Device is offline',
    'Person ist da': 'User is home',
    'Person ist weg': 'User is away',
    'Jemand ist zu Hause': 'Someone is home',
    'Niemand ist zu Hause': 'Nobody is home',
    'eigene Bedingung (Text)': 'custom condition (text)',
    'Heizung auf Temperatur': 'Heating to temperature',
    'Heizung auf höchstens': 'Heating to at most',
    'Heizung auf Automatik (Wochenprogramm)': 'Heating to automatic (week profile)',
    'Heizung wie vorher (wiederherstellen)': 'Heating as before (restore)',
    'CCU-Programm ausführen': 'Execute CCU program',
    'Datenpunkt setzen': 'Set datapoint',
    'Systemvariable setzen': 'Set system variable',
    'eigene Aktion (Text)': 'custom action (text)',
    'Alle Heizungen': 'All heating',
    'Räume': 'Rooms',
    'Einzelne Heizungen': 'Single heating channels',
    ' °C für:': ' °C for:',
    '— Programm wählen —': '— choose a program —',
    'z.B. HmIP-RF.00021709AECCAD:3.STATE': 'e.g. HmIP-RF.00021709AECCAD:3.STATE',
    'Name der Systemvariable': 'name of the system variable',
    'Wert, z.B. true oder 21': 'value, e.g. true or 21',
    'z.B. temp:room:Oben=20': 'e.g. temp:room:Office=20',
    'Aktion entfernen': 'remove action',
    '— wählen —': '— choose —',
    ' (unbekannt)': ' (unknown)',
    'z.B. device:BueroPC': 'e.g. device:OfficePC',
    'und ': 'and ',
    'Bedingung entfernen': 'remove condition',
    'Name der Regel': 'name of the rule',
    'Regel löschen': 'Delete rule',
    'Wenn': 'If',
    '+ Bedingung (und)': '+ Condition (and)',
    'Dann': 'Then',
    '+ Aktion': '+ Action',
    'Sobald die Bedingung nicht mehr zutrifft': 'As soon as the condition no longer applies',
    '+ Regel': '+ Rule'
  };

  function tr(s) { return (DATA.lang === 'en' && EN[s] !== undefined) ? EN[s] : s; }

  // ---------------------------------------------------------------- helpers

  function el(tag, attrs, children) {
    var e = document.createElement(tag);
    Object.keys(attrs || {}).forEach(function (k) {
      if (k === 'class') e.className = attrs[k];
      else if (k === 'text') e.textContent = attrs[k];
      else if (k.indexOf('on') === 0) e.addEventListener(k.substring(2), attrs[k]);
      else e.setAttribute(k, attrs[k]);
    });
    (children || []).forEach(function (c) {
      if (c !== null && c !== undefined) e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    });
    return e;
  }

  function select(options, value, attrs) {
    var s = el('select', Object.assign({ class: 'form-control input-sm' }, attrs || {}));
    options.forEach(function (o) {
      if (o.group) {
        var g = el('optgroup', { label: o.group });
        o.options.forEach(function (oo) { g.appendChild(el('option', { value: oo.value, text: oo.label })); });
        s.appendChild(g);
      } else {
        s.appendChild(el('option', { value: o.value, text: o.label }));
      }
    });
    if (value !== undefined) s.value = value;
    return s;
  }

  function button(label, cls, onclick, title) {
    return el('button', { type: 'button', class: 'btn btn-default btn-xs ' + (cls || ''), title: title || '', onclick: onclick }, [label]);
  }

  // rule/device names may only contain letters, digits, _ and -
  function safeName(s) {
    return s.replace(/ä/g, 'ae').replace(/ö/g, 'oe').replace(/ü/g, 'ue').replace(/Ä/g, 'Ae')
      .replace(/Ö/g, 'Oe').replace(/Ü/g, 'Ue').replace(/ß/g, 'ss').replace(/\s+/g, '_').replace(/[^A-Za-z0-9_-]/g, '');
  }

  function q(s) { return DATA.lang === 'en' ? '\u201c' + s + '\u201d' : '\u201e' + s + '\u201c'; }

  function fritzOptions(current) {
    var opts = [{ value: '', label: tr('— Gerät aus der FRITZ!Box wählen —') }];
    var list = DATA.fritz.slice().sort(function (a, b) {
      return (b.active - a.active) || a.name.toLowerCase().localeCompare(b.name.toLowerCase());
    });
    var seen = {};
    list.forEach(function (d) {
      if (seen[d.name.toUpperCase()]) return;
      seen[d.name.toUpperCase()] = true;
      opts.push({ value: d.name, label: d.name + ' (' + d.ip + (d.active ? tr(', aktiv') : '') + ')' });
    });
    if (current && !seen[current.toUpperCase()]) opts.push({ value: current, label: current + tr(' (derzeit nicht in der FRITZ!Box)') });
    return opts;
  }

  function fritzByName(name) {
    var n = (name || '').toUpperCase();
    for (var i = 0; i < DATA.fritz.length; i++) if (DATA.fritz[i].name.toUpperCase() === n) return DATA.fritz[i];
    return null;
  }

  // ------------------------------------------------- persons & devices

  // entries: 'name:X', MAC or IP -> { fritz: 'X' or '', extra: 'MAC IP ...' }
  function splitEntries(entries) {
    var fritz = '';
    var extra = [];
    entries.forEach(function (e) {
      if (!fritz && /^name:/i.test(e)) fritz = e.substring(5);
      else extra.push(e);
    });
    var dev = fritzByName(fritz);
    // the MAC of the selected FRITZ! device is added automatically again on save
    if (dev) extra = extra.filter(function (e) { return e.toUpperCase() !== dev.mac.toUpperCase(); });
    return { fritz: fritz, extra: extra.join(' ') };
  }

  function joinEntries(fritz, extra) {
    var out = [];
    if (fritz) {
      out.push('name:' + fritz);
      var dev = fritzByName(fritz);
      if (dev && dev.mac) out.push(dev.mac);
    }
    extra.split(/\s+/).forEach(function (e) {
      if (e && out.map(function (x) { return x.toUpperCase(); }).indexOf(e.toUpperCase()) < 0) out.push(e);
    });
    return out;
  }

  function parseUsers(text) {
    var list = [];
    var re = /\[([^\]]+)\]=('([^']*)'|"([^"]*)"|(\S+))/g;
    var m;
    while ((m = re.exec(text)) !== null) {
      var val = m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : m[5]);
      list.push({ name: m[1], entries: val.split(/\s+/).filter(Boolean) });
    }
    return list;
  }

  function serializeUsers(list) {
    return list.filter(function (u) { return u.name; }).map(function (u) {
      return '[' + u.name + "]='" + u.entries.join(' ') + "'";
    }).join('\n');
  }

  function parseDevices(text) {
    return text.split(/\r?\n/).map(function (l) { return l.trim(); })
      .filter(function (l) { return l && l.charAt(0) !== '#'; })
      .map(function (l) {
        var m = /^([^=]+?)\s*=\s*(.*)$/.exec(l);
        return m ? { name: m[1].trim(), entries: m[2].split(/\s+/).filter(Boolean) } : { name: l, entries: [] };
      });
  }

  function serializeDevices(list) {
    return list.filter(function (d) { return d.name; }).map(function (d) {
      return d.name + ' = ' + d.entries.join(' ');
    }).join('\n');
  }

  function entryEditor(container, list, kind, onchange) {
    container.innerHTML = '';
    var table = el('table', { class: 'table table-condensed', style: 'margin-bottom:6px' });
    table.appendChild(el('tr', {}, [
      el('th', { text: kind === 'person' ? tr('Person') : tr('Name') }),
      el('th', { text: tr('Gerät in der FRITZ!Box') }),
      el('th', { text: tr('weitere MAC/IP (optional)') }),
      el('th', {})
    ]));
    list.forEach(function (item, idx) {
      var parts = splitEntries(item.entries);
      var name = el('input', { class: 'form-control input-sm', value: item.name, placeholder: kind === 'person' ? tr('z.B. Hans') : tr('z.B. BueroPC') });
      var dev = select(fritzOptions(parts.fritz), parts.fritz);
      var extra = el('input', { class: 'form-control input-sm', value: parts.extra, placeholder: tr('z.B. AA:BB:CC:DD:EE:FF') });
      function update() {
        item.name = kind === 'person' ? name.value.trim().replace(/[\]\['"\s]/g, '') : safeName(name.value);
        if (kind !== 'person') name.value = item.name;
        item.entries = joinEntries(dev.value, extra.value);
        onchange();
      }
      [name, dev, extra].forEach(function (i) { i.addEventListener('change', update); });
      table.appendChild(el('tr', {}, [
        el('td', { style: 'width:22%' }, [name]),
        el('td', { style: 'width:40%' }, [dev]),
        el('td', {}, [extra]),
        el('td', { style: 'width:1%' }, [button('✕', 'btn-danger', function () {
          list.splice(idx, 1); onchange(); entryEditor(container, list, kind, onchange);
        }, tr('entfernen'))])
      ]));
    });
    container.appendChild(table);
    container.appendChild(button(kind === 'person' ? tr('+ Person') : tr('+ Gerät'), '', function () {
      list.push({ name: '', entries: [] }); entryEditor(container, list, kind, onchange);
    }));
  }

  // ---------------------------------------------------------------- rules

  var COND_TYPES = [
    { value: 'device_on', label: tr('Gerät ist online') },
    { value: 'device_off', label: tr('Gerät ist offline') },
    { value: 'user_on', label: tr('Person ist da') },
    { value: 'user_off', label: tr('Person ist weg') },
    { value: 'anyone', label: tr('Jemand ist zu Hause') },
    { value: 'nobody', label: tr('Niemand ist zu Hause') },
    { value: 'raw', label: tr('eigene Bedingung (Text)') }
  ];

  var ACTION_TYPES = [
    { value: 'temp', label: tr('Heizung auf Temperatur') },
    { value: 'maxtemp', label: tr('Heizung auf höchstens') },
    { value: 'auto', label: tr('Heizung auf Automatik (Wochenprogramm)') },
    { value: 'restore', label: tr('Heizung wie vorher (wiederherstellen)') },
    { value: 'prog', label: tr('CCU-Programm ausführen') },
    { value: 'set', label: tr('Datenpunkt setzen') },
    { value: 'var', label: tr('Systemvariable setzen') },
    { value: 'raw', label: tr('eigene Aktion (Text)') }
  ];

  function parseCond(term) {
    var t = term.trim();
    var neg = false;
    while (t.charAt(0) === '!') { neg = !neg; t = t.substring(1).trim(); }
    var m;
    if ((m = /^device:(.+)$/i.exec(t))) return { type: neg ? 'device_off' : 'device_on', arg: m[1] };
    if ((m = /^user:(.+)$/i.exec(t))) return { type: neg ? 'user_off' : 'user_on', arg: m[1] };
    if (/^anyone$/i.test(t)) return { type: neg ? 'nobody' : 'anyone', arg: '' };
    if (/^nobody$/i.test(t)) return { type: neg ? 'anyone' : 'nobody', arg: '' };
    return { type: 'raw', arg: term.trim() };
  }

  function serializeCond(c) {
    switch (c.type) {
      case 'device_on': return 'device:' + c.arg;
      case 'device_off': return '!device:' + c.arg;
      case 'user_on': return 'user:' + c.arg;
      case 'user_off': return '!user:' + c.arg;
      case 'anyone': return 'anyone';
      case 'nobody': return 'nobody';
      default: return c.arg;
    }
  }

  function parseAction(a) {
    a = a.trim();
    var type = a.split(':')[0].toLowerCase();
    var arg = a.indexOf(':') >= 0 ? a.substring(a.indexOf(':') + 1).trim() : '';
    var eq = arg.lastIndexOf('=');
    switch (type) {
      case 'temp': case 'maxtemp':
        if (eq < 0) break;
        return { type: type, targets: parseTargets(arg.substring(0, eq)), value: arg.substring(eq + 1).trim().replace(',', '.') };
      case 'auto':
        return { type: type, targets: parseTargets(arg), value: '' };
      case 'restore':
        return { type: 'restore' };
      case 'prog':
        return { type: 'prog', name: arg };
      case 'set': case 'var':
        var e1 = arg.indexOf('=');
        if (e1 < 0) break;
        return { type: type, name: arg.substring(0, e1), value: arg.substring(e1 + 1) };
    }
    return { type: 'raw', text: a };
  }

  function parseTargets(t) {
    t = t.trim();
    if (/^all$/i.test(t)) return ['ALL'];
    if (/^room:/i.test(t)) return ['room:' + t.substring(5)];
    return t.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
  }

  // one editor row may select several targets; the backend accepts one target
  // type per action, so rooms become separate actions and channels are joined
  function serializeAction(a) {
    switch (a.type) {
      case 'restore': return ['restore'];
      case 'prog': return a.name ? ['prog:' + a.name] : [];
      case 'set': case 'var': return a.name ? [a.type + ':' + a.name + '=' + a.value] : [];
      case 'raw': return a.text ? [a.text] : [];
    }
    var targets = a.targets || [];
    if (!targets.length) return [];
    var suffix = a.type === 'auto' ? '' : '=' + a.value;
    if (targets.indexOf('ALL') >= 0) return [a.type + ':ALL' + suffix];
    var out = [];
    var channels = [];
    targets.forEach(function (t) {
      if (/^room:/.test(t)) out.push(a.type + ':' + t + suffix);
      else channels.push(t);
    });
    if (channels.length) out.push(a.type + ':' + channels.join(',') + suffix);
    return out;
  }

  function parseRules(text) {
    return text.split(/\r?\n/).map(function (l) { return l.trim(); })
      .filter(function (l) { return l && l.charAt(0) !== '#'; })
      .map(function (l) {
        var p = l.split('|').map(function (s) { return s.trim(); });
        var split = function (s, sep) { return (s || '').split(sep).map(function (x) { return x.trim(); }).filter(Boolean); };
        return {
          name: p[0] || '',
          cond: split(p[1], '&').map(parseCond),
          enter: split(p[2], ';').map(parseAction),
          leave: split(p[3], ';').map(parseAction)
        };
      });
  }

  function serializeRules(rules) {
    return rules.filter(function (r) { return r.name; }).map(function (r) {
      var acts = function (list) {
        return [].concat.apply([], list.map(serializeAction)).join('; ');
      };
      return (r.name + ' | ' + r.cond.map(serializeCond).join(' & ') + ' | ' + acts(r.enter) + ' | ' + acts(r.leave)).replace(/\s+$/, '');
    }).join('\n');
  }

  // ------------------------------------------------- human readable text

  function condText(c) {
    var en = DATA.lang === 'en';
    switch (c.type) {
      case 'device_on': return q(c.arg) + (en ? ' is online' : ' online ist');
      case 'device_off': return q(c.arg) + (en ? ' is offline' : ' offline ist');
      case 'user_on': return q(c.arg) + (en ? ' is home' : ' zu Hause ist');
      case 'user_off': return q(c.arg) + (en ? ' is away' : ' nicht zu Hause ist');
      case 'anyone': return en ? 'someone is home' : 'jemand zu Hause ist';
      case 'nobody': return en ? 'nobody is home' : 'niemand zu Hause ist';
      default: return q(c.arg);
    }
  }

  function targetText(targets) {
    var en = DATA.lang === 'en';
    if (!targets || !targets.length) return en ? '(no heating selected)' : '(keine Heizung gewählt)';
    if (targets.indexOf('ALL') >= 0) return en ? 'all heating' : 'alle Heizungen';
    var rooms = targets.filter(function (x) { return /^room:/.test(x); }).map(function (x) { return (en ? 'room ' : 'Raum ') + q(x.substring(5)); });
    var ch = targets.filter(function (x) { return !/^room:/.test(x); });
    var parts = rooms.slice();
    if (ch.length === 1) parts.push(q(ch[0]));
    else if (ch.length > 1) parts.push(ch.length + (en ? ' heating channels (' : ' Heizungen (') + ch.join(', ') + ')');
    return parts.join(en ? ' and ' : ' und ');
  }

  function actionText(a) {
    var en = DATA.lang === 'en';
    var deg = en ? String(a.value || '') : String(a.value || '').replace('.', ',');
    switch (a.type) {
      case 'temp': return en ? 'set ' + targetText(a.targets) + ' to ' + deg + ' °C' : targetText(a.targets) + ' auf ' + deg + ' °C stellen';
      case 'maxtemp': return en ? 'limit ' + targetText(a.targets) + ' to at most ' + deg + ' °C' : targetText(a.targets) + ' auf höchstens ' + deg + ' °C begrenzen';
      case 'auto': return en ? 'set ' + targetText(a.targets) + ' to automatic' : targetText(a.targets) + ' auf Automatik stellen';
      case 'restore': return en ? 'restore the heating as it was before' : 'Heizungen wieder so einstellen wie vorher';
      case 'prog': return en ? 'execute program ' + q(a.name) : 'Programm ' + q(a.name) + ' ausführen';
      case 'set': return en ? 'set ' + q(a.name) + ' to ' + a.value : q(a.name) + ' auf ' + a.value + ' setzen';
      case 'var': return en ? 'set system variable ' + q(a.name) + ' to ' + a.value : 'Systemvariable ' + q(a.name) + ' auf ' + a.value + ' setzen';
      default: return q(a.text);
    }
  }

  function ruleText(r) {
    var en = DATA.lang === 'en';
    var when = r.cond.length ? r.cond.map(condText).join(en ? ' and ' : ' und ') : (en ? '(no condition)' : '(keine Bedingung)');
    var s = (en ? 'If ' : 'Wenn ') + when + ': ' + (r.enter.length ? r.enter.map(actionText).join(', ') : (en ? 'do nothing' : 'nichts tun')) + '.';
    if (r.leave.length) s += (en ? ' Afterwards: ' : ' Danach: ') + r.leave.map(actionText).join(', ') + '.';
    return s;
  }

  // ------------------------------------------------------------ rule editor

  // checkbox list: tr('Alle Heizungen'), rooms and single heating channels
  function targetPicker(selected, onchange) {
    var box = el('div', { style: 'border:1px solid #ccc;border-radius:3px;padding:4px 8px;max-height:11em;overflow-y:auto;background:#fff' });
    var boxes = [];
    function current() {
      return boxes.filter(function (b) { return b.checked; }).map(function (b) { return b.value; });
    }
    function refresh() {
      var all = current().indexOf('ALL') >= 0;
      boxes.forEach(function (b) { if (b.value !== 'ALL') b.disabled = all; });
    }
    function add(value, label, bold) {
      var cb = el('input', { type: 'checkbox', value: value });
      cb.checked = selected.indexOf(value) >= 0;
      cb.addEventListener('change', function () { refresh(); onchange(current()); });
      boxes.push(cb);
      box.appendChild(el('label', { style: 'display:block;font-weight:' + (bold ? 'bold' : 'normal') + ';margin:1px 0' }, [cb, ' ' + label]));
    }
    function head(text) { box.appendChild(el('div', { class: 'text-muted', style: 'margin-top:4px;font-size:90%', text: text })); }
    add('ALL', tr('Alle Heizungen'), true);
    head(tr('Räume'));
    DATA.rooms.forEach(function (r) { add('room:' + r, r); });
    head(tr('Einzelne Heizungen'));
    var known = DATA.channels.slice();
    selected.forEach(function (t) { if (t !== 'ALL' && !/^room:/.test(t) && known.indexOf(t) < 0) known.push(t); });
    // selected channels first so they are visible without scrolling
    known.sort(function (x, y) { return (selected.indexOf(y) >= 0) - (selected.indexOf(x) >= 0); });
    known.forEach(function (c) { add(c, c); });
    refresh();
    return box;
  }

  function actionRow(list, idx, onchange, rerender) {
    var a = list[idx];
    var type = select(ACTION_TYPES, a.type, { style: 'margin-bottom:4px' });
    var cell = el('div', {});

    function fill() {
      cell.innerHTML = '';
      if (a.type === 'temp' || a.type === 'maxtemp' || a.type === 'auto') {
        a.targets = a.targets || [];
        if (a.type !== 'auto') {
          a.value = a.value || '21';
          var v = el('input', { type: 'number', step: '0.5', min: '4.5', max: '30.5', class: 'form-control input-sm', value: a.value, style: 'width:6em;display:inline-block' });
          v.addEventListener('change', function () { a.value = v.value; onchange(); });
          cell.appendChild(el('div', { style: 'margin-bottom:4px' }, [v, tr(' °C für:')]));
        }
        cell.appendChild(targetPicker(a.targets, function (sel) { a.targets = sel; onchange(); }));
      } else if (a.type === 'prog') {
        var opts = [{ value: '', label: tr('— Programm wählen —') }].concat(DATA.programs.map(function (p) { return { value: p, label: p }; }));
        if (a.name && DATA.programs.indexOf(a.name) < 0) opts.push({ value: a.name, label: a.name });
        var ps = select(opts, a.name || '');
        ps.addEventListener('change', function () { a.name = ps.value; onchange(); });
        cell.appendChild(ps);
      } else if (a.type === 'set' || a.type === 'var') {
        var n = el('input', { class: 'form-control input-sm', value: a.name || '', placeholder: a.type === 'set' ? tr('z.B. HmIP-RF.00021709AECCAD:3.STATE') : tr('Name der Systemvariable'), style: 'margin-bottom:4px' });
        var val = el('input', { class: 'form-control input-sm', value: a.value || '', placeholder: tr('Wert, z.B. true oder 21') });
        n.addEventListener('change', function () { a.name = n.value.trim(); onchange(); });
        val.addEventListener('change', function () { a.value = val.value.trim(); onchange(); });
        cell.appendChild(n);
        cell.appendChild(val);
      } else if (a.type === 'raw') {
        var t = el('input', { class: 'form-control input-sm', value: a.text || '', placeholder: tr('z.B. temp:room:Oben=20') });
        t.addEventListener('change', function () { a.text = t.value.trim(); onchange(); });
        cell.appendChild(t);
      }
    }

    type.addEventListener('change', function () {
      var old = a;
      list[idx] = a = { type: type.value, targets: old.targets, value: old.value };
      fill();
      onchange();
    });
    fill();
    return el('tr', {}, [
      el('td', { style: 'width:38%;vertical-align:top' }, [type]),
      el('td', { style: 'vertical-align:top' }, [cell]),
      el('td', { style: 'width:1%;vertical-align:top' }, [button('✕', 'btn-danger', function () { list.splice(idx, 1); onchange(); rerender(); }, tr('Aktion entfernen'))])
    ]);
  }

  function condRow(list, idx, onchange, rerender, users, devices) {
    var c = list[idx];
    var type = select(COND_TYPES, c.type);
    var cell = el('div', {});

    function fill() {
      cell.innerHTML = '';
      var names = null;
      if (c.type === 'device_on' || c.type === 'device_off') names = devices;
      if (c.type === 'user_on' || c.type === 'user_off') names = users;
      if (names) {
        var opts = [{ value: '', label: tr('— wählen —') }].concat(names.map(function (n) { return { value: n, label: n }; }));
        if (c.arg && names.indexOf(c.arg) < 0) opts.push({ value: c.arg, label: c.arg + tr(' (unbekannt)') });
        var s = select(opts, c.arg || '');
        s.addEventListener('change', function () { c.arg = s.value; onchange(); });
        cell.appendChild(s);
      } else if (c.type === 'raw') {
        var t = el('input', { class: 'form-control input-sm', value: c.arg || '', placeholder: tr('z.B. device:BueroPC') });
        t.addEventListener('change', function () { c.arg = t.value.trim(); onchange(); });
        cell.appendChild(t);
      }
    }

    type.addEventListener('change', function () {
      var keepArg = (c.type.split('_')[0] === type.value.split('_')[0]);
      c.type = type.value;
      if (!keepArg) c.arg = '';
      fill();
      onchange();
    });
    fill();
    return el('tr', {}, [
      el('td', { style: 'width:38%;vertical-align:top' }, [idx === 0 ? null : el('small', { class: 'text-muted', text: tr('und ') }), type]),
      el('td', { style: 'vertical-align:top' }, [cell]),
      el('td', { style: 'width:1%' }, [button('✕', 'btn-danger', function () { list.splice(idx, 1); onchange(); rerender(); }, tr('Bedingung entfernen'))])
    ]);
  }

  function ruleCard(rules, idx, ctx) {
    var r = rules[idx];
    var summary = el('div', { class: 'text-info', style: 'margin:4px 0 8px 0' });
    var card;

    function changed() {
      summary.textContent = ruleText(r);
      ctx.onchange();
    }
    function rerender() {
      var fresh = ruleCard(rules, idx, ctx);
      card.parentNode.replaceChild(fresh, card);
    }

    var name = el('input', { class: 'form-control input-sm', value: r.name, placeholder: tr('Name der Regel'), style: 'width:16em;display:inline-block' });
    name.addEventListener('change', function () { r.name = safeName(name.value); name.value = r.name; changed(); });

    function block(title, list, rowFn, addLabel, addFn) {
      var table = el('table', { class: 'table table-condensed', style: 'margin-bottom:4px' });
      list.forEach(function (_, i) { table.appendChild(rowFn(list, i)); });
      return el('div', { style: 'margin-bottom:8px' }, [
        el('b', { text: title }),
        table,
        button(addLabel, '', function () { list.push(addFn()); changed(); rerender(); })
      ]);
    }

    var condFn = function (list, i) { return condRow(list, i, changed, rerender, ctx.users(), ctx.devices()); };
    var actFn = function (list, i) { return actionRow(list, i, changed, rerender); };

    card = el('div', { class: 'panel panel-default', style: 'margin-bottom:10px' }, [
      el('div', { class: 'panel-heading', style: 'padding:6px 10px' }, [
        name,
        el('span', { class: 'pull-right' }, [button(tr('Regel löschen'), 'btn-danger', function () {
          rules.splice(idx, 1); ctx.onchange(); ctx.rerenderAll();
        })])
      ]),
      el('div', { class: 'panel-body', style: 'padding:8px 10px' }, [
        summary,
        block(tr('Wenn'), r.cond, condFn, tr('+ Bedingung (und)'), function () { return { type: 'device_on', arg: '' }; }),
        block(tr('Dann'), r.enter, actFn, tr('+ Aktion'), function () { return { type: 'temp', targets: [], value: '21' }; }),
        block(tr('Sobald die Bedingung nicht mehr zutrifft'), r.leave, actFn, tr('+ Aktion'), function () { return { type: 'restore' }; })
      ])
    ]);
    summary.textContent = ruleText(r);
    return card;
  }

  // ------------------------------------------------------------------ setup

  function init() {
    var userText = document.getElementById('HM_USER_LIST');
    var devText = document.getElementById('HM_DEVICE_LIST');
    var ruleText_ = document.getElementById('HM_RULE_LIST');
    var userBox = document.getElementById('user-editor');
    var devBox = document.getElementById('device-editor');
    var ruleBox = document.getElementById('rule-editor');
    var toggle = document.getElementById('expert-toggle');
    if (!userText || !devText || !ruleText_ || !ruleBox) return;

    var users, devices, rules;

    function load() {
      users = parseUsers(userText.value);
      devices = parseDevices(devText.value);
      rules = parseRules(ruleText_.value);
    }

    function store() {
      userText.value = serializeUsers(users);
      devText.value = serializeDevices(devices);
      ruleText_.value = serializeRules(rules);
    }

    var ctx = {
      users: function () { return users.map(function (u) { return u.name; }).filter(Boolean); },
      devices: function () { return devices.map(function (d) { return d.name; }).filter(Boolean); },
      onchange: store,
      rerenderAll: renderRules
    };

    function renderRules() {
      ruleBox.innerHTML = '';
      rules.forEach(function (_, i) { ruleBox.appendChild(ruleCard(rules, i, ctx)); });
      ruleBox.appendChild(button(tr('+ Regel'), '', function () {
        rules.push({ name: 'Regel' + (rules.length + 1), cond: [{ type: 'device_on', arg: '' }], enter: [{ type: 'temp', targets: [], value: '21' }], leave: [{ type: 'restore' }] });
        store();
        renderRules();
      }));
    }

    function renderAll() {
      // person/device names feed the condition selects, so re-render rules too
      if (userBox) entryEditor(userBox, users, 'person', function () { store(); renderRules(); });
      if (devBox) entryEditor(devBox, devices, 'device', function () { store(); renderRules(); });
      renderRules();
    }

    function setExpert(on) {
      document.querySelectorAll('.expert-only').forEach(function (e) { e.style.display = on ? '' : 'none'; });
      document.querySelectorAll('.editor-only').forEach(function (e) { e.style.display = on ? 'none' : ''; });
      if (!on) { load(); renderAll(); }
    }

    load();
    renderAll();
    if (ruleText_.form) {
      ruleText_.form.addEventListener('reset', function () {
        setTimeout(function () { load(); renderAll(); }, 0);
      });
    }
    if (toggle) {
      toggle.addEventListener('change', function () { setExpert(toggle.checked); });
      setExpert(toggle.checked);
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
