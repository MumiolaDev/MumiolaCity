extends Node

## Arma y aplica el perfil de quien esta jugando. Va ultimo en el orden de
## autoloads (D9), porque restaura sobre todos los demas.
##
## Orquesta, no serializa ni escribe: le pide su estado a cada manager, lo mete
## en un SaveGame y se lo da a Servidor para que lo guarde. Las salas no pasan
## por aca: cada una se guarda sola, porque son documentos de quien las tenga y
## no parte de tu perfil.
##
## Hasta la fase 3 escribia user://partida.json el mismo. Ahora el disco es del
## servidor, y esto es lo que un cliente manda: el dia de la red, lo que cambia
## es quien recibe el diccionario, no como se arma.
##
## JSON y no .tres, desde siempre: un .tres cargado desde afuera puede contener
## rutas de script, y un perfil algun dia va a llegar de un servidor. El costo es
## ser deliberado sobre que se escribe —lo que no pasa por to_dict() no se
## guarda—, y es un costo que conviene.
##
## Sin sesion (el mundo corrido directo, los tests) no guarda nada: el perfil de
## desarrollo no existe en disco, y los tests no tienen por que dejar rastros.

signal guardado_completado()
signal carga_completada()

const VERSION_ACTUAL := 3


func _ready() -> void:
	# Cambiar de sala es un buen momento para guardar: es cuando el jugador da
	# algo por terminado, y es barato.
	GameManager.sala_cambiada.connect(func(_s : RoomController) -> void:
		if GameManager.hay_sesion():
			guardar())


## Guarda el perfil de quien esta jugando. Devuelve OK, o por que no se pudo.
func guardar() -> Errores.Codigo:
	if not GameManager.hay_sesion():
		return Errores.Codigo.PERFIL_NO_EXISTE

	var partida := SaveGame.new()
	partida.from_dict(GameManager.perfil())
	partida.version_formato = VERSION_ACTUAL
	partida.timestamp_guardado = int(Time.get_unix_time_from_system())

	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	if sala != null:
		partida.sala_actual = String(sala.id_sala)
		if jugador != null:
			partida.celda_jugador = sala.grid.mundo_a_celda(jugador.global_position)

	partida.inventario = InventoryManager.to_dict()
	partida.habilidades = SkillManager.to_dict()

	var doc := partida.to_dict()
	var codigo : Errores.Codigo = await Servidor.guardar_perfil(doc, GameManager.perfil_id())
	if Errores.ok(codigo):
		# La sesion se queda con lo recien guardado: si no, volver al menu y
		# entrar de nuevo sin leer el disco devolveria el perfil de antes.
		GameManager.iniciar_sesion(doc)
		guardado_completado.emit()
	return codigo


## Guarda todo lo que hay que guardar antes de irse: el perfil y la sala.
func guardar_todo() -> Errores.Codigo:
	await GameManager.guardar_si_cambio()
	if not GameManager.hay_sesion():
		return Errores.Codigo.OK
	return await guardar()


## Pone al jugador en el mundo: con su perfil si hay sesion, o en la plaza si no.
##
## Es lo primero que hace el mundo al cargarse. Aplica lo que el jugador lleva
## antes de entrar a la sala, para que no aparezca en su casa con la mochila
## vacia ni un cuadro.
func entrar_al_mundo() -> Errores.Codigo:
	if not GameManager.hay_sesion():
		return await GameManager.ir_a(GameManager.SALA_INICIAL)

	var partida := SaveGame.new()
	partida.from_dict(_migrar(GameManager.perfil()))
	InventoryManager.from_dict(partida.inventario)
	SkillManager.from_dict(partida.habilidades)

	var codigo : Errores.Codigo = Errores.Codigo.SALA_NO_EXISTE
	if partida.sala_actual != "":
		codigo = await GameManager.ir_a(StringName(partida.sala_actual), partida.celda_jugador)
	if not Errores.ok(codigo):
		# La sala donde estabas ya no esta —la borraste, o era de otro que la
		# borro—. Se entra a la plaza en vez de a ningun lado.
		codigo = await GameManager.ir_a(GameManager.SALA_INICIAL)

	carga_completada.emit()
	return codigo


## Lleva un perfil viejo al esquema actual.
##
## El punto de entrada existe desde el primer dia: cuando cambie el esquema, el
## lugar donde va el arreglo ya esta decidido y no hay que inventarlo con
## guardados rotos sobre la mesa.
func _migrar(datos : Dictionary) -> Dictionary:
	var version := int(datos.get("version_formato", 1))
	if version < 2:
		# La 1 identificaba la sala por la ruta de su escena, que ya no existe.
		datos["sala_actual"] = ""
		datos.erase("salas")
	if version > VERSION_ACTUAL:
		push_warning(
			"SaveManager: el perfil es de la version %d y esta build entiende hasta la %d. "
			% [version, VERSION_ACTUAL] + "Se intenta cargar igual."
		)
	return datos


## Cerrar la ventana guarda antes de irse.
func _notification(que : int) -> void:
	if que == NOTIFICATION_WM_CLOSE_REQUEST and GameManager.hay_sesion():
		guardar()
