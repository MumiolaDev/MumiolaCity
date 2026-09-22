# -*- coding: utf-8 -*-
"""Genera data/objetos/items.json v0.5 y valida el catalogo antes de escribirlo."""
import json, io, os, sys

VENTA_NPC = 0.6    # lo que el NPC paga: siempre menos, a proposito
COMPRA_NPC = 1.0   # lo que el NPC cobra

I = []  # items

def item(id, nombre, categoria, valor, modelo=None, desc="", peso=0.2,
         apilable=True, stack=99, comprable=False, vendible=True, familia="",
         size=(1, 1), rotable=None, colocable=None, interacciones=None, receta=None):
	# Por defecto, todo lo que se puede colocar se puede girar.
	#
	# Antes el defecto era False y solo doce de los cuarenta y cinco colocables
	# rotaban, que en un editor de salas es media herramienta: un mueble que solo
	# mira al norte sirve para una pared de cuatro. Girar algo con simetria
	# radial —un tomate, un plato— no se nota, pero nunca esta mal; no poder
	# girar algo que lo necesita si.
	se_coloca = (modelo is not None) if colocable is None else colocable
	I.append({
		"id": id, "nombre": nombre, "descripcion": desc, "categoria": categoria,
		"peso": peso, "apilable": apilable, "stack_maximo": stack,
		"valor_base": valor, "comprable": comprable, "vendible": vendible,
		"familia": familia,
		"tamano_grilla": list(size), "rotable": se_coloca if rotable is None else rotable,
		"colocable": se_coloca,
		"modelo": modelo,
		"interacciones": interacciones or [],
		"receta": receta,
	})

def cultivo(resultado, nivel, seg, xp):
	return {"insumos": [{"id": "semilla_" + resultado, "cantidad": 1}], "utensilios": [],
	        "estacion": "parcela", "habilidad": "agricultura",
	        "nivel_requerido": nivel, "xp": xp, "tiempo_seg": seg, "resultado_fallo": None}

def receta(insumos, habilidad, nivel, seg, xp, utensilios=(), estacion=None, fallo=None):
	return {"insumos": [{"id": i, "cantidad": c} for i, c in insumos],
	        "utensilios": list(utensilios), "estacion": estacion, "habilidad": habilidad,
	        "nivel_requerido": nivel, "xp": xp, "tiempo_seg": seg, "resultado_fallo": fallo}

R = "restoran/"; M = "muebles/"; P = "prototipo/"

# ---------------------------------------------------------------- semillas
for sid, nom, val, niv in [("tomate","tomate",2,1),("lechuga","lechuga",2,1),
                            ("papa","papa",3,2),("cebolla","cebolla",3,2),("zanahoria","zanahoria",4,3)]:
	item("semilla_" + sid, "Semilla de " + nom, "materia_prima", val, None,
	     "Se planta en una parcela. La compra el NPC de abastecimiento.",
	     peso=0.05, comprable=True, colocable=False)

# ---------------------------------------------------------------- verduras
for vid, nom, val, mod, niv, seg, xp in [
	("tomate","Tomate",7,"food_ingredient_tomato",1,120,6),
	("lechuga","Lechuga",7,"food_ingredient_lettuce",1,120,6),
	("papa","Papa",10,"food_ingredient_potato",2,180,9),
	("cebolla","Cebolla",10,"food_ingredient_onion",2,180,9),
	("zanahoria","Zanahoria",12,"food_ingredient_carrot",3,240,12)]:
	item(vid, nom, "materia_prima", val, R + mod,
	     "Cosechada en la parcela. Se puede cortar o dejar a la vista.",
	     peso=0.2, receta=cultivo(vid, niv, seg, xp))

item("cajon_verduras", "Cajon de verduras", "decorativo", 40, R + "crate_tomatoes",
     "Mueble contenedor. Cambia de aspecto segun la verdura que guarde.",
     peso=8.0, apilable=False, stack=1, comprable=True, size=(1,1),
     interacciones=["abrir"])

# ---------------------------------------------------------------- comprados
item("pan_hamburguesa","Pan de hamburguesa","intermedio",5,R+"food_ingredient_bun",
     "Insumo de panaderia. Todavia no se craftea.", comprable=True)
item("queso","Queso","intermedio",9,R+"food_ingredient_cheese",
     "Insumo lacteo. Todavia no se craftea.", comprable=True)
item("carne_cruda","Carne cruda","intermedio",14,R+"food_ingredient_burger_uncooked",
     "Insumo de carniceria. Todavia no se craftea.", comprable=True)
item("jamon","Jamon","intermedio",18,R+"food_ingredient_ham",
     "Insumo de carniceria. Todavia no se craftea.", comprable=True)

# ---------------------------------------------------------------- procesados
item("tomate_rodajas","Tomate en rodajas","intermedio",11,R+"food_ingredient_tomato_slices",
     receta=receta([("tomate",1)],"cocina",1,3,4,utensilios=["cuchillo","tabla_cortar"]))
item("lechuga_picada","Lechuga picada","intermedio",11,R+"food_ingredient_lettuce_chopped",
     receta=receta([("lechuga",1)],"cocina",1,3,4,utensilios=["cuchillo","tabla_cortar"]))
item("queso_fetas","Queso en fetas","intermedio",20,R+"food_ingredient_cheese_slice",
     receta=receta([("queso",1)],"cocina",1,3,4,utensilios=["cuchillo","tabla_cortar"]))
item("cebolla_aros","Cebolla en aros","intermedio",15,R+"food_ingredient_onion_rings",
     receta=receta([("cebolla",1)],"cocina",2,4,6,utensilios=["cuchillo","tabla_cortar"]))
item("zanahoria_trozos","Zanahoria en trozos","intermedio",18,R+"food_ingredient_carrot_pieces",
     receta=receta([("zanahoria",1)],"cocina",2,4,6,utensilios=["cuchillo","tabla_cortar"]))
item("papa_pure","Pure de papa","intermedio",26,R+"food_ingredient_potato_mashed",
     receta=receta([("papa",2)],"cocina",3,8,10,utensilios=["olla"],estacion="estufa"))
item("carne_cocida","Carne cocida","intermedio",32,R+"food_ingredient_burger_cooked",
     "Se quema si la cocina alguien sin nivel suficiente.",
     receta=receta([("carne_cruda",1)],"cocina",2,6,8,utensilios=["sarten"],
                   estacion="estufa",fallo="carne_quemada"))
item("jamon_cocido","Jamon cocido","intermedio",40,R+"food_ingredient_ham_cooked",
     "Se quema si la cocina alguien sin nivel suficiente.",
     receta=receta([("jamon",1)],"cocina",3,6,10,utensilios=["sarten"],
                   estacion="estufa",fallo="carne_quemada"))
item("carne_quemada","Carne quemada","intermedio",0,R+"food_ingredient_burger_trash",
     "El resultado de cocinar sin nivel. No vale nada y no se puede vender.",
     vendible=False)

# ---------------------------------------------------------------- platos
item("hamburguesa","Hamburguesa","consumible",78,R+"food_burger",
     "Plato terminado. Se sirve en un plato y se puede dejar servido en una mesa.",
     apilable=False,stack=1,
     receta=receta([("pan_hamburguesa",1),("carne_cocida",1),("tomate_rodajas",1),("lechuga_picada",1)],
                   "cocina",4,10,20,utensilios=["plato"]))
item("hamburguesa_veggie","Hamburguesa vegetariana","consumible",86,R+"food_vegetableburger",
     "Plato terminado sin carne comprada: el mas rentable si tenes huerta.",
     apilable=False,stack=1,
     receta=receta([("pan_hamburguesa",1),("papa_pure",1),("tomate_rodajas",1),
                    ("lechuga_picada",1),("queso_fetas",1)],"cocina",4,12,24,utensilios=["plato"]))
item("guiso","Guiso","consumible",140,R+"food_stew",
     "Plato terminado. Se sirve en bol.",
     apilable=False,stack=1,
     receta=receta([("papa_pure",1),("zanahoria_trozos",1),("cebolla_aros",1),("jamon_cocido",1)],
                   "cocina",6,20,40,utensilios=["olla","bol"],estacion="estufa"))
item("plato_del_dia","Plato del dia","consumible",260,R+"food_dinner",
     "La receta mas alta de Cocina: un plato de cada tipo.",
     apilable=False,stack=1,
     receta=receta([("hamburguesa",1),("guiso",1)],"cocina",8,15,70,utensilios=["plato"]))

# ---------------------------------------------------------------- utensilios
item("cuchillo","Cuchillo","utensilio",30,R+"knife","Requerido para cortar.",
     peso=0.3,apilable=False,stack=1,comprable=True)
item("tabla_cortar","Tabla de cortar","utensilio",25,R+"cuttingboard","Requerida para cortar.",
     peso=1.0,apilable=False,stack=1,comprable=True)
item("sarten","Sarten","utensilio",40,R+"pan_A","Requerida para freir.",
     peso=1.5,apilable=False,stack=1,comprable=True)
item("olla","Olla","utensilio",55,R+"pot_A","Requerida para hervir y para el guiso.",
     peso=2.0,apilable=False,stack=1,comprable=True,familia="olla")
item("plato","Plato","utensilio",12,R+"plate","Contiene un plato terminado. Se ensucia al usarse.",
     peso=0.4,apilable=False,stack=1,comprable=True,familia="plato",interacciones=["servir","vaciar"])
item("bol","Bol","utensilio",14,R+"bowl","Contiene guiso. Se ensucia al usarse.",
     peso=0.4,apilable=False,stack=1,comprable=True,familia="plato",interacciones=["servir","vaciar"])
item("plato_sucio","Plato sucio","utensilio",0,R+"plate_dirty","Se lava en el fregadero.",
     peso=0.4,apilable=False,stack=1,vendible=False,
     receta=None)
item("bol_sucio","Bol sucio","utensilio",0,R+"bowl_dirty","Se lava en el fregadero.",
     peso=0.4,apilable=False,stack=1,vendible=False)
item("frasco","Frasco","decorativo",18,R+"jar_A_medium","Decorativo de estanteria.",
     peso=0.5,apilable=False,stack=1,comprable=True)

# lavado: devuelve la vajilla limpia
I_by = {x["id"]: x for x in I}
I_by["plato"]["receta"] = receta([("plato_sucio",1)],"cocina",1,4,1,estacion="fregadero")
I_by["bol"]["receta"] = receta([("bol_sucio",1)],"cocina",1,4,1,estacion="fregadero")
I_by["plato"]["comprable"] = True
I_by["bol"]["comprable"] = True

# ---------------------------------------------------------------- carpinteria
item("tabla_madera","Tabla de madera","materia_prima",10,P+"Primitive_Beam",
     "Materia prima del taller. Todavia no se produce.", peso=2.0, comprable=True)

for mid, nom, val, mod, tablas, niv, seg, xp, size, inter in [
	("banqueta","Banqueta",28,M+"chair_stool_wood",2,1,5,8,(1,1),["sentarse"]),
	("silla_madera","Silla de madera",45,M+"chair_A_wood",3,1,6,10,(1,1),["sentarse"]),
	("mesa_chica","Mesa chica",60,M+"table_small",4,2,8,14,(1,1),["apoyar"]),
	("estante","Estante",75,M+"shelf_A_small",5,3,10,18,(1,1),["abrir"]),
	("mesa","Mesa",90,M+"table_medium",6,3,12,22,(2,2),["apoyar"]),
	("alacena","Alacena",120,M+"cabinet_small",8,4,15,30,(1,1),["abrir"]),
	("cama","Cama",150,M+"bed_single_A",10,5,20,40,(1,2),["acostarse"])]:
	item(mid, nom, "decorativo", val, mod, "Mueble del taller. Se coloca en tu sala.",
	     peso=6.0, apilable=False, stack=1, rotable=True, size=size, interacciones=inter,
	     receta=receta([("tabla_madera",tablas)],"carpinteria",niv,seg,xp,
	                   utensilios=["serrucho","martillo"],estacion="banco_carpintero"))

item("serrucho","Serrucho","utensilio",45,None,"Requerido en el taller.",
     peso=1.2,apilable=False,stack=1,comprable=True,colocable=False)
item("martillo","Martillo","utensilio",40,None,"Requerido en el taller.",
     peso=1.0,apilable=False,stack=1,comprable=True,colocable=False)

# ---------------------------------------------------------------- decorativos comprados
for did, nom, val, mod, size, inter in [
	("alfombra","Alfombra",48,M+"rug_rectangle_A",(2,1),[]),
	("lampara_mesa","Lampara de mesa",62,M+"lamp_table",(1,1),["encender"]),
	("cuadro","Cuadro",50,M+"pictureframe_medium",(1,1),[]),
	("maceta","Maceta con cactus",34,M+"cactus_small_A",(1,1),[]),
	("libro","Libro",22,M+"book_single",(1,1),[])]:
	item(did, nom, "decorativo", val, mod, "Decoracion. Se compra al NPC.",
	     peso=2.0, apilable=False, stack=1, comprable=True, rotable=True, size=size,
	     interacciones=inter)
I_by = {x["id"]: x for x in I}
I_by["alfombra"]["descripcion"] = "Decoracion. Se pisa: ocupa la celda pero no la bloquea."


# ================================================================ validacion
RAIZ = "/home/mumiola/Programacion/Godot/MumiolaCity/mumiola-city"
ARTE = os.path.join(RAIZ, "arte/modelos_3d")

HABILIDADES = [
	{"id": "agricultura", "nombre": "Agricultura", "animacion": "cavar"},
	{"id": "cocina", "nombre": "Cocina", "animacion": "trabajar"},
	{"id": "carpinteria", "nombre": "Carpinteria", "animacion": "martillar"},
]
ESTACIONES = [
	{"id": "parcela", "nombre": "Parcela", "modelo": "prototipo/Floor_Dirt", "habilidad": "agricultura"},
	{"id": "estufa", "nombre": "Estufa", "modelo": "restoran/stove_single", "habilidad": "cocina"},
	{"id": "fregadero", "nombre": "Fregadero", "modelo": "restoran/kitchencounter_sink", "habilidad": "cocina"},
	{"id": "banco_carpintero", "nombre": "Banco de carpintero", "modelo": "restoran/kitchentable_A", "habilidad": "carpinteria"},
]

por_id = {x["id"]: x for x in I}
errores, avisos = [], []

# 1. ids unicos
if len(por_id) != len(I):
	errores.append("hay ids duplicados")

# 2. los modelos existen
for x in I:
	if x["modelo"]:
		ruta = os.path.join(ARTE, x["modelo"])
		if not (os.path.exists(ruta + ".gltf") or os.path.exists(ruta + ".glb")):
			errores.append("%s: no existe el modelo %s" % (x["id"], x["modelo"]))
for e in ESTACIONES:
	ruta = os.path.join(ARTE, e["modelo"])
	if not (os.path.exists(ruta + ".gltf") or os.path.exists(ruta + ".glb")):
		errores.append("estacion %s: no existe el modelo %s" % (e["id"], e["modelo"]))

# 3. insumos, utensilios, estaciones y fallos existen
ids_estacion = {e["id"] for e in ESTACIONES}
ids_hab = {h["id"] for h in HABILIDADES}
for x in I:
	r = x["receta"]
	if not r: continue
	for ins in r["insumos"]:
		if ins["id"] not in por_id: errores.append("%s: insumo inexistente '%s'" % (x["id"], ins["id"]))
	for u in r["utensilios"]:
		if u not in por_id: errores.append("%s: utensilio inexistente '%s'" % (x["id"], u))
		elif por_id[u]["categoria"] != "utensilio": avisos.append("%s: '%s' no es utensilio" % (x["id"], u))
	if r["estacion"] and r["estacion"] not in ids_estacion:
		errores.append("%s: estacion inexistente '%s'" % (x["id"], r["estacion"]))
	if r["habilidad"] not in ids_hab:
		errores.append("%s: habilidad inexistente '%s'" % (x["id"], r["habilidad"]))
	if r["resultado_fallo"] and r["resultado_fallo"] not in por_id:
		errores.append("%s: resultado_fallo inexistente" % x["id"])

# 4. invariante de la fase: si no se craftea, se compra
for x in I:
	if x["receta"] is None and not x["comprable"] and x["vendible"]:
		avisos.append("%s: no se craftea ni se compra, no hay forma de conseguirlo" % x["id"])

# 5. sin ciclos en las recetas
def profundidad(id, visto):
	if id in visto: errores.append("ciclo de receta en '%s'" % id); return 0
	r = por_id[id]["receta"]
	if not r: return 0
	return 1 + max([profundidad(i["id"], visto | {id}) for i in r["insumos"]] or [0])
for x in I: profundidad(x["id"], set())

# 6. el margen: vender el resultado tiene que pagar reponer los insumos comprados
def costo_reposicion(id, visto=None):
	"""Lo que cuesta conseguir una unidad: si se compra, su precio; si se craftea,
	la suma de reponer sus insumos."""
	visto = visto or set()
	if id in visto: return 0
	x = por_id[id]
	if x["receta"] is None:
		return x["valor_base"] * COMPRA_NPC if x["comprable"] else 0
	return sum(costo_reposicion(i["id"], visto | {id}) * i["cantidad"] for i in x["receta"]["insumos"])

print("%-22s %-9s %7s %7s %7s %8s" % ("item", "regla", "valor", "vende", "costo", "margen"))
print("-" * 66)
margenes = []
for x in I:
	if not x["receta"] or not x["vendible"]: continue
	venta = x["valor_base"] * VENTA_NPC
	costo = costo_reposicion(x["id"])
	margen = venta - costo
	margenes.append((x["id"], margen))
	# La regla depende de para que existe el item, no es una sola.
	#  - Cadena productiva: transformar tiene que pagar, o nadie produce.
	#  - Muebles: vender tiene que dar PERDIDA, o craftear y revender imprime
	#    dinero y el sumidero deja de serlo.
	#  - Vajilla: lavar no produce valor, recicla; queda fuera de la regla.
	if x["categoria"] == "decorativo":
		esperado, ok = "perdida", margen < 0
	elif x["categoria"] == "utensilio":
		esperado, ok = "recicla", True
	else:
		esperado, ok = "ganancia", margen >= 2.0
	marca = "" if ok else "  <-- deberia dar " + esperado
	print("%-22s %-9s %7d %7.1f %7.1f %8.1f%s"
		% (x["id"], esperado, x["valor_base"], venta, costo, margen, marca))
	if not ok:
		errores.append("%s: margen %.1f, se esperaba %s" % (x["id"], margen, esperado))

print()
for e in errores: print("  ERROR  " + e)
for a in avisos: print("  aviso  " + a)
print()
print("%d items, %d con receta, %d comprables, %d vendibles"
	% (len(I), sum(1 for x in I if x["receta"]), sum(1 for x in I if x["comprable"]),
	   sum(1 for x in I if x["vendible"])))

if errores:
	print("\nNO SE ESCRIBE NADA: hay %d errores." % len(errores)); sys.exit(1)

doc = {
	"version": "0.5",
	"moneda": "ducados",
	"notas": [
		"Catalogo reconstruido a partir de los modelos 3D que el proyecto ya tiene.",
		"valor_base es la referencia de mercado. El NPC paga venta_npc y cobra compra_npc.",
		"El NPC siempre paga menos de lo que cobra: es un piso de emergencia, no un negocio.",
		"Por ahora todo lo que no se craftea se compra. A medida que algo se vuelva",
		"crafteable, alcanza con poner comprable en false.",
		"Los modelos son rutas relativas a arte/modelos_3d/, sin extension.",
	],
	"tasas": {"venta_npc": VENTA_NPC, "compra_npc": COMPRA_NPC},
	"habilidades": HABILIDADES,
	"estaciones": ESTACIONES,
	"items": I,
}
destino = os.path.join(RAIZ, "data/objetos/items.json")
io.open(destino, "w", encoding="utf-8").write(json.dumps(doc, ensure_ascii=False, indent="\t") + "\n")
print("escrito %s (%d KB)" % (destino, os.path.getsize(destino) // 1024))
