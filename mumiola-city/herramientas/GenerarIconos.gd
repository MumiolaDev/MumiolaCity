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
##
## No usa await en ninguna parte, y no es un descuido: el _run() de un
## EditorScript no puede ser corrutina. Al primer await devuelve el control al
## editor, el objeto del script se libera y la corrutina no se reanuda nunca
## —sin error y sin una sola linea en consola, que es exactamente como se
## manifesto la primera version de este archivo—. Por eso el dibujo se pide
## sincronico con RenderingServer.force_draw(), y las transformadas se arman a
## mano en vez de con global_position y look_at, que necesitan que el nodo ya
## este dentro del arbol.

const DIR_DEFINICIONES := "res://data/objetos/definiciones"
const DIR_SALIDA := "res://arte/iconos"

## Se renderiza grande y se achica: sale mas limpio de bordes que renderizar
## directo al tamano final, y cuesta una linea.
const LADO_RENDER := 512
const LADO_ICONO := 128

## Cuanto aire queda alrededor del objeto. 1.0 seria el objeto tocando los cuatro
## bordes.
const MARGEN := 1.12

## Desde donde mira la camara. Es la diagonal (1,1,1), que es exactamente por
## donde mira la camara de las salas: su pivote da yaw 45 y pitch 35.3 grados, el
## isometrico de manual. Asi el icono muestra el mueble como se va a ver puesto.
const DIRECCION := Vector3(1, 1, 1)

## La misma DirectionalLight3D que tienen SalaComun y SalaPrivada, para que el
## icono no este iluminado distinto que el mueble de verdad.
const ROTACION_LUZ := Vector3(-114.9, 0.0, 0.0)
const ENERGIA_LUZ := 1.2
## Sin algo de ambiente, la cara que no mira a la luz sale negra y el icono se
## lee como una silueta.
const LUZ_AMBIENTE := 0.45


func _run() -> void:
	# Lo primero que hace es hablar. Si esta linea no aparece, el problema es que
	# el script ni siquiera arranco, y eso es mucho mas facil de diagnosticar que
	# una consola en blanco.
	print("GenerarIconos: empezando...")

	var definiciones := _cargar_definiciones()
	if definiciones.is_empty():
		push_error("GenerarIconos: no hay definiciones en %s. Corre antes ImportarItems.gd."
			% DIR_DEFINICIONES)
		return

	DirAccess.make_dir_recursive_absolute(DIR_SALIDA)

	var vista := _armar_vista()
	EditorInterface.get_base_control().add_child(vista)

	var camara : Camera3D = vista.get_node(^"Camara")
	var escritos : Array[String] = []
	var sin_modelo : Array[String] = []
	var fallidos : Array[String] = []
	var vacios : Array[String] = []

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
			vista.remove_child(visual)
			visual.free()
			continue

		_encuadrar(camara, caja)

		# Un cuadro por objeto, pedido a mano y sincronico: force_draw() vuelve
		# recien cuando ya dibujo, asi que la textura tiene algo en la linea
		# siguiente. Es lo que reemplaza al await que aca no se puede usar.
		vista.render_target_update_mode = SubViewport.UPDATE_ONCE
		RenderingServer.force_draw(false)

		var imagen := vista.get_texture().get_image()
		if _esta_vacia(imagen):
			vacios.append(String(def.id))

		var codigo := _guardar(imagen, String(def.id))
		if codigo == OK:
			escritos.append(String(def.id))
		else:
			fallidos.append("%s: no se pudo escribir el PNG (error %d)" % [def.id, codigo])

		vista.remove_child(visual)
		visual.free()

	vista.queue_free()
	_reportar(escritos, sin_modelo, fallidos, vacios)


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
	# Mundo propio, o los iconos saldrian con las luces de lo que este abierto en
	# el editor y cambiarian de un dia para el otro.
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
## Estatica y sin tocar el arbol: arma la transformada con Basis.looking_at() en
## vez de usar look_at(), que necesita que el nodo ya este dentro del arbol.
## Mientras no lo esta, escribirle global_position no hace nada y no avisa, y una
## camara que se quedo en la identidad produce cuarenta y cinco iconos
## encuadrados desde el origen del mundo sin que nada de error.
##
## El encuadre no usa el radio de la caja sino las ocho esquinas proyectadas al
## espacio de la camara. Con el radio, una cama quedaria diminuta en el medio de
## su icono; con las esquinas, cada objeto llena el suyo. Que entonces el tomate
## y la cama se vean igual de grandes es a proposito: en una paleta, respetar la
## escala real deja la mitad de las entradas como puntitos.
static func _encuadrar(camara : Camera3D, caja : AABB) -> void:
	var direccion := DIRECCION.normalized()
	var centro := caja.get_center()
	var distancia := maxf(caja.size.length(), 1.0) * 2.0

	var base := Basis.looking_at(-direccion)
	var posicion := centro + direccion * distancia

	var inverso := Transform3D(base, posicion).affine_inverse()
	var minimo := Vector2(INF, INF)
	var maximo := Vector2(-INF, -INF)
	for i in 8:
		var p : Vector3 = inverso * caja.get_endpoint(i)
		var plano := Vector2(p.x, p.y)
		minimo = minimo.min(plano)
		maximo = maximo.max(plano)

	# Recentrar: el centro de la caja y el centro de su proyeccion no coinciden.
	var corrimiento := (minimo + maximo) * 0.5
	posicion += base.x * corrimiento.x + base.y * corrimiento.y

	camara.transform = Transform3D(base, posicion)
	var lado := maxf(maximo.x - minimo.x, maximo.y - minimo.y)
	camara.size = maxf(lado, 0.01) * MARGEN


## Devuelve la caja que envuelve a todas las mallas del modelo, en el espacio de
## su propia raiz.
##
## Hay que recorrerlo porque un modelo de KayKit trae varias MeshInstance3D, y
## quedarse con la primera encuadraria por una pata de la silla.
static func _caja_de(raiz : Node3D) -> AABB:
	var mallas : Array[VisualInstance3D] = []
	_juntar_mallas(raiz, mallas)
	if mallas.is_empty():
		return AABB()

	var total := _transformada_hasta(mallas[0], raiz) * mallas[0].get_aabb()
	for i in range(1, mallas.size()):
		total = total.merge(_transformada_hasta(mallas[i], raiz) * mallas[i].get_aabb())
	return total


## Acumula las transformadas locales desde una malla hasta la raiz del modelo.
##
## No usa global_transform por lo mismo que _encuadrar(): tiene que dar el mismo
## resultado este el nodo dentro del arbol o no.
static func _transformada_hasta(nodo : Node3D, raiz : Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual := nodo
	while actual != null:
		t = actual.transform * t
		if actual == raiz:
			break
		actual = actual.get_parent() as Node3D
	return t


static func _juntar_mallas(nodo : Node, salida : Array[VisualInstance3D]) -> void:
	if nodo is VisualInstance3D:
		salida.append(nodo)
	for hijo in nodo.get_children():
		_juntar_mallas(hijo, salida)


## Devuelve si la imagen salio enteramente transparente.
##
## Es la comprobacion que avisa cuando el render no dibujo nada. Sin ella, el
## script reportaria cuarenta y cinco iconos escritos con toda razon, y los
## cuarenta y cinco serian cuadrados vacios. Mira una grilla de puntos y no la
## imagen entera, que a 512 por 512 por 45 items seria lento sin decir mas.
static func _esta_vacia(imagen : Image) -> bool:
	if imagen == null:
		return true

	var paso := maxi(imagen.get_width() / 32, 1)
	for y in range(0, imagen.get_height(), paso):
		for x in range(0, imagen.get_width(), paso):
			if imagen.get_pixel(x, y).a > 0.02:
				return false
	return true


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
		fallidos : Array[String], vacios : Array[String]) -> void:
	print("GenerarIconos: %d iconos escritos en %s." % [escritos.size(), DIR_SALIDA])

	if not sin_modelo.is_empty():
		print("  Sin modelo, sin icono (%d): %s" % [sin_modelo.size(), ", ".join(sin_modelo)])

	if not vacios.is_empty():
		push_warning(
			"GenerarIconos: %d de %d iconos salieron transparentes. "
			% [vacios.size(), escritos.size()]
			+ "O el dibujo no llego a ocurrir, o la luz y el encuadre estan mal: %s"
			% ", ".join(vacios.slice(0, 8))
		)

	for aviso in fallidos:
		push_warning("GenerarIconos: %s" % aviso)

	if escritos.is_empty():
		return

	EditorInterface.get_resource_filesystem().scan()
	print("  Ahora corre ImportarItems.gd para que los ItemDefinition tomen su icono.")
