class_name OperacionSala
extends Resource

## Un cambio a una sala, como dato en vez de como llamada.
##
## Es la costura del multijugador, y la razon por la que existe hoy y no cuando
## haya red. Si el editor llamara directo a colocar_objeto(), pintar() y
## retirar_objeto(), el dia del servidor autoritativo habria tres formas
## distintas que interceptar y el editor habria que reescribirlo. Hablando en
## operaciones, la red es un cambio de destinatario: local se aplican en el acto,
## online se mandan, el servidor valida y retransmite, y el mismo aplicar() corre
## en todos los clientes.
##
## Pero se paga hoy: una lista de operaciones da deshacer y rehacer casi gratis,
## y un editor de salas lo necesita si o si.
##
## Todo viaja por nombre y nunca por id (D18): dos clientes tienen que coincidir
## en que es "suelo_base" sin compartir la misma MeshLibrary en memoria.

enum Tipo { COLOCAR, RETIRAR, PINTAR, BORRAR }

@export var tipo : Tipo = Tipo.COLOCAR
## La celda sobre la que opera. Es tambien la identidad del objeto afectado:
## mientras haya uno por celda, alcanza y no hace falta inventar ids.
@export var celda : Vector2i = Vector2i.ZERO

@export_group("Colocar")
@export var item : StringName = &""
@export var rotacion : int = 0
## El estado de la instancia, para que deshacer un retiro devuelva la taza con su
## cafe y no una taza vacia.
@export var estado : Dictionary = {}

@export_group("Estructura")
@export var capa : StringName = &""
@export var pieza : StringName = &""
@export var orientacion : int = 0


static func colocar(item_id : StringName, en_celda : Vector2i, giro : int = 0,
		estado_inicial : Dictionary = {}) -> OperacionSala:
	var op := OperacionSala.new()
	op.tipo = Tipo.COLOCAR
	op.item = item_id
	op.celda = en_celda
	op.rotacion = giro
	op.estado = estado_inicial
	return op


static func retirar(en_celda : Vector2i) -> OperacionSala:
	var op := OperacionSala.new()
	op.tipo = Tipo.RETIRAR
	op.celda = en_celda
	return op


static func pintar(en_capa : StringName, en_celda : Vector2i, que_pieza : StringName,
		giro : int = 0) -> OperacionSala:
	var op := OperacionSala.new()
	op.tipo = Tipo.PINTAR
	op.capa = en_capa
	op.celda = en_celda
	op.pieza = que_pieza
	op.orientacion = giro
	return op


static func borrar(en_capa : StringName, en_celda : Vector2i) -> OperacionSala:
	var op := OperacionSala.new()
	op.tipo = Tipo.BORRAR
	op.capa = en_capa
	op.celda = en_celda
	return op


## Vuelca la operacion a un diccionario serializable.
##
## Solo escribe los campos que su tipo usa: una operacion de pintado no tiene por
## que arrastrar un item vacio, y el dia que esto viaje por la red cada byte de
## mas se paga en cada gesto de cada jugador.
func to_dict() -> Dictionary:
	var d := {"op": _nombre_tipo(), "celda": [celda.x, celda.y]}
	match tipo:
		Tipo.COLOCAR:
			d["item"] = String(item)
			d["rotacion"] = rotacion
			if not estado.is_empty():
				d["estado"] = estado
		Tipo.PINTAR:
			d["capa"] = String(capa)
			d["pieza"] = String(pieza)
			d["orientacion"] = orientacion
		Tipo.BORRAR:
			d["capa"] = String(capa)
	return d


## Reconstruye una operacion leida de disco o de la red.
##
## Los numeros llegan como float desde JSON, que no distingue enteros, de ahi los
## int(). Devuelve null si el diccionario no es una operacion valida, en vez de
## un objeto a medias: una operacion mal formada tiene que rebotar en el borde y
## no llegar a aplicar().
static func desde_dict(d : Dictionary) -> OperacionSala:
	var nombres := {"colocar": Tipo.COLOCAR, "retirar": Tipo.RETIRAR,
		"pintar": Tipo.PINTAR, "borrar": Tipo.BORRAR}
	var clave := str(d.get("op", ""))
	if not nombres.has(clave):
		push_warning("OperacionSala: tipo desconocido '%s'." % clave)
		return null

	var c : Array = d.get("celda", [])
	if c.size() != 2:
		push_warning("OperacionSala: celda mal formada en '%s'." % clave)
		return null

	var op := OperacionSala.new()
	op.tipo = nombres[clave]
	op.celda = Vector2i(int(c[0]), int(c[1]))
	op.item = StringName(d.get("item", ""))
	op.rotacion = int(d.get("rotacion", 0))
	op.estado = d.get("estado", {})
	op.capa = StringName(d.get("capa", ""))
	op.pieza = StringName(d.get("pieza", ""))
	op.orientacion = int(d.get("orientacion", 0))
	return op


## Texto corto para el historial y para depurar.
func descripcion() -> String:
	match tipo:
		Tipo.COLOCAR: return "colocar %s en %s" % [item, celda]
		Tipo.RETIRAR: return "retirar de %s" % celda
		Tipo.PINTAR: return "pintar %s en %s de %s" % [pieza, celda, capa]
		Tipo.BORRAR: return "borrar %s de %s" % [celda, capa]
	return "operacion desconocida"


func _nombre_tipo() -> String:
	match tipo:
		Tipo.COLOCAR: return "colocar"
		Tipo.RETIRAR: return "retirar"
		Tipo.PINTAR: return "pintar"
		Tipo.BORRAR: return "borrar"
	return "?"
