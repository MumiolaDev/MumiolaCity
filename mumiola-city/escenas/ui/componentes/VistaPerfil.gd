extends VBoxContainer
class_name VistaPerfil

## Muestra quien es alguien: como se llama, desde cuando juega, donde esta.
##
## Por ahora lo general y nada mas. Recibe un diccionario ya armado y no lo va a
## buscar, asi que no sabe si es tu perfil o el de otro: el dia que clickear a
## otro jugador muestre el suyo, es esta misma vista con los datos que mande el
## servidor.
##
## Claves que entiende, todas opcionales:
##
##     nombre         como se llama
##     creado         cuando se creo, en segundos Unix; 0 si no se sabe
##     sala           el nombre de la sala donde esta
##     salas_propias  cuantas salas tiene; -1 si no se sabe
##     mochila        un resumen de lo que lleva, ya escrito
##     de_prueba      true si es el perfil de desarrollo, que no se guarda

const MESES := ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
	"agosto", "septiembre", "octubre", "noviembre", "diciembre"]

var _nombre : Label
var _filas : GridContainer
var _nota : Label


func _init() -> void:
	add_theme_constant_override(&"separation", 12)
	custom_minimum_size = Vector2(320, 0)

	_nombre = Label.new()
	_nombre.theme_type_variation = &"Titulo"
	add_child(_nombre)

	_filas = GridContainer.new()
	_filas.columns = 2
	_filas.add_theme_constant_override(&"h_separation", 16)
	_filas.add_theme_constant_override(&"v_separation", 6)
	add_child(_filas)

	_nota = Label.new()
	_nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nota.custom_minimum_size = Vector2(300, 0)
	add_child(_nota)


## Muestra los datos de un perfil. Lo que falte no se muestra.
func mostrar(datos : Dictionary) -> void:
	_nombre.text = str(datos.get("nombre", ""))

	for hijo in _filas.get_children():
		_filas.remove_child(hijo)
		hijo.queue_free()

	var creado := int(datos.get("creado", 0))
	if creado > 0:
		_fila("Jugando desde", fecha_legible(creado))
	if datos.has("sala"):
		_fila("Estas en", str(datos.sala))
	var salas := int(datos.get("salas_propias", -1))
	if salas >= 0:
		_fila("Salas propias", "ninguna" if salas == 0 else str(salas))
	if datos.has("mochila"):
		_fila("En la mochila", str(datos.mochila))

	_nota.text = "Es el perfil de prueba: no se guarda nada." if datos.get("de_prueba", false) else ""
	_nota.visible = _nota.text != ""


## Escribe una fecha Unix como "25 de septiembre de 2026", en la hora local.
static func fecha_legible(unix : int) -> String:
	var desfase := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var f := Time.get_datetime_dict_from_unix_time(unix + desfase)
	return "%d de %s de %d" % [f.day, MESES[f.month - 1], f.year]


func _fila(clave : String, valor : String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = clave
	etiqueta.modulate = Color(1, 1, 1, 0.7)
	_filas.add_child(etiqueta)
	var dato := Label.new()
	dato.text = valor
	_filas.add_child(dato)
