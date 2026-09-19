# -*- coding: utf-8 -*-
"""Regenera la seccion 7 de docs/SISTEMAS.md desde items.json.

El grafo y las cifras no se escriben a mano: se derivan del catalogo, para que
no puedan quedar desfasados de el sin que nadie lo note."""
import json, io, re

RAIZ = "/home/mumiola/Programacion/Godot/MumiolaCity"
d = json.load(io.open(RAIZ + "/mumiola-city/data/objetos/items.json", encoding="utf-8"))
items = d["items"]; por_id = {x["id"]: x for x in items}
venta, compra = d["tasas"]["venta_npc"], d["tasas"]["compra_npc"]

def costo(id, visto=None):
	visto = visto or set()
	if id in visto: return 0
	x = por_id[id]
	if x["receta"] is None:
		return x["valor_base"] * compra if x["comprable"] else 0
	return sum(costo(i["id"], visto | {id}) * i["cantidad"] for i in x["receta"]["insumos"])

L = []
L.append("## 7. Estado de los datos\n")
L.append("> **Reescrito para el catálogo v0.5.** El anterior partía de una economía imaginada")
L.append("> —trigo, manzanas, mineral, pescado— que después habría habido que ilustrar con modelos")
L.append("> que el proyecto no tiene. El actual se construyó al revés: partiendo de los modelos 3D")
L.append("> disponibles. Esta sección **se genera** con `herramientas/generar_seccion_datos.py`.\n")
L.append("%d ítems, %d con receta, %d comprables al NPC, %d habilidades y %d estaciones."
	% (len(items), sum(1 for x in items if x["receta"]), sum(1 for x in items if x["comprable"]),
	   len(d["habilidades"]), len(d["estaciones"])))
L.append("El NPC paga **%d %%** del valor base y cobra **%d %%**.\n" % (venta * 100, compra * 100))

L.append("### 7.0 El grafo real de la economía\n")
L.append("Generado desde `items.json`, no dibujado a mano. Los nodos redondeados se compran al NPC;")
L.append("las flechas punteadas son utensilios requeridos pero **no** consumidos.\n")
L.append("```mermaid")
L.append("flowchart LR")
for h in d["habilidades"]:
	dela = [x for x in items if x["receta"] and x["receta"]["habilidad"] == h["id"]]
	if not dela: continue
	L.append("  subgraph %s[%s]" % (h["id"], h["nombre"]))
	for x in dela:
		L.append("    %s[%s]" % (x["id"], x["nombre"]))
	L.append("  end")
comprados = sorted({i["id"] for x in items if x["receta"] for i in x["receta"]["insumos"]
                    if por_id[i["id"]]["comprable"] and not por_id[i["id"]]["receta"]})
for c in comprados:
	L.append("  %s([%s])" % (c, por_id[c]["nombre"]))
for x in items:
	r = x["receta"]
	if not r: continue
	for i in r["insumos"]:
		L.append("  %s -->|%d| %s" % (i["id"], i["cantidad"], x["id"]))
	for u in r["utensilios"]:
		L.append("  %s -.-> %s" % (u, x["id"]))
L.append("```\n")

L.append("### 7.1 Los precios salen de tres reglas, no de la intuición\n")
L.append("`herramientas/generar_items.py` no escribe el catálogo si alguna no se cumple:\n")
L.append("| Categoría | Regla | Por qué |")
L.append("|---|---|---|")
L.append("| Cadena productiva | Vender el resultado **deja ganancia** sobre reponer los insumos | Si transformar no paga, nadie produce |")
L.append("| Muebles | Venderlos al NPC **da pérdida** | Si no, craftear y revender imprime dinero y dejan de ser el sumidero |")
L.append("| Vajilla | Lavar **recicla**, no produce valor | Queda fuera de la regla a propósito |\n")
L.append("Los márgenes que salen hoy, con el NPC pagando %d %%:\n" % (venta * 100))
L.append("| Ítem | Regla | Valor | NPC paga | Reponer | Margen |")
L.append("|---|---|---:|---:|---:|---:|")
for x in items:
	if not x["receta"] or not x["vendible"]: continue
	regla = {"decorativo": "pérdida", "utensilio": "recicla"}.get(x["categoria"], "ganancia")
	m = x["valor_base"] * venta - costo(x["id"])
	L.append("| `%s` | %s | %d | %.0f | %.0f | **%+.0f** |"
		% (x["id"], regla, x["valor_base"], x["valor_base"] * venta, costo(x["id"]), m))

L.append("\n### 7.2 Lo que este catálogo hizo desaparecer\n")
L.append("Tres problemas abiertos dejaron de existir, no por resolverse sino porque el diseño")
L.append("que los causaba ya no está:\n")
L.append("- **D6, la tabla de drops.** Salía de que la semilla de manzana caía «en baja proporción»")
L.append("  al cosechar. En el catálogo v0.5 **no hay recolección aleatoria**: plantar una semilla da")
L.append("  siempre su verdura. Sin azar no hace falta `GatherTable`.")
L.append("- **D7, el sumidero de energía.** Ningún ítem restaura energía y nada la gasta. El sumidero")
L.append("  de la economía son los muebles, que se compran con lo que rinde cocinar. La barra del")
L.append("  `HUD` sigue existiendo, oculta, por si vuelve.")
L.append("- **El desfase de tildes de D4.** Las habilidades son `agricultura`, `cocina` y `carpinteria`,")
L.append("  en minúscula y sin tildes, con `nombre` aparte para mostrar. Del lado de los datos ya está;")
L.append("  falta el `const Habilidades` que impida escribir una cadena suelta desde el código.\n")

L.append("### 7.3 Lo que el catálogo todavía no cubre\n")
L.append("- **Pan, queso, carne y jamón se compran.** No tienen cadena propia porque no hay modelos")
L.append("  de panadería ni de ganadería. El día que los haya, alcanza con darles receta y poner")
L.append("  `comprable: false`.")
L.append("- **La madera se compra.** No hay árbol en ningún pack, así que talar no puede ser la fuente.")
L.append("- **La pesca y la minería quedan fuera** pese a tener sus animaciones completas: sin modelo")
L.append("  de pez, de agua ni de veta, el resultado sería un ítem invisible sacado de un lugar que")
L.append("  no existe.\n")

texto = io.open(RAIZ + "/docs/SISTEMAS.md", encoding="utf-8").read()
i = texto.index("## 7. Estado de los datos")
j = texto.index("## 8. Qué cerrar antes de cada fase")
io.open(RAIZ + "/docs/SISTEMAS.md", "w", encoding="utf-8").write(texto[:i] + "\n".join(L) + "\n" + texto[j:])
print("seccion 7 regenerada: %d lineas" % len(L))
