extends Ventana
class_name Dialogo

## Una pregunta que hay que contestar antes de seguir: confirmar algo, o escribir
## un texto corto.
##
## Se usa con await y sin escena:
##
##     var d := Dialogo.confirmar(self, "Borrar sala", "¿Borrar 'Taller'?")
##     var r : Dictionary = await d.respondido
##     if r.aceptado: ...
##
## Es modal: mientras esta abierto, un velo tapa el resto de la interfaz y el
## mundo, asi que no hay clics que se escapen por detras. El velo es su padre y
## se va con el dialogo.
##
## Enter acepta y Esc cancela, como en cualquier ventana de sistema.

## Se contesto. {"aceptado": bool, "texto": String}. Un diccionario y no dos
## argumentos porque await de una senal con varios argumentos devuelve un array,
## y r.aceptado se lee mejor que r[0].
signal respondido(respuesta : Dictionary)

var _campo : LineEdit = null
var _velo : ColorRect = null


## Pregunta si o no. Devuelve el dialogo ya abierto; esperar respondido.
static func confirmar(padre : Node, titulo_dialogo : String, texto : String,
		aceptar : String = "Aceptar", cancelar : String = "Cancelar") -> Dialogo:
	var d := Dialogo.new()
	d._armar_pregunta(titulo_dialogo, texto, aceptar, cancelar, false, "")
	d._mostrar_en(padre)
	return d


## Pide un texto. Devuelve el dialogo ya abierto; esperar respondido.
static func pedir_texto(padre : Node, titulo_dialogo : String, texto : String,
		inicial : String = "", aceptar : String = "Aceptar") -> Dialogo:
	var d := Dialogo.new()
	d._armar_pregunta(titulo_dialogo, texto, aceptar, "Cancelar", true, inicial)
	d._mostrar_en(padre)
	return d


## Cierra el dialogo con una respuesta.
func responder(aceptado : bool) -> void:
	var texto := _campo.text.strip_edges() if _campo != null else ""
	respondido.emit({"aceptado": aceptado, "texto": texto})
	if is_instance_valid(_velo):
		_velo.queue_free()
	else:
		queue_free()


## La cruz cuenta como cancelar.
func cerrar() -> void:
	super.cerrar()
	responder(false)


func _unhandled_key_input(evento : InputEvent) -> void:
	if not visible or not (evento is InputEventKey) or not evento.pressed:
		return
	if evento.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		responder(false)
	elif evento.keycode in [KEY_ENTER, KEY_KP_ENTER] and _campo == null:
		get_viewport().set_input_as_handled()
		responder(true)


func _armar_pregunta(titulo_dialogo : String, texto : String, aceptar : String,
		cancelar : String, con_campo : bool, inicial : String) -> void:
	titulo = titulo_dialogo
	custom_minimum_size = Vector2(360, 0)

	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override(&"separation", 12)

	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.custom_minimum_size = Vector2(320, 0)
	contenido.add_child(etiqueta)

	if con_campo:
		_campo = LineEdit.new()
		_campo.text = inicial
		_campo.max_length = 40
		_campo.select_all_on_focus = true
		_campo.text_submitted.connect(func(_t : String) -> void: responder(true))
		contenido.add_child(_campo)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	botones.add_theme_constant_override(&"separation", 8)
	var boton_cancelar := Button.new()
	boton_cancelar.text = cancelar
	boton_cancelar.pressed.connect(responder.bind(false))
	botones.add_child(boton_cancelar)
	var boton_aceptar := Button.new()
	boton_aceptar.text = aceptar
	boton_aceptar.pressed.connect(responder.bind(true))
	botones.add_child(boton_aceptar)
	contenido.add_child(botones)

	add_child(contenido)


## Cuelga el dialogo, con su velo, del padre dado y lo abre.
func _mostrar_en(padre : Node) -> void:
	_velo = ColorRect.new()
	_velo.name = "VeloDialogo"
	_velo.color = Color(0, 0, 0, 0.35)
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.add_child(self)
	padre.add_child(_velo)
	abrir()
	if _campo != null:
		_campo.grab_focus.call_deferred()
