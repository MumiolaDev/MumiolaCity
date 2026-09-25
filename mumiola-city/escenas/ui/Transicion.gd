extends CanvasLayer

## El telon entre una sala y otra: funde a negro, espera a que lo de atras este
## listo, y vuelve a abrir.
##
## Es un autoload de escena, y no parte del mundo, porque tiene que sobrevivir a
## los cambios de escena: el menu de inicio lo cierra, la escena cambia debajo, y
## el mundo lo abre cuando ya entro a su sala.
##
## Se usa con await y en dos pasos, con el trabajo en el medio:
##
##     await Transicion.cubrir()
##     ... cargar la sala, que manana puede tardar ...
##     await Transicion.descubrir()
##
## Cubrir cuando ya esta cubierto no espera nada. Eso es lo que deja que el primer
## ingreso a una sala —con la pantalla que ya viene negra del menu— ocurra en el
## mismo cuadro, sin un fundido de mas.
##
## Mientras cubre se traga los clics: nadie tiene que poder caminar hacia una
## sala que se esta yendo. Mientras descubre ya los deja pasar, porque la sala
## nueva ya esta y hacer esperar al jugador medio segundo a que termine un
## fundido es puro estorbo.

## Cuanto tarda en cerrarse o abrirse.
@export var duracion : float = 0.25
## Cuanto queda cerrado como minimo. Sin esto, una carga instantanea da un
## parpadeo negro que se lee como un error y no como un cambio de lugar.
@export var minimo_cubierto : float = 0.15

@onready var _velo : ColorRect = $Velo
@onready var _texto : Label = $Velo/Texto

var _cubierto : bool = false
var _cubierto_desde : int = 0
var _animacion : Tween = null


func _ready() -> void:
	_velo.modulate.a = 0.0
	_velo.visible = false
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Cierra el telon. Devuelve cuando ya esta cerrado.
func cubrir(texto : String = "Cargando...") -> void:
	_texto.text = texto
	if _cubierto:
		return
	_cubierto = true
	_velo.visible = true
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animar(1.0)
	_cubierto_desde = Time.get_ticks_msec()


## Cierra el telon de golpe, sin fundido. Para cuando la pantalla ya viene negra.
func cubrir_ya(texto : String = "Cargando...") -> void:
	_detener()
	_texto.text = texto
	_cubierto = true
	_velo.visible = true
	_velo.modulate.a = 1.0
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_cubierto_desde = Time.get_ticks_msec()


## Abre el telon. Devuelve cuando ya esta abierto.
func descubrir() -> void:
	if not _cubierto:
		return
	_cubierto = false
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var falta := minimo_cubierto - (Time.get_ticks_msec() - _cubierto_desde) / 1000.0
	if falta > 0.0:
		await get_tree().create_timer(falta).timeout
	# Si mientras se esperaba alguien volvio a cubrir, no se abre.
	if _cubierto:
		return
	await _animar(0.0)
	if not _cubierto:
		_velo.visible = false


## Devuelve si el telon esta cerrado o cerrandose.
func esta_cubierto() -> bool:
	return _cubierto


func _animar(alfa : float) -> void:
	_detener()
	_animacion = create_tween()
	_animacion.tween_property(_velo, "modulate:a", alfa, duracion * absf(_velo.modulate.a - alfa))
	await _animacion.finished


func _detener() -> void:
	if _animacion != null and _animacion.is_valid():
		_animacion.kill()
	_animacion = null
