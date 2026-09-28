extends Ventana
class_name InventoryUI

## La ventana del personaje: lo que lleva encima y quien es, en dos pestanas.
##
## La mochila es una VistaContenedor sobre InventoryManager.mochila, la misma
## vista que va a mostrar una alacena o una heladera. Esta ventana le agrega lo
## que solo tiene sentido para tu mochila: Colocar, que pone lo elegido en la
## sala. El boton, o el doble clic, piden colocar; quien coloca es
## ColocadorJuego, y el mundo los conecta.
##
## El perfil es una VistaPerfil con tus datos. Se arma cada vez que se mira, y no
## se guarda entre aperturas: la sala donde estas y cuantas tenes cambian, y con
## red, un dato viejo es un dato que miente.
##
## I abre y cierra la mochila. En la barra, Mochila y Yo abren cada una su
## pestana; con la ventana abierta en la otra, cambian de pestana en vez de
## cerrar.

## Se pidio colocar en la sala lo de una casilla de la mochila.
signal colocar_pedido(indice : int)

## Las pestanas, en el orden en que aparecen.
enum Pestana { MOCHILA, PERFIL }

var _pestanas : TabContainer = null
var _vista_mochila : VistaContenedor = null
var _vista_perfil : VistaPerfil = null
var _boton_colocar : Button = null


func _ready() -> void:
	titulo = GameManager.nombre_jugador()

	_pestanas = TabContainer.new()
	# La ventana mide lo que la pestana mas grande, asi no cambia de tamano ni
	# salta de lugar al pasar de una a otra.
	_pestanas.use_hidden_tabs_for_min_size = true
	_pestanas.add_child(_armar_mochila())
	_vista_perfil = VistaPerfil.new()
	_vista_perfil.name = "Perfil"
	_pestanas.add_child(_vista_perfil)
	_pestanas.tab_changed.connect(func(_i : int) -> void:
		if pestana() == Pestana.PERFIL:
			refrescar_perfil())
	add_child(_pestanas)
	super._ready()

	_vista_mochila.mostrar(InventoryManager.mochila)
	_vista_mochila.eleccion_cambiada.connect(func(_i : int) -> void: _actualizar_acciones())
	_vista_mochila.casilla_activada.connect(_pedir_colocar)
	GameManager.modo_cambiado.connect(func(_m : GameManager.Modo) -> void: _actualizar_acciones())
	GameManager.sala_cambiada.connect(func(_s : RoomController) -> void:
		_actualizar_acciones()
		if visible and pestana() == Pestana.PERFIL:
			refrescar_perfil())
	_actualizar_acciones()


## Abre la ventana en la pestana en que estaba.
func abrir() -> void:
	# El nombre se lee al abrir y no una vez: la ventana nace antes de saber con
	# que perfil se juega si el mundo se carga sin pasar por el menu.
	titulo = GameManager.nombre_jugador()
	super.abrir()
	if pestana() == Pestana.PERFIL:
		refrescar_perfil()


## Abre la ventana en una pestana.
func abrir_en(cual : Pestana) -> void:
	_pestanas.current_tab = cual
	abrir()


## Abre la ventana en una pestana, o la cierra si ya esta abierta en esa.
func alternar_en(cual : Pestana) -> void:
	if visible and pestana() == cual:
		cerrar()
	else:
		abrir_en(cual)


## Devuelve en que pestana esta.
func pestana() -> Pestana:
	return _pestanas.current_tab as Pestana


## Devuelve la vista de la mochila.
func vista_mochila() -> VistaContenedor:
	return _vista_mochila


## Devuelve la vista del perfil.
func vista_perfil() -> VistaPerfil:
	return _vista_perfil


## Vuelve a armar el perfil con los datos de ahora.
func refrescar_perfil() -> void:
	var sala := GameManager.sala_actual()
	var mochila := InventoryManager.mochila
	var datos := {
		"nombre": GameManager.nombre_jugador(),
		"creado": int(GameManager.perfil().get("creado", 0)),
		"mochila": "%d cosas, %.1f kg" % [mochila.casillas_usadas(), mochila.peso_total()],
		"de_prueba": not GameManager.hay_sesion(),
	}
	if sala != null:
		datos["sala"] = sala.nombre_sala if sala.nombre_sala != "" else String(sala.id_sala)
	# Se muestra lo que ya se sabe y se completa cuando responde el servidor:
	# con red, la ventana no puede quedarse en blanco esperando.
	_vista_perfil.mostrar(datos)
	var propias : Array[Dictionary] = await Servidor.listar_salas_de(GameManager.perfil_id())
	datos["salas_propias"] = propias.size()
	_vista_perfil.mostrar(datos)


func _unhandled_key_input(evento : InputEvent) -> void:
	super._unhandled_key_input(evento)
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_I:
		alternar_en(Pestana.MOCHILA)
		get_viewport().set_input_as_handled()


func _armar_mochila() -> Control:
	var hoja := VBoxContainer.new()
	hoja.name = "Mochila"
	hoja.add_theme_constant_override(&"separation", 8)
	_vista_mochila = VistaContenedor.new()
	hoja.add_child(_vista_mochila)

	var acciones := HBoxContainer.new()
	acciones.alignment = BoxContainer.ALIGNMENT_END
	_boton_colocar = Button.new()
	_boton_colocar.text = "Colocar"
	_boton_colocar.focus_mode = Control.FOCUS_NONE
	_boton_colocar.pressed.connect(func() -> void: _pedir_colocar(_vista_mochila.elegida()))
	acciones.add_child(_boton_colocar)
	hoja.add_child(acciones)
	return hoja


## Prende Colocar si lo elegido se puede colocar ahora, y si no dice por que.
##
## La regla es la de ColocadorJuego, preguntada y no copiada: el boton no puede
## prometer algo que el gesto despues rechaza.
func _actualizar_acciones() -> void:
	var slot := _vista_mochila.slot_elegido()
	var motivo := ColocadorJuego.motivo_para_colocar(slot)
	_boton_colocar.disabled = not Errores.ok(motivo)
	if slot == null:
		_boton_colocar.tooltip_text = "Elegi algo de la mochila para ponerlo en la sala."
	elif Errores.ok(motivo):
		_boton_colocar.tooltip_text = "Poner %s en la sala (doble clic)." % slot.nombre_mostrado()
	else:
		_boton_colocar.tooltip_text = Errores.mensaje(motivo)


func _pedir_colocar(indice : int) -> void:
	if Errores.ok(ColocadorJuego.motivo_para_colocar(_vista_mochila.contenedor().casilla(indice))):
		colocar_pedido.emit(indice)
