extends VBoxContainer
class_name VistaContenedor

## Muestra un Contenedor: todas sus casillas, las ocupadas y los huecos, cuantas
## hay usadas, cuanto pesa, y el detalle de la que este elegida.
##
## Es la pieza que se reutiliza para todo lo que guarda cosas. Hoy la usa la
## pestana de la mochila; manana la ventana de una alacena o de una heladera es
## otra VistaContenedor con otro Contenedor, y lo unico que cambia es a quien
## se le pasa en mostrar().
##
## No sabe que se puede hacer con lo que muestra. Eso depende de donde este
## —desde la mochila se coloca en la sala, desde una alacena se saca—, asi que
## avisa que se eligio o se activo una casilla y quien la contiene decide. Lo
## unico que hace por su cuenta es ordenar: arrastrar una casilla sobre otra
## llama a Contenedor.mover(), que vale igual para cualquier contenedor.
##
## Se entera sola de los cambios por Contenedor.cambiado. Nadie tiene que
## acordarse de refrescarla.
##
## Se arma en codigo, en _init, para que se pueda crear con new() y usar sin
## escena, como un control mas.

## Se eligio una casilla con algo adentro, con un clic.
signal casilla_elegida(indice : int)
## Se activo una casilla, con doble clic. Quien contiene la vista decide que
## significa: desde la mochila, colocar.
signal casilla_activada(indice : int)

## Lo que arrastra una casilla lleva esta marca, para no confundirlo con otras
## cosas que se arrastren por la interfaz.
const TIPO_ARRASTRE := &"casilla_contenedor"
## El tono de la casilla elegida. Tine solo el marco, no el icono.
const TONO_ELEGIDA := Color(1.0, 0.8, 0.45)

## Cuantas casillas por fila.
@export var columnas : int = 8 : set = set_columnas
## Cuanto mide de lado cada casilla, en pixeles.
@export var lado_casilla : int = 56
## Cuantas filas se ven sin desplazar. Un contenedor mas grande se desplaza.
@export var filas_visibles : int = 5

var _contenedor : Contenedor = null
var _casillas : Array[Casilla] = []
var _elegida : int = -1

var _capacidad : Label
var _peso : ProgressBar
var _peso_texto : Label
var _desplazable : ScrollContainer
var _grilla : GridContainer
var _detalle_nombre : Label
var _detalle_texto : Label


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	_armar()


## Muestra un contenedor, soltando el que se mostraba antes.
func mostrar(contenedor_nuevo : Contenedor) -> void:
	if _contenedor != null and _contenedor.cambiado.is_connected(refrescar):
		_contenedor.cambiado.disconnect(refrescar)
	_contenedor = contenedor_nuevo
	_elegida = -1
	if _contenedor != null:
		_contenedor.cambiado.connect(refrescar)
	_armar_casillas()
	refrescar()


## Devuelve el contenedor que se esta mostrando, o null.
func contenedor() -> Contenedor:
	return _contenedor


## Devuelve cuantas casillas se estan mostrando.
func cantidad_casillas() -> int:
	return _casillas.size()


## Devuelve el control de una casilla, o null si no existe.
func casilla_vista(indice : int) -> Casilla:
	if indice < 0 or indice >= _casillas.size():
		return null
	return _casillas[indice]


## Devuelve que casilla esta elegida, o -1.
func elegida() -> int:
	return _elegida


## Devuelve lo que hay en la casilla elegida, o null.
func slot_elegido() -> InventorySlot:
	return null if _contenedor == null else _contenedor.casilla(_elegida)


## Elige una casilla. Un hueco no se elige: soltar la eleccion es elegir -1.
func elegir(indice : int) -> void:
	if _contenedor == null or _contenedor.casilla(indice) == null:
		indice = -1
	_elegida = indice
	_pintar_eleccion()
	if indice != -1:
		casilla_elegida.emit(indice)


## Vuelve a dibujar todo desde el contenedor.
func refrescar() -> void:
	if _contenedor == null:
		_capacidad.text = ""
		_peso.visible = false
		_peso_texto.visible = false
		_pintar_eleccion()
		return

	for i in _casillas.size():
		_casillas[i].pintar(_contenedor.casilla(i))

	_capacidad.text = "%d/%d casillas" % [_contenedor.casillas_usadas(), _contenedor.casillas()]
	_peso.visible = _contenedor.peso_maximo > 0.0
	_peso_texto.visible = _peso.visible
	if _peso.visible:
		_peso.max_value = _contenedor.peso_maximo
		_peso.value = _contenedor.peso_total()
		_peso_texto.text = "%.1f / %.0f kg" % [_contenedor.peso_total(), _contenedor.peso_maximo]

	# Si lo elegido se fue —se coloco, se saco, se movio a otra casilla—, la
	# eleccion se suelta en vez de quedar apuntando a un hueco.
	if _contenedor.casilla(_elegida) == null:
		_elegida = -1
	_pintar_eleccion()


func set_columnas(valor : int) -> void:
	columnas = maxi(valor, 1)
	if _grilla != null:
		_grilla.columns = columnas


# --- Armado ---------------------------------------------------------------------


func _armar() -> void:
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override(&"separation", 12)
	_capacidad = Label.new()
	_capacidad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(_capacidad)

	# El texto del peso va al lado de la barra y no encima: la barra del tema es
	# mas baja que una linea de texto.
	_peso_texto = Label.new()
	cabecera.add_child(_peso_texto)
	_peso = ProgressBar.new()
	_peso.show_percentage = false
	_peso.custom_minimum_size = Vector2(140, 0)
	_peso.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_peso.tooltip_text = "Cuanto pesa lo que hay adentro"
	cabecera.add_child(_peso)
	add_child(cabecera)

	_desplazable = ScrollContainer.new()
	_desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grilla = GridContainer.new()
	_grilla.columns = columnas
	_grilla.add_theme_constant_override(&"h_separation", 4)
	_grilla.add_theme_constant_override(&"v_separation", 4)
	_desplazable.add_child(_grilla)
	add_child(_desplazable)

	var detalle := PanelContainer.new()
	detalle.theme_type_variation = &"PanelAzul"
	detalle.custom_minimum_size = Vector2(0, 84)
	var columna := VBoxContainer.new()
	_detalle_nombre = Label.new()
	_detalle_texto = Label.new()
	_detalle_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle_texto.custom_minimum_size = Vector2(200, 0)
	columna.add_child(_detalle_nombre)
	columna.add_child(_detalle_texto)
	detalle.add_child(columna)
	add_child(detalle)


## Crea un control por casilla del contenedor, y ajusta el alto visible.
func _armar_casillas() -> void:
	for c in _casillas:
		_grilla.remove_child(c)
		c.queue_free()
	_casillas.clear()

	var total := 0 if _contenedor == null else _contenedor.casillas()
	for i in total:
		var c := Casilla.new(self, i, lado_casilla)
		_grilla.add_child(c)
		_casillas.append(c)

	var filas := ceili(float(total) / float(columnas))
	var separacion := 4
	var ancho := columnas * lado_casilla + (columnas - 1) * separacion
	var alto := mini(filas, filas_visibles) * (lado_casilla + separacion)
	# Lo que la barra de desplazamiento ocupa se suma solo cuando hace falta.
	if filas > filas_visibles:
		ancho += 16
	_desplazable.custom_minimum_size = Vector2(ancho, alto)


## Tine la casilla elegida y llena el detalle.
func _pintar_eleccion() -> void:
	for c in _casillas:
		c.self_modulate = TONO_ELEGIDA if c.indice == _elegida else Color.WHITE

	var s := slot_elegido()
	if s == null:
		_detalle_nombre.text = ""
		_detalle_texto.text = "Elegi algo para ver que es." if _contenedor != null and _contenedor.casillas_usadas() > 0 else ""
		return

	var def := s.definicion()
	_detalle_nombre.text = s.instancia.nombre_mostrado() if s.es_unico() else (def.nombre if def != null else String(s.definicion_id))
	var lineas : Array[String] = []
	if def != null and def.descripcion != "":
		lineas.append(def.descripcion)
	if s.cantidad > 1:
		lineas.append("%d unidades, %.1f kg en total." % [s.cantidad, s.peso_total()])
	else:
		lineas.append("Pesa %.1f kg." % s.peso_total())
	_detalle_texto.text = "\n".join(lineas)


## Una casilla: el marco, el icono de lo que tiene y cuantos.
##
## Es la que se clickea y se arrastra. Ordenar pasa por aca: soltar una casilla
## sobre otra del mismo contenedor le pide a Contenedor.mover() que las mude.
class Casilla extends PanelContainer:
	var vista : VistaContenedor
	var indice : int
	var icono : TextureRect
	var cantidad : Label

	func _init(de_vista : VistaContenedor, en_indice : int, lado : int) -> void:
		vista = de_vista
		indice = en_indice
		theme_type_variation = &"Ranura"
		custom_minimum_size = Vector2(lado, lado)

		icono = TextureRect.new()
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icono)

		cantidad = Label.new()
		cantidad.theme_type_variation = &"TextoClaro"
		cantidad.add_theme_font_size_override(&"font_size", 15)
		cantidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cantidad.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cantidad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cantidad)

	## Muestra lo que hay en la casilla, o el hueco.
	func pintar(s : InventorySlot) -> void:
		if s == null:
			icono.texture = null
			cantidad.text = ""
			tooltip_text = ""
			return
		var def := s.definicion()
		icono.texture = def.icono if def != null else null
		cantidad.text = str(s.cantidad) if s.cantidad > 1 else ""
		tooltip_text = s.nombre_mostrado()

	## Lo que lleva esta casilla si se la arrastra, o null si es un hueco.
	##
	## Separado de _get_drag_data() porque ese ademas pone la imagen que sigue al
	## puntero, y eso solo se puede hacer con un arrastre en curso.
	func datos_de_arrastre() -> Variant:
		var c := vista.contenedor()
		if c == null or c.casilla(indice) == null:
			return null
		return {"tipo": VistaContenedor.TIPO_ARRASTRE, "contenedor": c, "indice": indice}

	func _get_drag_data(_punto : Vector2) -> Variant:
		var datos = datos_de_arrastre()
		if datos == null:
			return null
		var imagen := TextureRect.new()
		imagen.texture = icono.texture
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.size = size * 0.8
		imagen.modulate.a = 0.8
		set_drag_preview(imagen)
		vista.elegir(indice)
		return datos

	## Por ahora solo se ordena dentro del mismo contenedor. Pasar cosas de uno a
	## otro llega con ContenedorBehavior, y entra por aca.
	func _can_drop_data(_punto : Vector2, datos : Variant) -> bool:
		return datos is Dictionary and datos.get("tipo") == VistaContenedor.TIPO_ARRASTRE \
			and datos.get("contenedor") == vista.contenedor()

	func _drop_data(_punto : Vector2, datos : Variant) -> void:
		var codigo := vista.contenedor().mover(int(datos.indice), indice)
		if Errores.ok(codigo):
			vista.elegir(indice)
		else:
			GameManager.avisar_error(codigo)

	func _gui_input(evento : InputEvent) -> void:
		if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
			if evento.double_click:
				vista.elegir(indice)
				if vista.elegida() == indice:
					vista.casilla_activada.emit(indice)
			else:
				vista.elegir(indice)
			accept_event()
