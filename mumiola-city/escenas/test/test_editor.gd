extends Node

## Comprueba el editor de punta a punta, por el camino real de las operaciones.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Escribe el resultado por consola y cierra el juego al terminar.
##
## Cubre lo que el plan marca como automatizable porque son las costuras:
## que colocar, pintar, retirar y borrar pasen por aplicar(); que toda operacion
## tenga inversa y deshacer devuelva la sala a como estaba; que una ranura de
## D25 se rechace en vez de aplicarse al piso; y que en modo juego el editor
## quede apagado y sin historial.

func _ready() -> void:
	for i in 3: await get_tree().process_frame

	var editor : EditorSala = get_tree().root.find_child("EditorSala", true, false)
	var paleta : RoomBuilderUI = get_tree().root.find_child("RoomBuilderUI", true, false)
	var sala := GameManager.sala_actual()
	var fallos := 0

	if editor == null or paleta == null or sala == null:
		print("FALLO: falta editor, paleta o sala"); get_tree().quit(); return
	print("editor y paleta en el arbol, sala: ", sala.name)

	GameManager.cambiar_modo(GameManager.Modo.EDITANDO)
	await get_tree().process_frame

	# Buscar una celda libre de verdad.
	var celda := Vector2i.ZERO
	var encontrada := false
	for x in range(2, 18):
		for z in range(2, 18):
			var c := Vector2i(x, z)
			if Errores.ok(sala.grid.motivo_bloqueo(c, Vector2i.ONE)):
				celda = c; encontrada = true; break
		if encontrada: break
	if not encontrada:
		print("FALLO: no hay celda libre"); get_tree().quit(); return

	var antes := sala.objetos().size()

	# --- colocar un item elegido en la paleta ---
	var def := ItemDatabase.obtener(&"silla_madera")
	paleta.item_elegido.emit(def)
	var codigo := editor.aplicar(OperacionSala.colocar(def.id, celda, 0))
	if not Errores.ok(codigo):
		print("FALLO: colocar dio ", Errores.mensaje(codigo)); fallos += 1
	if sala.objetos().size() != antes + 1:
		print("FALLO: el objeto no aparecio"); fallos += 1
	else:
		print("colocado en %s, objetos: %d -> %d" % [celda, antes, sala.objetos().size()])

	# --- deshacer ---
	if not sala.deshacer():
		print("FALLO: deshacer devolvio false"); fallos += 1
	if sala.objetos().size() != antes:
		print("FALLO: deshacer no quito el objeto (%d)" % sala.objetos().size()); fallos += 1
	else:
		print("deshecho, objetos de vuelta en %d" % antes)

	# --- rehacer ---
	if not sala.rehacer():
		print("FALLO: rehacer devolvio false"); fallos += 1
	if sala.objetos().size() != antes + 1:
		print("FALLO: rehacer no repuso el objeto"); fallos += 1
	else:
		print("rehecho")

	# --- retirar por operacion ---
	codigo = editor.aplicar(OperacionSala.retirar(celda))
	if not Errores.ok(codigo) or sala.objetos().size() != antes:
		print("FALLO: retirar (%s, %d objetos)" % [Errores.mensaje(codigo), sala.objetos().size()]); fallos += 1
	else:
		print("retirado")

	# --- pintar escenario y deshacer ---
	var pieza_antes : Dictionary = sala.grid.pieza_en(CatalogoPiezas.SUELO, celda)
	# Elegir a proposito una pieza distinta de la que ya esta, o el pintado seria
	# un no-op y la prueba pasaria sin comprobar nada.
	var otra : StringName = &"suelo_tierra"
	if pieza_antes.get("pieza", &"") == otra:
		otra = &"suelo_base"
	codigo = editor.aplicar(OperacionSala.pintar(CatalogoPiezas.SUELO, celda, otra))
	var despues : Dictionary = sala.grid.pieza_en(CatalogoPiezas.SUELO, celda)
	if not Errores.ok(codigo) or despues.get("pieza", &"") != otra:
		print("FALLO: pintar (%s -> %s)" % [Errores.mensaje(codigo), despues]); fallos += 1
	else:
		print("pintado: %s -> %s" % [pieza_antes.get("pieza", "nada"), despues["pieza"]])
	sala.deshacer()
	var vuelto : Dictionary = sala.grid.pieza_en(CatalogoPiezas.SUELO, celda)
	if vuelto.get("pieza", &"") != pieza_antes.get("pieza", &""):
		print("FALLO: deshacer el pintado dejo %s en vez de %s" % [vuelto, pieza_antes]); fallos += 1
	else:
		print("pintado deshecho, volvio a %s" % vuelto.get("pieza", "nada"))

	# --- una ranura no implementada se rechaza, no se aplica al piso (D25) ---
	codigo = editor.aplicar(OperacionSala.colocar(def.id, celda, 0, {}, 2))
	if codigo != Errores.Codigo.NO_ES_SUPERFICIE:
		print("FALLO: una ranura deberia rechazarse, dio %s" % Errores.mensaje(codigo)); fallos += 1
	else:
		print("ranura rechazada correctamente")

	# --- en modo juego el editor no hace nada ---
	GameManager.cambiar_modo(GameManager.Modo.JUGANDO)
	await get_tree().process_frame
	if editor.is_processing():
		print("FALLO: el editor sigue procesando en modo juego"); fallos += 1
	else:
		print("en modo juego el editor esta apagado")
	if sala.puede_deshacer():
		print("FALLO: volver a jugar no olvido el historial"); fallos += 1
	else:
		print("historial olvidado al volver a jugar")

	print("EDITOR: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
