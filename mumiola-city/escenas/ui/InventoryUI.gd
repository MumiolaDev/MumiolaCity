extends Ventana
class_name InventoryUI

## La ventana del personaje: lo que lleva encima y quien es, en dos pestanas.
##
## La mochila es una VistaContenedor sobre InventoryManager.mochila, la misma
## vista que va a mostrar una alacena o una heladera. Esta ventana le agrega lo
## que solo tiene sentido para tu mochila.
##
## El perfil es una VistaPerfil con tus datos. Se arma cada vez que se mira, y no
## se guarda entre aperturas: la sala donde estas y cuantas tenes cambian, y con
## red, un dato viejo es un dato que miente.
##
## I abre y cierra la mochila. En la barra, Mochila y Yo abren cada una su
## pestana; con la ventana abierta en la otra, cambian de pestana en vez de
## cerrar.

## Las pestanas, en el orden en que aparecen.
enum Pestana { MOCHILA, PERFIL }

var _pestanas : TabContainer = null
var _vista_mochila : VistaContenedor = null
var _vista_perfil : VistaPerfil = null


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
	GameManager.sala_cambiada.connect(func(_s : RoomController) -> void:
		if visible and pestana() == Pestana.PERFIL:
			refrescar_perfil())


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
	return hoja
