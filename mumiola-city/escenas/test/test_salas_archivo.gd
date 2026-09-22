extends Node

## Comprueba guardar y cargar una sala como archivo suelto.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Cubre el ida y vuelta por disco —que es distinto del de memoria, porque pasa
## por JSON de texto— y los cuatro rechazos: archivo que no existe, nombre que no
## sirve, sala nula y archivo danado. Incluye los nombres de archivo, que no son
## cosmetica: sin filtrar, un nombre con "../" escribiria fuera de la carpeta de
## salas.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var fallos := 0

	# --- nombres de archivo seguros ---
	var casos := {
		"Plaza": "plaza", "Mi Sala Linda": "mi_sala_linda",
		"Mi Habitación": "mi_habitacion", "Niño": "nino",
		"../../etc/passwd": "etcpasswd", "!!!": "", "  ": "",
	}
	for entrada in casos:
		var obtenido : String = SaveManager._nombre_archivo(entrada)
		if obtenido != casos[entrada]:
			print("FALLO: '%s' -> '%s', se esperaba '%s'" % [entrada, obtenido, casos[entrada]]); fallos += 1
	print("nombres de archivo: %d casos comprobados" % casos.size())

	# --- armar algo distinto para poder notar la diferencia ---
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(4, 4), &"suelo_tierra"))
	sala.aplicar(OperacionSala.borrar(CatalogoPiezas.SUELO, Vector2i(6, 6)))
	for c in [Vector2i(3, 3), Vector2i(8, 8)]:
		sala.aplicar(OperacionSala.colocar(&"silla_madera", c, 0))
	var antes := sala.to_dict()

	# --- guardar ---
	var codigo := SaveManager.guardar_sala(sala)
	if not Errores.ok(codigo):
		print("FALLO: guardar dio %s" % Errores.mensaje(codigo)); fallos += 1
	var ruta := "user://salas/%s.json" % SaveManager._nombre_archivo(sala.nombre_sala)
	if not FileAccess.file_exists(ruta):
		print("FALLO: no se escribio %s" % ruta); fallos += 1
	else:
		print("guardada en %s (%.1f KB)" % [ruta, FileAccess.open(ruta, FileAccess.READ).get_length() / 1024.0])

	if not SaveManager.existe_sala(sala.nombre_sala):
		print("FALLO: existe_sala dice que no"); fallos += 1
	var lista := SaveManager.salas_guardadas()
	print("salas guardadas: %s" % str(lista))
	if not (SaveManager._nombre_archivo(sala.nombre_sala) in lista):
		print("FALLO: no aparece en salas_guardadas()"); fallos += 1

	# --- romper la sala y volver a cargar ---
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(4, 4), &"suelo_base"))
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(6, 6), &"suelo_base"))
	sala.aplicar(OperacionSala.colocar(&"mesa", Vector2i(12, 12), 0))
	await get_tree().process_frame

	codigo = SaveManager.cargar_sala(sala, sala.nombre_sala)
	await get_tree().process_frame
	if not Errores.ok(codigo):
		print("FALLO: cargar dio %s" % Errores.mensaje(codigo)); fallos += 1

	var despues := sala.to_dict()
	if JSON.stringify(despues["estructura"]) != JSON.stringify(antes["estructura"]):
		print("FALLO: la estructura no volvio igual desde el archivo"); fallos += 1
	else:
		print("estructura identica tras el viaje por disco")
	if JSON.stringify(despues["objetos"]) != JSON.stringify(antes["objetos"]):
		print("FALLO: los objetos no volvieron iguales"); fallos += 1
	else:
		print("objetos identicos tras el viaje por disco")

	# --- casos de error ---
	if SaveManager.cargar_sala(sala, "no_existe_esta") != Errores.Codigo.ARCHIVO_NO_EXISTE:
		print("FALLO: cargar algo inexistente deberia dar ARCHIVO_NO_EXISTE"); fallos += 1
	if SaveManager.guardar_sala(sala, "!!!") != Errores.Codigo.NOMBRE_INVALIDO:
		print("FALLO: un nombre imposible deberia dar NOMBRE_INVALIDO"); fallos += 1
	if SaveManager.cargar_sala(null, "plaza") == Errores.Codigo.OK:
		print("FALLO: cargar sobre null deberia fallar"); fallos += 1

	# Un archivo danado.
	var roto := FileAccess.open("user://salas/rota.json", FileAccess.WRITE)
	roto.store_string("{esto no es json")
	roto.close()
	if SaveManager.cargar_sala(sala, "rota") != Errores.Codigo.ARCHIVO_CORRUPTO:
		print("FALLO: un json roto deberia dar ARCHIVO_CORRUPTO"); fallos += 1
	else:
		print("archivo danado detectado")

	print("SALAS EN ARCHIVO: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
