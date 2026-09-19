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


## Devuelve si hay una partida guardada.
func existe_partida() -> bool:
	return FileAccess.file_exists(RUTA)


## Borra la partida guardada.
func borrar() -> void:
	if existe_partida():
		DirAccess.remove_absolute(RUTA)


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
		if partida.salas.has(sala.scene_file_path):
			sala.from_dict(partida.salas[sala.scene_file_path])

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
