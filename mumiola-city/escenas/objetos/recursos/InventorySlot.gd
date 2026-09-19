class_name InventorySlot
extends Resource

## Una casilla del inventario: o una pila de items identicos, o una unidad con
## estado propio.
##
## Los dos casos existen a proposito (D1). Noventa y nueve tomates identicos no
## pueden ser noventa y nueve recursos: seria desperdiciar memoria y engordar el
## guardado sin ganar nada. Pero *esta* taza servida con cafe no es
## intercambiable con la de al lado, asi que necesita su propia instancia.
##
## Es la asimetria opuesta a la del mundo, donde todo WorldObject tiene instancia
## aunque no la necesite: el inventario optimiza por volumen y el mundo por
## uniformidad. La conversion entre las dos formas ocurre solo al colocar y al
## retirar.

@export var definicion_id : StringName = &""
@export var cantidad : int = 0

## La unidad concreta, si este slot guarda una. Null si es una pila simple.
@export var instancia : ItemInstance


## Devuelve si el slot guarda una unidad con estado propio.
func es_unico() -> bool:
	return instancia != null


## Devuelve si el slot no tiene nada.
func esta_vacio() -> bool:
	return cantidad <= 0 or definicion_id == &""


## Devuelve la definicion del item que guarda, o null.
func definicion() -> ItemDefinition:
	return ItemDatabase.obtener(definicion_id)


## Devuelve el peso de todo lo que hay en el slot.
func peso_total() -> float:
	var def := definicion()
	return 0.0 if def == null else def.peso * cantidad


## Devuelve el nombre para mostrar, con la cantidad si es una pila.
func nombre_mostrado() -> String:
	if es_unico():
		return instancia.nombre_mostrado()
	var def := definicion()
	var base := String(definicion_id) if def == null else def.nombre
	return base if cantidad <= 1 else "%s x%d" % [base, cantidad]


## Devuelve si dos slots se pueden fusionar en uno.
##
## Basta con que cualquiera de los dos tenga instancia para que no: una taza
## servida nunca se apila con una vacia aunque compartan definicion_id, porque
## apilarlas perderia el cafe de una de las dos.
func puede_apilar_con(otro : InventorySlot) -> bool:
	if otro == null or es_unico() or otro.es_unico():
		return false
	if definicion_id != otro.definicion_id or esta_vacio() or otro.esta_vacio():
		return false
	var def := definicion()
	return def != null and def.es_apilable()


## Devuelve cuanto mas entra en este slot antes de llegar al tope de la pila.
func espacio_libre() -> int:
	if es_unico():
		return 0
	var def := definicion()
	return 0 if def == null else maxi(def.stack_maximo - cantidad, 0)
