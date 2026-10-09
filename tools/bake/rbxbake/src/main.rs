// rbxbake: converte i record di export_world.lua (+ gli script del progetto) in un place .rbxlx con l'encoder ufficiale rbx_xml,
// e rilegge un .rbxlx stampando gli stessi record (per i controlli di andata e ritorno).
//   rbxbake build <record.txt>... -o <uscita.rbxlx> [--binary <uscita.rbxl>]
//   rbxbake dump  <file.rbxlx|file.rbxl>  (stampa i record su stdout; il formato si riconosce dal contenuto)
use std::{collections::{BTreeMap, HashMap}, env, fs::File, io::{BufReader, BufWriter, Write}, process};

use rbx_dom_weak::{
    types::{
        Attributes, CFrame, Color3, ColorSequence, ColorSequenceKeypoint, Content, ContentId, CustomPhysicalProperties, Enum, Matrix3, NumberRange,
        NumberSequence, NumberSequenceKeypoint, PhysicalProperties, Ref, Tags, UDim, UDim2, Variant, VariantType, Vector2, Vector3,
    },
    ustr, InstanceBuilder, WeakDom,
};
use rbx_reflection::{DataType, ReflectionDatabase};

type Rec = (String, String, Vec<String>); // (nome, tipo, dati)

#[derive(Default)]
struct Node {
    parent: u64,
    class: String,
    name: String,
    props: Vec<Rec>,
    attrs: Vec<Rec>,
    tags: Vec<String>,
}

// Le stringhe nei record sono codificate con %XX; la stringa vuota e' "~" (un vero "~" diventa %7E).
fn dec(s: &str) -> String {
    if s == "~" {
        return String::new();
    }
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' && i + 2 < b.len() {
            let h = u8::from_str_radix(&s[i + 1..i + 3], 16).expect("codifica %XX non valida");
            out.push(h);
            i += 3;
        } else {
            out.push(b[i]);
            i += 1;
        }
    }
    String::from_utf8(out).expect("UTF-8 non valido")
}

fn enc(s: &str) -> String {
    if s.is_empty() {
        return "~".to_string();
    }
    let mut o = String::new();
    for &c in s.as_bytes() {
        if c.is_ascii_alphanumeric() || c == b'.' || c == b'_' || c == b'-' {
            o.push(c as char);
        } else {
            o.push_str(&format!("%{:02X}", c));
        }
    }
    o
}

fn f(d: &[String], i: usize) -> f32 {
    d[i].parse::<f32>().unwrap_or_else(|_| panic!("numero non valido: {}", d[i]))
}

fn find_prop<'a>(db: &'a ReflectionDatabase<'a>, class: &str, prop: &str) -> Option<&'a rbx_reflection::PropertyDescriptor<'a>> {
    let cd = db.classes.get(class)?;
    for c in db.superclasses_iter(cd) {
        if let Some(pd) = c.properties.get(prop) {
            return Some(pd);
        }
    }
    None
}

fn variant(db: &ReflectionDatabase, class: &str, prop: &str, kind: &str, d: &[String], refs: &HashMap<u64, Ref>) -> Result<Variant, String> {
    let pd = find_prop(db, class, prop).ok_or_else(|| format!("proprieta' sconosciuta {}.{}", class, prop))?;
    let dt = &pd.data_type;
    let want = match dt {
        DataType::Value(v) => Some(*v),
        _ => None,
    };
    let v: Variant = match kind {
        "b" => Variant::Bool(d[0] == "1"),
        "n" => {
            let x: f64 = d[0].parse().map_err(|_| format!("numero non valido {}", d[0]))?;
            match want {
                Some(VariantType::Float32) => Variant::Float32(x as f32),
                Some(VariantType::Float64) => Variant::Float64(x),
                Some(VariantType::Int32) => Variant::Int32(x.round() as i32),
                Some(VariantType::Int64) => Variant::Int64(x.round() as i64),
                other => return Err(format!("{}.{}: numero dato a una proprieta' di tipo {:?}", class, prop, other)),
            }
        }
        "s" => {
            let s = dec(&d[0]);
            match want {
                Some(VariantType::String) => Variant::String(s),
                Some(VariantType::ContentId) => Variant::ContentId(ContentId::from(s)),
                Some(VariantType::Content) => Variant::Content(Content::from(s)),
                other => return Err(format!("{}.{}: stringa data a una proprieta' di tipo {:?}", class, prop, other)),
            }
        }
        "e" => {
            let ename = match dt {
                DataType::Enum(n) => n.as_ref(),
                _ => return Err(format!("{}.{}: enum dato a una proprieta' che non lo e'", class, prop)),
            };
            if d[0] != ename {
                return Err(format!("{}.{}: l'enum e' {} ma il record dice {}", class, prop, ename, d[0]));
            }
            let val = d[1].parse::<f64>().map_err(|_| "enum non valido".to_string())? as u32;
            let ed = db.enums.get(ename).ok_or_else(|| format!("enum {} non nel database", ename))?;
            if !ed.items.values().any(|&x| x == val) {
                return Err(format!("{}.{}: {} non e' un valore valido di {}", class, prop, val, ename));
            }
            Variant::Enum(Enum::from_u32(val))
        }
        "v3" => Variant::Vector3(Vector3::new(f(d, 0), f(d, 1), f(d, 2))),
        "v2" => Variant::Vector2(Vector2::new(f(d, 0), f(d, 1))),
        "u2" => Variant::UDim2(UDim2::new(UDim::new(f(d, 0), f(d, 1).round() as i32), UDim::new(f(d, 2), f(d, 3).round() as i32))),
        "cf" => Variant::CFrame(CFrame::new(
            Vector3::new(f(d, 0), f(d, 1), f(d, 2)),
            Matrix3::new(Vector3::new(f(d, 3), f(d, 4), f(d, 5)), Vector3::new(f(d, 6), f(d, 7), f(d, 8)), Vector3::new(f(d, 9), f(d, 10), f(d, 11))),
        )),
        "c3" => Variant::Color3(Color3::new(f(d, 0), f(d, 1), f(d, 2))),
        "nr" => Variant::NumberRange(NumberRange::new(f(d, 0), f(d, 1))),
        "ns" => {
            let n: usize = d[0].parse().unwrap();
            let mut k = Vec::new();
            for i in 0..n {
                k.push(NumberSequenceKeypoint::new(f(d, 1 + 3 * i), f(d, 2 + 3 * i), f(d, 3 + 3 * i)));
            }
            Variant::NumberSequence(NumberSequence { keypoints: k })
        }
        "cs" => {
            let n: usize = d[0].parse().unwrap();
            let mut k = Vec::new();
            for i in 0..n {
                k.push(ColorSequenceKeypoint::new(f(d, 1 + 4 * i), Color3::new(f(d, 2 + 4 * i), f(d, 3 + 4 * i), f(d, 4 + 4 * i))));
            }
            Variant::ColorSequence(ColorSequence { keypoints: k })
        }
        "pp" => Variant::PhysicalProperties(PhysicalProperties::Custom(CustomPhysicalProperties::new(f(d, 0), f(d, 1), f(d, 2), f(d, 3), f(d, 4), 1.0))),
        "r" => {
            let id: u64 = d[0].parse().unwrap();
            Variant::Ref(*refs.get(&id).ok_or_else(|| format!("riferimento a un nodo inesistente: {}", id))?)
        }
        other => return Err(format!("tipo di record sconosciuto: {}", other)),
    };
    if let Some(w) = want {
        if v.ty() != w {
            return Err(format!("{}.{}: il tipo {:?} non corrisponde a quello dell'API ({:?})", class, prop, v.ty(), w));
        }
    }
    Ok(v)
}

fn attr_variant(kind: &str, d: &[String]) -> Result<Variant, String> {
    Ok(match kind {
        "s" => Variant::String(dec(&d[0])),
        "n" => Variant::Float64(d[0].parse::<f64>().map_err(|_| "numero non valido".to_string())?),
        "b" => Variant::Bool(d[0] == "1"),
        "v3" => Variant::Vector3(Vector3::new(f(d, 0), f(d, 1), f(d, 2))),
        "c3" => Variant::Color3(Color3::new(f(d, 0), f(d, 1), f(d, 2))),
        other => return Err(format!("attributo di tipo non gestito: {}", other)),
    })
}

fn parse(files: &[String]) -> (BTreeMap<u64, Node>, Vec<(String, u64)>, Vec<(u64, String)>) {
    let mut nodes: BTreeMap<u64, Node> = BTreeMap::new();
    let mut services = Vec::new();
    let mut unders = Vec::new();
    for path in files {
        let text = std::fs::read_to_string(path).unwrap_or_else(|e| panic!("{}: {}", path, e));
        for line in text.lines() {
            let t: Vec<&str> = line.split_whitespace().collect();
            if t.is_empty() || t[0].starts_with('#') {
                continue;
            }
            match t[0] {
                "I" => {
                    let id: u64 = t[1].parse().unwrap();
                    if nodes.contains_key(&id) {
                        panic!("id duplicato {} in {}", id, path);
                    }
                    nodes.insert(id, Node { parent: t[2].parse().unwrap(), class: t[3].to_string(), name: dec(t[4]), ..Default::default() });
                }
                "P" => {
                    let id: u64 = t[1].parse().unwrap();
                    nodes.get_mut(&id).expect("P prima di I").props.push((t[2].to_string(), t[3].to_string(), t[4..].iter().map(|s| s.to_string()).collect()));
                }
                "A" => {
                    let id: u64 = t[1].parse().unwrap();
                    nodes.get_mut(&id).expect("A prima di I").attrs.push((dec(t[2]), t[3].to_string(), t[4..].iter().map(|s| s.to_string()).collect()));
                }
                "T" => {
                    let id: u64 = t[1].parse().unwrap();
                    nodes.get_mut(&id).expect("T prima di I").tags.push(dec(t[2]));
                }
                "S" => services.push((t[1].to_string(), t[2].parse().unwrap())),
                "U" => unders.push((t[1].parse().unwrap(), t[2].to_string())),
                other => panic!("record sconosciuto: {}", other),
            }
        }
    }
    (nodes, services, unders)
}

fn build_node(db: &ReflectionDatabase, nodes: &BTreeMap<u64, Node>, kids: &HashMap<u64, Vec<u64>>, refs: &HashMap<u64, Ref>, id: u64, errors: &mut Vec<String>) -> InstanceBuilder {
    let n = &nodes[&id];
    let mut b = InstanceBuilder::new(n.class.as_str()).with_name(n.name.clone()).with_referent(refs[&id]);
    apply(db, &mut b, n, refs, errors);
    if let Some(ks) = kids.get(&id) {
        for &k in ks {
            b.add_child(build_node(db, nodes, kids, refs, k, errors));
        }
    }
    b
}

fn apply(db: &ReflectionDatabase, b: &mut InstanceBuilder, n: &Node, refs: &HashMap<u64, Ref>, errors: &mut Vec<String>) {
    for (prop, kind, d) in &n.props {
        match variant(db, &n.class, prop, kind, d, refs) {
            Ok(v) => b.add_property(ustr(prop), v),
            Err(e) => errors.push(format!("{} \"{}\": {}", n.class, n.name, e)),
        }
    }
    if !n.attrs.is_empty() {
        let mut a = Attributes::new();
        for (k, kind, d) in &n.attrs {
            match attr_variant(kind, d) {
                Ok(v) => {
                    a.insert(k.clone(), v);
                }
                Err(e) => errors.push(format!("{} \"{}\": attributo {}: {}", n.class, n.name, k, e)),
            }
        }
        b.add_property(ustr("Attributes"), Variant::Attributes(a));
    }
    if !n.tags.is_empty() {
        let mut t = Tags::new();
        for tag in &n.tags {
            t.push(tag);
        }
        b.add_property(ustr("Tags"), Variant::Tags(t));
    }
}

fn cmd_build(args: &[String]) {
    let mut files = Vec::new();
    let mut out = None;
    let mut binary = None;
    let mut i = 0;
    while i < args.len() {
        if args[i] == "-o" {
            out = Some(args[i + 1].clone());
            i += 2;
        } else if args[i] == "--binary" {
            binary = Some(args[i + 1].clone());
            i += 2;
        } else {
            files.push(args[i].clone());
            i += 1;
        }
    }
    let out = out.expect("manca -o <uscita.rbxlx>");
    let db = rbx_reflection_database::get().expect("database delle API");
    let (nodes, services, unders) = parse(&files);
    let mut refs: HashMap<u64, Ref> = HashMap::new();
    let mut kids: HashMap<u64, Vec<u64>> = HashMap::new();
    for (&id, n) in &nodes {
        refs.insert(id, Ref::new());
        if n.parent != 0 {
            kids.entry(n.parent).or_default().push(id);
        }
    }
    let mut errors = Vec::new();
    let mut dom = WeakDom::new(InstanceBuilder::new("DataModel"));
    let root = dom.root_ref();
    for svc in ["Workspace", "Players", "Lighting", "ReplicatedStorage", "ServerScriptService", "StarterPlayer"] {
        let mut b = InstanceBuilder::new(svc).with_name(svc);
        for (s, id) in &services {
            if s == svc {
                let n = &nodes[id];
                apply(db, &mut b, n, &refs, &mut errors);
                if let Some(ks) = kids.get(id) {
                    for &k in ks {
                        b.add_child(build_node(db, &nodes, &kids, &refs, k, &mut errors));
                    }
                }
            }
        }
        for (id, s) in &unders {
            if s == svc {
                b.add_child(build_node(db, &nodes, &kids, &refs, *id, &mut errors));
            }
        }
        dom.insert(root, b);
    }
    if !errors.is_empty() {
        for e in errors.iter().take(40) {
            eprintln!("ERRORE: {}", e);
        }
        eprintln!("{} errori", errors.len());
        process::exit(1);
    }
    let w = BufWriter::new(File::create(&out).expect("creazione file"));
    // ErrorOnUnknown: una proprieta' che l'encoder non sa scrivere e' un errore, non va persa in silenzio
    let opts = rbx_xml::EncodeOptions::new().property_behavior(rbx_xml::EncodePropertyBehavior::ErrorOnUnknown);
    rbx_xml::to_writer(w, &dom, dom.root().children(), opts).expect("scrittura XML (proprieta' non scrivibile?)");
    println!("scritto {} ({} istanze)", out, dom.descendants().count() - 1);
    if let Some(bin) = binary {
        // stesso albero nel formato nativo di Studio (.rbxl)
        let w = BufWriter::new(File::create(&bin).expect("creazione file binario"));
        rbx_binary::to_writer(w, &dom, dom.root().children()).expect("scrittura binaria");
        println!("scritto {} (formato binario)", bin);
    }
}

fn fmt_f(x: f64) -> String {
    if x == x.trunc() && x.abs() < 1e15 {
        format!("{}", x as i64)
    } else {
        format!("{}", x)
    }
}

fn rec_of(v: &Variant, ids: &HashMap<Ref, u64>) -> Option<String> {
    Some(match v {
        Variant::Bool(b) => format!("b {}", if *b { 1 } else { 0 }),
        Variant::Float32(x) => format!("n {}", fmt_f(*x as f64)),
        Variant::Float64(x) => format!("n {}", fmt_f(*x)),
        Variant::Int32(x) => format!("n {}", x),
        Variant::Int64(x) => format!("n {}", x),
        Variant::String(s) => format!("s {}", enc(s)),
        Variant::ContentId(s) => format!("s {}", enc(s.as_str())),
        Variant::Content(c) => format!("s {}", enc(c.as_uri().unwrap_or(""))),
        Variant::Enum(e) => format!("e - {}", e.to_u32()),
        Variant::Vector3(v) => format!("v3 {} {} {}", fmt_f(v.x as f64), fmt_f(v.y as f64), fmt_f(v.z as f64)),
        Variant::Vector2(v) => format!("v2 {} {}", fmt_f(v.x as f64), fmt_f(v.y as f64)),
        Variant::UDim2(u) => format!("u2 {} {} {} {}", fmt_f(u.x.scale as f64), u.x.offset, fmt_f(u.y.scale as f64), u.y.offset),
        Variant::CFrame(c) => format!(
            "cf {} {} {} {} {} {} {} {} {} {} {} {}",
            fmt_f(c.position.x as f64), fmt_f(c.position.y as f64), fmt_f(c.position.z as f64),
            fmt_f(c.orientation.x.x as f64), fmt_f(c.orientation.x.y as f64), fmt_f(c.orientation.x.z as f64),
            fmt_f(c.orientation.y.x as f64), fmt_f(c.orientation.y.y as f64), fmt_f(c.orientation.y.z as f64),
            fmt_f(c.orientation.z.x as f64), fmt_f(c.orientation.z.y as f64), fmt_f(c.orientation.z.z as f64)
        ),
        Variant::Color3(c) => format!("c3 {} {} {}", fmt_f(c.r as f64), fmt_f(c.g as f64), fmt_f(c.b as f64)),
        Variant::Color3uint8(c) => format!("c3 {} {} {}", fmt_f(c.r as f64 / 255.0), fmt_f(c.g as f64 / 255.0), fmt_f(c.b as f64 / 255.0)),
        Variant::NumberRange(r) => format!("nr {} {}", fmt_f(r.min as f64), fmt_f(r.max as f64)),
        Variant::NumberSequence(s) => {
            let mut o = format!("ns {}", s.keypoints.len());
            for k in &s.keypoints {
                o.push_str(&format!(" {} {} {}", fmt_f(k.time as f64), fmt_f(k.value as f64), fmt_f(k.envelope as f64)));
            }
            o
        }
        Variant::ColorSequence(s) => {
            let mut o = format!("cs {}", s.keypoints.len());
            for k in &s.keypoints {
                o.push_str(&format!(" {} {} {} {}", fmt_f(k.time as f64), fmt_f(k.color.r as f64), fmt_f(k.color.g as f64), fmt_f(k.color.b as f64)));
            }
            o
        }
        Variant::PhysicalProperties(p) => match p {
            PhysicalProperties::Custom(c) => format!("pp {} {} {} {} {}", fmt_f(c.density() as f64), fmt_f(c.friction() as f64), fmt_f(c.elasticity() as f64), fmt_f(c.friction_weight() as f64), fmt_f(c.elasticity_weight() as f64)),
            _ => return None,
        },
        Variant::Ref(r) => format!("r {}", ids.get(r).copied().unwrap_or(0)),
        // nei valori degli attributi le stringhe arrivano come BinaryString
        Variant::BinaryString(b) => format!("s {}", enc(&String::from_utf8_lossy(b.as_ref()))),
        Variant::Font(ft) => format!("font {} {} {:?}", enc(&ft.family), ft.weight.as_u16(), ft.style),
        _ => return None,
    })
}

fn cmd_dump(args: &[String]) {
    let path = &args[0];
    let mut magic = [0u8; 8];
    {
        use std::io::Read;
        File::open(path).expect("apertura").read_exact(&mut magic).expect("file troppo corto");
    }
    let r = BufReader::with_capacity(1 << 20, File::open(path).expect("apertura"));
    let dom = if &magic == b"<roblox!" {
        rbx_binary::from_reader(r).expect("lettura binaria")
    } else {
        rbx_xml::from_reader(r, rbx_xml::DecodeOptions::new().property_behavior(rbx_xml::DecodePropertyBehavior::ErrorOnUnknown)).expect("lettura XML (proprieta' sconosciuta?)")
    };
    // numerazione in preordine, come l'esportatore
    let mut ids: HashMap<Ref, u64> = HashMap::new();
    let mut order: Vec<(Ref, u64)> = Vec::new();
    fn walk(dom: &WeakDom, r: Ref, parent: u64, ids: &mut HashMap<Ref, u64>, order: &mut Vec<(Ref, u64)>) {
        let id = ids.len() as u64 + 1;
        ids.insert(r, id);
        order.push((r, parent));
        for &c in dom.get_by_ref(r).unwrap().children() {
            walk(dom, c, id, ids, order);
        }
    }
    for &s in dom.root().children() {
        walk(&dom, s, 0, &mut ids, &mut order);
    }
    let out = std::io::stdout();
    let mut o = BufWriter::new(out.lock());
    for (r, parent) in order {
        let inst = dom.get_by_ref(r).unwrap();
        let id = ids[&r];
        writeln!(o, "I {} {} {} {}", id, parent, inst.class, enc(&inst.name)).unwrap();
        let mut keys: Vec<_> = inst.properties.keys().collect();
        keys.sort_by(|a, b| a.as_str().cmp(b.as_str()));
        for k in keys {
            let v = &inst.properties[k];
            match (k.as_str(), v) {
                ("Attributes", Variant::Attributes(a)) => {
                    let mut items: Vec<_> = a.iter().collect();
                    items.sort_by(|x, y| x.0.cmp(y.0));
                    for (key, val) in items {
                        if let Some(rec) = rec_of(val, &ids) {
                            writeln!(o, "A {} {} {}", id, enc(key), rec).unwrap();
                        }
                    }
                }
                ("Tags", Variant::Tags(t)) => {
                    let mut tg: Vec<&str> = t.iter().collect();
                    tg.sort();
                    for tag in tg {
                        writeln!(o, "T {} {}", id, enc(tag)).unwrap();
                    }
                }
                _ => {
                    if let Some(rec) = rec_of(v, &ids) {
                        writeln!(o, "P {} {} {}", id, k, rec).unwrap();
                    } else {
                        writeln!(o, "# P {} {} (tipo non stampato: {:?})", id, k, v.ty()).unwrap();
                    }
                }
            }
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("uso: rbxbake build <record.txt>... -o <uscita.rbxlx>  |  rbxbake dump <file.rbxlx>");
        process::exit(2);
    }
    match args[1].as_str() {
        "build" => cmd_build(&args[2..]),
        "dump" => cmd_dump(&args[2..]),
        _ => {
            eprintln!("comando sconosciuto");
            process::exit(2);
        }
    }
}
