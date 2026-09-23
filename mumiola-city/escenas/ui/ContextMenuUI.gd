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

## Cuanto se corre el menu respecto del objeto, en pixeles.
##
## Arriba y a la derecha: abajo taparia el mueble que estas mirando, y con el
## cursor justo encima de la primera opcion es facil elegirla sin querer.
@export var desplazamiento : Vector2i = Vector2i(14, -12)

var _objeto : WorldObject = null
var _actor : Node = null
var _verbos : Array[InteractionBehavior] = []


func _ready() -> void:
	id_pressed.connect(_al_elegir)
	popup_hide.connect(_al_cerrarse)
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

	_abrir_junto_a(objeto)
	return true


## Abre el menu pegado al objeto y sin que se corte contra el borde.
##
## reset_size() primero, y no es opcional: hasta que se llama, size sigue siendo
## el del menu anterior, y recortar contra el borde con el tamanio viejo dejaria
## cortado justo al menu con mas opciones, que es el unico caso en que importa.
## Despues de reset_size() el tamanio ya es el bueno, asi que alcanza con abrirlo
## una sola vez en el lugar correcto; corregir la posicion despues de popup() no
## funciona, porque el segundo seteo se pisa con el primero.
func _abrir_junto_a(objeto : WorldObject) -> void:
	reset_size()
	popup(Rect2i(_a_coordenadas_de_popup(_posicion_para(objeto, size)), Vector2i.ZERO))


## Traduce coordenadas del viewport a las que espera popup().
##
## Con las subventanas embebidas —lo que hace Godot por defecto— un PopupMenu se
## dibuja dentro del viewport y se posiciona en sus coordenadas. Sin embeber es
## una ventana del escritorio y hay que sumarle donde esta la ventana del juego.
##
## Este era el bug: el menu se abria con DisplayServer.mouse_get_position(), que
## devuelve la posicion contra el escritorio, y embebido eso cae en cualquier
## lado menos donde esta el mouse.
func _a_coordenadas_de_popup(punto : Vector2i) -> Vector2i:
	var raiz := get_tree().root
	return punto if raiz.gui_embed_subwindows else punto + raiz.position


## Donde abrir el menu: al lado del objeto, dentro de la pantalla.
##
## Junto al objeto y no bajo el cursor porque el menu actua sobre el mueble, y
## que aparezca pegado a el lo dice sin explicarlo. Ademas queda en el mismo
## lugar sin importar si clickeaste el borde o el medio de una mesa de dos por
## dos, y sirve igual el dia que el menu se abra sin un clic —desde el teclado o
## desde una seleccion—, que con la posicion del mouse no funcionaria.
##
## Devuelve coordenadas del viewport; traducirlas a las de popup() es trabajo de
## _a_coordenadas_de_popup().
func _posicion_para(objeto : WorldObject, tamano : Vector2i) -> Vector2i:
	# El viewport del juego y no get_viewport(), que aca devuelve otra cosa: un
	# PopupMenu es una Window, y una Window es un Viewport, asi que get_viewport()
	# devuelve el del propio menu. Con eso el limite de pantalla era el tamanio
	# del menu —cuarenta por ocho pixeles— y el recorte aplastaba cualquier
	# posicion contra el origen. De ahi que apareciera siempre en la esquina.
	var padre := get_parent()
	var vista : Viewport = padre.get_viewport() if padre != null else null
	if vista == null:
		vista = get_tree().root
	var limite := Vector2i(vista.get_visible_rect().size)

	# Respaldo: si no hay camara a mano, al menos cerca del cursor.
	var punto := Vector2i(vista.get_mouse_position())

	var sala := objeto.sala()
	if sala != null and sala.camara != null and sala.camara.is_inside_tree():
		var mundo := objeto.global_position
		# Un objeto detras de la camara proyecta a coordenadas sin sentido.
		if not sala.camara.is_position_behind(mundo):
			punto = Vector2i(sala.camara.unproject_position(mundo))

	punto += desplazamiento
	punto.x = clampi(punto.x, 0, maxi(0, limite.x - tamano.x))
	punto.y = clampi(punto.y, 0, maxi(0, limite.y - tamano.y))
	return punto


## Al cerrarse, pide que el clic que lo cerro no llegue al mundo.
##
## Sin esto, cancelar el menu manda al personaje a caminar hasta donde
## clickeaste: el clic cierra el popup y despues sigue viaje hasta
## _unhandled_input. Cerrar un menu y ordenar un movimiento son dos intenciones
## distintas, y el mismo clic no puede ser las dos.
func _al_cerrarse() -> void:
	GameManager.descartar_clic()


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
