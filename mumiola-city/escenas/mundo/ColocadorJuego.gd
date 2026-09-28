extends Node
class_name ColocadorJuego

## Pone en la sala algo de la mochila, jugando. Es la otra mitad de levantar: lo
## que se levanto se puede volver a poner sin abrir el editor.
##
## El gesto es el de Habbo: se elige algo en la mochila, su fantasma sigue al
## puntero sobre la sala, el clic izquierdo lo deja, R lo gira, y Esc o el clic
## derecho lo sueltan. Se coloca una vez y termina.
##
## Es primo de EditorSala y no parte de el, porque son dos cosas distintas. El
## editor construye con el catalogo entero y tiene deshacer; esto mueve cosas
## que el jugador tiene, de la mochila a la sala, y como levantar, no entra al
## historial. Si entrara, un Ctrl+Z en el editor sacaria el mueble de la sala
## sin devolverlo a la mochila.
##
## Colocar pasa por RoomController.aplicar(), la costura de D23: jugando se
## aplica en el acto, y online se manda la misma operacion.
##
## El orden de la transaccion es el de levantar, al reves, y por el mismo
## motivo: nada puede quedar en dos lugares ni en ninguno. Se pregunta si entra,
## se saca de la mochila, se aplica, y si la sala lo rechaza igual, se devuelve a
## la casilla de donde salio.
##
## Sigue lo que coloca por su casilla viva y no por su numero: reordenar la
## mochila mientras se coloca no le hace perder de vista la cosa, y si la cosa
## desaparece de la mochila, se suelta sola.

## Empezo o termino de colocar algo.
signal cambiado(activo : bool)

## Cuantos pasos de rotacion tiene una vuelta completa.
const PASOS_ROTACION := 4

var _slot : InventorySlot = null
var _definicion : ItemDefinition = null
var _rotacion : int = 0
## Mientras se saca y se devuelve algo de la mochila, sus avisos son propios y
## no significan que la cosa desaparecio.
var _en_transaccion : bool = false


func _ready() -> void:
	set_process(false)
	GameManager.modo_cambiado.connect(func(_m : GameManager.Modo) -> void: cancelar())
	GameManager.saliendo_de_sala.connect(func(_s : RoomController) -> void: cancelar())
	InventoryManager.inventario_cambiado.connect(_al_cambiar_mochila)


## Devuelve por que no se puede colocar lo de una casilla, u OK si se puede.
##
## Es la regla entera, y es estatica para que la ventana de la mochila la use
## para prender su boton sin tener que conocer a este nodo: el boton y el gesto
## dicen lo mismo porque preguntan lo mismo.
static func motivo_para_colocar(slot : InventorySlot) -> Errores.Codigo:
	if slot == null:
		return Errores.Codigo.NO_TIENE_ITEM
	var def := slot.definicion()
	if def == null or not def.colocable:
		return Errores.Codigo.NO_COLOCABLE
	if GameManager.editando():
		return Errores.Codigo.EDITANDO
	var sala := GameManager.sala_actual()
	if sala == null:
		return Errores.Codigo.SALA_NO_EXISTE
	if not sala.puede_editar(GameManager.jugador_actual()):
		return Errores.Codigo.SIN_PERMISO
	return Errores.Codigo.OK


## Empieza a colocar lo de una casilla de la mochila. Devuelve OK o por que no.
func empezar(indice : int) -> Errores.Codigo:
	var slot := InventoryManager.mochila.casilla(indice)
	var motivo := motivo_para_colocar(slot)
	if not Errores.ok(motivo):
		return motivo

	_slot = slot
	_definicion = slot.definicion()
	_rotacion = 0
	var indicador := _indicador()
	if indicador != null:
		indicador.elegir(_definicion, _rotacion)
	set_process(true)
	cambiado.emit(true)
	GameManager.avisar("Elegi donde poner %s. R gira, Esc cancela." % _definicion.nombre)
	return Errores.Codigo.OK


## Devuelve si se esta colocando algo.
func activo() -> bool:
	return _slot != null


## Devuelve el giro con que se va a colocar, en cuartos de vuelta.
func rotacion() -> int:
	return _rotacion


## Gira lo que se va a colocar un cuarto de vuelta. Lo que no gira, no gira: la
## sala lo pondria derecho igual.
func rotar() -> void:
	if not activo() or not _definicion.rotable:
		return
	_rotacion = posmod(_rotacion + 1, PASOS_ROTACION)


## Suelta lo que se estaba colocando, sin colocarlo.
func cancelar() -> void:
	if activo():
		_terminar()


## Pone en una celda lo que se esta colocando. Devuelve OK o por que no.
##
## Un rechazo no termina: el jugador puede probar en otra celda.
func colocar_en(celda : Vector2i) -> Errores.Codigo:
	if not activo():
		return Errores.Codigo.NO_TIENE_ITEM
	var sala := GameManager.sala_actual()
	if sala == null:
		return Errores.Codigo.SALA_NO_EXISTE
	if not sala.puede_editar(GameManager.jugador_actual()):
		return Errores.Codigo.SIN_PERMISO

	var mochila := InventoryManager.mochila
	var indice := mochila.indice_de(_slot)
	if indice == -1:
		_terminar()
		return Errores.Codigo.NO_TIENE_ITEM

	var def := _definicion
	var giro := _rotacion if def.rotable else 0
	var motivo := sala.grid.motivo_bloqueo(celda, def.tamano_grilla, giro)
	if not Errores.ok(motivo):
		return motivo

	_en_transaccion = true
	var inst := mochila.sacar_unidad(indice)
	# La operacion lleva el estado y no la instancia: es lo que viaja por la red.
	# La sala arma una instancia nueva con ese estado, asi que el plato llega
	# servido aunque no sea el mismo objeto en memoria.
	var codigo := sala.aplicar(OperacionSala.colocar(def.id, celda, giro, _estado_de(inst)), false)
	if not Errores.ok(codigo):
		var devuelto := mochila.agregar_instancia(inst, indice)
		if not Errores.ok(devuelto):
			push_error("ColocadorJuego: '%s' salio de la mochila, la sala lo rechazo y no volvio (%s)."
				% [def.id, Errores.mensaje(devuelto)])
		# Volvio a su casilla, pero quizas en una casilla nueva: se la sigue ahi.
		_slot = mochila.casilla(indice)
		_en_transaccion = false
		if _slot == null:
			_terminar()
		return codigo
	_en_transaccion = false

	GameManager.avisar("Pusiste %s." % def.nombre)
	_terminar()
	return Errores.Codigo.OK


func _process(_delta : float) -> void:
	var indicador := _indicador()
	var sala := GameManager.sala_actual()
	if indicador == null or sala == null:
		return
	# Sobre la interfaz no se coloca, asi que tampoco se muestra donde caeria.
	if get_viewport().gui_get_hovered_control() != null:
		indicador.ocultar()
		return
	var celda := sala.grid.celda_bajo_puntero(sala.camara, get_viewport().get_mouse_position())
	if celda == IsoGrid.SIN_CELDA:
		indicador.ocultar()
	else:
		indicador.mostrar(_definicion, celda, _rotacion if _definicion.rotable else 0)


## Los clics, mientras se coloca, son de esto y de nada mas.
##
## Este nodo va despues del personaje en el arbol, asi que ve el clic primero, y
## al marcarlo como atendido el personaje no sale caminando hacia donde se puso
## la cosa. El clic derecho tampoco llega a abrir el menu de un mueble.
func _unhandled_input(evento : InputEvent) -> void:
	if not activo() or not (evento is InputEventMouseButton) or not evento.pressed:
		return
	var boton := evento as InputEventMouseButton
	if boton.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		cancelar()
	elif boton.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var sala := GameManager.sala_actual()
		if sala == null:
			return
		var celda := sala.grid.celda_bajo_puntero(sala.camara, boton.position)
		if celda == IsoGrid.SIN_CELDA:
			return
		var codigo := colocar_en(celda)
		if not Errores.ok(codigo):
			GameManager.avisar_error(codigo)


## Esc suelta y R gira. Va aca y no en _unhandled_input para ganarle al menu de
## Esc y a las ventanas, que escuchan en el mismo lugar y estan antes en el
## arbol.
func _unhandled_key_input(evento : InputEvent) -> void:
	if not activo() or not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelar()
	elif evento.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		rotar()


func _terminar() -> void:
	_slot = null
	_definicion = null
	_rotacion = 0
	set_process(false)
	var indicador := _indicador()
	if indicador != null:
		indicador.ocultar()
		indicador.elegir(null)
	cambiado.emit(false)


## Si lo que se estaba colocando ya no esta en la mochila, se suelta.
func _al_cambiar_mochila() -> void:
	if activo() and not _en_transaccion and InventoryManager.mochila.indice_de(_slot) == -1:
		_terminar()


## El estado de una instancia como lo lleva una operacion: lo mismo que usa la
## sala para deshacer un retiro.
func _estado_de(inst : ItemInstance) -> Dictionary:
	if inst == null or inst.esta_vacio():
		return {}
	return {"contenido": String(inst.contenido_id), "contenido_cantidad": inst.contenido_cantidad}


func _indicador() -> IndicadorCelda:
	var sala := GameManager.sala_actual()
	return null if sala == null else sala.indicador
