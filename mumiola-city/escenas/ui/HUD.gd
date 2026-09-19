class_name HUD
extends CanvasLayer

## La capa fija de interfaz: donde estas, que acaba de pasar y como se juega.
##
## Se suscribe y nunca la consultan. Se puede borrar del arbol y el juego sigue
## funcionando, que es el test de que la capa de UI esta bien puesta.
##
## Lo que muestra hoy es lo que existe hoy. La barra de energia y los Ducados
## estan declarados porque su API es la que el resto del juego va a llamar en la
## fase 2, pero arrancan ocultos: una barra vacia y un cero no informan nada y
## ensucian la pantalla durante toda la fase 1.

## Cuanto dura en pantalla un aviso antes de desvanecerse.
@export var segundos_mensaje : float = 3.0

@onready var _sala : Label = $Sala
@onready var _mensaje : Label = $Mensaje
@onready var _ayuda : Label = $Ayuda
@onready var _estado : HBoxContainer = $Estado
@onready var _energia : ProgressBar = $Estado/Energia
@onready var _ducados : Label = $Estado/Ducados
@onready var _reloj : Timer = $RelojMensaje


func _ready() -> void:
	_mensaje.text = ""
	_estado.visible = false
	_reloj.timeout.connect(_ocultar_mensaje)

	# Se suscribe y nadie lo consulta: por eso el HUD se puede borrar del arbol y
	# el juego sigue andando.
	GameManager.sala_cambiada.connect(mostrar_sala)
	mostrar_sala(GameManager.sala_actual())


## Escribe en que sala esta el jugador.
func mostrar_sala(sala : RoomController) -> void:
	if sala == null:
		_sala.text = ""
		return
	_sala.text = sala.nombre_sala if sala.nombre_sala != "" else sala.name


## Muestra un aviso pasajero.
##
## Reinicia el reloj en cada aviso en vez de encolarlos: si algo falla tres veces
## seguidas, lo que importa es el ultimo mensaje y no leer los tres en fila.
func avisar(texto : String) -> void:
	_mensaje.text = texto
	_mensaje.modulate.a = 1.0
	_reloj.start(segundos_mensaje)


## Muestra el mensaje que le corresponde a un codigo de rechazo.
##
## Es el punto donde Errores.mensaje() deja de ser texto que nadie lee: los
## codigos existen justamente para poder decirle al jugador por que no se pudo.
func avisar_error(codigo : Errores.Codigo) -> void:
	if not Errores.ok(codigo):
		avisar(Errores.mensaje(codigo))


## Escribe la ayuda fija de la esquina.
##
## El texto lo pasa quien llama y no vive aca, porque hoy son los atajos
## provisionales de Mundo: cuando dejen de existir, este Label se queda sin que
## haya que tocar el HUD.
func mostrar_ayuda(texto : String) -> void:
	_ayuda.text = texto


## Actualiza la barra de energia. Al primer valor, la deja visible.
func actualizar_energia(valor : float) -> void:
	_estado.visible = true
	_energia.value = valor


## Actualiza el contador de Ducados. Al primer valor, lo deja visible.
func actualizar_ducados(valor : int) -> void:
	_estado.visible = true
	_ducados.text = "%d D" % valor


func _ocultar_mensaje() -> void:
	var animacion := create_tween()
	animacion.tween_property(_mensaje, "modulate:a", 0.0, 0.4)
