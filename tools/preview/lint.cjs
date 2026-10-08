const fs = require('fs'), path = require('path');
const luaparse = require('luaparse');
let bad = 0;
function walk(d) {
  for (const e of fs.readdirSync(d)) {
    const f = path.join(d, e);
    if (fs.statSync(f).isDirectory()) walk(f);
    else if (f.endsWith('.lua')) {
      try { luaparse.parse(fs.readFileSync(f, 'utf8'), { luaVersion: '5.3' }); console.log('OK  ', f); }
      catch (err) { bad++; console.log('FAIL', f, err.message); }
    }
  }
}
walk(process.argv[2]);
process.exit(bad ? 1 : 0);
