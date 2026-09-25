extends Node

## Comprueba las reglas del servidor local: salas publicas, plantillas, crear,
## guardar, renombrar y borrar, con sus rechazos.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Escribe en user://salas, asi que conviene correrlo con un
## directorio de usuario aparte (config/custom_user_dir_name) para no mezclarse
## con las salas de verdad.
##
## Reemplaza a test_salas_archivo, que probaba las salas guardadas por nombre de
## la fase 3. Lo que se conserva de alli es lo importante: el ida y vuelta por
## disco —que pasa por JSON de texto y no es el de memoria— y que nada que venga
## de afuera pueda armar una ruta fuera de la carpeta de salas.

var _fallos := 0
var _local := ServidorLocal.new()


func _ready() -> void:
	for i in 3: await get_tree().process_frame

	_probar_ids()
	_probar_lectura()
	var id := _probar_crear()
	_probar_permisos(id)
	await _probar_ida_y_vuelta(id)
	_probar_borrar(id)

	print("SERVIDOR: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_ids() -> void:
	for malo in [&"../../etc/passwd", &"a/b", &"", &"MAYUSCULA", &"con espacio", StringName("x".repeat(65))]:
		_comprobar(not _local._id_valido(malo), "id rechazado: '%s'" % malo)
		_comprobar(_local.obtener_sala(malo).codigo == Errores.Codigo.SALA_NO_EXISTE,
			"y obtener_sala no lo usa para leer")
	_comprobar(_local._id_valido(&"pub_plaza") and _local._id_valido(&"s_0a1b2c"), "los ids buenos pasan")


func _probar_lectura() -> void:
	var publicas := _local.listar_salas_publicas()
	var ids := publicas.map(func(s : Dictionary) -> String: return s.id)
	_comprobar("pub_plaza" in ids, "la plaza esta entre las publicas (%s)" % [ids])

	var plaza := _local.obtener_sala(&"pub_plaza")
	_comprobar(Errores.ok(plaza.codigo) and plaza.doc.nombre == "Plaza", "se lee la plaza")
	_comprobar((plaza.doc.estructura.suelo as Array).size() > 100, "con su estructura entera")

	var formas := _local.plantillas()
	_comprobar(formas.size() == 5, "cinco plantillas (%d)" % formas.size())
	for f in formas:
		_comprobar(f.has("nombre") and (f.estructura.suelo as Array).size() > 0
			and (f.estructura.paredes as Array).size() > 0, "plantilla %s tiene suelo y paredes" % f.id)

	_comprobar(_local.obtener_sala(&"no_existe").codigo == Errores.Codigo.SALA_NO_EXISTE,
		"una sala que no existe")

	DirAccess.make_dir_recursive_absolute(ServidorLocal.DIR_SALAS)
	var roto := FileAccess.open(ServidorLocal.DIR_SALAS + "/s_rota.json", FileAccess.WRITE)
	roto.store_string("{esto no es json")
	roto.close()
	_comprobar(_local.obtener_sala(&"s_rota").codigo == Errores.Codigo.ARCHIVO_CORRUPTO,
		"un archivo danado se detecta")
	DirAccess.remove_absolute(ServidorLocal.DIR_SALAS + "/s_rota.json")

	# Una sala guardada por nombre en la fase 3, sin id: no se lista.
	var vieja := FileAccess.open(ServidorLocal.DIR_SALAS + "/mi_sala.json", FileAccess.WRITE)
	vieja.store_string(JSON.stringify({"nombre": "Mi sala", "propietario": "ana"}))
	vieja.close()
	_comprobar(_local.listar_salas_de(&"ana").is_empty(), "una sala vieja sin id no se lista")
	DirAccess.remove_absolute(ServidorLocal.DIR_SALAS + "/mi_sala.json")


func _probar_crear() -> StringName:
	_comprobar(_local.crear_sala("   ", &"cuadrada_chica", &"ana").codigo == Errores.Codigo.NOMBRE_INVALIDO,
		"un nombre en blanco se rechaza")
	_comprobar(_local.crear_sala("Taller", &"no_hay", &"ana").codigo == Errores.Codigo.PLANTILLA_NO_EXISTE,
		"una plantilla que no existe se rechaza")
	_comprobar(_local.crear_sala("Taller", &"../publicas/pub_plaza", &"ana").codigo
		== Errores.Codigo.PLANTILLA_NO_EXISTE, "y una plantilla con ruta tambien")

	var r := _local.crear_sala("  Taller   de  Ana ", &"en_l", &"ana")
	_comprobar(Errores.ok(r.codigo) and String(r.id).begins_with("s_"), "se crea una sala (%s)" % r.id)
	var doc : Dictionary = _local.obtener_sala(r.id).doc
	_comprobar(doc.get("nombre") == "Taller de Ana", "con el nombre limpio (%s)" % doc.get("nombre"))
	_comprobar(doc.get("propietario") == "ana" and doc.get("id") == String(r.id), "de Ana y con su id")
	var forma : Dictionary = _local.obtener_sala(&"pub_plaza").doc
	_comprobar((doc.estructura.suelo as Array).size() == 147, "con la forma de la plantilla")
	_comprobar(forma.id == "pub_plaza", "sin tocar la plaza")

	_comprobar(_local.crear_sala("taller DE ana", &"pasillo", &"ana").codigo == Errores.Codigo.NOMBRE_EN_USO,
		"el mismo nombre para el mismo duenio se rechaza")
	var de_otro := _local.crear_sala("Taller de Ana", &"pasillo", &"beto")
	_comprobar(Errores.ok(de_otro.codigo), "pero otro jugador si puede usarlo")

	var de_ana := _local.listar_salas_de(&"ana")
	_comprobar(de_ana.size() == 1 and de_ana[0].id == String(r.id), "Ana ve solo la suya")
	_local.borrar_sala(de_otro.id, &"beto")
	return r.id


func _probar_permisos(id : StringName) -> void:
	var doc : Dictionary = _local.obtener_sala(id).doc
	_comprobar(_local.guardar_sala(doc, &"beto") == Errores.Codigo.NO_ES_TUYO, "Beto no guarda la sala de Ana")
	_comprobar(_local.renombrar_sala(id, "Mia", &"beto") == Errores.Codigo.NO_ES_TUYO, "ni la renombra")
	_comprobar(_local.borrar_sala(id, &"beto") == Errores.Codigo.NO_ES_TUYO, "ni la borra")
	_comprobar(_local.borrar_sala(&"pub_plaza", &"ana") == Errores.Codigo.SALA_NO_EXISTE
		or _local.borrar_sala(&"pub_plaza", &"ana") == Errores.Codigo.SIN_PERMISO,
		"una publica no se borra desde el juego")

	_comprobar(Errores.ok(_local.renombrar_sala(id, "Estudio", &"ana")), "Ana si la renombra")
	_comprobar(_local.obtener_sala(id).doc.nombre == "Estudio", "y el nombre cambia")
	_comprobar(_local.renombrar_sala(id, "", &"ana") == Errores.Codigo.NOMBRE_INVALIDO, "a vacio no")


## La sala viva -> documento -> disco -> documento -> sala viva, y que vuelva igual.
func _probar_ida_y_vuelta(id : StringName) -> void:
	var sala : RoomController = GameManager.ESCENA_SALA.instantiate()
	add_child(sala)
	sala.from_dict(_local.obtener_sala(id).doc)
	_comprobar(sala.id_sala == id and sala.nombre_sala == "Estudio" and sala.propietario_id == &"ana",
		"la sala toma su identidad del documento")
	_comprobar(not sala.esta_sucia(), "recien cargada no esta sucia")

	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(3, 3), &"suelo_tierra"))
	sala.aplicar(OperacionSala.colocar(&"silla_madera", Vector2i(2, 2), 1))
	sala.aplicar(OperacionSala.colocar(&"mesa", Vector2i(4, 4), 0))
	_comprobar(sala.esta_sucia(), "editar la ensucia")
	var antes := sala.to_dict()

	_comprobar(Errores.ok(_local.guardar_sala(antes, &"ana")), "Ana la guarda")
	var otra : RoomController = GameManager.ESCENA_SALA.instantiate()
	add_child(otra)
	otra.from_dict(_local.obtener_sala(id).doc)
	var despues := otra.to_dict()
	_comprobar(JSON.stringify(despues.estructura) == JSON.stringify(antes.estructura),
		"la estructura vuelve igual del disco")
	_comprobar(JSON.stringify(despues.objetos) == JSON.stringify(antes.objetos),
		"los objetos vuelven iguales (%d)" % (despues.objetos as Array).size())
	sala.queue_free()
	otra.queue_free()
	await get_tree().process_frame


func _probar_borrar(id : StringName) -> void:
	_comprobar(Errores.ok(_local.borrar_sala(id, &"ana")), "Ana la borra")
	_comprobar(_local.obtener_sala(id).codigo == Errores.Codigo.SALA_NO_EXISTE, "y ya no esta")
	_comprobar(_local.borrar_sala(id, &"ana") == Errores.Codigo.SALA_NO_EXISTE, "borrarla dos veces no")


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
