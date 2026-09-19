# -*- coding: utf-8 -*-
"""Regenera lista_items.md desde items.json. No se edita a mano."""
import json, io

RAIZ = "/home/mumiola/Programacion/Godot/MumiolaCity/mumiola-city"
d = json.load(io.open(RAIZ + "/data/objetos/items.json", encoding="utf-8"))
items = d["items"]; por_id = {x["id"]: x for x in items}
venta, compra = d["tasas"]["venta_npc"], d["tasas"]["compra_npc"]

L = []
L.append("# Lista de items\n")
L.append("> **Generado** desde `items.json` con `herramientas/generar_items.py` y")
L.append("> `herramientas/generar_lista.py`. No editar a mano: los cambios se hacen en el generador,")
L.append("> que ademas valida que los modelos existan y que los margenes cierren.\n")
L.append("Catalogo v%s — %d items, %d con receta, %d comprables al NPC.\n"
	% (d["version"], len(items), sum(1 for x in items if x["receta"]),
	   sum(1 for x in items if x["comprable"])))
L.append("El NPC **paga %d%%** del valor base y **cobra %d%%**. Siempre paga menos de lo que"
	% (venta * 100, compra * 100))
L.append("cobra: es un piso de emergencia, no un negocio.\n")

L.append("## Habilidades\n")
L.append("| id | Nombre | Animacion |")
L.append("|---|---|---|")
for h in d["habilidades"]:
	L.append("| `%s` | %s | `%s` |" % (h["id"], h["nombre"], h["animacion"]))

L.append("\n## Estaciones\n")
L.append("| id | Nombre | Modelo | Habilidad |")
L.append("|---|---|---|---|")
for e in d["estaciones"]:
	L.append("| `%s` | %s | `%s` | %s |" % (e["id"], e["nombre"], e["modelo"], e["habilidad"]))

CATS = [("materia_prima", "Materia prima"), ("intermedio", "Intermedios"),
        ("consumible", "Platos terminados"), ("utensilio", "Utensilios y vajilla"),
        ("decorativo", "Muebles y decoracion")]
for cat, titulo in CATS:
	del_cat = [x for x in items if x["categoria"] == cat]
	if not del_cat: continue
	L.append("\n## %s\n" % titulo)
	L.append("| id | Nombre | Valor | NPC paga | NPC cobra | Modelo |")
	L.append("|---|---|---:|---:|---:|---|")
	for x in sorted(del_cat, key=lambda y: y["valor_base"]):
		paga = "%d" % round(x["valor_base"] * venta) if x["vendible"] else "—"
		cobra = "%d" % round(x["valor_base"] * compra) if x["comprable"] else "—"
		L.append("| `%s` | %s | %d | %s | %s | %s |"
			% (x["id"], x["nombre"], x["valor_base"], paga, cobra, "`%s`" % x["modelo"] if x["modelo"] else "—"))

L.append("\n## Recetas\n")
L.append("| Resultado | Insumos | Utensilios | Estacion | Habilidad | Nivel | Seg | XP | Si falla |")
L.append("|---|---|---|---|---|---:|---:|---:|---|")
for x in items:
	r = x["receta"]
	if not r: continue
	ins = " + ".join("%d× %s" % (i["cantidad"], i["id"]) for i in r["insumos"])
	ute = ", ".join(r["utensilios"]) or "—"
	L.append("| `%s` | %s | %s | %s | %s | %d | %d | %d | %s |"
		% (x["id"], ins, ute, r["estacion"] or "—", r["habilidad"],
		   r["nivel_requerido"], r["tiempo_seg"], r["xp"], r["resultado_fallo"] or "—"))

L.append("\n## Reglas que el generador verifica\n")
L.append("- Todo modelo citado existe en `arte/modelos_3d/`.")
L.append("- Todo insumo, utensilio, estacion, habilidad y resultado de fallo existe.")
L.append("- Ningun ciclo de recetas.")
L.append("- Todo item se consigue de alguna forma: o se craftea, o se compra.")
L.append("- **Cadena productiva**: transformar deja ganancia, o nadie produce.")
L.append("- **Muebles**: venderlos al NPC da perdida, o craftear y revender imprimiria")
L.append("  dinero y dejarian de ser el sumidero de la economia.")
L.append("- **Vajilla**: lavar recicla, no produce valor; queda fuera de la regla.\n")

io.open(RAIZ + "/data/objetos/lista_items.md", "w", encoding="utf-8").write("\n".join(L))
print("lista_items.md regenerada: %d lineas" % len(L))
