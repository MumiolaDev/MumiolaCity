extends Node

## Comprueba el desplazamiento y el zoom de la camara.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## La prueba que importa no es que el pivote se mueva, sino que el mundo se mueva
## *con el cursor*: se mira que celda hay bajo un punto de pantalla, se arrastra,
## y esa misma celda tiene que quedar bajo el punto desplazado.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var fallos := 0
	var camara := sala.camara

	var punto := Vector2(500, 400)
	var arrastre := Vector2(120, -80)

	for etapa in ["de fabrica", "girado", "acercado", "girado y acercado"]:
		if etapa == "girado" or etapa == "girado y acercado":
			sala.rotar(1)
		if etapa == "acercado" or etapa == "girado y acercado":
			sala.acercar(4)
		await get_tree().process_frame

		# En continuo y no por celda: celda_bajo_puntero() redondea a entero, y
		# medir con el la exactitud del arrastre confunde el redondeo con un error.
		var mundo_antes := _punto_en_el_piso(camara, punto, sala.grid.altura_piso)
		sala.desplazar(arrastre)
		await get_tree().process_frame
		var mundo_despues := _punto_en_el_piso(camara, punto + arrastre, sala.grid.altura_piso)

		var error : float = Vector2(mundo_antes.x - mundo_despues.x, mundo_antes.z - mundo_despues.z).length()
		var ok := error < 0.01
		print("  %-20s zoom %5.2f   desvio %.5f m  %s"
			% [etapa, sala.zoom(), error, "ok" if ok else "MAL"])
		if not ok:
			fallos += 1

	# --- zoom ---
	sala.camara.size = 20.0
	sala.acercar(1)
	var acercado := sala.zoom()
	sala.acercar(-1)
	var vuelto := sala.zoom()
	print("zoom: 20.00 -> %.3f -> %.3f" % [acercado, vuelto])
	if acercado >= 20.0:
		print("FALLO: acercar no achico el size"); fallos += 1
	if absf(vuelto - 20.0) > 0.001:
		print("FALLO: acercar y alejar no vuelve al mismo zoom"); fallos += 1

	# --- limites ---
	for i in 200: sala.acercar(1)
	if absf(sala.zoom() - sala.zoom_minimo) > 0.001:
		print("FALLO: no respeto el zoom minimo (%.2f)" % sala.zoom()); fallos += 1
	for i in 400: sala.acercar(-1)
	if absf(sala.zoom() - sala.zoom_maximo) > 0.001:
		print("FALLO: no respeto el zoom maximo (%.2f)" % sala.zoom()); fallos += 1
	print("limites: %.1f a %.1f respetados" % [sala.zoom_minimo, sala.zoom_maximo])

	# --- encuadrar ---
	sala.centrar()
	await get_tree().process_frame
	var region := sala.grid.region_usada()
	var centro_celda := sala.grid.celda_bajo_puntero(camara, get_viewport().get_visible_rect().size * 0.5)
	var esperado := region.position + region.size / 2
	var lejos : int = (centro_celda - esperado).length()
	print("encuadrar: region %s, centro de pantalla en %s (esperado ~%s, a %d celdas)"
		% [region.size, centro_celda, esperado, lejos])
	if lejos > 2:
		print("FALLO: centrar() no dejo la sala centrada"); fallos += 1
	if sala.zoom() > sala.zoom_maximo or sala.zoom() < sala.zoom_minimo:
		print("FALLO: centrar() dejo el zoom fuera de rango"); fallos += 1

	print("CAMARA: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()


## Donde cae un punto de pantalla sobre el plano del piso.
func _punto_en_el_piso(camara : Camera3D, pantalla : Vector2, altura : float) -> Vector3:
	var origen := camara.project_ray_origin(pantalla)
	var direccion := camara.project_ray_normal(pantalla)
	var plano := Plane(Vector3.UP, altura)
	var golpe = plano.intersects_ray(origen, direccion)
	return Vector3.ZERO if golpe == null else golpe
