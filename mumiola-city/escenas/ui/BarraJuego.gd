extends PanelContainer
class_name BarraJuego

## La barra de abajo, como la de Habbo: los botones de todo lo que tiene
## ventana, mas editar la sala.
##
## Cada boton hace lo mismo que su atajo de teclado, asi que nada queda
## escondido detras de una tecla que hay que saber. Las ventanas se le pasan
## por @export y cualquiera puede faltar: su boton se apaga y el resto anda.
##
## Editar se apaga en una sala que no es tuya, por la misma regla que usa el
## servidor para guardarla (RoomController.puede_editar). Guardar solo aparece
## editando: salir del editor y dejar la sala ya guardan solos, y el boton es
## para quien quiere asegurarse a mitad de una obra.

## Se apreto Menu. Lo atiende quien tenga el menu de pausa.
signal menu_pedido()

@export var navegador : Ventana
@export var ayuda : Ventana
## El inventario, cuando exista. Mientras falte, el boton queda apagado.
@export var inventario : Ventana

@onready var _salas : Button = %Salas
@onready var _editar : Button = %Editar
@onready var _guardar : Button = %Guardar
@onready var _mochila : Button = %Mochila
@onready var _ayuda : Button = %Ayuda
@onready var _menu : Button = %Menu


func _ready() -> void:
	for b in [_salas, _editar, _guardar, _mochila, _ayuda, _menu]:
		b.focus_mode = Control.FOCUS_NONE

	_conectar_ventana(_salas, navegador)
	_conectar_ventana(_ayuda, ayuda)
	_conectar_ventana(_mochila, inventario)
	if inventario == null:
		_mochila.tooltip_text = "La mochila todavia no tiene ventana. Mientras tanto: /inv"

	_editar.toggle_mode = true
	_editar.toggled.connect(_al_apretar_editar)
	_guardar.pressed.connect(_al_guardar)
	_menu.pressed.connect(menu_pedido.emit)

	GameManager.modo_cambiado.connect(func(_m : GameManager.Modo) -> void: _actualizar())
	GameManager.sala_cambiada.connect(func(_s : RoomController) -> void: _actualizar())
	_actualizar()


func _conectar_ventana(boton : Button, ventana : Ventana) -> void:
	boton.disabled = ventana == null
	if ventana != null:
		boton.pressed.connect(ventana.alternar)


func _al_apretar_editar(apretado : bool) -> void:
	if apretado != GameManager.editando():
		GameManager.alternar_modo()


func _al_guardar() -> void:
	var sala := GameManager.sala_actual()
	var codigo : Errores.Codigo = await GameManager.guardar_sala_actual()
	if Errores.ok(codigo) and sala != null:
		GameManager.avisar("Sala '%s' guardada." % sala.nombre_sala)
	else:
		GameManager.avisar_error(codigo)


## Pone los botones de acuerdo al modo y a la sala.
func _actualizar() -> void:
	var sala := GameManager.sala_actual()
	var puede := sala != null and sala.puede_editar(GameManager.jugador_actual())
	_editar.disabled = not puede
	_editar.tooltip_text = "Editar la sala (B)" if puede else "Solo se puede editar una sala tuya."
	_editar.set_pressed_no_signal(GameManager.editando())
	_editar.text = "Listo" if GameManager.editando() else "Editar"
	_guardar.visible = GameManager.editando()
