extends Node

## Guarda y carga la partida. Va ultimo en el orden de autoloads (D9), porque
## restaura sobre todos los demas.
##
## Orquesta, no serializa: le pide su estado a cada sala y lo mete en el
## SaveGame. Agregar un campo a una sala no deberia obligar a tocar este archivo.
##
## Escribe JSON y no un .tres, aunque ResourceSaver seria mas corto. Un .tres
## cargado desde afuera puede contener rutas de script, y este juego apunta a ser
## en linea: algun dia el guardado va a llegar de un servidor o de otro jugador.
## JSON es inspeccionable, portable y no ejecuta nada.
##
## El costo de esa eleccion conviene tenerlo presente: con ResourceSaver, que
## estado_runtime quedara fuera del guardado era automatico —no lleva @export, asi
## que el serializador no lo veia—. Con JSON esa red desaparece y hay que ser
## deliberado sobre que se escribe.

signal guardado_completado()
signal carga_completada()

const RUTA := "user://partida.json"
const VERSION_ACTUAL := 1

## Donde viven las salas sueltas, una por archivo.
##
## Son otra cosa que la partida: la partida es *tu* estado —inventario,
## habilidades, donde estas—, y una sala guardada es un documento portable que
## no tiene dueno. Sirve para armar mapas y versionarlos, para compartir una
## sala, y es lo que un servidor almacenaria (D24).
const DIR_SALAS := "user://salas"

## Que puede tener el nombre de un archivo de sala. Todo lo demas se descarta.
const PERMITIDOS := "abcdefghijklmnopqrstuvwxyz0123456789-_"

## Las letras con tilde se pasan a su version pelada antes del filtro, para que
## "Mi Habitacion" y "Mi Habitación" no terminen en dos archivos distintos.
const SIN_TILDE := {
	"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n",
}


## Devuelve si hay una partida guardada.
func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA)


## Borra la partida guardada.
func borrar() -> void:
	if existe_partida():
		DirAccess.remove_absolute(RUTA)


## Guarda una sala como archivo suelto, con el nombre que se le pase o el suyo.
##
## Devuelve un codigo y no un Error del motor porque esto se le muestra al
## jugador: "no se pudo guardar" y "ese nombre no sirve" son cosas distintas que
## tiene que poder leer.
func guardar_sala(sala : RoomController, nombre : String = "") -> Errores.Codigo:
	if sala == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var archivo_nombre := _nombre_archivo(nombre if nombre != "" else sala.nombre_sala)
	if archivo_nombre == "":
		return Errores.Codigo.NOMBRE_INVALIDO

	DirAccess.make_dir_recursive_absolute(DIR_SALAS)
	var ruta := "%s/%s.json" % [DIR_SALAS, archivo_nombre]

	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_error("SaveManager: no se pudo escribir %s (%d)."
			% [ruta, FileAccess.get_open_error()])
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR

	archivo.store_string(JSON.stringify(sala.to_dict(), "\t"))
	archivo.close()

	# Comprobar que el archivo aparecio en vez de confiar en que no hubo error.
	# Es la misma leccion que dejo el importador, que reporto 52 guardados y
	# escribio uno.
	if not FileAccess.file_exists(ruta):
		push_error("SaveManager: se escribio %s sin error pero el archivo no existe." % ruta)
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR

	guardado_completado.emit()
	return Errores.Codigo.OK


## Carga una sala guardada sobre una sala viva, reemplazando lo que tuviera.
func cargar_sala(sala : RoomController, nombre : String) -> Errores.Codigo:
	if sala == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var archivo_nombre := _nombre_archivo(nombre)
	if archivo_nombre == "":
		return Errores.Codigo.NOMBRE_INVALIDO

	var ruta := "%s/%s.json" % [DIR_SALAS, archivo_nombre]
	if not FileAccess.file_exists(ruta):
		return Errores.Codigo.ARCHIVO_NO_EXISTE

	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return Errores.Codigo.ARCHIVO_NO_EXISTE

	var crudo = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not (crudo is Dictionary):
		push_error("SaveManager: %s no es un documento de sala valido." % ruta)
		return Errores.Codigo.ARCHIVO_CORRUPTO

	var codigo := sala.from_dict(crudo)
	if Errores.ok(codigo):
		carga_completada.emit()
	return codigo


## Devuelve los nombres de archivo de las salas guardadas, ordenados.
func salas_guardadas() -> Array[String]:
	var salida : Array[String] = []
	var dir := DirAccess.open(DIR_SALAS)
	if dir == null:
		return salida
	for archivo in dir.get_files():
		if archivo.ends_with(".json"):
			salida.append(archivo.trim_suffix(".json"))
	salida.sort()
	return salida


## Devuelve si existe una sala guardada con ese nombre.
func existe_sala(nombre : String) -> bool:
	var archivo_nombre := _nombre_archivo(nombre)
	return archivo_nombre != "" and FileAccess.file_exists("%s/%s.json" % [DIR_SALAS, archivo_nombre])


## Convierte un nombre visible en un nombre de archivo seguro.
##
## "Mi Sala Linda" -> "mi_sala_linda". Devuelve vacio si no queda nada utilizable.
##
## No es cosmetica: un nombre de sala lo escribe una persona y algun dia va a
## llegar de la red. Sin filtrar, un nombre con "../" escribiria fuera de la
## carpeta de salas, que es la clase de agujero que conviene no abrir nunca —
## menos todavia en un juego que apunta a compartir salas entre jugadores.
func _nombre_archivo(nombre : String) -> String:
	var limpio := ""
	for caracter in nombre.strip_edges().to_lower():
		var c : String = SIN_TILDE.get(caracter, caracter)
		if c in PERMITIDOS:
			limpio += c
		elif c == " ":
			limpio += "_"
	return limpio.substr(0, 64)


## Guarda el estado actual. Devuelve OK, o el error de escritura.
func guardar() -> Error:
	var partida := SaveGame.new()
	partida.version_formato = VERSION_ACTUAL
	partida.timestamp_guardado = int(Time.get_unix_time_from_system())

	var sala := GameManager.sala_actual()
	if sala != null:
		partida.sala_actual = sala.scene_file_path

	var jugador := GameManager.jugador_actual()
	if jugador != null and sala != null:
		partida.celda_jugador = sala.grid.mundo_a_celda(jugador.global_position)

	partida.inventario = InventoryManager.to_dict()
	partida.habilidades = SkillManager.to_dict()

	# Se guardan todas las salas y no solo la actual: los muebles de tu casa
	# siguen ahi mientras estas en la plaza.
	for otra in GameManager.salas():
		partida.salas[otra.scene_file_path] = otra.to_dict()

	var archivo := FileAccess.open(RUTA, FileAccess.WRITE)
	if archivo == null:
		push_error("SaveManager: no se pudo escribir %s (%d)." % [RUTA, FileAccess.get_open_error()])
		return FileAccess.get_open_error()

	archivo.store_string(JSON.stringify(partida.to_dict(), "\t"))
	archivo.close()
	guardado_completado.emit()
	return OK


## Carga la partida guardada y la aplica. Devuelve OK, o el error.
func cargar() -> Error:
	if not existe_partida():
		return ERR_FILE_NOT_FOUND

	var archivo := FileAccess.open(RUTA, FileAccess.READ)
	if archivo == null:
		return FileAccess.get_open_error()

	var crudo = JSON.parse_string(archivo.get_as_text())
	archivo.close()
	if not (crudo is Dictionary):
		push_error("SaveManager: %s no contiene un guardado valido." % RUTA)
		return ERR_PARSE_ERROR

	var partida := SaveGame.new()
	partida.from_dict(_migrar(crudo))
	_aplicar(partida)
	carga_completada.emit()
	return OK


## Lleva un guardado viejo al esquema actual.
##
## Hoy no hay nada que migrar porque solo existe la version 1, pero el punto de
## entrada existe desde el primer dia: cuando cambie el esquema, el lugar donde
## va el arreglo ya esta decidido y no hay que inventarlo con guardados rotos
## sobre la mesa.
func _migrar(datos : Dictionary) -> Dictionary:
	var version := int(datos.get("version_formato", 1))
	if version > VERSION_ACTUAL:
		push_warning(
			"SaveManager: el guardado es de la version %d y esta build entiende hasta la %d. "
			% [version, VERSION_ACTUAL] + "Se intenta cargar igual."
		)
	return datos


## Vuelca el estado leido sobre el mundo vivo.
func _aplicar(partida : SaveGame) -> void:
	# El inventario primero: si una sala guardada trae un mueble cuyo item ya no
	# existe, conviene que el jugador tenga su mochila intacta igual.
	InventoryManager.from_dict(partida.inventario)
	SkillManager.from_dict(partida.habilidades)

	for sala in GameManager.salas():
		if not partida.salas.has(sala.scene_file_path):
			continue
		var codigo := sala.from_dict(partida.salas[sala.scene_file_path])
		if not Errores.ok(codigo):
			push_warning("SaveManager: no se pudo restaurar la sala '%s': %s"
				% [sala.name, Errores.mensaje(codigo)])

	# La sala se cambia despues de repoblarla, para que el jugador no aparezca en
	# una habitacion a medio armar.
	for sala in GameManager.salas():
		if sala.scene_file_path == partida.sala_actual:
			GameManager.ir_a_sala(sala)
			break

	var jugador := GameManager.jugador_actual()
	var actual := GameManager.sala_actual()
	if jugador != null and actual != null:
		jugador.ubicar_en_celda(partida.celda_jugador)
