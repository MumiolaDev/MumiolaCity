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
##          encuadre, V elige que item
##          colocar —con shift va para atras—, R lo gira, C lo coloca bajo el
##          mouse, X retira, G guarda, L carga.
## Economia: I lista el inventario, K muestra el nivel de Cocina, 1 corta un
##          tomate y 2 cocina carne.
##
## Las de economia existen porque todavia no hay forma de craftear desde el
## mundo: el verbo que abre el crafteo es uno de los seis que el importador
## reporta sin comportamiento. Son andamio para poder juzgar como se siente la
## progresion antes de construirle el mundo encima.
##
## Girar el encuadre y girar el objeto son dos cosas distintas y por eso son dos
## teclas distintas: la camara orbita y los objetos se quedan donde estan, asi
## que una silla ya colocada se ve desde otro lado sin haber cambiado de
## orientacion. Como decide el jugador hacia donde mira un mueble es D19.
##
## C y X existen para poder probar el paso 4b sin menu contextual: el clic
## izquierdo ya lo usa el personaje para caminar, y ContextMenuUI es el paso 7.
##
## V es el andamio de la paleta que todavia no existe: recorre el catalogo
## entero de colocables y le dice a la vista previa cual mostrar. Desaparece con
## RoomBuilderUI.

@onready var contenedor_salas : Node3D = $Salas
@onready var menu : ContextMenuUI = $UI/ContextMenuUI

## Con que rotacion se coloca el proximo item. Gira con R, no con el encuadre,
## para poder comprobar que la rotacion de la huella y la visual concuerdan sin
## confundirla con el giro de la camara.
var _rotacion_colocacion : int = 0

## Todos los items colocables, en el orden en que los recorre V.
var _catalogo : Array[ItemDefinition] = []
## Cual de ellos esta elegido.
var _elegido : int = 0


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
	GameManager.mostrar_ayuda("TAB cambiar de sala   Q/E girar la vista   B jugar/editar   V elegir item   R girarlo   C colocar   X retirar   G guardar   L cargar\nI inventario   K habilidad   1 cortar tomate   2 cocinar carne\nClic izquierdo: caminar   Clic derecho sobre un mueble: menu")

	for sala in GameManager.salas():
		sala.objeto_colocado.connect(_atender_clics_de)
		for obj in sala.objetos():
			_atender_clics_de(obj)

	RecipeManager.crafteo_terminado.connect(_al_terminar_crafteo)
	_dar_equipo_de_prueba()

	# Antes de ir_a_indice(), para que la primera sala ya entre con la vista
	# previa cargada en vez de quedarse vacia hasta el primer TAB.
	_catalogo = ItemDatabase.colocables()
	GameManager.sala_cambiada.connect(_al_cambiar_de_sala)

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
	elif evento.keycode == KEY_V:
		_elegir_otro(sala, -1 if evento.shift_pressed else 1)
	elif evento.keycode == KEY_R:
		_rotacion_colocacion = posmod(_rotacion_colocacion + 1, 4)
		_refrescar_vista_previa(sala)
		GameManager.avisar("Rotacion de colocacion: %d" % _rotacion_colocacion)
	elif evento.keycode == KEY_C:
		_colocar_elegido(sala)
	elif evento.keycode == KEY_X:
		_retirar_bajo_el_mouse(sala)
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


## Coloca el item elegido en la celda bajo el mouse y reporta el resultado.
##
## Provisional, para poder probar colocar_objeto() sin menu contextual. La
## instancia se crea aca porque el editor va a colocar desde catalogo infinito y
## no desde la mochila (D22).
##
## Coloca exactamente lo que muestra la vista previa: si fuera otra cosa, el
## fantasma dejaria de servir para lo unico que sirve.
func _colocar_elegido(sala : RoomController) -> void:
	var def := _item_elegido()
	if def == null:
		GameManager.avisar("No hay ningun item elegido.")
		return

	var celda := sala.grid.celda_bajo_puntero(sala.camara, get_viewport().get_mouse_position())
	if celda == IsoGrid.SIN_CELDA:
		return

	var inst := ItemInstance.new()
	inst.definicion_id = def.id

	var resultado := sala.colocar_objeto(inst, celda, _rotacion_colocacion)
	if Errores.ok(resultado):
		GameManager.avisar("Colocaste: %s" % sala.grid.objeto_en(celda).nombre_mostrado())
	else:
		GameManager.avisar_error(resultado)


## Retira el objeto que haya en la celda bajo el mouse.
func _retirar_bajo_el_mouse(sala : RoomController) -> void:
	var celda := sala.grid.celda_bajo_puntero(sala.camara, get_viewport().get_mouse_position())
	if celda == IsoGrid.SIN_CELDA:
		return

	var obj := sala.grid.objeto_en(celda)
	if obj == null:
		GameManager.avisar_error(Errores.Codigo.NO_TIENE_ITEM)
		return

	var inst := sala.retirar_objeto(obj)
	if inst != null:
		GameManager.avisar("Retiraste: %s" % inst.nombre_mostrado())


## Devuelve el item elegido para colocar, o null si el catalogo esta vacio.
func _item_elegido() -> ItemDefinition:
	return null if _catalogo.is_empty() else _catalogo[_elegido]


## Pasa al siguiente item colocable del catalogo, o al anterior con paso -1.
func _elegir_otro(sala : RoomController, paso : int) -> void:
	if _catalogo.is_empty():
		GameManager.avisar("El catalogo no tiene ningun item colocable con modelo.")
		return

	_elegido = posmod(_elegido + paso, _catalogo.size())
	_refrescar_vista_previa(sala)
	GameManager.avisar("Vas a colocar: %s   (%d de %d)"
		% [_item_elegido().nombre, _elegido + 1, _catalogo.size()])


## Le dice a la vista previa de una sala que mostrar.
##
## La sala puede no tener indicador: es opcional por contrato, asi que esto no
## comprueba nada mas que eso y nunca es un error.
func _refrescar_vista_previa(sala : RoomController) -> void:
	if sala != null and sala.indicador != null:
		sala.indicador.elegir(_item_elegido(), _rotacion_colocacion)


## Le pasa el item elegido a la sala que acaba de activarse.
##
## Hace falta porque cada sala trae su propio indicador: al cambiar de sala, el
## de la nueva todavia no sabe nada de lo que venias colocando.
func _al_cambiar_de_sala(sala : RoomController) -> void:
	_refrescar_vista_previa(sala)


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
