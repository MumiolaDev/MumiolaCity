## Autoridad sobre la grilla de una sala.
##
## Coordina dos capas de escenario ([member suelo] y [member paredes]) y lleva
## la cuenta de que [WorldObject] ocupa cada celda. La proyeccion isometrica no
## es asunto de esta clase: es el angulo de la camara.
##
## La API publica habla en [Vector2i] (planta del piso) y convierte a [Vector3i]
## solo para hablarle a los GridMap, donde el eje Y es la altura y el eje Z es
## la segunda coordenada de la planta.
##
## [b]Invariante:[/b] los dos GridMap hijos van con transformacion en cero, y el
## origen de este nodo es el origen de la sala. [code]map_to_local()[/code]
## trabaja en el espacio local del GridMap: si alguien mueve un hijo, las
## conversiones mienten sin dar error.
extends Node3D
class_name IsoGrid

## Capa de escenario caminable. Define que celdas existen.
@export var suelo : GridMap
## Capa de escenario del anillo exterior. No define celdas caminables.
@export var paredes : GridMap

## Se emite cada vez que cambia la ocupacion, con todas las celdas afectadas de
## una sola vez. Quien mantenga un AStarGrid2D debe suscribirse: esa copia de
## celdas solidas es independiente de esta y hay que invalidarla.
signal ocupacion_cambiada(celdas : Array[Vector2i])

var _ocupadas : Dictionary = {} # Vector2i -> WorldObject

# Planta de las paredes: Vector2i -> true. Se calcula una sola vez, la primera
# vez que alguien pregunta, para no depender del orden de _ready() entre nodos.
var _paredes_planta : Dictionary = {}
var _paredes_listas : bool = false


## Devuelve la posicion en el mundo dado el indice de la celda.
func celda_a_mundo(celda: Vector2i) -> Vector3:
	return suelo.map_to_local(Vector3i(celda.x, 0, celda.y))


## Devuelve el indice de la celda correspondiente a una posicion en el mundo.
func mundo_a_celda(pos: Vector3) -> Vector2i:
	var celda = suelo.local_to_map(pos)
	return Vector2i(celda.x, celda.z)


## Sirve para saber si hay suelo existente en tal celda.
func celda_valida(celda : Vector2i) -> bool:
	var item_en_celda = suelo.get_cell_item(Vector3i(celda.x,0,celda.y))
	return item_en_celda != GridMap.INVALID_CELL_ITEM


## Dado un origen y un size, se calculan las celdas que pertenecen al objeto en
## origen.
##
## [param rotacion] es una de cuatro direcciones [code][0,1,2,3][/code]; como
## todas las cajas son cuadradas solo hay que intercambiar los ejes.
func celdas_de(origen : Vector2i, size : Vector2i, rotacion : int = 0) -> Array[Vector2i]:
	var t := size if rotacion % 2 == 0 else Vector2i(size.y,size.x)
	var celdas : Array[Vector2i] = []
	for dx in maxi(t.x,1):
		for dz in maxi(t.y, 1):
			celdas.append(origen + Vector2i(dx,dz))
	return celdas


## Promedia las posiciones para entregar la posicion del centro de un area en
## tal origen. Se usa para colocar correctamente objetos en el grid, porque los
## modelos tienen el origen centrado y un objeto de varias celdas no va en el
## centro de su celda de origen.
func centro_de(origen : Vector2i, size : Vector2i, rotacion : int = 0) -> Vector3:
	var celdas := celdas_de(origen, size, rotacion)
	var suma := Vector3.ZERO
	for c in celdas:
		suma += celda_a_mundo(c)
	return suma / celdas.size()


## Revisa el espacio dado por el origen y el size, y devuelve si todas esas
## celdas son validas y no estan ocupadas.
func esta_libre(origen : Vector2i, size := Vector2i.ONE , rotacion := 0) -> bool:
	for c in celdas_de(origen, size,rotacion):
		if not celda_valida(c) or hay_pared(c) or _ocupadas.has(c):
			return false
	return true


## Devuelve si hay una pared ocupando la planta de tal celda.
##
## Se mira la planta y no una altura concreta: las paredes se pintan en el nivel
## que haga falta para que calcen visualmente, y para caminar solo importa el
## (x, z). Una pared bloquea aunque haya suelo debajo, que es lo que permite
## tabiques interiores ademas del anillo del perimetro.
func hay_pared(celda : Vector2i) -> bool:
	if not _paredes_listas:
		recalcular_paredes()
	return _paredes_planta.has(celda)


## Reconstruye la planta de las paredes desde el GridMap. Hay que llamarla si se
## pintan o borran paredes mientras el juego corre.
func recalcular_paredes() -> void:
	_paredes_planta.clear()
	for c in paredes.get_used_cells():
		_paredes_planta[Vector2i(c.x, c.z)] = true
	_paredes_listas = true


## Marca las celdas como ocupadas siempre que sea posible, con un obj de
## dimensiones dadas. Valida todo antes de escribir nada, para que la operacion
## no pueda quedar a medias.
func ocupar(origen : Vector2i, size : Vector2i, obj : WorldObject, rotacion := 0 ) -> bool:
	if not esta_libre(origen,size,rotacion):
		return false
	var celdas := celdas_de(origen, size,rotacion)
	for c in celdas:
		_ocupadas[c] = obj
	ocupacion_cambiada.emit(celdas)
	return true


## Devuelve el rectangulo minimo que contiene todo el suelo pintado. Sirve para
## dimensionar el AStarGrid2D, que necesita una region finita.
func region_usada() -> Rect2i:
	var celdas := suelo.get_used_cells()
	if celdas.is_empty():
		return Rect2i()
	var minimo := Vector2i(celdas[0].x, celdas[0].z)
	var maximo := minimo
	for c in celdas:
		minimo = minimo.min(Vector2i(c.x, c.z))
		maximo = maximo.max(Vector2i(c.x, c.z))
	return Rect2i(minimo, maximo - minimo + Vector2i.ONE)


## Devuelve todas las celdas de la region que no se pueden caminar: las que no
## tienen suelo, las que tienen pared y las ocupadas por un objeto.
##
## Recorre la region en vez de listar el diccionario porque "bloqueada" son tres
## cosas distintas y solo una vive en _ocupadas. Es el mismo criterio que usa
## esta_libre(), asi que nunca pueden discrepar.
func celdas_bloqueadas() -> Array[Vector2i]:
	var celdas : Array[Vector2i] = []
	var region := region_usada()
	for x in region.size.x:
		for z in region.size.y:
			var celda := region.position + Vector2i(x, z)
			if not esta_libre(celda):
				celdas.append(celda)
	return celdas
