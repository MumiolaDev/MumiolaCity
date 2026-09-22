extends Node

## Comprueba que el documento de una sala sea una ida y vuelta exacta.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Es la comprobacion que el plan pide automatizar, porque es una costura: pinta,
## despinta, coloca, guarda, rompe la sala a proposito y vuelve a cargar. Pasa
## por JSON de verdad y no por el diccionario en memoria, que es donde los
## enteros se vuelven float y donde un ida y vuelta se rompe de verdad.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var fallos := 0

	# Armar algo para guardar: pintar, romper el suelo y poner muebles.
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(4, 4), &"suelo_tierra"))
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(5, 4), &"suelo_tierra"))
	sala.aplicar(OperacionSala.borrar(CatalogoPiezas.SUELO, Vector2i(6, 6)))
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.PAREDES, Vector2i(7, 7), &"pilar_base", 10))
	var puestos := 0
	for c in [Vector2i(3, 3), Vector2i(8, 8), Vector2i(9, 9)]:
		if Errores.ok(sala.aplicar(OperacionSala.colocar(&"silla_madera", c, 0))):
			puestos += 1

	var doc := sala.to_dict()
	print("version_formato=%s  catalogo='%s'  objetos=%d" % [doc["version_formato"], doc["catalogo"], doc["objetos"].size()])
	print("estructura: suelo %d celdas, paredes %d celdas"
		% [doc["estructura"]["suelo"].size(), doc["estructura"]["paredes"].size()])
	if doc["objetos"].size() != puestos:
		print("FALLO: se guardaron %d objetos y se pusieron %d" % [doc["objetos"].size(), puestos]); fallos += 1
	if doc["catalogo"] == "":
		print("FALLO: el documento no lleva version de catalogo"); fallos += 1

	# Pasar por JSON de verdad, que es donde los enteros se vuelven float.
	var texto := JSON.stringify(doc)
	var crudo = JSON.parse_string(texto)
	if not (crudo is Dictionary):
		print("FALLO: el documento no sobrevivio a JSON"); get_tree().quit(); return
	print("json: %.1f KB" % (texto.length() / 1024.0))

	# Romper la sala a proposito.
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(4, 4), &"suelo_base"))
	sala.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, Vector2i(6, 6), &"suelo_base"))
	sala.aplicar(OperacionSala.colocar(&"mesa", Vector2i(12, 12), 0))
	await get_tree().process_frame

	var codigo := sala.from_dict(crudo)
	await get_tree().process_frame
	if not Errores.ok(codigo):
		print("FALLO: from_dict dio %s" % Errores.mensaje(codigo)); fallos += 1

	var vuelta := sala.to_dict()
	if JSON.stringify(vuelta["estructura"]) != JSON.stringify(doc["estructura"]):
		print("FALLO: la estructura no volvio igual")
		fallos += 1
	else:
		print("estructura identica tras el viaje")
	if JSON.stringify(vuelta["objetos"]) != JSON.stringify(doc["objetos"]):
		print("FALLO: los objetos no volvieron iguales")
		print("   antes:  ", doc["objetos"])
		print("   despues:", vuelta["objetos"])
		fallos += 1
	else:
		print("objetos identicos tras el viaje")

	# La celda que se habia despintado tiene que seguir despintada.
	if not sala.grid.pieza_en(CatalogoPiezas.SUELO, Vector2i(6, 6)).is_empty():
		print("FALLO: (6,6) deberia haber quedado sin suelo"); fallos += 1
	# Y el mueble agregado despues de guardar no tiene que estar.
	if sala.grid.objeto_en(Vector2i(12, 12)) != null:
		print("FALLO: quedo un mueble que no estaba en el documento"); fallos += 1

	# Cargar no deja historial que deshacer.
	if sala.puede_deshacer():
		print("FALLO: cargar dejo historial"); fallos += 1

	# Un documento de una version mas nueva se rechaza.
	var futuro := doc.duplicate(true)
	futuro["version_formato"] = 99
	if sala.from_dict(futuro) != Errores.Codigo.FORMATO_DESCONOCIDO:
		print("FALLO: un documento del futuro deberia rechazarse"); fallos += 1
	else:
		print("documento de version 99 rechazado")

	print("DOCUMENTO: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
