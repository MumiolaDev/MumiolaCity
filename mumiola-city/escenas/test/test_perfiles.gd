extends Node

## Comprueba los perfiles, del menu de inicio al juego y de vuelta.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. Escribe en user://perfiles y user://salas; ver test_servidor.
##
## Es la prueba de punta a punta de la etapa: crear un perfil desde el menu,
## aparecer en su casa, llevarse algo, ir a otra sala, volver al menu con
## "Guardar y volver", entrar de nuevo y estar donde se estaba, con lo que se
## llevaba. Recorre dos cambios de escena, asi que lo primero que hace es mudarse
## a la raiz del arbol: colgado del mundo, moriria con el.

const MENU := "res://escenas/menu/MenuInicio.tscn"
const MUNDO := "res://escenas/mundo/Mundo.tscn"

var _fallos := 0
## El mundo que se vuelve a cargar trae otra copia de esta prueba colgada, como
## la trajo la primera vez. Esa copia se va sin hacer nada.
static var _corriendo := false


func _ready() -> void:
	if _corriendo:
		queue_free()
		return
	_corriendo = true
	for i in 3: await get_tree().process_frame
	_probar_reglas()

	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	await tree_entered
	await _recorrido()

	print("PERFILES: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_reglas() -> void:
	var local := ServidorLocal.new()
	for malo in ["ab", "   ", "!!!!", "a b", "x".repeat(21), "<b>hola</b>"]:
		_comprobar(local.crear_perfil(malo).codigo == Errores.Codigo.NOMBRE_INVALIDO,
			"nombre de jugador rechazado: '%s'" % malo)
	var r := local.crear_perfil("  Ana  María ")
	_comprobar(Errores.ok(r.codigo) and String(r.id).begins_with("p_"), "se crea un perfil con tildes")
	var doc : Dictionary = local.obtener_perfil(r.id).doc
	_comprobar(doc.nombre == "Ana María", "con el nombre limpio (%s)" % doc.nombre)
	_comprobar(local.crear_perfil("ana maría").codigo == Errores.Codigo.NOMBRE_EN_USO,
		"el mismo nombre no se repite")

	var casas := local.listar_salas_de(r.id)
	_comprobar(casas.size() == 1 and casas[0].nombre == "Casa de Ana María", "trae su casa")
	_comprobar(doc.sala_actual == casas[0].id, "y empieza en ella")
	_comprobar(local.guardar_perfil(doc, &"otro") == Errores.Codigo.NO_ES_TUYO, "otro no guarda tu perfil")

	_comprobar(Errores.ok(local.borrar_perfil(r.id)), "se borra el perfil")
	_comprobar(local.listar_salas_de(r.id).is_empty(), "y se lleva sus salas")
	_comprobar(local.obtener_perfil(r.id).codigo == Errores.Codigo.PERFIL_NO_EXISTE, "ya no esta")


func _recorrido() -> void:
	# --- menu: crear y entrar ---
	get_tree().change_scene_to_file(MENU)
	var menu : MenuInicio = await _esperar_escena(MENU)
	_comprobar(menu._perfiles.is_item_disabled(0), "sin perfiles, la lista lo dice")
	menu._nombre.text = "Marta"
	menu._nombre.text_changed.emit("Marta")
	menu.crear()
	await _esperar_escena(MUNDO)
	await _esperar_sala()

	var sala := GameManager.sala_actual()
	var jugador := GameManager.jugador_actual()
	var id := GameManager.perfil_id()
	jugador.set_process_unhandled_input(false)
	_comprobar(GameManager.hay_sesion() and String(id).begins_with("p_"), "hay sesion con el perfil nuevo")
	_comprobar(sala.nombre_sala == "Casa de Marta" and sala.propietario_id == id, "aparece en su casa")
	_comprobar(GameManager.id_de_actor(jugador) == id, "el jugador es el actor del perfil")
	await Consola.enviar("hola")
	var ultimo : Dictionary = Consola.historial()[-1]
	_comprobar(ultimo.autor_nombre == "Marta" and ultimo.autor_id == id, "habla con su nombre")

	# --- llevarse algo, moverse, volver al menu ---
	InventoryManager.vaciar()
	await Consola.enviar("/dar silla_madera 3")
	await GameManager.ir_a(GameManager.SALA_INICIAL)
	var plaza := GameManager.sala_actual()
	var celda := plaza.celda_entrada + Vector2i(2, 1)
	jugador.ubicar_en_celda(celda)
	await get_tree().process_frame

	var pausa : MenuPausa = get_tree().root.find_child("MenuPausa", true, false)
	pausa.volver_al_inicio()
	menu = await _esperar_escena(MENU)
	_comprobar(not GameManager.hay_sesion(), "volver al inicio cierra la sesion")
	var guardado : Dictionary = ServidorLocal.new().obtener_perfil(id).doc
	_comprobar(guardado.sala_actual == "pub_plaza", "el perfil guardo donde estaba (%s)" % guardado.sala_actual)
	var guardada := Vector2i(int(guardado.celda_jugador[0]), int(guardado.celda_jugador[1]))
	_comprobar(guardada == celda, "y en que celda (%s)" % guardada)
	_comprobar(menu._perfiles.item_count == 1 and menu._perfiles.get_item_text(0) == "Marta",
		"el menu lista a Marta")

	# --- entrar de nuevo ---
	InventoryManager.vaciar()
	menu.entrar()
	await _esperar_escena(MUNDO)
	await _esperar_sala()
	jugador = GameManager.jugador_actual()
	sala = GameManager.sala_actual()
	_comprobar(sala.id_sala == GameManager.SALA_INICIAL, "vuelve a la plaza")
	_comprobar(sala.grid.mundo_a_celda(jugador.global_position) == celda, "en la misma celda")
	_comprobar(InventoryManager.cantidad_de(&"silla_madera") == 3, "con las tres sillas en la mochila")

	GameManager.cerrar_sesion()
	ServidorLocal.new().borrar_perfil(id)


func _esperar_escena(ruta : String) -> Node:
	for i in 600:
		await get_tree().process_frame
		var escena := get_tree().current_scene
		if escena != null and escena.scene_file_path == ruta and escena.is_node_ready():
			await get_tree().process_frame
			return escena
	_comprobar(false, "llego a la escena %s" % ruta)
	return null


func _esperar_sala() -> void:
	for i in 600:
		await get_tree().process_frame
		if GameManager.sala_actual() != null and not GameManager.cambiando_de_sala():
			return


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
