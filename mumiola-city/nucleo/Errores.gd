class_name Errores
extends RefCounted

## Codigos de rechazo de las acciones del juego, con su mensaje para el jugador.
##
## Sirve para que cualquier operacion que pueda fallar —colocar un mueble,
## comprar, craftear, entrar a una sala— devuelva *por que* fallo y no solo un
## bool. Un bool obliga a quien llama a adivinar el motivo o a inventarse un
## string, y el mismo texto termina escrito en varios lugares que se
## desincronizan.
##
## Alcance, a proposito estrecho: aca solo van los rechazos que hay que
## explicarle al jugador. Los errores de programacion —un @export sin asignar,
## un nodo que falta— siguen siendo push_error() y nunca reciben codigo: no son
## para el jugador y mezclarlos convierte esto en un cajon de sastre.
##
## Los numeros son explicitos y estan agrupados por sistema para que se puedan
## reordenar, ampliar y leer en un log sin ambiguedad:
##
##     0     todo bien
##     1xx   grilla y colocacion
##     2xx   inventario y propiedad
##     3xx   economia
##     4xx   habilidades y produccion
##     5xx   permisos y salas
enum Codigo {
	OK = 0,

	# 1xx — grilla y colocacion
	CELDA_INEXISTENTE = 101,
	CELDA_OCUPADA = 102,
	HAY_PARED = 103,
	FUERA_DEL_AREA = 104,
	PARTIRIA_LA_SALA = 105,
	NO_APOYADO = 106,

	# 2xx — inventario y propiedad
	NO_ES_TUYO = 201,
	INVENTARIO_LLENO = 202,
	NO_TIENE_ITEM = 203,
	ITEM_EN_USO = 204,

	# 3xx — economia
	SALDO_INSUFICIENTE = 301,
	PRECIO_INVALIDO = 302,

	# 4xx — habilidades y produccion
	NIVEL_INSUFICIENTE = 401,
	FALTAN_MATERIALES = 402,
	ESTACION_OCUPADA = 403,

	# 5xx — permisos y salas
	SIN_PERMISO = 501,
	SALA_LLENA = 502,
}

## Texto que se le muestra al jugador para cada codigo.
##
## Vive al lado del enum y no en la UI para que agregar un codigo sin su mensaje
## sea imposible de pasar por alto. Redactados en segunda persona y sin culpar a
## nadie: dicen que paso, no que hiciste mal.
const MENSAJES := {
	Codigo.OK: "Listo.",

	Codigo.CELDA_INEXISTENTE: "Ahi no hay piso.",
	Codigo.CELDA_OCUPADA: "Ya hay algo en ese lugar.",
	Codigo.HAY_PARED: "Hay una pared en el medio.",
	Codigo.FUERA_DEL_AREA: "Eso queda fuera del area que podes modificar.",
	Codigo.PARTIRIA_LA_SALA: "Asi quedaria una parte de la sala sin salida.",
	Codigo.NO_APOYADO: "Esto necesita apoyarse en algo.",

	Codigo.NO_ES_TUYO: "Eso no es tuyo.",
	Codigo.INVENTARIO_LLENO: "No te entra nada mas en el inventario.",
	Codigo.NO_TIENE_ITEM: "No tenes ese objeto.",
	Codigo.ITEM_EN_USO: "Alguien lo esta usando.",

	Codigo.SALDO_INSUFICIENTE: "No te alcanza.",
	Codigo.PRECIO_INVALIDO: "Ese precio no es valido.",

	Codigo.NIVEL_INSUFICIENTE: "Todavia no tenes el nivel para esto.",
	Codigo.FALTAN_MATERIALES: "Te faltan materiales.",
	Codigo.ESTACION_OCUPADA: "La estacion esta ocupada.",

	Codigo.SIN_PERMISO: "No tenes permiso para hacer eso aca.",
	Codigo.SALA_LLENA: "La sala esta llena.",
}


## Devuelve el mensaje para el jugador de un codigo.
##
## Nunca devuelve vacio: si el codigo no esta en la tabla avisa por consola y
## devuelve un texto generico, porque una ventana de error en blanco es peor
## para el jugador que un mensaje impreciso.
static func mensaje(codigo : Codigo) -> String:
	if not MENSAJES.has(codigo):
		push_warning("Errores: no hay mensaje para el codigo %d." % codigo)
		return "No se pudo completar la accion."
	return MENSAJES[codigo]


## Atajo de lectura para las condiciones. Equivale a comparar contra OK, pero
## deja las llamadas como `if Errores.ok(resultado):` en vez de repetir el
## nombre completo del enum en cada if.
static func ok(codigo : Codigo) -> bool:
	return codigo == Codigo.OK
