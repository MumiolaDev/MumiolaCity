class_name ItemInstance
extends Resource

## Una unidad concreta con estado propio: *esta* taza, no "las tazas de madera".
##
## Es la mitad persistente del estado de un objeto (D3), la que sobrevive a
## cerrar el juego. En el inventario solo existe para items que tienen estado
## propio, asi que el trigo nunca genera una (D1); en el mundo, en cambio, todo
## WorldObject tiene la suya.
##
## Dos reglas duras, y las dos son la misma decision:
##
## 1. Nunca guarda una referencia a un nodo. Solo ids, numeros y textos: cosas
##    que un archivo de guardado puede contener. Si un dato necesita apuntar a
##    algo vivo, por definicion es de sesion y va en WorldObject.estado_runtime.
##    Esa sola regla elimina la clase entera de bugs de "el guardado apunta a un
##    objeto que ya no existe".
##
## 2. Nunca es un .tres en disco. Se crea con ItemInstance.new() y se serializa
##    dentro del SaveGame. El motivo es un comportamiento del motor que muerde
##    justo aca: Godot cachea los recursos cargados, asi que load() del mismo
##    archivo dos veces devuelve el mismo objeto. Si esto fuera un .tres, dos
##    tazas del mismo tipo compartirian contenido y servir una serviria las dos.
##    Por lo mismo, partir un stack o craftear pide un duplicate() explicito.

## El id de la definicion, no la referencia al recurso.
##
## Si guardara la referencia, cada partida embeberia una copia completa de la
## definicion, y al editar el .tres original las partidas viejas seguirian
## usando la copia vieja. Guardando el id, la definicion se resuelve siempre
## contra el catalogo actual. Es la diferencia entre un guardado de 2 KB y uno
## de 4 MB.
@export var definicion_id : StringName = &""

## Que hay servido adentro, para los utensilios. Vacio es vacio (D2).
@export var contenido_id : StringName = &""
@export var contenido_cantidad : int = 0

## Identificador del temporizador asociado en TimeManager, para lo que madura o
## se enfria. Lo consume la fase 2.
@export var temporizador_id : String = ""

## Espacio de extension para lo que todavia no tiene campo propio. Solo admite
## datos serializables, por la regla 1.
@export var datos : Dictionary = {}


## Devuelve la definicion de este item, resuelta contra el catalogo actual.
func definicion() -> ItemDefinition:
	return ItemDatabase.obtener(definicion_id)


## Devuelve si el utensilio no tiene nada servido.
func esta_vacio() -> bool:
	return contenido_id == &"" or contenido_cantidad <= 0


## Nombre para mostrarle al jugador, con el contenido entre parentesis si lo hay:
## "Taza de madera (Cafe)".
func nombre_mostrado() -> String:
	var def := definicion()
	var base := String(definicion_id) if def == null else def.nombre
	if esta_vacio():
		return base
	var dentro := ItemDatabase.obtener(contenido_id)
	return "%s (%s)" % [base, String(contenido_id) if dentro == null else dentro.nombre]


## Valor de referencia de la unidad: el del recipiente mas el de lo servido (D2).
##
## Es una referencia de mercado y no un precio. El precio lo hacen los jugadores.
func valor_total() -> int:
	var def := definicion()
	var total := 0 if def == null else def.valor_base
	if not esta_vacio():
		var dentro := ItemDatabase.obtener(contenido_id)
		if dentro != null:
			total += dentro.valor_base * contenido_cantidad
	return total
