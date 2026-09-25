extends PanelContainer
class_name Ventana

## Una ventana flotante al estilo Habbo: barra de titulo arrastrable, cruz para
## cerrar, y lo que se le cuelgue abajo.
##
## Se usa poniendo este script en un PanelContainer y colgandole el contenido
## como hijo, en el editor, como a cualquier contenedor. Al arrancar, la ventana
## arma su barra de titulo en codigo y muda el contenido debajo. Asi una ventana
## nueva es una escena comun y corriente, sin "hijos editables" ni slots que
## haya que acordarse de respetar.
##
## Es la pieza de la que cuelgan el navegador, la ayuda, los dialogos, las
## opciones y —cuando llegue— el inventario. Todo lo que tenga que ser igual en
## todas ellas vive aca y no en cada una.
##
## No tiene que colgar de un Container: se posiciona sola, y un contenedor la
## volveria a acomodar en cada cambio de tamano.

## Se cerro, por la cruz, por Esc o por codigo.
signal cerrada()

@export var titulo : String = "" : set = set_titulo
## Si muestra la cruz. Un dialogo que exige respuesta la apaga.
@export var cerrable : bool = true
## Si se puede mover arrastrando la barra de titulo.
@export var arrastrable : bool = true
## La primera vez que se abre, aparece centrada. Despues recuerda donde la
## dejaste, que es lo que se espera de una ventana que se abre y se cierra mucho.
@export var centrar_al_abrir : bool = true

var _cuerpo : VBoxContainer = null
var _etiqueta : Label = null
var _boton_cerrar : Button = null
var _arrastrando : bool = false
var _ubicada : bool = false


func _ready() -> void:
	_armar()
	# Sin anclas de estiramiento: el tamano lo decide el contenido, y la posicion
	# la ventana. Con anclas a pantalla completa, arrastrarla la deformaria.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_encajar)
	get_viewport().size_changed.connect(_encajar)


## Abre la ventana y la trae al frente.
func abrir() -> void:
	show()
	move_to_front()
	if not _ubicada:
		# El tamano recien se conoce con el contenido ya medido: se centra un
		# cuadro despues, no ahora.
		reset_size()
		_centrar.call_deferred()
	else:
		_encajar()


## Pone la ventana en un lugar dado, y deja de centrarla al abrirse.
func ubicar(punto : Vector2) -> void:
	position = punto
	_ubicada = true
	_encajar()


## Cierra la ventana. No la destruye: al volver a abrirla esta donde estaba.
func cerrar() -> void:
	if not visible:
		return
	hide()
	_arrastrando = false
	cerrada.emit()


## Abre la ventana si esta cerrada, y la cierra si esta abierta.
func alternar() -> void:
	if visible:
		cerrar()
	else:
		abrir()


## Cambia el texto de la barra de titulo.
func set_titulo(valor : String) -> void:
	titulo = valor
	if _etiqueta != null:
		_etiqueta.text = valor


## Devuelve el contenedor donde va el contenido, para quien lo arma en codigo.
func cuerpo() -> VBoxContainer:
	if _cuerpo == null:
		_armar()
	return _cuerpo


## Un clic en cualquier parte de la ventana la trae al frente.
func _gui_input(evento : InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		move_to_front()


## Arma la barra de titulo y muda el contenido debajo de ella.
func _armar() -> void:
	if _cuerpo != null:
		return

	var contenido := get_children()

	_cuerpo = VBoxContainer.new()
	_cuerpo.name = "Cuerpo"
	_cuerpo.add_theme_constant_override(&"separation", 8)

	var barra := PanelContainer.new()
	barra.name = "BarraTitulo"
	barra.theme_type_variation = &"BarraTitulo"
	barra.mouse_default_cursor_shape = Control.CURSOR_MOVE if arrastrable else Control.CURSOR_ARROW
	barra.gui_input.connect(_al_input_barra)

	var fila := HBoxContainer.new()
	_etiqueta = Label.new()
	_etiqueta.theme_type_variation = &"TituloVentana"
	_etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_etiqueta.text = titulo
	fila.add_child(_etiqueta)

	_boton_cerrar = Button.new()
	_boton_cerrar.name = "Cerrar"
	_boton_cerrar.theme_type_variation = &"BotonCerrar"
	_boton_cerrar.icon = get_theme_icon(&"cerrar", &"Ventana")
	_boton_cerrar.focus_mode = Control.FOCUS_NONE
	_boton_cerrar.tooltip_text = "Cerrar"
	_boton_cerrar.visible = cerrable
	_boton_cerrar.pressed.connect(cerrar)
	fila.add_child(_boton_cerrar)

	barra.add_child(fila)
	_cuerpo.add_child(barra)

	for hijo in contenido:
		remove_child(hijo)
		_cuerpo.add_child(hijo)
	add_child(_cuerpo)


## Arrastra la ventana desde la barra de titulo.
func _al_input_barra(evento : InputEvent) -> void:
	if not arrastrable:
		return
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = evento.pressed
		if evento.pressed:
			move_to_front()
		else:
			_encajar()
		accept_event()
	elif evento is InputEventMouseMotion and _arrastrando:
		position += evento.relative
		_ubicada = true
		accept_event()


## Pone la ventana en el centro de la pantalla, salvo que alguien la haya
## ubicado entre que se pidio y que llego el cuadro siguiente.
func _centrar() -> void:
	if _ubicada:
		return
	position = ((get_viewport_rect().size - size) / 2.0).floor()
	_ubicada = true


## Mantiene la ventana dentro de la pantalla.
##
## No exige que entre entera, solo que la barra de titulo quede al alcance: una
## ventana que se fue de la pantalla y no se puede agarrar es una ventana
## perdida, pero una que asoma a medias es una decision del jugador.
func _encajar() -> void:
	if not is_inside_tree():
		return
	var pantalla := get_viewport_rect().size
	var visible_minimo := 64.0
	position.x = clampf(position.x, visible_minimo - size.x, pantalla.x - visible_minimo)
	position.y = clampf(position.y, 0.0, pantalla.y - 40.0)
