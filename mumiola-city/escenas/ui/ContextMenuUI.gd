class_name ContextMenuUI
extends PopupMenu

## El menu que lista los verbos de un objeto del mundo.
##
## No conoce ningun verbo, y eso no es un detalle: se puebla con lo que devuelve
## WorldObject.verbos_disponibles() y mapea el indice elegido de vuelta al
## comportamiento. Agregar un verbo nuevo al juego no toca este archivo, y ese es
## el test de que el sistema de verbos del GDD 6.1 esta bien planteado. Si algun
## dia hay que editar aca para sumar un verbo, algo se rompio antes.
##
## Tampoco ejecuta nada. Avisa que se eligio, y quien escucha decide: hoy el
## personaje, que camina hasta el mueble antes de actuar; manana podria ser un
## servidor que valida primero (D8).

## Se emite al elegir una opcion del menu.
signal verbo_elegido(verbo : InteractionBehavior, objeto : WorldObject, actor : Node)

var _objeto : WorldObject = null
var _actor : Node = null
var _verbos : Array[InteractionBehavior] = []


func _ready() -> void:
	id_pressed.connect(_al_elegir)
	hide()


## Abre el menu para un objeto, poblado con lo que el actor puede hacerle ahora.
##
## Si no hay nada que hacer no abre un menu vacio: un popup con cero opciones se
## lee como un bug. Devuelve si llego a abrirse, para que quien llame pueda
## avisar por otro lado.
func mostrar_para(objeto : WorldObject, actor : Node) -> bool:
	clear()
	_objeto = objeto
	_actor = actor
	_verbos = []

	if objeto == null or actor == null:
		return false

	_verbos = objeto.verbos_disponibles(actor)
	if _verbos.is_empty():
		hide()
		return false

	for i in _verbos.size():
		var verbo := _verbos[i]
		var texto := verbo.etiqueta_para(actor, objeto)
		if texto == "":
			texto = String(verbo.verbo)
		if verbo.icono != null:
			add_icon_item(verbo.icono, texto, i)
		else:
			add_item(texto, i)

	# En coordenadas de pantalla y no del viewport: un PopupMenu es una Window
	# aparte, asi que se posiciona contra el escritorio. PopupMenu se encarga solo
	# de no quedar cortado contra el borde.
	popup(Rect2i(DisplayServer.mouse_get_position(), Vector2i.ZERO))
	return true


## Traduce el indice elegido de vuelta al comportamiento y avisa.
##
## Vuelve a comprobar que el objeto siga vivo: entre que el menu se abrio y el
## jugador eligio, el mueble pudo retirarse.
func _al_elegir(id : int) -> void:
	if id < 0 or id >= _verbos.size():
		return
	if not is_instance_valid(_objeto) or not is_instance_valid(_actor):
		return
	verbo_elegido.emit(_verbos[id], _objeto, _actor)
