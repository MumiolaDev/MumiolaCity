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
## Teclas de prueba, todas provisionales: TAB cambia de sala, Q y E giran el
## encuadre un cuarto de vuelta, R gira la silla que se va a colocar, C la coloca
## en la celda bajo el mouse y X retira lo que haya ahi.
##
## Girar el encuadre y girar el objeto son dos cosas distintas y por eso son dos
## teclas distintas: la camara orbita y los objetos se quedan donde estan, asi
## que una silla ya colocada se ve desde otro lado sin haber cambiado de
## orientacion. Como decide el jugador hacia donde mira un mueble es D19.
##
## C y X existen para poder probar el paso 4b sin menu contextual: el clic
## izquierdo ya lo usa el personaje para caminar, y ContextMenuUI es el paso 7.

@onready var contenedor_salas : Node3D = $Salas
@onready var menu : ContextMenuUI = $UI/ContextMenuUI

## Con que rotacion se coloca la proxima silla de prueba. Gira con R, no con el
## encuadre, para poder comprobar que la rotacion de la huella y la visual
## concuerdan sin confundirla con el giro de la camara.
var _rotacion_silla : int = 0


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
	GameManager.mostrar_ayuda("TAB cambiar de sala   Q/E girar la vista   R girar la silla   C colocar   X retirar   G guardar   L cargar\nClic izquierdo: caminar   Clic derecho sobre un mueble: menu")

	for sala in GameManager.salas():
		sala.objeto_colocado.connect(_atender_clics_de)
		for obj in sala.objetos():
			_atender_clics_de(obj)

	if not GameManager.ir_a_indice(0):
		push_error("Mundo: no hay ninguna RoomController colgando de Salas.")


func _unhandled_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return

	if evento.keycode == KEY_TAB:
		GameManager.siguiente_sala()
		return

	var sala := GameManager.sala_actual()
	if sala == null:
		return
	if evento.keycode == KEY_Q:
		sala.rotar(-1)
	elif evento.keycode == KEY_E:
		sala.rotar(1)
	elif evento.keycode == KEY_R:
		_rotacion_silla = posmod(_rotacion_silla + 1, 4)
		GameManager.avisar("Rotacion de colocacion: %d" % _rotacion_silla)
	elif evento.keycode == KEY_C:
		_colocar_silla_de_prueba(sala)
	elif evento.keycode == KEY_X:
		_retirar_bajo_el_mouse(sala)
	elif evento.keycode == KEY_G:
		GameManager.avisar("Partida guardada." if SaveManager.guardar() == OK
			else "No se pudo guardar.")
	elif evento.keycode == KEY_L:
		GameManager.avisar("Partida cargada." if SaveManager.cargar() == OK
			else "No hay partida guardada.")


## Coloca una silla en la celda bajo el mouse y reporta el resultado.
##
## Provisional, para poder probar colocar_objeto() sin menu contextual. La
## instancia se crea aca porque todavia no hay inventario del cual sacarla: en la
## fase 2 este paso pasa a ser InventoryManager.quitar_instancia().
func _colocar_silla_de_prueba(sala : RoomController) -> void:
	var celda := sala.grid.celda_bajo_puntero(sala.camara, get_viewport().get_mouse_position())
	if celda == IsoGrid.SIN_CELDA:
		return

	var inst := ItemInstance.new()
	inst.definicion_id = &"silla_madera"

	var resultado := sala.colocar_objeto(inst, celda, _rotacion_silla)
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
