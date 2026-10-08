#!/usr/bin/env python3
"""Converte API-Dump.json di Roblox in un file Lua compatto (api_index.lua) usato dallo shim per la verifica rigorosa."""
import json, sys
import os, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
DUMP = os.path.join(HERE, 'api_dump.json')
if not os.path.exists(DUMP):
    url = 'https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json'
    print('scarico', url)
    urllib.request.urlretrieve(url, DUMP)
d = json.load(open(DUMP))
out = ['return {']
# enum
out.append('enums = {')
for e in d['Enums']:
    items = ','.join('%s=%d' % (i['Name'] if i['Name'].isidentifier() and i['Name'] not in ('end','and','or','not','if','then','else','for','while','do','in','nil','true','false','function','local','repeat','until','return','break','goto','elseif') else '["%s"]' % i['Name'], i['Value']) for i in e['Items'])
    out.append('%s={%s},' % (e['Name'], items))
out.append('},')
out.append('classes = {')
def lit(s): return '"%s"' % s
for c in d['Classes']:
    tags = c.get('Tags', [])
    props = []; funcs = []; events = []
    for m in c['Members']:
        mt = m['MemberType']; name = m['Name']
        import re
        if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name): continue
        mtags = m.get('Tags', [])
        if mt == 'Property':
            vt = m['ValueType']; cat = vt['Category']; vn = vt['Name']
            code = {'Enum': 'E', 'Primitive': 'P', 'DataType': 'D', 'Class': 'C', 'Group': 'G'}.get(cat, 'X') + ':' + vn
            sec = m.get('Security', {})
            wsec = sec.get('Write', 'None') if isinstance(sec, dict) else 'None'
            rsec = sec.get('Read', 'None') if isinstance(sec, dict) else 'None'
            flag = ''
            if 'ReadOnly' in mtags or 'NotScriptable' in mtags or wsec not in ('None',): flag += '!'
            if rsec not in ('None',): flag += '?'
            if 'Deprecated' in mtags: flag += '~'
            props.append('[%s]=%s' % (lit(name), lit(flag + code)))
        elif mt == 'Function':
            if 'Deprecated' in mtags: funcs.append('[%s]=2' % lit(name))
            else: funcs.append('[%s]=1' % lit(name))
        elif mt == 'Event':
            events.append('[%s]=1' % lit(name))
        elif mt == 'Callback':
            events.append('[%s]=1' % lit(name))
    out.append('[%s]={s=%s,c=%d,v=%d,p={%s},f={%s},e={%s}},' % (
        lit(c['Name']), lit(c.get('Superclass', '<<<ROOT>>>')),
        0 if 'NotCreatable' in tags else 1, 1 if 'Service' in tags else 0,
        ','.join(props), ','.join(funcs), ','.join(events)))
out.append('}}')
open(os.path.join(HERE, 'api_index.lua'), 'w').write('\n'.join(out))
print('ok', len(d['Classes']), 'classi', len(d['Enums']), 'enum')
