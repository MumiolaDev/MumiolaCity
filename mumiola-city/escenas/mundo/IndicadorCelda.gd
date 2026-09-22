class_name IndicadorCelda
extends MeshInstance3D

## Resalta las celdas que ocuparia algo y muestra un fantasma de lo que se va a
## colocar.
##
## Tiene dos modos y el mismo cuerpo sirve para los dos. Por defecto se queda
## quieto hasta que alguien le dice que mostrar con mostrar(), que es como lo usa
## EditorSala: ahi quien decide la celda es el editor y no el puntero, porque
## puede estar arrastrando o el mouse puede estar sobre la paleta. Con
## 'seguir_puntero' en true vuelve a manejarse solo leyendo el mouse cada cuadro,
## que es la ayuda de desarrollo que era antes.
##
## El color de cada celda sale de IsoGrid.motivo_bloqueo(), no de esta_libre(),
## para que el rojo se pueda explicar. Con una huella de 2x2 eso ademas deja ver
## cual de las cuatro celdas es la que estorba, que es la diferencia entre
## "no cabe" y "no cabe por ese lado".
##
## De donde sale el fantasma: ItemDefinition.instanciar_visual(), que sabe sacar
## la malla de una escena de objeto sin despertar al WorldObject que la envuelve.
##
## Ojo con la raiz: es un MeshInstance3D porque asi esta declarado el nodo en
## SalaComun.tscn y SalaPrivada.tscn, pero su propia malla queda en null y todo
## lo dibujan sus hijos. Cambiarle el tipo obligaria a tocar las dos escenas a
## mano.

## Se emite cuando cambia el motivo por el que la posicion actual esta o no
## bloqueada. Lleva OK cuando se puede colocar.
##
## Existe para que el HUD pueda escribir el motivo sin preguntar cada cuadro.
signal motivo_cambiado(codigo : Errores.Codigo)

## Cuantos recuadros se preparan de entrada. El objeto mas grande del catalogo
## ocupa 2x2, asi que dieciseis sobra de lejos; si alguna vez no alcanza, se
## crean mas en el momento y no se rompe nada.
const CELDAS_RESERVADAS := 16

## La grilla a la que pertenecen las celdas resaltadas.
@export var grid : IsoGrid
## La camara con la que se convierte la posicion del puntero en celda.
@export var camara : Camera3D
## Si se maneja solo siguiendo el mouse.
##
## Viene en false: la vista previa es del editor, y en modo juego un recuadro
## persiguiendo el puntero sobre muebles que no se pueden mover solo distrae.
## Queda el modo automatico por si hace falta volver a usarlo como ayuda de
## desarrollo, que es para lo que nacio.
@export var seguir_puntero : bool = false

@export_group("Colores")
## Hay suelo y no hay nada encima: se puede caminar y se puede construir.
@export var color_libre : Color = Color(0.25, 0.9, 0.45, 0.35)
## Hay suelo pero esta ocupado por una pared o un objeto.
@export var color_bloqueado : Color = Color(0.95, 0.3, 0.25, 0.35)

@export_group("Fantasma")
## Cuanto se transparenta la malla de la vista previa.
##
## Es GeometryInstance3D.transparency y no modulate: modulate es de CanvasItem y
## no hace nada sobre una malla 3D.
@export_range(0.0, 1.0) var transparencia : float = 0.55

## Cuanto se levantan los recuadros sobre el piso para que no peleen con el en
## el z-buffer.
@export var alzado : float = 0.02

var _recuadros : Array[MeshInstance3D] = []
var _malla_celda : PlaneMesh
var _material_libre : StandardMaterial3D
var _material_bloqueado : StandardMaterial3D

var _fantasma : Node3D
## Que genero el fantasma que hay ahora: una ItemDefinition o una Mesh. Se guarda
## para no reconstruirlo sesenta veces por segundo cuando no cambio nada.
var _fuente : Variant = null
## Si lo que se previsualiza es una pieza de escenario. Cambia donde se ancla el
## fantasma, porque un GridMap y un mueble no se apoyan en el mismo punto.
var _es_pieza : bool = false
var _definicion : ItemDefinition
var _origen : Vector2i = IsoGrid.SIN_CELDA
var _rotacion : int = 0
var _motivo : Errores.Codigo = Errores.Codigo.OK


func _ready() -> void:
	if grid == null or camara == null:
		push_error("IndicadorCelda: faltan asignar 'grid' o 'camara' en el inspector.")
		set_process(false)
		return

	# La raiz se desprende de la transformada de la sala porque todo lo que este
	# nodo ubica lo ubica en coordenadas de mundo, y componerlo dos veces
	# dejaria el fantasma girado respecto del objeto real.
	top_level = true
	global_transform = Transform3D.IDENTITY

	# La raiz no dibuja: dibujan los hijos.
	mesh = null

	_malla_celda = PlaneMesh.new()
	_malla_celda.size = Vector2(grid.suelo.cell_size.x, grid.suelo.cell_size.z)

	_material_libre = _nuevo_material(color_libre)
	_material_bloqueado = _nuevo_material(color_bloqueado)

	for i in CELDAS_RESERVADAS:
		_crear_recuadro()

	_ocultar_recuadros()
	set_process(seguir_puntero)


func _process(_delta : float) -> void:
	_actualizar(grid.celda_bajo_puntero(camara, get_viewport().get_mouse_position()))


## Elige que item previsualizar, sin decir donde.
##
## Es la mitad que usa la paleta: cambiar de mueble no deberia moverlo de lugar.
## Con 'seguir_puntero' en true alcanza con esto y el fantasma sigue al mouse.
##
## Pasar null deja solo el recuadro de una celda, que es lo que corresponde al
## pintar suelo o paredes, donde no hay malla que previsualizar.
func elegir(definicion : ItemDefinition, rotacion : int = 0) -> void:
	if definicion != _fuente:
		_cambiar_fantasma(definicion)
	_definicion = definicion
	_es_pieza = false
	_rotacion = rotacion
	if _origen != IsoGrid.SIN_CELDA:
		_actualizar(_origen)


## Elige una pieza de escenario para previsualizar, por su malla.
##
## Existe para que girar una pared no sea a ciegas. Una pieza no tiene
## ItemDefinition —es una entrada de MeshLibrary, no un item— asi que entra por
## su malla, y su huella es siempre una celda (D15).
##
## Hay que pasarle tambien la transformada que la biblioteca guarda para esa
## pieza, que es la que el GridMap le aplica al colocarla. Sin ella el fantasma
## sale con el tamanio crudo de la malla: suelo_base mide cuatro metros y se
## coloca escalado a 0.25, asi que el fantasma se veria cuatro veces mas grande
## que el suelo que va a quedar.
func elegir_pieza(malla : Mesh, transformada : Transform3D, rotacion : int = 0) -> void:
	if malla != _fuente:
		_cambiar_fantasma(malla, transformada)
	_definicion = null
	_es_pieza = true
	_rotacion = rotacion
	if _origen != IsoGrid.SIN_CELDA:
		_actualizar(_origen)


## Ubica la vista previa sin tocar lo elegido.
##
## Es la pareja de elegir() y elegir_pieza(): una dice **que** y esta dice
## **donde**. Existe porque mostrar() interpreta un null como "no hay nada
## elegido" y destruye el fantasma, asi que usarla para ubicar una pieza —que no
## tiene ItemDefinition— borraba el fantasma recien creado en cada cuadro.
func mostrar_en(celda : Vector2i, rotacion : int = 0) -> void:
	_rotacion = rotacion
	_actualizar(celda)


## Muestra la vista previa de un item en una celda, con una rotacion en pasos de
## noventa grados.
##
## Atajo de elegir() mas mostrar_en() para el caso de un item. Para una pieza de
## escenario hay que usar los dos por separado.
func mostrar(definicion : ItemDefinition, celda : Vector2i, rotacion : int = 0) -> void:
	if definicion != _fuente:
		_cambiar_fantasma(definicion)
	_definicion = definicion
	_es_pieza = false
	_rotacion = rotacion
	_actualizar(celda)


## Esconde la vista previa entera, recuadros y fantasma.
func ocultar() -> void:
	_origen = IsoGrid.SIN_CELDA
	_ocultar_recuadros()
	if _fantasma != null:
		_fantasma.visible = false
	_cambiar_motivo(Errores.Codigo.OK)


## Devuelve por que no se puede colocar en la posicion actual, u OK si se puede.
##
## Es lo mismo que devolveria IsoGrid.motivo_bloqueo() para esta posicion, pero
## ya calculado: quien lo quiera para un cartel no tiene que repetir la cuenta.
func motivo() -> Errores.Codigo:
	return _motivo


## Devuelve la celda de origen que se esta mostrando, o IsoGrid.SIN_CELDA si no
## se esta mostrando ninguna.
func celda() -> Vector2i:
	return _origen


## Devuelve cuantas celdas ocupa lo que se esta previsualizando.
func huella() -> Vector2i:
	return Vector2i.ONE if _definicion == null else _definicion.tamano_grilla


## Rearma la vista previa alrededor de una celda de origen.
func _actualizar(origen : Vector2i) -> void:
	# Fuera del suelo pintado no se muestra nada: un recuadro flotando sobre el
	# vacio confunde mas de lo que informa.
	if origen == IsoGrid.SIN_CELDA or not grid.celda_valida(origen):
		ocultar()
		return

	_origen = origen
	var celdas := grid.celdas_de(origen, huella(), _rotacion)
	_dibujar_recuadros(celdas)
	_ubicar_fantasma(origen)
	_cambiar_motivo(grid.motivo_bloqueo(origen, huella(), _rotacion))


## Pone un recuadro sobre cada celda de la huella y esconde los que sobran.
##
## Cada recuadro se colorea por su cuenta, preguntando por esa sola celda: en una
## mesa de 2x2 se ve cual es la que no entra, no solo que la mesa no entra.
func _dibujar_recuadros(celdas : Array[Vector2i]) -> void:
	while _recuadros.size() < celdas.size():
		_crear_recuadro()

	for i in _recuadros.size():
		var recuadro := _recuadros[i]
		if i >= celdas.size():
			recuadro.visible = false
			continue

		var c : Vector2i = celdas[i]
		var pos := grid.celda_a_mundo(c)
		pos.y += alzado
		recuadro.global_position = pos
		recuadro.visible = true
		recuadro.material_override = (_material_libre
			if Errores.ok(grid.motivo_bloqueo(c)) else _material_bloqueado)


## Lleva el fantasma al centro de la huella y lo gira como quedaria el objeto.
##
## El giro repite el de RoomController.colocar_objeto() usando su misma
## constante, para que la vista previa no pueda desfasarse de lo que termina
## colocado.
func _ubicar_fantasma(origen : Vector2i) -> void:
	if _fantasma == null:
		return
	# Un mueble se apoya en el centro de su huella y sobre la cara de la losa; una
	# pieza se ancla donde el GridMap la anclaria, que es otro punto.
	var pos := (grid.ancla_de_pieza(origen) if _es_pieza
		else grid.centro_de(origen, huella(), _rotacion))
	_fantasma.global_position = pos
	_fantasma.rotation.y = -RoomController.PASO_ROTACION * _rotacion
	_fantasma.visible = true


## Reemplaza la malla de la vista previa por la del item dado.
##
## Solo se llama cuando cambia el item elegido, no cada cuadro: instanciar una
## escena por cuadro seria caro y ademas inutil.
func _cambiar_fantasma(fuente : Variant, transformada := Transform3D.IDENTITY) -> void:
	if _fantasma != null:
		_fantasma.queue_free()
		_fantasma = null
	_fuente = fuente

	if fuente is ItemDefinition:
		_fantasma = (fuente as ItemDefinition).instanciar_visual()
	elif fuente is Mesh:
		# La malla va en un hijo con la transformada de la biblioteca, para que la
		# raiz se pueda ubicar y girar igual que la de un mueble. Asi
		# _ubicar_fantasma() no tiene que saber de cual de los dos se trata.
		var nodo := MeshInstance3D.new()
		nodo.mesh = fuente as Mesh
		nodo.transform = transformada
		_fantasma = Node3D.new()
		_fantasma.add_child(nodo)

	if _fantasma == null:
		return

	add_child(_fantasma)
	_atenuar(_fantasma, transparencia)
	_fantasma.visible = false


## Transparenta todas las mallas de un subarbol.
##
## Recorre en vez de tocar solo la raiz porque un modelo de KayKit trae varias
## MeshInstance3D, y transparentar una sola se ve peor que no transparentar
## ninguna.
static func _atenuar(nodo : Node, valor : float) -> void:
	if nodo is GeometryInstance3D:
		(nodo as GeometryInstance3D).transparency = valor
		(nodo as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for hijo in nodo.get_children():
		_atenuar(hijo, valor)


## Agrega un recuadro mas a la reserva.
func _crear_recuadro() -> MeshInstance3D:
	var recuadro := MeshInstance3D.new()
	recuadro.mesh = _malla_celda
	recuadro.top_level = true
	recuadro.visible = false
	add_child(recuadro)
	_recuadros.append(recuadro)
	return recuadro


## Esconde todos los recuadros sin destruirlos.
func _ocultar_recuadros() -> void:
	for recuadro in _recuadros:
		recuadro.visible = false


## Guarda el motivo y avisa solo si cambio, para no emitir sesenta veces por
## segundo lo mismo.
func _cambiar_motivo(codigo : Errores.Codigo) -> void:
	if codigo == _motivo:
		return
	_motivo = codigo
	motivo_cambiado.emit(codigo)


## Arma el material de un recuadro: plano, translucido y visible de los dos
## lados, porque la camara puede pasar por debajo del piso al girar.
func _nuevo_material(color : Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material
