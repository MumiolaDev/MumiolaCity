extends Node

## Comprueba que se pueda girar tanto un mueble como una pieza de escenario,
## y que las dos giren para el mismo lado.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## Lo que mas vale de aca es la comparacion de sentidos: un GridMap guarda
## indices ortogonales y no grados, asi que es facil terminar con la pared
## girando para un lado y la silla para el otro con la misma tecla, y eso no se
## nota leyendo el codigo.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var editor : EditorSala = get_tree().root.find_child("EditorSala", true, false)
	var paleta : RoomBuilderUI = get_tree().root.find_child("RoomBuilderUI", true, false)
	var fallos := 0

	# --- las cuatro orientaciones son distintas y dan la vuelta ---
	var vistos := {}
	for pasos in 4:
		vistos[CatalogoPiezas.orientacion_de(pasos)] = true
	if vistos.size() != 4:
		print("FALLO: las cuatro orientaciones no son distintas: %s" % str(vistos.keys())); fallos += 1
	if CatalogoPiezas.orientacion_de(4) != CatalogoPiezas.orientacion_de(0):
		print("FALLO: no da la vuelta a los cuatro pasos"); fallos += 1
	for pasos in 4:
		if CatalogoPiezas.pasos_de(CatalogoPiezas.orientacion_de(pasos)) != pasos:
			print("FALLO: ida y vuelta de orientacion falla en %d" % pasos); fallos += 1
	print("orientaciones: %s" % str(CatalogoPiezas.ORIENTACIONES))

	# --- giran para el mismo lado que los muebles ---
	var gm := GridMap.new()
	for pasos in 4:
		var base := gm.get_basis_with_orthogonal_index(CatalogoPiezas.orientacion_de(pasos))
		var grados_pieza : float = rad_to_deg(base.get_euler().y)
		var grados_mueble : float = rad_to_deg(-RoomController.PASO_ROTACION * pasos)
		var dif : float = fmod(absf(grados_pieza - grados_mueble) + 360.0, 360.0)
		var ok : bool = dif < 0.1 or absf(dif - 360.0) < 0.1
		print("  paso %d: pieza %6.1f  mueble %6.1f  %s" % [pasos, grados_pieza, grados_mueble, "ok" if ok else "MAL"])
		if not ok:
			fallos += 1
	gm.free()

	# --- pintar con orientacion y leerla de vuelta ---
	var celda := Vector2i(5, 5)
	for pasos in 4:
		var orientacion := CatalogoPiezas.orientacion_de(pasos)
		sala.aplicar(OperacionSala.pintar(CatalogoPiezas.PAREDES, celda, &"pared_base", orientacion))
		var leida : Dictionary = sala.grid.pieza_en(CatalogoPiezas.PAREDES, celda)
		if int(leida.get("orientacion", -1)) != orientacion:
			print("FALLO: se pinto %d y se leyo %s" % [orientacion, leida]); fallos += 1
	print("pintado con orientacion: ida y vuelta por los cuatro pasos")

	# --- el editor gira una pieza ---
	GameManager.cambiar_modo(GameManager.Modo.EDITANDO)
	await get_tree().process_frame
	paleta.pieza_elegida.emit(CatalogoPiezas.PAREDES, &"pared_base")
	# La paleta guarda su seleccion al elegir de verdad; para la prueba se fuerza.
	var listas : Array = paleta.get_node(^"Panel/Pestanias").get_children()
	var lista_paredes : ItemList = listas[listas.size() - 1]
	lista_paredes.select(1)
	lista_paredes.item_selected.emit(1)
	if paleta.clase() != RoomBuilderUI.Clase.PIEZA:
		print("FALLO: no quedo una pieza elegida"); fallos += 1

	var antes_giro : int = editor.get("_rotacion")
	editor.rotar()
	var despues_giro : int = editor.get("_rotacion")
	if despues_giro == antes_giro:
		print("FALLO: rotar() no giro una pieza (%d -> %d)" % [antes_giro, despues_giro]); fallos += 1
	else:
		print("el editor gira una pieza: %d -> %d" % [antes_giro, despues_giro])

	# --- y que lo colocado use esa orientacion ---
	var celda2 := Vector2i(6, 5)
	editor._colocar_en(celda2)
	var puesta : Dictionary = sala.grid.pieza_en(CatalogoPiezas.PAREDES, celda2)
	var esperada := CatalogoPiezas.orientacion_de(despues_giro)
	if int(puesta.get("orientacion", -1)) != esperada:
		print("FALLO: se coloco con orientacion %s y se esperaba %d" % [puesta, esperada]); fallos += 1
	else:
		print("la pieza se coloca con la orientacion girada (%d)" % esperada)

	# --- el fantasma muestra la pieza ---
	var indicador := sala.indicador
	var pieza : Dictionary = editor._pieza_elegida()
	if pieza["malla"] == null:
		print("FALLO: no se pudo sacar la malla de la pieza"); fallos += 1
	else:
		indicador.elegir_pieza(pieza["malla"], pieza["transformada"], 1)
		indicador.mostrar_en(celda2, 1)
		await get_tree().process_frame
		var tiene := false
		for h in indicador.get_children():
			if h is Node3D and h.get_child_count() > 0 and h.get_child(0) is MeshInstance3D:
				if (h.get_child(0) as MeshInstance3D).mesh == pieza["malla"]:
					tiene = true
		if not tiene:
			print("FALLO: el fantasma no muestra la malla de la pieza"); fallos += 1
		else:
			print("el fantasma muestra la pieza elegida")

	print("ROTACION: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
