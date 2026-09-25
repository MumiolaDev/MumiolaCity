extends Ventana
class_name NavegadorUI

## El navegador de salas, como el de Habbo: las publicas, las tuyas, y crear
## una nueva desde una forma.
##
## Todo lo pide a Servidor y todo cambio de sala pasa por GameManager.ir_a(): la
## ventana no sabe de archivos ni de escenas. Por eso sirve tal cual el dia que
## las listas vengan de la red, con salas de otros jugadores y gente adentro.
##
## Las listas se piden de nuevo cada vez que se abre la ventana y despues de
## crear, renombrar o borrar. No se guardan entre aperturas: con red, una lista
## vieja es una lista que miente.
##
## N la abre y la cierra.

## Lado en pixeles de cada celda en la miniatura de una forma.
const PIXELES_POR_CELDA := 5
const COLOR_SUELO := Color("dfe5e9")
const COLOR_PARED := Color("2b2622")
const COLOR_ENTRADA := Color("ffa61f")

var _pestanas : TabContainer = null
var _publicas : ItemList = null
var _propias : ItemList = null
var _boton_ir_propia : Button = null
var _boton_renombrar : Button = null
var _boton_borrar : Button = null
var _nombre_nueva : LineEdit = null
var _formas : ItemList = null
var _boton_crear : Button = null


func _ready() -> void:
	titulo = "Navegador"
	custom_minimum_size = Vector2(490, 480)

	_pestanas = TabContainer.new()
	_pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pestanas.add_child(_armar_publicas())
	_pestanas.add_child(_armar_propias())
	_pestanas.add_child(_armar_crear())
	add_child(_pestanas)
	super._ready()

	GameManager.sala_cambiada.connect(func(_s : RoomController) -> void:
		if visible:
			refrescar())


## Abre el navegador con las listas al dia.
func abrir() -> void:
	super.abrir()
	refrescar()


## Vuelve a pedir las tres listas.
func refrescar() -> void:
	var actual := GameManager.sala_actual()
	var aca := actual.id_sala if actual != null else &""

	_llenar(_publicas, await Servidor.listar_salas_publicas(), aca)
	_llenar(_propias, await Servidor.listar_salas_de(GameManager.perfil_id()), aca)
	_al_cambiar_eleccion_propia()

	if _formas.item_count == 0:
		for forma in await Servidor.plantillas():
			var i := _formas.add_item(forma.nombre, miniatura(forma.estructura, forma.get("entrada", [])))
			_formas.set_item_metadata(i, forma.id)
			_formas.set_item_tooltip(i, str(forma.get("descripcion", "")))
		if _formas.item_count > 0:
			_formas.select(0)
	_al_cambiar_nombre(_nombre_nueva.text)


func _unhandled_key_input(evento : InputEvent) -> void:
	super._unhandled_key_input(evento)
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_N:
		alternar()
		get_viewport().set_input_as_handled()


## Dibuja la planta de una sala: suelo claro, paredes oscuras, la entrada en
## naranja. Sale del documento y no de una imagen, asi que una forma nueva trae
## su miniatura sin que nadie la dibuje.
static func miniatura(estructura : Dictionary, entrada : Array = []) -> ImageTexture:
	var celdas : Array = []
	celdas.append_array(estructura.get("suelo", []))
	celdas.append_array(estructura.get("paredes", []))
	if celdas.is_empty():
		return null

	var minimo := Vector2i(1 << 20, 1 << 20)
	var maximo := Vector2i(-(1 << 20), -(1 << 20))
	for c in celdas:
		minimo = Vector2i(mini(minimo.x, int(c[0])), mini(minimo.y, int(c[1])))
		maximo = Vector2i(maxi(maximo.x, int(c[0])), maxi(maximo.y, int(c[1])))
	var lado := maximo - minimo + Vector2i.ONE

	var imagen := Image.create(lado.x * PIXELES_POR_CELDA, lado.y * PIXELES_POR_CELDA, false, Image.FORMAT_RGBA8)
	var pintar := func(c : Vector2i, color : Color) -> void:
		var p := (c - minimo) * PIXELES_POR_CELDA
		imagen.fill_rect(Rect2i(p, Vector2i.ONE * PIXELES_POR_CELDA), color)
	for c in estructura.get("suelo", []):
		pintar.call(Vector2i(int(c[0]), int(c[1])), COLOR_SUELO)
	for c in estructura.get("paredes", []):
		pintar.call(Vector2i(int(c[0]), int(c[1])), COLOR_PARED)
	if entrada.size() == 2:
		pintar.call(Vector2i(int(entrada[0]), int(entrada[1])), COLOR_ENTRADA)
	return ImageTexture.create_from_image(imagen)


# --- Armado ---------------------------------------------------------------------


func _armar_publicas() -> Control:
	var hoja := VBoxContainer.new()
	hoja.name = "Publicas"
	_publicas = _lista()
	_publicas.item_activated.connect(func(i : int) -> void: _ir(_publicas, i))
	hoja.add_child(_publicas)

	var ir := Button.new()
	ir.text = "Ir"
	ir.size_flags_horizontal = Control.SIZE_SHRINK_END
	ir.pressed.connect(func() -> void: _ir_a_elegida(_publicas))
	hoja.add_child(ir)
	return hoja


func _armar_propias() -> Control:
	var hoja := VBoxContainer.new()
	hoja.name = "Mis salas"
	_propias = _lista()
	_propias.item_activated.connect(func(i : int) -> void: _ir(_propias, i))
	_propias.item_selected.connect(func(_i : int) -> void: _al_cambiar_eleccion_propia())
	hoja.add_child(_propias)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_END
	_boton_borrar = _boton("Borrar", _borrar_elegida)
	_boton_renombrar = _boton("Renombrar", _renombrar_elegida)
	_boton_ir_propia = _boton("Ir", func() -> void: _ir_a_elegida(_propias))
	for b in [_boton_borrar, _boton_renombrar, _boton_ir_propia]:
		botones.add_child(b)
	hoja.add_child(botones)
	return hoja


func _armar_crear() -> Control:
	var hoja := VBoxContainer.new()
	hoja.name = "Crear sala"
	hoja.add_theme_constant_override(&"separation", 8)

	var etiqueta := Label.new()
	etiqueta.text = "Nombre"
	hoja.add_child(etiqueta)
	_nombre_nueva = LineEdit.new()
	_nombre_nueva.placeholder_text = "Mi sala"
	_nombre_nueva.max_length = ServidorLocal.LARGO_MAXIMO_NOMBRE
	_nombre_nueva.text_changed.connect(_al_cambiar_nombre)
	_nombre_nueva.text_submitted.connect(func(_t : String) -> void: _crear())
	hoja.add_child(_nombre_nueva)

	var forma := Label.new()
	forma.text = "Forma"
	hoja.add_child(forma)
	_formas = ItemList.new()
	_formas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_formas.max_columns = 0
	_formas.icon_mode = ItemList.ICON_MODE_TOP
	_formas.fixed_column_width = 140
	_formas.same_column_width = true
	_formas.fixed_icon_size = Vector2i(90, 90)
	_formas.item_selected.connect(func(_i : int) -> void: _al_cambiar_nombre(_nombre_nueva.text))
	hoja.add_child(_formas)

	_boton_crear = _boton("Crear e ir", _crear)
	_boton_crear.size_flags_horizontal = Control.SIZE_SHRINK_END
	hoja.add_child(_boton_crear)
	return hoja


func _lista() -> ItemList:
	var lista := ItemList.new()
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.custom_minimum_size = Vector2(0, 300)
	return lista


func _boton(texto : String, accion : Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.pressed.connect(accion)
	return b


## Llena una lista de salas, marcando en la que estas.
func _llenar(lista : ItemList, salas : Array[Dictionary], aca : StringName) -> void:
	var elegida := _id_elegido(lista)
	lista.clear()
	for s in salas:
		var texto : String = s.nombre
		if StringName(s.id) == aca:
			texto += "   (estas aca)"
		var i := lista.add_item(texto)
		lista.set_item_metadata(i, StringName(s.id))
		var descripcion : String = s.descripcion if s.descripcion != "" else "Sin descripcion."
		lista.set_item_tooltip(i, "%s\n%d objetos" % [descripcion, s.objetos])
		if StringName(s.id) == elegida:
			lista.select(i)
	if lista == _propias and salas.is_empty():
		var i := lista.add_item("Todavia no tenes salas. Crea una en la pestana de al lado.")
		lista.set_item_disabled(i, true)
		lista.set_item_selectable(i, false)


func _id_elegido(lista : ItemList) -> StringName:
	var elegidos := lista.get_selected_items()
	if elegidos.is_empty():
		return &""
	var meta = lista.get_item_metadata(elegidos[0])
	return meta if meta is StringName else &""


# --- Acciones -------------------------------------------------------------------


func _ir(lista : ItemList, indice : int) -> void:
	var id = lista.get_item_metadata(indice)
	if not (id is StringName):
		return
	# Se cierra al elegir y no al llegar: el fundido ya dice que se esta yendo, y
	# la ventana flotando sobre el telon solo estorba. Si el viaje falla, el
	# motivo va a la consola y el jugador sigue donde estaba.
	cerrar()
	var codigo : Errores.Codigo = await GameManager.ir_a(id)
	if not Errores.ok(codigo):
		GameManager.avisar_error(codigo)


func _ir_a_elegida(lista : ItemList) -> void:
	var elegidos := lista.get_selected_items()
	if not elegidos.is_empty():
		_ir(lista, elegidos[0])


func _al_cambiar_eleccion_propia() -> void:
	var hay := _id_elegido(_propias) != &""
	for b in [_boton_ir_propia, _boton_renombrar, _boton_borrar]:
		b.disabled = not hay


func _renombrar_elegida() -> void:
	var id := _id_elegido(_propias)
	if id == &"":
		return
	var actual := _propias.get_item_text(_propias.get_selected_items()[0]).trim_suffix("   (estas aca)")
	var r : Dictionary = await Dialogo.pedir_texto(get_parent(), "Renombrar sala", "Nuevo nombre:",
		actual).respondido
	if not r.aceptado:
		return
	var codigo : Errores.Codigo = await Servidor.renombrar_sala(id, r.texto, GameManager.perfil_id())
	if not Errores.ok(codigo):
		GameManager.avisar_error(codigo)
		return
	var sala := GameManager.sala_actual()
	if sala != null and sala.id_sala == id:
		sala.nombre_sala = r.texto.strip_edges()
		GameManager.sala_actualizada.emit(sala)
	refrescar()


func _borrar_elegida() -> void:
	var id := _id_elegido(_propias)
	if id == &"":
		return
	var actual := GameManager.sala_actual()
	if actual != null and actual.id_sala == id:
		GameManager.avisar_error(Errores.Codigo.SALA_EN_USO)
		return
	var nombre := _propias.get_item_text(_propias.get_selected_items()[0])
	var r : Dictionary = await Dialogo.confirmar(get_parent(), "Borrar sala",
		"¿Borrar '%s' con todo lo que tiene adentro? No se puede deshacer." % nombre, "Borrar").respondido
	if not r.aceptado:
		return
	var codigo : Errores.Codigo = await Servidor.borrar_sala(id, GameManager.perfil_id())
	if Errores.ok(codigo):
		GameManager.avisar("Sala '%s' borrada." % nombre)
	else:
		GameManager.avisar_error(codigo)
	refrescar()


func _al_cambiar_nombre(texto : String) -> void:
	_boton_crear.disabled = texto.strip_edges().is_empty() or _formas.get_selected_items().is_empty()


func _crear() -> void:
	var elegidas := _formas.get_selected_items()
	if _nombre_nueva.text.strip_edges().is_empty() or elegidas.is_empty():
		return
	var forma : StringName = _formas.get_item_metadata(elegidas[0])
	var r : Dictionary = await Servidor.crear_sala(_nombre_nueva.text, forma, GameManager.perfil_id())
	if not Errores.ok(r.codigo):
		GameManager.avisar_error(r.codigo)
		return
	_nombre_nueva.clear()
	_al_cambiar_nombre("")
	_pestanas.current_tab = 1
	cerrar()
	var codigo : Errores.Codigo = await GameManager.ir_a(r.id)
	if not Errores.ok(codigo):
		GameManager.avisar_error(codigo)
