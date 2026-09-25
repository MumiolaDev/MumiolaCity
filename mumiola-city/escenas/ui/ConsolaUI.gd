extends PanelContainer
class_name ConsolaUI

## La caja de abajo a la izquierda: chat, avisos y depuracion, como en Tibia o
## RuneScape.
##
## Solo muestra lo que publica el autoload Consola y le pasa lo que el jugador
## escribe. No guarda mensajes propios: al aparecer se pone al dia con el
## historial de la consola, asi que puede nacer y morir con cada escena.
##
## Enter abre el campo para escribir, Enter de nuevo manda, Esc lo suelta sin
## mandar. Con el campo tomado el teclado es de la caja y no del mundo: escribir
## "b" no cambia de modo. Al mandar se suelta sola, porque el juego se juega con
## el mouse y el campo tomado solo estorbaria. La barra abre el campo con la
## barra ya escrita, que es el atajo de los comandos.
##
## Flechas arriba y abajo recorren lo que ya mandaste.

## Filtros de las pestanas, en el mismo orden que los botones.
enum Filtro { TODO, CHAT, SISTEMA, DEBUG }

## Colores por canal. Salen de la paleta del tema cuando hay equivalente.
@export var color_autor : Color = Color("ffc579")
@export var color_sistema : Color = Color("9fd3ff")
@export var color_error : Color = Color("ff8a7a")
@export var color_debug : Color = Color("9a9a9a")
## Cuan visible queda la caja cuando no la estas usando.
@export_range(0.2, 1.0) var opacidad_reposo : float = 0.75

## Cuantas lineas mandadas se recuerdan para las flechas.
const MAXIMO_ENVIADAS := 30

@onready var _texto : RichTextLabel = %Texto
@onready var _campo : LineEdit = %Campo
@onready var _filtros : HBoxContainer = %Filtros

var _filtro : Filtro = Filtro.TODO
var _enviadas : Array[String] = []
## Donde esta parado el recorrido con las flechas. -1 es "escribiendo algo nuevo".
var _indice_enviada : int = -1


func _ready() -> void:
	var grupo := ButtonGroup.new()
	var i := 0
	for boton in _filtros.get_children():
		if boton is Button:
			boton.toggle_mode = true
			boton.button_group = grupo
			boton.focus_mode = Control.FOCUS_NONE
			boton.button_pressed = i == Filtro.TODO
			boton.pressed.connect(_elegir_filtro.bind(i))
			i += 1

	_campo.text_submitted.connect(_al_enviar)
	_campo.gui_input.connect(_al_input_campo)
	_campo.focus_entered.connect(_actualizar_opacidad)
	_campo.focus_exited.connect(_actualizar_opacidad)
	mouse_entered.connect(_actualizar_opacidad)
	mouse_exited.connect(_actualizar_opacidad)

	Consola.mensaje_publicado.connect(_al_publicar)
	Consola.limpiada.connect(_redibujar)
	Consola.debug_cambiado.connect(func(_v : bool) -> void: _redibujar())

	_redibujar()
	_actualizar_opacidad()


## Toma el teclado para escribir, opcionalmente con un texto ya puesto.
func escribir(inicial : String = "") -> void:
	_campo.text = inicial
	_campo.grab_focus()
	_campo.caret_column = inicial.length()


## Devuelve si el jugador esta escribiendo en la caja.
func escribiendo() -> bool:
	return _campo.has_focus()


func _unhandled_key_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		escribir()
		get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_SLASH or evento.unicode == 47:
		escribir("/")
		get_viewport().set_input_as_handled()


func _al_enviar(texto : String) -> void:
	texto = texto.strip_edges()
	_campo.clear()
	_campo.release_focus()
	_indice_enviada = -1
	if texto.is_empty():
		return
	if _enviadas.is_empty() or _enviadas[-1] != texto:
		_enviadas.append(texto)
		if _enviadas.size() > MAXIMO_ENVIADAS:
			_enviadas.pop_front()
	Consola.enviar(texto)


func _al_input_campo(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed:
		return
	match evento.keycode:
		KEY_ESCAPE:
			_campo.clear()
			_campo.release_focus()
			_indice_enviada = -1
			_campo.accept_event()
		KEY_UP:
			_recorrer_enviadas(-1)
			_campo.accept_event()
		KEY_DOWN:
			_recorrer_enviadas(1)
			_campo.accept_event()


## Trae al campo una linea ya mandada. -1 va hacia atras en el tiempo.
func _recorrer_enviadas(paso : int) -> void:
	if _enviadas.is_empty():
		return
	if _indice_enviada == -1:
		_indice_enviada = _enviadas.size() if paso < 0 else -1
	_indice_enviada += paso
	if _indice_enviada < 0:
		_indice_enviada = 0
	if _indice_enviada >= _enviadas.size():
		_indice_enviada = -1
		_campo.clear()
		return
	_campo.text = _enviadas[_indice_enviada]
	_campo.caret_column = _campo.text.length()


func _elegir_filtro(filtro : int) -> void:
	_filtro = filtro as Filtro
	_redibujar()


func _al_publicar(mensaje : Dictionary) -> void:
	if _se_ve(mensaje):
		_texto.append_text(_formatear(mensaje) + "\n")


## Vuelve a escribir todo el historial con el filtro actual.
func _redibujar() -> void:
	_texto.clear()
	for mensaje in Consola.historial():
		if _se_ve(mensaje):
			_texto.append_text(_formatear(mensaje) + "\n")


func _se_ve(mensaje : Dictionary) -> bool:
	var canal : int = mensaje.canal
	if canal == Consola.Canal.DEBUG and not Consola.mostrar_debug:
		return false
	match _filtro:
		Filtro.CHAT:
			return canal == Consola.Canal.CHAT
		Filtro.SISTEMA:
			return canal == Consola.Canal.SISTEMA or canal == Consola.Canal.ERROR
		Filtro.DEBUG:
			return canal == Consola.Canal.DEBUG
	return true


## Convierte un mensaje en una linea con color.
##
## El texto se escapa antes de ponerle color: lo escribe una persona, y con red
## lo escribe otra persona. Sin escapar, "[img]..." en un chat se interpretaria
## como etiqueta en la pantalla de todos los que lo lean.
func _formatear(mensaje : Dictionary) -> String:
	var texto := _escapar(str(mensaje.texto))
	match mensaje.canal as int:
		Consola.Canal.CHAT:
			return "[color=#%s]%s:[/color] %s" % [
				color_autor.to_html(false), _escapar(str(mensaje.autor_nombre)), texto]
		Consola.Canal.SISTEMA:
			return "[color=#%s]%s[/color]" % [color_sistema.to_html(false), texto]
		Consola.Canal.ERROR:
			return "[color=#%s]%s[/color]" % [color_error.to_html(false), texto]
		Consola.Canal.DEBUG:
			return "[color=#%s][lb]debug] %s[/color]" % [color_debug.to_html(false), texto]
	return texto


func _escapar(texto : String) -> String:
	return texto.replace("[", "[lb]")


## Opaca mientras la usas, translucida mientras no, para tapar menos el mundo.
func _actualizar_opacidad() -> void:
	var activa := _campo.has_focus() or get_global_rect().has_point(get_global_mouse_position())
	modulate.a = 1.0 if activa else opacidad_reposo
