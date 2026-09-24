class_name WorldObject
extends Area3D

## Todo lo que un jugador coloca en una sala. El GridMap es escenario; esto es lo
## tocable, lo que tiene dueno, estado y verbos.
##
## Hereda de Area3D porque lo unico que necesita del motor es recibir clics; la
## ocupacion de celdas no la lleva el la fisica sino IsoGrid, asi que su
## CollisionShape3D no tiene que seguir la malla: una caja del tamano de la celda
## alcanza y es mas barata.

## El verbo que tiene absolutamente todo objeto del mundo.
##
## No vive en items.json ni en la lista de interacciones de cada item, y es a
## proposito: mirar es una propiedad de ser un objeto del mundo, no contenido de
## un item concreto. Si estuviera en el catalogo habria que acordarse de
## agregarlo a cada item nuevo, y olvidarse no daria error — simplemente ese
## mueble no se podria mirar, que es la clase de hueco que se descubre tarde.
##
## Tambien alcanza asi a los objetos que no vienen del catalogo, como una mesada
## puesta a mano en una sala.
const MIRAR : InteractionBehavior = preload("res://data/objetos/comportamientos/mirar.tres")

## El otro verbo universal: sacar el objeto de la sala y guardarlo.
##
## Vive aca por lo mismo que mirar. Todo lo que se pudo colocar se puede volver
## a levantar, asi que si estuviera en la lista de interacciones de cada item
## seria una lista que hay que acordarse de completar, y olvidarse no daria
## error: ese mueble quedaria clavado en el piso y nadie se enteraria hasta
## intentar sacarlo.
##
## A diferencia de mirar, este si puede negarse — ver LevantarBehavior.
const LEVANTAR : InteractionBehavior = preload("res://data/objetos/comportamientos/levantar.tres")

## Se emite despues de que un verbo se ejecuto de verdad.
signal interactuado(behavior : InteractionBehavior, actor : Node)

## Se emite al hacerle clic derecho. Lleva el objeto consigo para que un solo
## manejador pueda atender a todos los muebles de la sala.
signal clickeado(objeto : WorldObject)

## El estado persistente de este objeto concreto. Nunca es null, ni siquiera para
## una silla que no tiene estado propio.
##
## Es una asimetria a proposito con el inventario, que si apila sin instancia
## todo lo que no tiene estado (D1): el inventario optimiza por volumen —99
## maderas no pueden ser 99 recursos— y el mundo por uniformidad, porque 50
## objetos en una sala si pueden serlo, y a cambio ningun script del mundo tiene
## que preguntar si hay instancia o no. La conversion entre las dos formas pasa
## solo en RoomController.colocar_objeto() y retirar_objeto().
@export var instancia : ItemInstance

## Donde esta parado y como esta girado.
##
## No van en la instancia aunque tambien sean datos de este objeto: son del
## emplazamiento, no del objeto. Un mismo ItemInstance puede estar en distintas
## celdas a lo largo de su vida, y mientras esta en la mochila no esta en
## ninguna. Los persiste RoomController.
@export var celda_origen : Vector2i = Vector2i.ZERO
@export var rotacion_grilla : int = 0

## El estado de la sesion, que no se serializa.
##
## Es el unico lugar del juego donde se permite guardar una referencia a un nodo
## vivo (D3). El criterio para elegir entre esto y la instancia es una sola
## pregunta: 'tiene sentido que esto siga siendo cierto manana?'. Quien esta
## sentado, no. Que contiene la taza, si.
var estado_runtime : Dictionary = {}


func _ready() -> void:
	input_event.connect(_al_recibir_clic)

	if instancia == null:
		push_error(
			"WorldObject en %s: 'instancia' es null. Todo objeto del mundo tiene la suya, " % name
			+ "incluso los que no vienen de un item: esas escenas la traen creada adentro del .tscn."
		)


## Devuelve la definicion del item que este objeto representa, o null si falta.
func definicion() -> ItemDefinition:
	return null if instancia == null else instancia.definicion()


## Devuelve el nombre para mostrarle al jugador.
func nombre_mostrado() -> String:
	return "" if instancia == null else instancia.nombre_mostrado()


## Devuelve la sala a la que pertenece, o null si todavia no esta en ninguna.
##
## Sube por el arbol buscando el tipo en vez de asumir una profundidad fija: hoy
## el objeto cuelga de Objetos y Objetos de la sala, pero encadenar dos
## get_parent() deja de funcionar en cuanto alguien agrupa los muebles por
## categoria o los mete en un subnodo.
func sala() -> RoomController:
	var nodo := get_parent()
	while nodo != null:
		if nodo is RoomController:
			return nodo
		nodo = nodo.get_parent()
	return null


## Devuelve las celdas que ocupa, segun su tamano y su rotacion.
##
## Recibe la grilla en vez de buscarla hacia arriba en el arbol: la expansion de
## la huella ya esta escrita una sola vez en IsoGrid.celdas_de(), y duplicarla
## aca seria tener dos definiciones de que celdas ocupa una mesa de 2x2, que
## tarde o temprano dejan de coincidir.
func celdas_ocupadas(grid : IsoGrid) -> Array[Vector2i]:
	var def := definicion()
	var size := Vector2i.ONE if def == null else def.tamano_grilla
	return grid.celdas_de(celda_origen, size, rotacion_grilla)


## Devuelve los verbos que el actor puede ejecutar sobre este objeto ahora mismo.
func verbos_disponibles(actor : Node) -> Array[InteractionBehavior]:
	var salida : Array[InteractionBehavior] = []
	var def := definicion()
	if def != null:
		for comportamiento in def.interacciones:
			if comportamiento != null and comportamiento.puede_interactuar(actor, self):
				salida.append(comportamiento)

	# Los dos universales van al final y en este orden. Lo que el jugador suele
	# querer es la accion del mueble, asi que esas van primero; levantar es
	# destructivo y no tiene que quedar bajo el cursor al abrirse el menu; y
	# mirar es lo que queda cuando no hay otra cosa, asi que cierra la lista. Va
	# incluso sin definicion, que es el unico caso en que la lista podria salir
	# vacia.
	if LEVANTAR.puede_interactuar(actor, self):
		salida.append(LEVANTAR)
	if MIRAR.puede_interactuar(actor, self):
		salida.append(MIRAR)
	return salida


## Ejecuta un verbo sobre este objeto. Devuelve si efectivamente ocurrio.
##
## Es el unico punto que muta estado, a proposito: comprueba, actua y avisa. Ese
## embudo es lo que permite validar las acciones del lado del servidor el dia de
## la fase 6 sin redisenar nada (D8).
##
## Vuelve a comprobar puede_interactuar() aunque verbos_disponibles() ya lo haya
## hecho: entre que el menu contextual se abre y el jugador elige, alguien mas
## pudo sentarse en la silla.
func ejecutar(behavior : InteractionBehavior, actor : Node) -> bool:
	if behavior == null:
		return false
	if not behavior.puede_interactuar(actor, self):
		return false
	if not behavior.interactuar(actor, self):
		return false

	interactuado.emit(behavior, actor)
	return true


## Avisa de un clic derecho sobre el objeto.
##
## El izquierdo se deja pasar a proposito: lo usa el personaje para caminar, y
## que clickear un mueble lo dejara clavado seria peor que no poder clickearlo.
##
## Marca el evento como atendido para que _unhandled_input() no vea tambien ese
## clic. El sorteo de colisiones del viewport corre antes, asi que aca todavia se
## llega a tiempo. Requiere que el viewport tenga physics_object_picking activado,
## que en 3D viene apagado por defecto y no avisa de nada cuando falta.
func _al_recibir_clic(_camara : Node, evento : InputEvent, _pos : Vector3,
		_normal : Vector3, _indice : int) -> void:
	if not (evento is InputEventMouseButton):
		return
	if not evento.pressed or evento.button_index != MOUSE_BUTTON_RIGHT:
		return

	# Editando, los verbos del mueble no vienen al caso: lo que se quiere es
	# moverlo o sacarlo, y de eso se ocupa el editor.
	if GameManager.editando():
		return

	get_viewport().set_input_as_handled()
	clickeado.emit(self)
