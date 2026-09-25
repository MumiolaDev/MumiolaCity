class_name EditorSala
extends Node

## Traduce gestos en operaciones y se las entrega a RoomController.aplicar().
##
## Nunca toca la sala directamente, y esa es toda la gracia (D23). No llama a
## colocar_objeto(), ni a retirar_objeto(), ni a IsoGrid.pintar(): arma una
## OperacionSala y la entrega. Local se aplica en el acto; el dia del servidor
## autoritativo la misma operacion se manda, el servidor la valida y retransmite,
## y el mismo aplicar() corre en todos los clientes sin que este archivo cambie.
##
## Solo hace algo mientras GameManager.editando(). En modo juego no lee el mouse,
## no mueve la vista previa y no aplica nada.
##
## Reparto de responsabilidades: la paleta dice *que*, este nodo dice *donde* y
## *cuando*, la sala decide *si se puede*. Ninguno de los tres sabe hacer el
## trabajo de los otros.
##
## Atajos: clic izquierdo coloca o pinta, derecho quita, R gira, Ctrl+Z deshace,
## Ctrl+Y rehace, Ctrl+S guarda la sala en un archivo, Ctrl+O la vuelve a cargar,
## Esc suelta la seleccion.

## Se aplico una operacion. Lleva el codigo para que la interfaz pueda reaccionar
## sin volver a preguntar.
signal opero(op : OperacionSala, codigo : Errores.Codigo)

## De donde sale lo que se va a colocar. Opcional: sin paleta el editor sigue
## andando y simplemente no hay nada elegido.
@export var paleta : RoomBuilderUI

## Cuantos pasos de rotacion tiene una vuelta completa.
const PASOS_ROTACION := 4

var _rotacion : int = 0
## Ultima celda pintada en el arrastre en curso, para no repetir la operacion
## sesenta veces por segundo sobre la misma celda.
var _ultima_pintada : Vector2i = IsoGrid.SIN_CELDA
var _pintando : bool = false
var _borrando : bool = false


func _ready() -> void:
	GameManager.modo_cambiado.connect(_al_cambiar_modo)
	if paleta != null:
		paleta.item_elegido.connect(_al_elegir_item)
		paleta.pieza_elegida.connect(_al_elegir_pieza)
		paleta.seleccion_vaciada.connect(_al_vaciar_seleccion)
	_al_cambiar_modo(GameManager.modo())


func _process(_delta : float) -> void:
	_refrescar_vista_previa()
	if _pintando or _borrando:
		_pintar_arrastrando()


func _unhandled_input(evento : InputEvent) -> void:
	if not GameManager.editando():
		return

	if evento is InputEventMouseButton:
		_atender_boton(evento as InputEventMouseButton)
		return

	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return

	var tecla := evento as InputEventKey
	if tecla.keycode == KEY_R:
		rotar()
	elif tecla.keycode == KEY_Z and tecla.ctrl_pressed and tecla.shift_pressed:
		_rehacer()
	elif tecla.keycode == KEY_Z and tecla.ctrl_pressed:
		_deshacer()
	elif tecla.keycode == KEY_Y and tecla.ctrl_pressed:
		_rehacer()
	elif tecla.keycode == KEY_S and tecla.ctrl_pressed:
		_guardar_sala()
	elif tecla.keycode == KEY_O and tecla.ctrl_pressed:
		_cargar_sala()
	elif tecla.keycode == KEY_ESCAPE and paleta != null:
		paleta.limpiar()


## Gira lo que se va a colocar un cuarto de vuelta.
##
## Vale igual para muebles y para escenario: una pared que no se puede girar solo
## sirve para una de las cuatro caras de una sala, que es la mitad del problema
## de construir una.
##
## Lo unico que no gira es un item que declara rotable en false, porque
## colocar_objeto() lo enderezaria igual y girar la vista previa de algo que va a
## caer derecho seria mentir.
func rotar() -> void:
	match _clase_elegida():
		RoomBuilderUI.Clase.ITEM:
			if not _item_elegido().rotable:
				return
		RoomBuilderUI.Clase.PIEZA:
			pass
		_:
			return

	_rotacion = posmod(_rotacion + 1, PASOS_ROTACION)
	_refrescar_vista_previa()


## Aplica una operacion en la sala activa y avisa del resultado.
##
## Es el unico lugar de este archivo que habla con la sala, y habla en
## operaciones. Todo lo demas de aca arriba solo decide cual construir.
func aplicar(op : OperacionSala) -> Errores.Codigo:
	var sala := GameManager.sala_actual()
	if sala == null or op == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var codigo := sala.aplicar(op)
	if not Errores.ok(codigo):
		GameManager.avisar_error(codigo)
	opero.emit(op, codigo)
	return codigo


## Atiende los clics del mouse en modo edicion.
##
## El clic no llega hasta aca si el puntero esta sobre la paleta: ese Control se
## come el evento y _unhandled_input ni se entera. Es justamente para lo que la
## paleta usa mouse_filter en STOP.
func _atender_boton(evento : InputEventMouseButton) -> void:
	var izquierdo := evento.button_index == MOUSE_BUTTON_LEFT
	var derecho := evento.button_index == MOUSE_BUTTON_RIGHT
	if not izquierdo and not derecho:
		return

	if not evento.pressed:
		_pintando = false
		_borrando = false
		_ultima_pintada = IsoGrid.SIN_CELDA
		return

	var celda := _celda_bajo_puntero()
	if celda == IsoGrid.SIN_CELDA:
		return

	if izquierdo:
		_colocar_en(celda)
		# El arrastre solo vale para escenario: pintar cien celdas de suelo es un
		# gesto, pero arrastrar cien sillas es casi siempre un accidente.
		_pintando = _clase_elegida() == RoomBuilderUI.Clase.PIEZA
	else:
		_quitar_de(celda)
		_borrando = _clase_elegida() == RoomBuilderUI.Clase.PIEZA

	_ultima_pintada = celda


## Construye y aplica la operacion de poner, segun que haya elegido la paleta.
func _colocar_en(celda : Vector2i) -> void:
	match _clase_elegida():
		RoomBuilderUI.Clase.ITEM:
			var def := _item_elegido()
			aplicar(OperacionSala.colocar(def.id, celda, _rotacion if def.rotable else 0))
		RoomBuilderUI.Clase.PIEZA:
			aplicar(OperacionSala.pintar(paleta.capa(), celda, paleta.pieza(),
				CatalogoPiezas.orientacion_de(_rotacion)))
		_:
			GameManager.avisar("Elegi algo de la paleta primero.")


## Construye y aplica la operacion de quitar.
##
## Con una pieza elegida borra de esa capa; si no, retira el objeto de la celda.
## Asi el clic derecho siempre deshace lo que el izquierdo acaba de hacer, que es
## lo unico que se puede predecir sin leer un manual.
func _quitar_de(celda : Vector2i) -> void:
	if _clase_elegida() == RoomBuilderUI.Clase.PIEZA:
		aplicar(OperacionSala.borrar(paleta.capa(), celda))
		return
	aplicar(OperacionSala.retirar(celda))


## Sigue pintando mientras el boton este apretado.
##
## Salta las celdas repetidas: sin eso, quedarse quieto con el boton apretado
## metaria una operacion por cuadro en el historial y deshacer dejaria de
## servir para nada.
func _pintar_arrastrando() -> void:
	if not GameManager.editando():
		_pintando = false
		_borrando = false
		return

	var celda := _celda_bajo_puntero()
	if celda == IsoGrid.SIN_CELDA or celda == _ultima_pintada:
		return

	_ultima_pintada = celda
	if _pintando:
		_colocar_en(celda)
	else:
		_quitar_de(celda)


## Pone la vista previa donde esta el puntero, o la esconde si no corresponde.
func _refrescar_vista_previa() -> void:
	var indicador := _indicador()
	if indicador == null:
		return

	if not GameManager.editando() or _sobre_la_interfaz():
		indicador.ocultar()
		return

	var celda := _celda_bajo_puntero()
	if celda == IsoGrid.SIN_CELDA:
		indicador.ocultar()
		return

	# Una pieza de escenario no tiene ItemDefinition, asi que su fantasma entra
	# por la malla que la MeshLibrary ya guarda. Sin esto, girar una pared seria
	# a ciegas: el recuadro se ve igual en las cuatro orientaciones.
	if _clase_elegida() == RoomBuilderUI.Clase.PIEZA:
		var pieza := _pieza_elegida()
		indicador.elegir_pieza(pieza["malla"], pieza["transformada"], _rotacion)
		indicador.mostrar_en(celda, _rotacion)
		return

	indicador.mostrar(_item_elegido(), celda, _rotacion)


## Devuelve si el puntero esta sobre un Control.
##
## Sin esto la vista previa aparecería debajo de la paleta, marcando celdas que
## el clic nunca va a alcanzar.
func _sobre_la_interfaz() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _celda_bajo_puntero() -> Vector2i:
	var sala := GameManager.sala_actual()
	if sala == null or sala.grid == null or sala.camara == null:
		return IsoGrid.SIN_CELDA
	return sala.grid.celda_bajo_puntero(sala.camara, get_viewport().get_mouse_position())


func _indicador() -> IndicadorCelda:
	var sala := GameManager.sala_actual()
	return null if sala == null else sala.indicador


func _clase_elegida() -> RoomBuilderUI.Clase:
	return RoomBuilderUI.Clase.NADA if paleta == null else paleta.clase()


func _item_elegido() -> ItemDefinition:
	return null if paleta == null else paleta.item()


## La malla de la pieza elegida y la transformada con que la coloca el GridMap.
##
## Las dos juntas y no solo la malla: la biblioteca guarda una escala por pieza
## —suelo_base va a 0.25 con una malla de cuatro metros— y sin ella el fantasma
## se ve mucho mas grande que lo que termina colocado.
func _pieza_elegida() -> Dictionary:
	var vacio := {"malla": null, "transformada": Transform3D.IDENTITY}
	var sala := GameManager.sala_actual()
	if paleta == null or sala == null or sala.grid == null:
		return vacio

	var biblioteca := sala.grid.biblioteca_de(paleta.capa())
	if biblioteca == null:
		return vacio

	var id := CatalogoPiezas.id_de(biblioteca, paleta.pieza())
	if id == -1:
		return vacio
	return {
		"malla": biblioteca.get_item_mesh(id),
		"transformada": biblioteca.get_item_mesh_transform(id),
	}


## Guarda la sala activa.
##
## Salir del editor y dejar la sala ya guardan solos; esto es para quien quiere
## asegurarse a mitad de una obra larga.
func _guardar_sala() -> void:
	var sala := GameManager.sala_actual()
	if sala == null:
		return
	var codigo : Errores.Codigo = await GameManager.guardar_sala_actual()
	if Errores.ok(codigo):
		GameManager.avisar("Sala '%s' guardada." % sala.nombre_sala)
	else:
		GameManager.avisar_error(codigo)


## Descarta lo que cambio desde la ultima vez que se guardo.
##
## Pregunta antes, porque cargar olvida el historial y ya no hay Ctrl+Z que lo
## devuelva.
func _cargar_sala() -> void:
	var sala := GameManager.sala_actual()
	if sala == null:
		return
	var padre := paleta.get_parent() if paleta != null else get_tree().root
	var respuesta : Dictionary = await Dialogo.confirmar(padre, "Descartar cambios",
		"¿Volver a como estaba '%s' la ultima vez que se guardo?" % sala.nombre_sala,
		"Descartar").respondido
	if not respuesta.aceptado:
		return
	var codigo : Errores.Codigo = await GameManager.recargar_sala_actual()
	if Errores.ok(codigo):
		GameManager.avisar("Sala '%s' como estaba guardada." % sala.nombre_sala)
	else:
		GameManager.avisar_error(codigo)


func _deshacer() -> void:
	var sala := GameManager.sala_actual()
	if sala == null:
		return
	GameManager.avisar("Deshecho." if sala.deshacer() else "No hay nada que deshacer.")


func _rehacer() -> void:
	var sala := GameManager.sala_actual()
	if sala == null:
		return
	GameManager.avisar("Rehecho." if sala.rehacer() else "No hay nada que rehacer.")


## Al elegir otra cosa, la rotacion vuelve a cero.
##
## Arrastrar el giro de un mueble al siguiente sorprende: elegiste una alfombra y
## aparece torcida porque antes habias girado una silla.
func _al_elegir_item(_definicion : ItemDefinition) -> void:
	_rotacion = 0
	_refrescar_vista_previa()


func _al_elegir_pieza(_capa : StringName, _pieza : StringName) -> void:
	_rotacion = 0
	_refrescar_vista_previa()


func _al_vaciar_seleccion() -> void:
	_rotacion = 0
	var indicador := _indicador()
	if indicador != null:
		indicador.elegir(null)


func _al_cambiar_modo(modo : GameManager.Modo) -> void:
	var editando := modo == GameManager.Modo.EDITANDO
	set_process(editando)
	_pintando = false
	_borrando = false
	_ultima_pintada = IsoGrid.SIN_CELDA

	var indicador := _indicador()
	if indicador != null and not editando:
		indicador.ocultar()
		indicador.elegir(null)
