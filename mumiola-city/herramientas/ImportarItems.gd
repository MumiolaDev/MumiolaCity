@tool
extends EditorScript

## Genera el catalogo de Godot desde data/objetos/items.json.
##
## Se corre desde el editor con Archivo > Ejecutar (Ctrl+Shift+X) con este script
## abierto. No se ejecuta durante el juego.
##
## Por que un importador y no 52 .tres escritos a mano: para que items.json siga
## siendo la unica fuente. Con dos fuentes, editar una y olvidar la otra es
## cuestion de tiempo, y el desfase no da error — simplemente el juego usa
## valores viejos. Ademas herramientas/generar_items.py valida el JSON entero
## antes de escribirlo, y esa validacion se perderia si el catalogo se editara
## despues en el inspector.
##
## Es idempotente: volver a correrlo regenera todo. Lo que se edite a mano en los
## archivos generados se pierde, y eso es intencional.

const ORIGEN := "res://data/objetos/items.json"
const DIR_ITEMS := "res://data/objetos/definiciones"
const DIR_HABILIDADES := "res://data/habilidades"
const DIR_COMPORTAMIENTOS := "res://data/objetos/comportamientos"
const DIR_ESCENAS := "res://escenas/objetos/generadas"
const DIR_MODELOS := "res://arte/modelos_3d"
const DIR_ICONOS := "res://arte/iconos"
const RUTA_CATALOGO := "res://data/objetos/catalogo.tres"

var _avisos : Array[String] = []


func _run() -> void:
	var datos := _leer_json()
	if datos.is_empty():
		return

	for d in [DIR_ITEMS, DIR_HABILIDADES, DIR_ESCENAS]:
		DirAccess.make_dir_recursive_absolute(d)

	var items : Array = datos.get("items", [])
	var habilidades : Array = datos.get("habilidades", [])

	var escenas := _generar_escenas(items)
	var n_items := _generar_items(items, escenas)
	var n_hab := _generar_habilidades(habilidades)
	_generar_info(datos, items)

	print("\n--- importacion terminada ---")
	print("  reportado: %d definiciones, %d escenas, %d habilidades" % [n_items, escenas.size(), n_hab])
	print("  en disco:  %d definiciones, %d escenas, %d habilidades"
		% [_contar(DIR_ITEMS, ".tres"), _contar(DIR_ESCENAS, ".tscn"), _contar(DIR_HABILIDADES, ".tres")])
	if _contar(DIR_ITEMS, ".tres") < items.size():
		push_error("ImportarItems: faltan definiciones en disco. Mirar los errores de arriba.")
	for a in _avisos:
		print("  aviso: " + a)
	if _avisos.is_empty():
		print("  sin avisos")
	print("  Reimportar el proyecto para que el editor vea los archivos nuevos.")


## Lee y valida minimamente el JSON de origen.
func _leer_json() -> Dictionary:
	if not FileAccess.file_exists(ORIGEN):
		push_error("ImportarItems: no existe %s" % ORIGEN)
		return {}

	var texto := FileAccess.open(ORIGEN, FileAccess.READ).get_as_text()
	var crudo = JSON.parse_string(texto)
	if not (crudo is Dictionary) or not crudo.has("items"):
		push_error("ImportarItems: %s no tiene la forma esperada." % ORIGEN)
		return {}

	print("Catalogo v%s: %d items" % [crudo.get("version", "?"), crudo["items"].size()])
	return crudo


## Crea una escena por item colocable que tenga modelo.
##
## Se generan antes que las definiciones porque cada definicion apunta a la suya.
func _generar_escenas(items : Array) -> Dictionary:
	var rutas := {}
	for d in items:
		var modelo : String = str(d.get("modelo", ""))
		if modelo == "" or not bool(d.get("colocable", true)):
			continue

		var ruta_modelo := "%s/%s" % [DIR_MODELOS, modelo]
		var malla : PackedScene = _cargar_modelo(ruta_modelo)
		if malla == null:
			_avisos.append("%s: no se pudo cargar el modelo %s" % [d["id"], modelo])
			continue

		var destino := "%s/%s.tscn" % [DIR_ESCENAS, d["id"]]
		if _guardar(_armar_escena(d, malla), destino):
			rutas[d["id"]] = destino
	return rutas


## Prueba las dos extensiones con las que llegan los modelos del pack.
func _cargar_modelo(base : String) -> PackedScene:
	for ext in [".gltf", ".glb"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext) as PackedScene
	return null


## Arma la escena de un objeto colocable: un WorldObject con su malla y una caja
## de colision del tamano de su huella.
##
## La colision no sigue la malla a proposito: la ocupacion de celdas la lleva
## IsoGrid, asi que lo unico que esta forma tiene que hacer es recibir clics.
func _armar_escena(d : Dictionary, malla : PackedScene) -> PackedScene:
	var raiz := Area3D.new()
	raiz.name = _a_pascal(str(d["id"]))
	raiz.set_script(load("res://escenas/objetos/WorldObject.gd"))
	raiz.collision_layer = 2
	raiz.collision_mask = 0
	raiz.set("celda_origen", Vector2i.ZERO)
	raiz.set("rotacion_grilla", 0)

	var huella : Array = d.get("tamano_grilla", [1, 1])
	var caja := BoxShape3D.new()
	caja.size = Vector3(maxi(int(huella[0]), 1) - 0.1, 1.0, maxi(int(huella[1]), 1) - 0.1)

	var forma := CollisionShape3D.new()
	forma.name = "CollisionShape3D"
	forma.shape = caja
	forma.position = Vector3(0.0, 0.5, 0.0)
	raiz.add_child(forma)
	forma.owner = raiz

	var visual := malla.instantiate()
	visual.name = "Visual"

	# Apoyar el modelo sobre su base. Los modelos de KayKit no siguen una sola
	# convencion: la mayoria trae el origen en la base, pero catorce lo traen en
	# el centro, y esos se hundian hasta medio metro en el piso — la zanahoria
	# 58 cm, el cuadro 45. Se corrige aca y no al colocar para que lo hereden
	# todos a la vez: el mundo, el fantasma de la vista previa y cualquier otro
	# que instancie la escena.
	if visual is Node3D:
		(visual as Node3D).position.y = Volumen.apoyo_de(visual)

	raiz.add_child(visual)
	visual.owner = raiz

	var empaquetada := PackedScene.new()
	if empaquetada.pack(raiz) != OK:
		_avisos.append("%s: no se pudo empaquetar la escena" % d["id"])
		raiz.free()
		return null
	raiz.free()
	return empaquetada


## Guarda la version del catalogo para que exista en runtime.
##
## items.json es fuente y no dato de juego, asi que su numero de version se
## perderia al importar. El documento de sala lo necesita (D24).
func _generar_info(datos : Dictionary, items : Array) -> void:
	var info := CatalogoInfo.new()
	info.version = str(datos.get("version", ""))
	info.cantidad_items = items.size()
	_guardar(info, RUTA_CATALOGO)


## Crea un ItemDefinition por entrada del catalogo.
func _generar_items(items : Array, escenas : Dictionary) -> int:
	var hechos := 0
	for d in items:
		var def : ItemDefinition = _armar_definicion(d, escenas)
		if def == null:
			continue
		if _guardar(def, "%s/%s.tres" % [DIR_ITEMS, d["id"]]):
			hechos += 1
		else:
			_avisos.append("%s: no se pudo guardar la definicion" % d["id"])
	return hechos


## Arma la definicion de un item del catalogo.
##
## Devuelve null si algo no cierra, para que un item roto no se lleve puesta la
## tanda entera: en una herramienta de contenido conviene importar 51 y decir
## cual fallo, antes que no importar ninguno.
func _armar_definicion(d : Dictionary, escenas : Dictionary) -> ItemDefinition:
	if not d.has("id"):
		_avisos.append("hay una entrada sin id en el catalogo")
		return null

	var def := ItemDefinition.new()
	def.id = StringName(d["id"])
	def.nombre = str(d.get("nombre", ""))
	def.descripcion = str(d.get("descripcion", ""))
	def.categoria = str(d.get("categoria", "decorativo"))
	def.peso = float(d.get("peso", 0.1))
	def.apilable = bool(d.get("apilable", true))
	def.stack_maximo = int(d.get("stack_maximo", 99))
	def.valor_base = int(d.get("valor_base", 1))
	def.comprable = bool(d.get("comprable", false))
	def.vendible = bool(d.get("vendible", true))
	def.familia = _texto(d, "familia")
	def.colocable = bool(d.get("colocable", true))
	def.rotable = bool(d.get("rotable", false))

	var huella : Array = d.get("tamano_grilla", [1, 1])
	def.tamano_grilla = Vector2i(int(huella[0]), int(huella[1]))

	if escenas.has(d["id"]):
		var escena = load(escenas[d["id"]])
		if escena is PackedScene:
			def.escena_mundo = escena
		else:
			_avisos.append("%s: la escena generada no cargo como PackedScene" % d["id"])

	def.icono = _icono_de(str(d["id"]))

	def.interacciones = _resolver_interacciones(d)
	def.receta = _armar_receta(d)
	return def


## Busca el icono ya generado de un item, o null si todavia no existe.
##
## No avisa cuando falta, a proposito: el catalogo tiene items sin modelo y por
## lo tanto sin icono, y ademas este importador se corre muchas veces antes que
## GenerarIconos.gd la primera. Un aviso por item seria ruido constante.
##
## Pide el .import y no el .png porque lo que hace falta es que Godot ya lo haya
## importado: si el PNG existe pero el editor todavia no lo proceso, load()
## devuelve null igual. Es el orden de las dos pasadas, comprobado en vez de
## supuesto.
func _icono_de(id : String) -> Texture2D:
	var ruta := "%s/%s.png" % [DIR_ICONOS, id]
	if not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D


## Traduce la lista de verbos del JSON a los comportamientos que existen.
##
## Los que faltan se avisan en vez de fallar: la lista de verbos del catalogo es
## por diseño mas larga que la de comportamientos escritos, y ese hueco es
## justamente la lista de lo que queda por implementar.
func _resolver_interacciones(d : Dictionary) -> Array[InteractionBehavior]:
	var salida : Array[InteractionBehavior] = []
	for verbo in d.get("interacciones", []):
		var ruta := "%s/%s.tres" % [DIR_COMPORTAMIENTOS, verbo]
		if ResourceLoader.exists(ruta):
			salida.append(load(ruta))
		else:
			_avisos.append("%s: no hay comportamiento para el verbo '%s'" % [d["id"], verbo])
	return salida


## Arma la receta anidada, con los utensilios como insumos que no se consumen.
func _armar_receta(d : Dictionary) -> RecipeDefinition:
	var r = d.get("receta", null)
	if not (r is Dictionary):
		return null

	var receta := RecipeDefinition.new()
	receta.habilidad = StringName(r.get("habilidad", ""))
	receta.nivel_requerido = int(r.get("nivel_requerido", 1))
	receta.xp_otorgada = int(r.get("xp", 0))
	receta.tiempo_crafteo_seg = float(r.get("tiempo_seg", 1.0))
	receta.cantidad_resultado = int(r.get("cantidad_resultado", 1))
	receta.estacion = _texto(r, "estacion")
	receta.resultado_fallo = _texto(r, "resultado_fallo")

	var insumos : Array[InsumoReceta] = []
	for i in r.get("insumos", []):
		var ins := InsumoReceta.new()
		ins.id = StringName(i.get("id", ""))
		ins.cantidad = int(i.get("cantidad", 1))
		ins.consume = true
		insumos.append(ins)

	for u in r.get("utensilios", []):
		var ins := InsumoReceta.new()
		ins.id = StringName(u)
		ins.cantidad = 1
		ins.consume = false
		insumos.append(ins)

	receta.insumos = insumos
	return receta


## Crea un SkillDefinition por habilidad declarada.
##
## No pisa una curva ya balanceada: si el .tres existe, conserva su curva_xp y
## sus desbloqueos, que son trabajo de ajuste hecho en el inspector y no se
## pueden derivar del JSON.
func _generar_habilidades(habilidades : Array) -> int:
	var hechas := 0
	for h in habilidades:
		var ruta := "%s/%s.tres" % [DIR_HABILIDADES, h["id"]]
		var def : SkillDefinition
		if ResourceLoader.exists(ruta):
			def = load(ruta)
		else:
			def = SkillDefinition.new()

		def.id = StringName(h["id"])
		def.nombre_display = str(h.get("nombre", h["id"]))
		if _guardar(def, ruta):
			hechas += 1
	return hechas


## Lee un campo de texto del JSON tolerando que venga en null.
##
## JSON distingue "ausente" de "presente pero null", y el catalogo usa null para
## los campos opcionales. Sin esto, StringName(null) revienta.
func _texto(d : Dictionary, clave : String) -> StringName:
	var valor = d.get(clave)
	return StringName("") if valor == null else StringName(str(valor))


## Guarda un recurso y comprueba que el archivo haya aparecido.
##
## No alcanza con mirar el codigo de retorno: la primera version confiaba en el y
## reporto 52 guardados que nunca llegaron al disco. Un fallo silencioso en una
## herramienta de contenido es peor que uno ruidoso, porque el error aparece
## mucho despues, en forma de catalogo vacio.
func _guardar(recurso : Resource, ruta : String) -> bool:
	if recurso == null:
		push_error("ImportarItems: recurso nulo para %s" % ruta)
		return false

	var error := ResourceSaver.save(recurso, ruta, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("ImportarItems: ResourceSaver fallo en %s con error %d" % [ruta, error])
		return false
	if not FileAccess.file_exists(ruta):
		push_error("ImportarItems: ResourceSaver dijo OK pero %s no existe" % ruta)
		return false
	return true


## Cuenta los archivos de una carpeta con esa extension.
func _contar(carpeta : String, extension : String) -> int:
	var dir := DirAccess.open(carpeta)
	if dir == null:
		return 0
	var n := 0
	for archivo in dir.get_files():
		if archivo.trim_suffix(".remap").ends_with(extension):
			n += 1
	return n


## silla_madera -> SillaMadera, para que el nodo raiz tenga nombre de nodo.
func _a_pascal(id : String) -> String:
	var salida := ""
	for parte in id.split("_"):
		if parte != "":
			salida += parte.substr(0, 1).to_upper() + parte.substr(1)
	return salida
