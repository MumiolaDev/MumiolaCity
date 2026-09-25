extends Ventana
class_name OpcionesUI

## Las opciones de este equipo: pantalla completa, volumen y las lineas de
## depuracion.
##
## Son del cliente y no del perfil, a proposito: la pantalla completa depende
## del monitor en el que se juega, no de quien juega. Por eso van a su propio
## archivo en user:// y no pasan por Servidor.
##
## La misma ventana sirve en el menu de inicio y en el de pausa.

const RUTA := "user://opciones.cfg"


## Lee las opciones guardadas y las aplica. Lo llama el menu de inicio al
## arrancar, antes de que se vea nada.
static func aplicar_guardadas() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUTA)
	_aplicar_pantalla(cfg.get_value("pantalla", "completa", false))
	_aplicar_volumen(cfg.get_value("sonido", "volumen", 0.8))
	Consola.set_mostrar_debug(cfg.get_value("interfaz", "debug", OS.is_debug_build()))


static func _aplicar_pantalla(completa : bool) -> void:
	# Los tests corren sin ventana: pedirle modos al servidor de pantalla ahi
	# solo ensucia la salida.
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if completa else DisplayServer.WINDOW_MODE_WINDOWED)


static func _aplicar_volumen(lineal : float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(lineal, 0.0, 1.0)))
	AudioServer.set_bus_mute(0, lineal <= 0.001)


var _completa : CheckBox = null
var _volumen : HSlider = null
var _debug : CheckBox = null


func _ready() -> void:
	titulo = "Opciones"
	custom_minimum_size = Vector2(380, 0)

	var hoja := VBoxContainer.new()
	hoja.add_theme_constant_override(&"separation", 12)

	_completa = CheckBox.new()
	_completa.text = "Pantalla completa"
	_completa.toggled.connect(func(v : bool) -> void:
		_aplicar_pantalla(v)
		_guardar())
	hoja.add_child(_completa)

	var etiqueta := Label.new()
	etiqueta.text = "Volumen"
	hoja.add_child(etiqueta)
	_volumen = HSlider.new()
	_volumen.min_value = 0.0
	_volumen.max_value = 1.0
	_volumen.step = 0.05
	_volumen.value_changed.connect(func(v : float) -> void:
		_aplicar_volumen(v)
		_guardar())
	hoja.add_child(_volumen)

	_debug = CheckBox.new()
	_debug.text = "Mostrar lineas de depuracion en el chat"
	_debug.toggled.connect(func(v : bool) -> void:
		Consola.set_mostrar_debug(v)
		_guardar())
	hoja.add_child(_debug)

	add_child(hoja)
	super._ready()


## Abre la ventana mostrando lo que esta vigente.
func abrir() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RUTA)
	_completa.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.get_name() != "headless" else cfg.get_value("pantalla", "completa", false))
	_volumen.set_value_no_signal(cfg.get_value("sonido", "volumen", 0.8))
	_debug.set_pressed_no_signal(Consola.mostrar_debug)
	super.abrir()


func _guardar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("pantalla", "completa", _completa.button_pressed)
	cfg.set_value("sonido", "volumen", _volumen.value)
	cfg.set_value("interfaz", "debug", _debug.button_pressed)
	cfg.save(RUTA)
