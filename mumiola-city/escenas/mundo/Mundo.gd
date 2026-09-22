extends Node3D

## La escena del mundo: le dice a GameManager donde viven las salas, cablea la
## interfaz y ofrece los atajos de prueba.
##
## Ya no decide nada sobre salas ni jugador: eso vive en GameManager, que
## sobrevive a los cambios de escena y no depende de la forma del arbol. Lo que
## queda aca es lo desechable —los atajos— y el cableado de la UI, que es propio
## de esta escena.
##
## Interactuar con un mueble es clic derecho sobre el: abre el menu contextual.
## El clic izquierdo sigue siendo caminar.
##
## Teclas de prueba, todas provisionales.
##
## Mundo:   B alterna entre jugar y editar, TAB cambia de sala, Q y E giran el
##          encuadre, G guarda, L carga.
## Economia: I lista el inventario, K muestra el nivel de Cocina, 1 corta un
##          tomate y 2 cocina carne.
##
## Las de economia existen porque todavia no hay forma de craftear desde el
## mundo: el verbo que abre el crafteo es uno de los seis que el importador
## reporta sin comportamiento. Son andamio para poder juzgar como se siente la
## progresion antes de construirle el mundo encima.
##
## Colocar, retirar, girar y elegir ya no estan aca: se los llevo EditorSala, que
## es donde tienen sentido. En modo juego no se coloca nada y no hay vista previa
## siguiendo al puntero — un fantasma sobre muebles que no se pueden mover solo
## distrae. Q y E si se quedan: girar el encuadre es de mirar, no de editar.

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
	GameManager.mostrar_ayuda("TAB cambiar de sala   Q/E girar la vista   B jugar/editar   G guardar   L cargar\nI inventario   K habilidad   1 cortar tomate   2 cocinar carne\nClic izquierdo: caminar   Clic derecho sobre un mueble: menu")

	for sala in GameManager.salas():
		sala.objeto_colocado.connect(_atender_clics_de)
		for obj in sala.objetos():
			_atender_clics_de(obj)

	RecipeManager.crafteo_terminado.connect(_al_terminar_crafteo)
	_dar_equipo_de_prueba()

	if not GameManager.ir_a_indice(0):
		push_error("Mundo: no hay ninguna RoomController colgando de Salas.")


func _unhandled_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return

	if evento.keycode == KEY_TAB:
		GameManager.siguiente_sala()
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
		GameManager.avisar("Partida guardada." if SaveManager.guardar() == OK
			else "No se pudo guardar.")
	elif evento.keycode == KEY_I:
		_mostrar_inventario()
	elif evento.keycode == KEY_K:
		_mostrar_habilidad(Habilidades.COCINA)
	elif evento.keycode == KEY_1:
		_craftear_de_prueba(&"tomate_rodajas", &"")
	elif evento.keycode == KEY_2:
		_craftear_de_prueba(&"carne_cocida", &"estufa")
	elif evento.keycode == KEY_L:
		GameManager.avisar("Partida cargada." if SaveManager.cargar() == OK
			else "No hay partida guardada.")


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


## Le pone al jugador lo minimo para probar la cocina.
##
## Provisional: desaparece en cuanto exista una forma de conseguir estas cosas
## dentro del juego, que es comprarselas al NPC en la fase 2b.
func _dar_equipo_de_prueba() -> void:
	InventoryManager.agregar(&"cuchillo", 1)
	InventoryManager.agregar(&"tabla_cortar", 1)
	InventoryManager.agregar(&"sarten", 1)
	InventoryManager.agregar(&"tomate", 10)
	InventoryManager.agregar(&"carne_cruda", 5)


## Escribe el inventario en el HUD, en una linea.
func _mostrar_inventario() -> void:
	var partes : Array[String] = []
	for slot in InventoryManager.slots():
		partes.append(slot.nombre_mostrado())

	if partes.is_empty():
		GameManager.avisar("La mochila esta vacia.")
		return
	GameManager.avisar("%s   (%.1f de %.0f kg)"
		% ["  ·  ".join(partes), InventoryManager.peso_total(), InventoryManager.PESO_MAXIMO])


## Escribe el nivel y el progreso de una habilidad.
func _mostrar_habilidad(id : StringName) -> void:
	var def := SkillManager.definicion(id)
	if def == null:
		GameManager.avisar("No hay definicion para %s." % id)
		return

	var avance := SkillManager.progreso_de(id)
	var cola := "al maximo" if avance.y <= 0 else "%d / %d para el siguiente" % [avance.x, avance.y]
	GameManager.avisar("%s: nivel %d   (%d xp, %s)"
		% [def.nombre_display, SkillManager.nivel_de(id), SkillManager.xp_de(id), cola])


## Intenta un crafteo y avisa si no se pudo.
##
## La estacion se pasa a mano porque todavia no hay estaciones en el mundo: es
## como decirle al juego "hace de cuenta que estoy frente a la estufa".
func _craftear_de_prueba(id : StringName, estacion : StringName) -> void:
	var def := ItemDatabase.obtener(id)
	if def == null:
		GameManager.avisar("No existe '%s' en el catalogo." % id)
		return

	var codigo := RecipeManager.craftear(def, estacion)
	if Errores.ok(codigo):
		GameManager.avisar("Preparando %s..." % def.nombre)
	else:
		GameManager.avisar_error(codigo)


## Avisa que salio de la olla, y si fue lo que se buscaba.
func _al_terminar_crafteo(resultado_id : StringName, cantidad : int, fallo : bool) -> void:
	var def := ItemDatabase.obtener(resultado_id)
	var nombre := String(resultado_id) if def == null else def.nombre
	if fallo:
		GameManager.avisar("Se te arruino: %s" % nombre)
	else:
		GameManager.avisar("Listo: %s x%d" % [nombre, cantidad])
