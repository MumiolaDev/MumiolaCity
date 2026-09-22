@tool
extends EditorScript

## Renderiza un icono por cada item que tenga modelo y lo guarda en arte/iconos.
##
## Se corre desde el editor con Archivo > Ejecutar (Ctrl+Shift+X) con este script
## abierto. No se ejecuta durante el juego.
##
## Existe porque una paleta de cuarenta y cinco filas de texto es inusable. El
## editor de sala necesita que se reconozca un mueble de un vistazo, y lo unico
## que se parece a un mueble es el mueble.
##
## Son dos pasadas, y saltearse la segunda hace parecer que esto fallo:
##
##  1. Correr este script. Escribe los PNG y le pide al editor que reimporte.
##  2. Correr ImportarItems.gd, que recien ahi puede asignar el icono a cada
##     ItemDefinition. Antes de que Godot importe el PNG, load() no lo encuentra
##     y los cuarenta y cinco quedarian en null.
##
## Es idempotente: volver a correrlo regenera todos los iconos encima.

const DIR_DEFINICIONES := "res://data/objetos/definiciones"
const DIR_SALIDA := "res://arte/iconos"

## Se renderiza grande y se achica: sale mas limpio de bordes que renderizar
## directo al tamano final, y cuesta una linea.
const LADO_RENDER := 512
const LADO_ICONO := 128

## Cuanto aire queda alrededor del objeto. 1.0 seria el objeto tocando los cuatro
## bordes.
const MARGEN := 1.12

## La misma DirectionalLight3D que tienen SalaComun y SalaPrivada, para que el
## icono no este iluminado distinto que el mueble de verdad.
const ROTACION_LUZ := Vector3(-114.9, 0.0, 0.0)
const ENERGIA_LUZ := 1.2
## Sin algo de ambiente, la cara que no mira a la luz sale negra y el icono se
## lee como una silueta.
const LUZ_AMBIENTE := 0.45


func _run() -> void:
	var definiciones := _cargar_definiciones()
	if definiciones.is_empty():
		push_error("GenerarIconos: no hay definiciones en %s. Corre antes ImportarItems.gd." % DIR_DEFINICIONES)
		return

	DirAccess.make_dir_recursive_absolute(DIR_SALIDA)

	var vista := _armar_vista()
	EditorInterface.get_base_control().add_child(vista)

	# Un cuadro de gracia antes de tocar transformadas: mientras un Node3D no
	# esta de verdad en el arbol, escribirle global_position no hace nada y no
	# avisa. La camara se quedaria en la identidad y saldrian 45 iconos
	# encuadrados desde el origen del mundo.
	await RenderingServer.frame_post_draw

	var camara : Camera3D = vista.get_node(^"Camara")
	var escritos : Array[String] = []
	var sin_modelo : Array[String] = []
	var fallidos : Array[String] = []

	for def in definiciones:
		if def.escena_mundo == null:
			sin_modelo.append(String(def.id))
			continue

		var visual := def.instanciar_visual()
		if visual == null:
			fallidos.append("%s: la escena no tiene malla" % def.id)
			continue

		vista.add_child(visual)
		var caja := _caja_de(visual)
		if caja.size == Vector3.ZERO:
			fallidos.append("%s: el modelo no tiene ninguna malla con volumen" % def.id)
			visual.queue_free()
			continue

		_encuadrar(camara, caja)

		# Un solo cuadro por objeto, pedido a mano. frame_post_draw es lo que
		# garantiza que la textura ya tiene algo cuando se la lee.
		vista.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw

		var codigo := _guardar(vista.get_texture().get_image(), String(def.id))
		if codigo == OK:
			escritos.append(String(def.id))
		else:
			fallidos.append("%s: no se pudo escribir el PNG (error %d)" % [def.id, codigo])

		vista.remove_child(visual)
		visual.queue_free()

	vista.queue_free()
	_reportar(escritos, sin_modelo, fallidos)


## Arma el SubViewport con su camara, su luz y su ambiente.
##
## El fondo va transparente, o cada icono llevaria pegado un cuadrado de color
## que se veria en cuanto la paleta tenga otro fondo.
func _armar_vista() -> SubViewport:
	var vista := SubViewport.new()
	vista.size = Vector2i(LADO_RENDER, LADO_RENDER)
	vista.transparent_bg = true
	vista.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vista.msaa_3d = Viewport.MSAA_4X
	vista.own_world_3d = true

	var camara := Camera3D.new()
	camara.name = "Camara"
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	camara.near = 0.01
	camara.far = 1000.0
	vista.add_child(camara)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = ROTACION_LUZ
	luz.light_energy = ENERGIA_LUZ
	luz.shadow_enabled = false
	vista.add_child(luz)

	var ambiente := WorldEnvironment.new()
	var entorno := Environment.new()
	# BG_COLOR con alfa cero y no BG_CLEAR_COLOR: el clear color del proyecto es
	# opaco y taparia la transparencia del SubViewport. Asi queda dicho explicito
	# que el fondo del icono es nada.
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color(0, 0, 0, 0)
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.WHITE
	entorno.ambient_light_energy = LUZ_AMBIENTE
	ambiente.environment = entorno
	vista.add_child(ambiente)

	return vista


## Coloca la camara para que el objeto llene el cuadro.
##
## Estatica, como el resto del encuadre y del guardado: son funciones puras de
## sus argumentos y no tocan nada de la herramienta. De paso eso las vuelve
## comprobables sin abrir el editor, que es donde estaba el riesgo real de este
## script — el render es trivial y el encuadre no.
##
## Mira por la diagonal (1,1,1), que es exactamente por donde mira la camara de
## las salas: su pivote da yaw 45 y pitch 35.3 grados, el isometrico de manual.
## Asi el icono muestra el mueble tal como se va a ver colocado.
##
## El encuadre no usa el radio de la caja sino las ocho esquinas proyectadas al
## espacio de la camara. Con el radio, una cama quedaria diminuta en el medio de
## su icono; con las esquinas, cada objeto llena el suyo. Que entonces el tomate
## y la cama se vean igual de grandes es a proposito: en una paleta, respetar la
## escala real deja la mitad de las entradas como puntitos.
static func _encuadrar(camara : Camera3D, caja : AABB) -> void:
	var centro := caja.get_center()
	var distancia := maxf(caja.size.length(), 1.0) * 2.0

	camara.global_position = centro + Vector3.ONE.normalized() * distancia
	camara.look_at(centro)

	var inverso := camara.global_transform.affine_inverse()
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for i in 8:
		var p : Vector3 = inverso * caja.get_endpoint(i)
		var plano := Vector2(p.x, p.y)
		minimo = minimo.min(plano)
		maximo = maximo.max(plano)

	# Recentrar: el centro de la caja y el centro de su proyeccion no coinciden.
	var corrimiento := (minimo + maximo) * 0.5
	var base := camara.global_transform.basis
	camara.global_position += base.x * corrimiento.x + base.y * corrimiento.y

	var lado := maxf(maximo.x - minimo.x, maximo.y - minimo.y)
	camara.size = maxf(lado, 0.01) * MARGEN


## Devuelve la caja que envuelve a todas las mallas del subarbol, en coordenadas
## de mundo.
##
## Hay que recorrerlo porque un modelo de KayKit trae varias MeshInstance3D, y
## quedarse con la primera encuadraria por una pata de la silla.
static func _caja_de(raiz : Node3D) -> AABB:
	var mallas : Array[VisualInstance3D] = []
	_juntar_mallas(raiz, mallas)
	if mallas.is_empty():
		return AABB()

	var total := mallas[0].global_transform * mallas[0].get_aabb()
	for i in range(1, mallas.size()):
		total = total.merge(mallas[i].global_transform * mallas[i].get_aabb())
	return total


static func _juntar_mallas(nodo : Node, salida : Array[VisualInstance3D]) -> void:
	if nodo is VisualInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_juntar_mallas(hijo, salida)


## Achica el render al tamano final y lo escribe.
##
## Lanczos y no el filtro por defecto porque es el que menos aliasing deja al
## reducir, que es justo lo que se esta haciendo.
static func _guardar(imagen : Image, id : String) -> Error:
	if imagen == null:
		return ERR_INVALID_DATA

	imagen.resize(LADO_ICONO, LADO_ICONO, Image.INTERPOLATE_LANCZOS)
	var ruta := "%s/%s.png" % [DIR_SALIDA, id]
	var codigo := imagen.save_png(ruta)
	if codigo != OK:
		return codigo

	# save_png() puede devolver OK sin haber escrito, como ya paso con
	# ResourceSaver en el importador. Se comprueba en vez de confiar.
	return OK if FileAccess.file_exists(ruta) else ERR_FILE_CANT_WRITE


## Carga todas las definiciones del catalogo, ordenadas por id.
func _cargar_definiciones() -> Array[ItemDefinition]:
	var salida : Array[ItemDefinition] = []
	var archivos := DirAccess.get_files_at(DIR_DEFINICIONES)
	if archivos.is_empty():
		return salida

	var nombres : Array[String] = []
	for archivo in archivos:
		var limpio := archivo.trim_suffix(".remap")
		if limpio.ends_with(".tres"):
			nombres.append(limpio)
	nombres.sort()

	for nombre in nombres:
		var def := load("%s/%s" % [DIR_DEFINICIONES, nombre]) as ItemDefinition
		if def != null:
			salida.append(def)
	return salida


## Escribe el resumen y le pide al editor que reimporte lo que se acaba de crear.
func _reportar(escritos : Array[String], sin_modelo : Array[String],
		fallidos : Array[String]) -> void:
	print("GenerarIconos: %d iconos escritos en %s." % [escritos.size(), DIR_SALIDA])

	if not sin_modelo.is_empty():
		print("  Sin modelo, sin icono (%d): %s" % [sin_modelo.size(), ", ".join(sin_modelo)])

	for aviso in fallidos:
		push_warning("GenerarIconos: %s" % aviso)

	if escritos.is_empty():
		return

	EditorInterface.get_resource_filesystem().scan()
	print("  Ahora corre ImportarItems.gd para que los ItemDefinition tomen su icono.")
