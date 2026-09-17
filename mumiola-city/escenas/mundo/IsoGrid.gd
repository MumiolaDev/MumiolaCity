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

## Valor que devuelve celda_bajo_puntero() cuando el rayo no corta el plano del
## piso. Solo puede pasar si la camara mira exactamente en horizontal.
const SIN_CELDA := Vector2i.MAX

## Capa de escenario caminable. Define que celdas existen.
@export var suelo : GridMap
## Capa de escenario del anillo exterior. No define celdas caminables.
@export var paredes : GridMap

## Altura de la cara superior del suelo, en metros. No es cero: las piezas de
## suelo tienen grosor.
##
## Se usa para convertir un clic de pantalla en celda. Cortar el plano
## equivocado no da un error vertical sino lateral: con la camara a 35 grados,
## equivocarse medio metro de altura corre el resultado casi una celda entera.
@export var altura_piso : float = 0.632

## Nombres de piezas de la capa de paredes que NO bloquean el paso.
##
## Por defecto toda pieza pintada en 'paredes' bloquea su celda. Esta lista es la
## excepcion, para lo que es visualmente muro pero atravesable: el hueco de una
## puerta, un arco, una cornisa a la altura de la cabeza.
##
## Existe porque bloquear y dibujar son dos cosas distintas y conviene no
## deducir una de la otra: la capa donde se pinta una pieza dice como se ve, no
## como se comporta.
@export var piezas_transitables : Array[StringName] = []

## Se emite cada vez que cambia la ocupacion, con todas las celdas afectadas de
## una sola vez. Quien mantenga un AStarGrid2D debe suscribirse: esa copia de
## celdas solidas es independiente de esta y hay que invalidarla.
signal ocupacion_cambiada(celdas : Array[Vector2i])

var _ocupadas : Dictionary = {} # Vector2i -> WorldObject

# Planta de las paredes: Vector2i -> true. Se calcula una sola vez, la primera
# vez que alguien pregunta, para no depender del orden de _ready() entre nodos.
var _paredes_planta : Dictionary = {}
var _paredes_listas : bool = false

# El A* vive aqui y no en cada personaje: es un indice derivado de la grilla, no
# un dato de quien camina. Uno por sala, compartido por todos los que esten en
# ella. Se construye la primera vez que alguien pide una ruta.
var _astar : AStarGrid2D = null


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
	return motivo_bloqueo(origen, size, rotacion) == Errores.Codigo.OK


## Devuelve por que no se puede ocupar una huella, o Errores.Codigo.OK si se
## puede.
##
## esta_libre() delega aca en vez de repetir las comprobaciones: con dos copias
## del criterio, tarde o temprano una dice que si y la otra que no. Es lo que le
## permite a RoomController.colocar_objeto() decir "ahi hay una pared" en lugar
## de un no pelado (D16).
##
## El orden de las comprobaciones es el orden en que se le explican al jugador:
## primero si el lugar existe, despues si esta construido, y recien al final si
## alguien llego antes.
func motivo_bloqueo(origen : Vector2i, size := Vector2i.ONE, rotacion := 0) -> Errores.Codigo:
	for c in celdas_de(origen, size, rotacion):
		if not celda_valida(c):
			return Errores.Codigo.CELDA_INEXISTENTE
		if hay_pared(c):
			return Errores.Codigo.HAY_PARED
		if _ocupadas.has(c):
			return Errores.Codigo.CELDA_OCUPADA
	return Errores.Codigo.OK


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
		if _es_transitable(paredes.get_cell_item(c)):
			continue
		_paredes_planta[Vector2i(c.x, c.z)] = true
	_paredes_listas = true
	_validar_piezas(paredes, CatalogoPiezas.PAREDES)
	_validar_piezas(suelo, CatalogoPiezas.SUELO)
	_astar = null  # cambio la transitabilidad: el A* se reconstruye al pedirse


## Marca las celdas como ocupadas siempre que sea posible, con un obj de
## dimensiones dadas. Valida todo antes de escribir nada, para que la operacion
## no pueda quedar a medias.
func ocupar(origen : Vector2i, size : Vector2i, obj : WorldObject, rotacion := 0 ) -> bool:
	if not esta_libre(origen,size,rotacion):
		return false
	var celdas := celdas_de(origen, size,rotacion)
	for c in celdas:
		_ocupadas[c] = obj
	_marcar_en_astar(celdas)
	ocupacion_cambiada.emit(celdas)
	return true


## Libera todas las celdas que ocupa un objeto y lo saca de la grilla.
##
## Busca las celdas recorriendo el diccionario en vez de recalcularlas desde el
## origen y el size del objeto: si fue rotado, o si algo cambio entre ocupar y
## liberar, el recalculo puede no coincidir con lo que realmente se marco y deja
## celdas bloqueadas para siempre, sin nada que las reclame. _ocupadas es la
## unica fuente de verdad sobre que celdas son de quien.
##
## Devuelve false si el objeto no estaba ocupando ninguna celda.
func liberar_objeto(obj : WorldObject) -> bool:
	var celdas : Array[Vector2i] = []
	for celda in _ocupadas:
		if _ocupadas[celda] == obj:
			celdas.append(celda)

	if celdas.is_empty():
		return false

	# Borrar antes de tocar el A*: _marcar_en_astar() recalcula esta_libre() por
	# celda, asi que si todavia estuvieran en _ocupadas las volveria a marcar
	# solidas y liberar no serviria de nada.
	for c in celdas:
		_ocupadas.erase(c)
	_marcar_en_astar(celdas)
	ocupacion_cambiada.emit(celdas)
	return true


## Devuelve una celda vecina libre, o SIN_CELDA si esta rodeada.
##
## Hace falta para levantarse: quien se sienta queda parado sobre la celda de la
## silla, que esta ocupada por el WorldObject, y desde una celda solida el A* no
## puede trazar una ruta. Prueba primero las cuatro ortogonales y despues las
## diagonales, para que el paso al levantarse sea el mas natural posible.
func celda_libre_vecina(celda : Vector2i) -> Vector2i:
	const VECINDAD := [
		Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
		Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	for paso in VECINDAD:
		var vecina : Vector2i = celda + paso
		if esta_libre(vecina):
			return vecina
	return SIN_CELDA


## Devuelve el objeto que ocupa una celda, o null si no hay ninguno.
##
## Un objeto de varias celdas responde lo mismo desde cualquiera de ellas: quien
## clickea la esquina de una mesa de 2x2 recibe la mesa, no un hueco. Es lo que
## convierte un clic en un objeto con el que interactuar.
func objeto_en(celda : Vector2i) -> WorldObject:
	return _ocupadas.get(celda, null)


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


## Devuelve el camino de celdas desde origen hasta destino, sin incluir la celda
## de origen. Array vacio si no hay camino o si alguno de los extremos no sirve.
##
## El A* es unico por sala: cincuenta personajes caminando comparten este mismo
## indice en vez de mantener cincuenta copias del mismo mapa de celdas solidas.
func ruta(origen : Vector2i, destino : Vector2i) -> Array[Vector2i]:
	_asegurar_astar()
	if not _astar.region.has_point(origen) or not _astar.region.has_point(destino):
		return []
	if _astar.is_point_solid(destino):
		return []

	var camino := _astar.get_id_path(origen, destino)
	if camino.size() < 2:
		return []

	var resultado : Array[Vector2i] = []
	resultado.assign(camino)
	resultado.remove_at(0)  # la primera celda es en la que ya esta parado
	return resultado


## Construye el A* si todavia no existe, sobre la region de suelo pintado.
##
## Se hace de forma perezosa y no en _ready() para no depender del orden de los
## nodos: cualquiera que pida una ruta lo encuentra listo.
func _asegurar_astar() -> void:
	if _astar != null:
		return

	# La cache de paredes se calcula primero y aparte: esta_libre() la pide, y
	# recalcular_paredes() invalida el A*. Si eso pasara a mitad del bucle de
	# abajo, se anularia el A* que estamos construyendo.
	if not _paredes_listas:
		recalcular_paredes()

	# Se arma sobre una variable local y se publica al final, por la misma razon:
	# mientras dura la construccion, _astar sigue en null y nada puede leerlo a
	# medio llenar.
	var astar := AStarGrid2D.new()
	astar.region = region_usada()
	astar.cell_size = Vector2.ONE
	# AT_LEAST_ONE_WALKABLE permite moverse en diagonal si al menos una de las dos
	# celdas ortogonales adyacentes esta libre. Impide colarse por el hueco en X
	# entre dos esquinas que se tocan, pero deja caminar en diagonal pegado a una
	# pared. ONLY_IF_NO_OBSTACLES, que exige las dos libres, prohibe toda diagonal
	# cerca de un muro y obliga a recorridos en escalones.
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.update()

	var region := astar.region
	for x in region.size.x:
		for z in region.size.y:
			var celda := region.position + Vector2i(x, z)
			astar.set_point_solid(celda, not esta_libre(celda))

	_astar = astar


## Mantiene sincronizada la copia de celdas solidas que guarda el A*.
##
## Se llama desde dentro de ocupar(), a proposito: mientras esto vivia en el
## personaje, cada uno tenia que acordarse de suscribirse a ocupacion_cambiada
## para no caminar atravesando muebles. Ahora no hay nada que recordar.
func _marcar_en_astar(celdas : Array[Vector2i]) -> void:
	if _astar == null:
		return
	for c in celdas:
		if _astar.region.has_point(c):
			_astar.set_point_solid(c, not esta_libre(c))


## Devuelve la celda del piso a la que apunta una posicion de pantalla.
##
## Intersecta el rayo de la camara contra el plano del piso, asi que no hace
## falta que el escenario tenga colision para poder clicarlo. Devuelve SIN_CELDA
## si el rayo no corta el plano; la celda devuelta puede no tener suelo, eso lo
## decide quien llama con celda_valida() o esta_libre().
func celda_bajo_puntero(camara : Camera3D, pos_pantalla : Vector2) -> Vector2i:
	var origen := camara.project_ray_origin(pos_pantalla)
	var direccion := camara.project_ray_normal(pos_pantalla)
	var plano := Plane(Vector3.UP, altura_piso)
	var golpe = plano.intersects_ray(origen, direccion)
	if golpe == null:
		return SIN_CELDA
	return mundo_a_celda(golpe)


## Avisa por consola de todo lo que puede romper una sala en silencio.
##
## Tres fallas, las tres mudas si nadie las busca: una pieza mas grande que una
## celda solo bloquea donde se pinto (D15); un id pintado que la biblioteca ya no
## tiene deja la celda invisible pero bloqueando, y el bug aparece como "el
## personaje no puede pasar por un lugar vacio"; y una pieza pintada en la capa
## que no le toca es un muro que nadie va a poder explicar, porque en la capa de
## paredes todo bloquea salvo lo declarado en piezas_transitables.
##
## La segunda es la que importa a largo plazo: pasa sola, al re-exportar la
## MeshLibrary sin fusionar con la existente, y no rompe una celda sino todas.
func _validar_piezas(grid_map : GridMap, capa : StringName) -> void:
	if grid_map == null or grid_map.mesh_library == null:
		return

	for problema in CatalogoPiezas.verificar(grid_map.mesh_library, capa):
		push_warning("IsoGrid: " + problema)

	var avisados := {}
	var celda_xz := Vector2(grid_map.cell_size.x, grid_map.cell_size.z)
	var conocidos := grid_map.mesh_library.get_item_list()

	for c in grid_map.get_used_cells():
		var id := grid_map.get_cell_item(c)
		if avisados.has(id):
			continue

		if not (id in conocidos):
			avisados[id] = true
			push_warning(
				"IsoGrid: la celda (%d, %d) de la capa '%s' usa el id %d, que la biblioteca ya no tiene. " % [
					c.x, c.z, capa, id
				]
				+ "Se reasignaron los ids al exportar: hay que remapear la sala por nombre."
			)
			continue

		var nombre := CatalogoPiezas.nombre_de(grid_map.mesh_library, id)
		if not CatalogoPiezas.corresponde_a(nombre, capa):
			avisados[id] = true
			push_warning(
				"IsoGrid: la pieza '%s' esta pintada en la capa '%s', y por su nombre no le corresponde." % [
					nombre, capa
				]
			)
			continue

		var malla := grid_map.mesh_library.get_item_mesh(id)
		if malla == null:
			continue

		var caja : AABB = grid_map.mesh_library.get_item_mesh_transform(id) * malla.get_aabb()
		if caja.size.x > celda_xz.x * 1.05 or caja.size.z > celda_xz.y * 1.05:
			avisados[id] = true
			push_warning(
				"IsoGrid: la pieza '%s' mide %.2f x %.2f y la celda es %.2f x %.2f. " % [
					nombre, caja.size.x, caja.size.z, celda_xz.x, celda_xz.y
				]
				+ "Solo bloquea la celda donde se pinto, no las que invade. "
				+ "Escalala a una celda y pintala varias veces."
			)


## Devuelve si una pieza de la capa de paredes esta declarada como atravesable.
func _es_transitable(id : int) -> bool:
	if piezas_transitables.is_empty() or paredes.mesh_library == null:
		return false
	return StringName(paredes.mesh_library.get_item_name(id)) in piezas_transitables
