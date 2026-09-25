extends RefCounted
class_name ServidorLocal

## El servidor, corriendo adentro del cliente y guardando en disco.
##
## Es la implementacion de hoy de lo que Servidor promete. Guarda en user:// lo
## que manana guarda una base de datos, y aplica las mismas reglas que va a
## aplicar el servidor de verdad: quien puede tocar que sala, que nombre sirve,
## que id es valido. Esas reglas se escriben aca y no en la interfaz justamente
## para que el dia de la red se muden enteras, sin buscarlas por el cliente.
##
## Donde vive cada cosa:
##
##     res://data/salas/publicas/<id>.json    salas publicas, versionadas en el repo
##     res://data/salas/plantillas/<id>.json  formas para crear salas nuevas
##     user://salas/<id>.json                 salas de jugadores, y las publicas
##                                            editadas en este equipo
##     user://perfiles/<id>.json              los perfiles: quien sos, que llevas
##                                            y donde te quedaste
##
## Una publica editada se guarda en user:// y esa copia gana al cargarla. Asi el
## editor de salas sigue sirviendo para armar mapas sin escribir dentro de res://,
## que en un juego exportado es de solo lectura.

const DIR_PUBLICAS := "res://data/salas/publicas"
const DIR_PLANTILLAS := "res://data/salas/plantillas"
const DIR_SALAS := "user://salas"
const DIR_PERFILES := "user://perfiles"

## Lo que puede tener un id. Todo lo que llega de afuera se comprueba contra
## esto antes de usarlo para armar una ruta: un id "../algo" escribiria fuera de
## la carpeta de salas, y con red ese id lo manda otro.
const CARACTERES_ID := "abcdefghijklmnopqrstuvwxyz0123456789_"
const LARGO_MAXIMO_NOMBRE := 40
## El nombre de un perfil es mas corto y mas estricto que el de una sala: es el
## que aparece sobre la cabeza y en el chat de todos.
const LARGO_MINIMO_JUGADOR := 3
const LARGO_MAXIMO_JUGADOR := 20
## La forma de la casa que recibe cada perfil nuevo.
const PLANTILLA_CASA := &"cuadrada_chica"


# --- Salas: leer ----------------------------------------------------------------


## Devuelve un resumen de cada sala publica, ordenadas por nombre.
func listar_salas_publicas() -> Array[Dictionary]:
	var salida : Array[Dictionary] = []
	for id in _ids_en(DIR_PUBLICAS):
		var doc := _leer_sala(id)
		if not doc.is_empty():
			salida.append(_resumen(doc))
	salida.sort_custom(_por_nombre)
	return salida


## Devuelve un resumen de cada sala de un duenio, ordenadas por nombre.
func listar_salas_de(propietario : StringName) -> Array[Dictionary]:
	var salida : Array[Dictionary] = []
	if propietario == &"":
		return salida
	for id in _ids_en(DIR_SALAS):
		var doc := _leer_json("%s/%s.json" % [DIR_SALAS, id])
		# Un archivo sin id, o con uno que no es el suyo, es de antes de que las
		# salas tuvieran identidad (las guardadas por nombre en la fase 3): no
		# se lista, porque no hay como referirse a el.
		if doc.get("id", "") != id:
			continue
		if StringName(str(doc.get("propietario", ""))) == propietario:
			salida.append(_resumen(doc))
	salida.sort_custom(_por_nombre)
	return salida


## Devuelve el documento completo de una sala. {"codigo", "doc"}
func obtener_sala(id : StringName) -> Dictionary:
	if not _id_valido(id):
		return {"codigo": Errores.Codigo.SALA_NO_EXISTE, "doc": {}}
	var ruta := _ruta_de(id)
	if ruta == "":
		return {"codigo": Errores.Codigo.SALA_NO_EXISTE, "doc": {}}
	var doc := _leer_json(ruta)
	if doc.is_empty():
		return {"codigo": Errores.Codigo.ARCHIVO_CORRUPTO, "doc": {}}
	# El id lo dice el nombre del archivo, no lo que traiga adentro: un documento
	# copiado a mano con otro nombre tiene que ser la sala que dice su archivo.
	doc["id"] = String(id)
	return {"codigo": Errores.Codigo.OK, "doc": doc}


## Devuelve las formas disponibles para crear una sala, con su estructura.
func plantillas() -> Array[Dictionary]:
	var salida : Array[Dictionary] = []
	for id in _ids_en(DIR_PLANTILLAS):
		var doc := _leer_json("%s/%s.json" % [DIR_PLANTILLAS, id])
		if doc.is_empty():
			continue
		doc["id"] = String(id)
		salida.append(doc)
	salida.sort_custom(func(a : Dictionary, b : Dictionary) -> bool:
		return (a.estructura.suelo as Array).size() < (b.estructura.suelo as Array).size())
	return salida


# --- Salas: escribir ------------------------------------------------------------


## Crea una sala nueva desde una plantilla. {"codigo", "id"}
func crear_sala(nombre : String, plantilla_id : StringName, propietario : StringName) -> Dictionary:
	nombre = _limpiar_nombre(nombre)
	if nombre == "" or propietario == &"":
		return {"codigo": Errores.Codigo.NOMBRE_INVALIDO, "id": &""}
	for existente in listar_salas_de(propietario):
		if existente.nombre.to_lower() == nombre.to_lower():
			return {"codigo": Errores.Codigo.NOMBRE_EN_USO, "id": &""}

	if not _id_valido(plantilla_id):
		return {"codigo": Errores.Codigo.PLANTILLA_NO_EXISTE, "id": &""}
	var plantilla := _leer_json("%s/%s.json" % [DIR_PLANTILLAS, plantilla_id])
	if plantilla.is_empty():
		return {"codigo": Errores.Codigo.PLANTILLA_NO_EXISTE, "id": &""}

	var id := _id_nuevo()
	var doc := {
		"version_formato": plantilla.get("version_formato", 1),
		"id": String(id),
		"catalogo": ItemDatabase.version(),
		"nombre": nombre,
		"descripcion": "",
		"tipo": plantilla.get("tipo", "vivienda"),
		"propietario": String(propietario),
		"entrada": plantilla.get("entrada", [0, 0]),
		"estructura": plantilla.get("estructura", {}),
		"objetos": [],
	}
	var codigo := _escribir(id, doc)
	return {"codigo": codigo, "id": id if Errores.ok(codigo) else &""}


## Guarda el documento de una sala en nombre de un actor.
func guardar_sala(doc : Dictionary, actor_id : StringName) -> Errores.Codigo:
	var id := StringName(str(doc.get("id", "")))
	if not _id_valido(id):
		return Errores.Codigo.SALA_NO_EXISTE
	var permiso := _puede_modificar(id, actor_id)
	if not Errores.ok(permiso):
		return permiso
	return _escribir(id, doc)


## Cambia el nombre visible de una sala.
func renombrar_sala(id : StringName, nombre : String, actor_id : StringName) -> Errores.Codigo:
	nombre = _limpiar_nombre(nombre)
	if nombre == "":
		return Errores.Codigo.NOMBRE_INVALIDO
	var leido := obtener_sala(id)
	if not Errores.ok(leido.codigo):
		return leido.codigo
	var permiso := _puede_modificar(id, actor_id)
	if not Errores.ok(permiso):
		return permiso
	var doc : Dictionary = leido.doc
	for existente in listar_salas_de(StringName(str(doc.get("propietario", "")))):
		if existente.id != String(id) and existente.nombre.to_lower() == nombre.to_lower():
			return Errores.Codigo.NOMBRE_EN_USO
	doc["nombre"] = nombre
	return _escribir(id, doc)


## Borra una sala de jugador. Las publicas no se borran desde el juego.
func borrar_sala(id : StringName, actor_id : StringName) -> Errores.Codigo:
	if not _id_valido(id) or not FileAccess.file_exists("%s/%s.json" % [DIR_SALAS, id]):
		return Errores.Codigo.SALA_NO_EXISTE
	if _es_publica(id):
		return Errores.Codigo.SIN_PERMISO
	var permiso := _puede_modificar(id, actor_id)
	if not Errores.ok(permiso):
		return permiso
	if DirAccess.remove_absolute("%s/%s.json" % [DIR_SALAS, id]) != OK:
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR
	return Errores.Codigo.OK


# --- Perfiles -------------------------------------------------------------------


## Devuelve un resumen de cada perfil, del usado mas recientemente al mas viejo.
## {id, nombre, ultima_vez}
func listar_perfiles() -> Array[Dictionary]:
	var salida : Array[Dictionary] = []
	for id in _ids_en(DIR_PERFILES):
		var doc := _leer_json("%s/%s.json" % [DIR_PERFILES, id])
		if doc.is_empty():
			continue
		salida.append({
			"id": String(id),
			"nombre": str(doc.get("nombre", "")),
			"ultima_vez": int(doc.get("timestamp_guardado", 0)),
		})
	salida.sort_custom(func(a : Dictionary, b : Dictionary) -> bool:
		return a.ultima_vez > b.ultima_vez)
	return salida


## Crea un perfil nuevo, con su casa. {"codigo", "id"}
##
## La casa la da el servidor y no el cliente: con red, es el servidor el que
## decide que recibe una cuenta nueva.
func crear_perfil(nombre : String) -> Dictionary:
	nombre = _limpiar_nombre(nombre)
	if not _nombre_de_jugador_valido(nombre):
		return {"codigo": Errores.Codigo.NOMBRE_INVALIDO, "id": &""}
	for existente in listar_perfiles():
		if existente.nombre.to_lower() == nombre.to_lower():
			return {"codigo": Errores.Codigo.NOMBRE_EN_USO, "id": &""}

	var id := _id_nuevo_con(&"p_", DIR_PERFILES)
	var casa := crear_sala("Casa de %s" % nombre, PLANTILLA_CASA, id)
	if not Errores.ok(casa.codigo):
		return {"codigo": casa.codigo, "id": &""}
	var entrada : Array = _leer_json("%s/%s.json" % [DIR_SALAS, casa.id]).get("entrada", [0, 0])

	var perfil := SaveGame.new()
	perfil.perfil_id = String(id)
	perfil.nombre = nombre
	perfil.creado = int(Time.get_unix_time_from_system())
	perfil.timestamp_guardado = perfil.creado
	perfil.sala_actual = String(casa.id)
	perfil.celda_jugador = Vector2i(int(entrada[0]), int(entrada[1]))
	var codigo := _escribir_en(DIR_PERFILES, id, perfil.to_dict())
	return {"codigo": codigo, "id": id if Errores.ok(codigo) else &""}


## El perfil completo. {"codigo", "doc"}
func obtener_perfil(id : StringName) -> Dictionary:
	if not _id_valido(id) or not FileAccess.file_exists("%s/%s.json" % [DIR_PERFILES, id]):
		return {"codigo": Errores.Codigo.PERFIL_NO_EXISTE, "doc": {}}
	var doc := _leer_json("%s/%s.json" % [DIR_PERFILES, id])
	if doc.is_empty():
		return {"codigo": Errores.Codigo.ARCHIVO_CORRUPTO, "doc": {}}
	doc["perfil_id"] = String(id)
	return {"codigo": Errores.Codigo.OK, "doc": doc}


## Guarda un perfil. Solo lo puede guardar su duenio, que con un solo jugador
## local es siempre el caso; la comprobacion esta para cuando no lo sea.
func guardar_perfil(doc : Dictionary, actor_id : StringName) -> Errores.Codigo:
	var id := StringName(str(doc.get("perfil_id", "")))
	if not _id_valido(id) or not FileAccess.file_exists("%s/%s.json" % [DIR_PERFILES, id]):
		return Errores.Codigo.PERFIL_NO_EXISTE
	if id != actor_id:
		return Errores.Codigo.NO_ES_TUYO
	return _escribir_en(DIR_PERFILES, id, doc)


## Borra un perfil y todas sus salas.
func borrar_perfil(id : StringName) -> Errores.Codigo:
	if not _id_valido(id) or not FileAccess.file_exists("%s/%s.json" % [DIR_PERFILES, id]):
		return Errores.Codigo.PERFIL_NO_EXISTE
	for sala in listar_salas_de(id):
		borrar_sala(StringName(sala.id), id)
	if DirAccess.remove_absolute("%s/%s.json" % [DIR_PERFILES, id]) != OK:
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR
	return Errores.Codigo.OK


## Un nombre de jugador: entre 3 y 20 caracteres, letras, numeros, espacios,
## guion y guion bajo. Mas estricto que el de una sala porque va en el chat de
## todos, y un nombre hecho de simbolos es una forma de molestar.
func _nombre_de_jugador_valido(nombre : String) -> bool:
	if nombre.length() < LARGO_MINIMO_JUGADOR or nombre.length() > LARGO_MAXIMO_JUGADOR:
		return false
	var letras := 0
	for c in nombre:
		var codigo := c.unicode_at(0)
		var es_letra := c.to_lower() != c.to_upper() or (codigo >= 48 and codigo <= 57)
		if es_letra:
			letras += 1
		elif not (c in " _-"):
			return false
	return letras >= LARGO_MINIMO_JUGADOR


# --- Reglas ---------------------------------------------------------------------


## Quien puede cambiar una sala: su duenio. Una publica, solo en desarrollo.
##
## Es la misma pregunta que RoomController.puede_editar(), hecha del lado que
## guarda. Con red las dos tienen que dar lo mismo, y la que manda es esta: el
## cliente puede mentir sobre lo que dejo editar, el servidor no.
func _puede_modificar(id : StringName, actor_id : StringName) -> Errores.Codigo:
	if _es_publica(id):
		return Errores.Codigo.OK if OS.is_debug_build() else Errores.Codigo.SIN_PERMISO
	var ruta := "%s/%s.json" % [DIR_SALAS, id]
	if not FileAccess.file_exists(ruta):
		# Todavia no existe: es la primera vez que se guarda, y la esta creando
		# quien la guarda.
		return Errores.Codigo.OK
	var dueno := StringName(str(_leer_json(ruta).get("propietario", "")))
	return Errores.Codigo.OK if dueno == actor_id else Errores.Codigo.NO_ES_TUYO


func _es_publica(id : StringName) -> bool:
	return FileAccess.file_exists("%s/%s.json" % [DIR_PUBLICAS, id])


func _id_valido(id : StringName) -> bool:
	var texto := String(id)
	if texto.is_empty() or texto.length() > 64:
		return false
	for c in texto:
		if not (c in CARACTERES_ID):
			return false
	return true


## Un nombre visible: sin espacios en las puntas, sin saltos de linea y con un
## largo razonable. Devuelve vacio si no queda nada.
func _limpiar_nombre(nombre : String) -> String:
	var limpio := nombre.strip_edges().replace("\n", " ").replace("\t", " ")
	while limpio.contains("  "):
		limpio = limpio.replace("  ", " ")
	return limpio.substr(0, LARGO_MAXIMO_NOMBRE).strip_edges()


func _id_nuevo() -> StringName:
	return _id_nuevo_con(&"s_", DIR_SALAS)


## Un id al azar con un prefijo que dice que es: "s_" sala, "p_" perfil.
func _id_nuevo_con(prefijo : StringName, dir_ruta : String) -> StringName:
	var cripto := Crypto.new()
	for intento in 8:
		var id := StringName(prefijo + cripto.generate_random_bytes(6).hex_encode())
		if not FileAccess.file_exists("%s/%s.json" % [dir_ruta, id]) and _ruta_de(id) == "":
			return id
	push_error("ServidorLocal: ocho ids al azar ya existian. Eso no deberia pasar nunca.")
	return StringName("%s%d" % [prefijo, Time.get_ticks_usec()])


# --- Disco ----------------------------------------------------------------------


## La ruta de donde se lee una sala, o vacio si no existe en ningun lado.
func _ruta_de(id : StringName) -> String:
	var propia := "%s/%s.json" % [DIR_SALAS, id]
	if FileAccess.file_exists(propia):
		return propia
	var publica := "%s/%s.json" % [DIR_PUBLICAS, id]
	if FileAccess.file_exists(publica):
		return publica
	return ""


func _leer_sala(id : StringName) -> Dictionary:
	var ruta := _ruta_de(id)
	if ruta == "":
		return {}
	var doc := _leer_json(ruta)
	if not doc.is_empty():
		doc["id"] = String(id)
	return doc


func _leer_json(ruta : String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}
	var crudo = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not (crudo is Dictionary):
		push_warning("ServidorLocal: %s no es un documento valido." % ruta)
		return {}
	return crudo


func _escribir(id : StringName, doc : Dictionary) -> Errores.Codigo:
	return _escribir_en(DIR_SALAS, id, doc)


func _escribir_en(dir_ruta : String, id : StringName, doc : Dictionary) -> Errores.Codigo:
	DirAccess.make_dir_recursive_absolute(dir_ruta)
	var ruta := "%s/%s.json" % [dir_ruta, id]
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("ServidorLocal: no se pudo escribir %s (%d)." % [ruta, FileAccess.get_open_error()])
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR
	archivo.store_string(JSON.stringify(doc, "\t"))
	archivo.close()
	# Comprobar que el archivo aparecio en vez de confiar en que no hubo error: la
	# leccion del importador, que reporto 52 guardados y escribio uno.
	if not FileAccess.file_exists(ruta):
		push_error("ServidorLocal: se escribio %s sin error pero el archivo no existe." % ruta)
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR
	return Errores.Codigo.OK


## Los ids de los .json de una carpeta: el nombre de archivo sin extension.
func _ids_en(dir_ruta : String) -> Array[StringName]:
	var salida : Array[StringName] = []
	var dir := DirAccess.open(dir_ruta)
	if dir == null:
		return salida
	for archivo in dir.get_files():
		if archivo.ends_with(".json"):
			var id := StringName(archivo.trim_suffix(".json"))
			if _id_valido(id):
				salida.append(id)
	return salida


## Lo que el navegador necesita de una sala, sin cargar su estructura entera.
func _resumen(doc : Dictionary) -> Dictionary:
	return {
		"id": str(doc.get("id", "")),
		"nombre": str(doc.get("nombre", "")),
		"descripcion": str(doc.get("descripcion", "")),
		"tipo": str(doc.get("tipo", "")),
		"propietario": str(doc.get("propietario", "")),
		"objetos": (doc.get("objetos", []) as Array).size(),
	}


func _por_nombre(a : Dictionary, b : Dictionary) -> bool:
	return a.nombre.naturalnocasecmp_to(b.nombre) < 0
