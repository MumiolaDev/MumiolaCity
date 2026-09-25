extends Control
class_name MenuPausa

## El menu de Esc: seguir, opciones, volver al menu de inicio o salir.
##
## No pausa nada, aunque se llame asi: en un mundo en linea el tiempo de los
## demas no se detiene porque vos abras un menu, y conviene que el juego se
## comporte igual desde ahora. Solo tapa la pantalla y se come los clics.
##
## Esc lo abre solo si no hay ninguna ventana abierta: la primera tecla cierra lo
## que tengas adelante, y recien cuando no queda nada abre el menu. Por eso va
## ultimo entre sus hermanos —se dibuja encima— pero antes de actuar pregunta.

const ESCENA_INICIO := "res://escenas/menu/MenuInicio.tscn"

@export var opciones : Ventana

@onready var _continuar : Button = %Continuar
@onready var _opciones : Button = %Opciones
@onready var _volver : Button = %Volver
@onready var _salir : Button = %Salir


func _ready() -> void:
	hide()
	_continuar.pressed.connect(cerrar)
	_opciones.disabled = opciones == null
	_opciones.pressed.connect(func() -> void:
		cerrar()
		opciones.abrir())
	_volver.pressed.connect(volver_al_inicio)
	_salir.pressed.connect(salir)


## Muestra el menu.
func abrir() -> void:
	show()
	move_to_front()
	_continuar.grab_focus()


## Esconde el menu.
func cerrar() -> void:
	hide()


## Guarda todo y vuelve al menu de inicio.
func volver_al_inicio() -> void:
	_bloquear()
	await SaveManager.guardar_todo()
	await Transicion.cubrir("Guardando...")
	GameManager.cerrar_sesion()
	get_tree().change_scene_to_file(ESCENA_INICIO)


## Guarda todo y cierra el juego.
func salir() -> void:
	_bloquear()
	await SaveManager.guardar_todo()
	get_tree().quit()


func _unhandled_key_input(evento : InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode != KEY_ESCAPE:
		return
	if visible:
		cerrar()
		get_viewport().set_input_as_handled()
	elif not _hay_ventana_abierta():
		abrir()
		get_viewport().set_input_as_handled()


func _hay_ventana_abierta() -> bool:
	for hermano in get_parent().get_children():
		if hermano is Ventana and hermano.visible:
			return true
	return false


## Apaga los botones mientras se guarda: un segundo clic en Salir no tiene que
## guardar dos veces.
func _bloquear() -> void:
	for b in [_continuar, _opciones, _volver, _salir]:
		b.disabled = true
