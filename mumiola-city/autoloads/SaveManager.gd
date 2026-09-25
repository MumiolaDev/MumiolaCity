extends Node

## Guarda y carga la partida. Va ultimo en el orden de autoloads (D9), porque
## restaura sobre todos los demas.
##
## Orquesta, no serializa: le pide su estado a cada manager y lo mete en el
## SaveGame. Las salas no pasan por aca: cada una se guarda sola por Servidor,
## porque son documentos de quien las tenga y no parte de tu partida.
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
const VERSION_ACTUAL := 2

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
		partida.sala_actual = String(sala.id_sala)

	var jugador := GameManager.jugador_actual()
	if jugador != null and sala != null:
		partida.celda_jugador = sala.grid.mundo_a_celda(jugador.global_position)

	partida.inventario = InventoryManager.to_dict()
	partida.habilidades = SkillManager.to_dict()

	# La sala donde estas se guarda aparte, como documento. Las demas ya se
	# guardaron al dejarlas.
	await GameManager.guardar_si_cambio()

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
	await _aplicar(partida)
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
	if version < 2:
		# La 1 identificaba la sala por la ruta de su escena, que ya no existe, y
		# guardaba las salas adentro de la partida. Lo segundo se pierde: eran
		# las dos salas fijas, que ahora son documentos propios.
		datos["sala_actual"] = ""
		datos.erase("salas")
	if version > VERSION_ACTUAL:
		push_warning(
			"SaveManager: el guardado es de la version %d y esta build entiende hasta la %d. "
			% [version, VERSION_ACTUAL] + "Se intenta cargar igual."
		)
	return datos


## Vuelca el estado leido sobre el mundo vivo.
func _aplicar(partida : SaveGame) -> void:
	InventoryManager.from_dict(partida.inventario)
	SkillManager.from_dict(partida.habilidades)

	var destino := StringName(partida.sala_actual) if partida.sala_actual != "" else GameManager.SALA_INICIAL
	var codigo : Errores.Codigo = await GameManager.ir_a(destino)
	if codigo == Errores.Codigo.SALA_NO_EXISTE and destino != GameManager.SALA_INICIAL:
		# La sala donde estabas ya no esta —la borraste, o era de otro—.
		codigo = await GameManager.ir_a(GameManager.SALA_INICIAL)
	if not Errores.ok(codigo) and codigo != Errores.Codigo.ES_LA_SALA_ACTUAL:
		push_warning("SaveManager: no se pudo volver a la sala guardada: %s" % Errores.mensaje(codigo))

	var jugador := GameManager.jugador_actual()
	var actual := GameManager.sala_actual()
	if jugador != null and actual != null and actual.id_sala == destino:
		jugador.ubicar_en_celda(partida.celda_jugador)
