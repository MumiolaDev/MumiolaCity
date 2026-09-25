extends Node3D

## La escena del mundo: le dice a GameManager donde viven las salas, cablea la
## interfaz y registra los comandos que necesitan un mundo.
##
## Ya no decide nada sobre salas ni jugador: eso vive en GameManager, que
## sobrevive a los cambios de escena y no depende de la forma del arbol. Lo que
## queda aca es lo desechable —los atajos— y el cableado de la UI, que es propio
## de esta escena.
##
## Interactuar con un mueble es clic derecho sobre el: abre el menu contextual.
## El clic izquierdo sigue siendo caminar.
##
## Teclas: B alterna entre jugar y editar, Q y E giran el encuadre, G guarda la
## partida, L la carga. La lista completa, para el
## jugador, esta en la ventana de ayuda (F1).
##
## La camara no esta aca: la rueda, el boton del medio y la tecla Inicio los
## atiende RoomController, porque sirven igual jugando que editando y porque la
## unica sala que recibe input es la activa.
##
## Colocar, retirar, girar y elegir tampoco: se los llevo EditorSala, que es
## donde tienen sentido. Q y E si se quedan: girar el encuadre es de mirar, no
## de editar.
##
## Los atajos de economia (I, K, 1, 2) y el equipo de prueba se fueron con la
## economia. Lo que seguia sirviendo de ellos quedo como comando de la consola:
## /inv lista la mochila y /dar pone algo en ella.

@onready var contenedor_salas : Node3D = $Salas
@onready var menu : ContextMenuUI = $UI/ContextMenuUI


func _ready() -> void:
	GameManager.registrar_contenedor(contenedor_salas)

	# En 3D viene apagado por defecto, y sin esto los Area3D nunca reciben clics.
	# No da error de ningun tipo cuando falta: los muebles simplemente no
	# responden.
	get_viewport().physics_object_picking = true

	# La interfaz es opcional por contrato: borrar el menu del arbol quita la
	# funcion, no rompe el juego.
	if menu != null:
		menu.verbo_elegido.connect(_al_elegir_verbo)
	_registrar_comandos()
	GameManager.sala_cambiada.connect(_al_cambiar_sala)

	# La pantalla arranca cubierta y la primera sala entra en este mismo cuadro:
	# con el servidor local, ir_a() no espera nada hasta el fundido de salida.
	Transicion.cubrir_ya()
	var codigo : Errores.Codigo = await GameManager.ir_a(GameManager.SALA_INICIAL)
	if not Errores.ok(codigo):
		push_error("Mundo: no se pudo entrar a %s: %s" % [GameManager.SALA_INICIAL, Errores.mensaje(codigo)])


## Engancha los clics de los muebles de una sala recien cargada.
func _al_cambiar_sala(sala : RoomController) -> void:
	if not sala.objeto_colocado.is_connected(_atender_clics_de):
		sala.objeto_colocado.connect(_atender_clics_de)
	for obj in sala.objetos():
		_atender_clics_de(obj)


func _unhandled_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return

	if evento.keycode == KEY_B:
		GameManager.alternar_modo()
		GameManager.avisar("Modo: %s"
			% ("editando" if GameManager.editando() else "jugando"))
		return

	var sala := GameManager.sala_actual()
	if sala == null:
		return
	if evento.keycode == KEY_Q:
		sala.rotar(-1)
	elif evento.keycode == KEY_E:
		sala.rotar(1)
	elif evento.keycode == KEY_G:
		_cmd_guardar([])
	elif evento.keycode == KEY_L:
		var error : Error = await SaveManager.cargar()
		GameManager.avisar("Partida cargada." if error == OK else "No hay partida guardada.")


## Engancha el clic derecho de un mueble al menu contextual.
##
## Se llama al colocar cada objeto, y no una vez al arrancar, porque los muebles
## aparecen y desaparecen durante la partida.
func _atender_clics_de(obj : WorldObject) -> void:
	if obj != null and not obj.clickeado.is_connected(_abrir_menu):
		obj.clickeado.connect(_abrir_menu)


## Abre el menu contextual de un mueble para el personaje.
func _abrir_menu(obj : WorldObject) -> void:
	if menu == null:
		return
	if not menu.mostrar_para(obj, GameManager.jugador_actual()):
		GameManager.avisar("%s: nada que hacer ahora." % obj.nombre_mostrado())


## Ejecuta el verbo elegido en el menu.
##
## Pasa por interactuar_con() y no por ejecutar(): si el verbo pide adyacencia,
## el personaje camina hasta el mueble y actua recien al llegar. El menu no sabe
## nada de distancias ni de rutas.
func _al_elegir_verbo(verbo : InteractionBehavior, obj : WorldObject, actor : Node) -> void:
	if actor != null and actor.has_method(&"interactuar_con"):
		actor.interactuar_con(obj, verbo)


## Anota los comandos que son del mundo: los que necesitan una sala o un
## jugador para tener sentido.
func _registrar_comandos() -> void:
	Comandos.registrar(&"inv", _cmd_inventario, "Lista lo que llevas en la mochila.")
	Comandos.registrar(&"dar", _cmd_dar, "Pone un objeto del catalogo en tu mochila.",
		"<item> [cantidad]", true)
	Comandos.registrar(&"editar", _cmd_editar, "Pasa de jugar a editar la sala, y vuelve.")
	Comandos.registrar(&"guardar", _cmd_guardar, "Guarda la partida.")
	Comandos.registrar(&"ir", _cmd_ir, "Va a una sala, por su nombre o su id.", "<sala>")
	Comandos.registrar(&"salas", _cmd_salas, "Lista las salas publicas y las tuyas.")


func _cmd_inventario(_args : PackedStringArray) -> Errores.Codigo:
	var partes : Array[String] = []
	for slot in InventoryManager.slots():
		partes.append(slot.nombre_mostrado())

	if partes.is_empty():
		GameManager.avisar("La mochila esta vacia.")
	else:
		GameManager.avisar("%s   (%.1f de %.0f kg)"
			% ["  ·  ".join(partes), InventoryManager.peso_total(), InventoryManager.PESO_MAXIMO])
	return Errores.Codigo.OK


func _cmd_dar(args : PackedStringArray) -> Errores.Codigo:
	if args.is_empty():
		return Errores.Codigo.USO_INCORRECTO
	var def := ItemDatabase.obtener(StringName(args[0]))
	if def == null:
		return Errores.Codigo.ITEM_DESCONOCIDO
	var cantidad := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1
	if cantidad < 1:
		return Errores.Codigo.USO_INCORRECTO

	var codigo := InventoryManager.agregar(def.id, cantidad)
	if Errores.ok(codigo):
		GameManager.avisar("Recibiste %s x%d." % [def.nombre, cantidad])
	return codigo


func _cmd_editar(_args : PackedStringArray) -> Errores.Codigo:
	GameManager.alternar_modo()
	GameManager.avisar("Modo: %s" % ("editando" if GameManager.editando() else "jugando"))
	return Errores.Codigo.OK


func _cmd_guardar(_args : PackedStringArray) -> Errores.Codigo:
	if (await SaveManager.guardar()) != OK:
		return Errores.Codigo.NO_SE_PUDO_ESCRIBIR
	GameManager.avisar("Partida guardada.")
	return Errores.Codigo.OK


func _cmd_ir(args : PackedStringArray) -> Errores.Codigo:
	if args.is_empty():
		return Errores.Codigo.USO_INCORRECTO
	var buscado := " ".join(args).to_lower()
	var salas : Array[Dictionary] = await Servidor.listar_salas_publicas()
	salas.append_array(await Servidor.listar_salas_de(GameManager.perfil_id()))
	for s in salas:
		if s.id == buscado or s.nombre.to_lower() == buscado:
			return await GameManager.ir_a(StringName(s.id))
	return Errores.Codigo.SALA_NO_EXISTE


func _cmd_salas(_args : PackedStringArray) -> Errores.Codigo:
	var lineas : Array[String] = ["Salas publicas:"]
	for s in await Servidor.listar_salas_publicas():
		lineas.append("  %s  (%s)" % [s.nombre, s.id])
	lineas.append("Tus salas:")
	var propias : Array[Dictionary] = await Servidor.listar_salas_de(GameManager.perfil_id())
	if propias.is_empty():
		lineas.append("  ninguna todavia")
	for s in propias:
		lineas.append("  %s  (%s)" % [s.nombre, s.id])
	GameManager.avisar("\n".join(lineas))
	return Errores.Codigo.OK
