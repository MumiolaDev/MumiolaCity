extends Node

## La mochila del jugador. Es donde aterriza D1 de verdad.
##
## Desde la fase 5 la mochila es un Contenedor —el mismo que va a tener una
## alacena o una heladera— y este autoload es su duenio: la crea con los
## limites del jugador, la guarda con el perfil y reenvia su aviso. Las
## reglas —que entra, donde, que se apila— viven en Contenedor y no aca.
##
## Se conserva toda la API de antes, delegando, porque la usa medio juego: la
## economia archivada, LevantarBehavior, los comandos y los tests. Lo nuevo
## —las casillas con posicion, mover— se le pide a mochila directamente.
##
## Es la asimetria opuesta a la del mundo, donde todo WorldObject tiene instancia
## aunque no la necesite. El inventario optimiza por volumen y el mundo por
## uniformidad, y la conversion entre las dos formas ocurre al colocar y al
## retirar.
##
## Todo lo que puede ser rechazado devuelve un Errores.Codigo y no un bool (D16),
## porque "no entra" y "no tenes eso" son cosas distintas que el jugador merece
## poder distinguir.

## Se emite ante cualquier cambio. La interfaz se suscribe y nunca consulta.
signal inventario_cambiado()

## Cuantas casillas tiene la mochila.
const CASILLAS := 40
## Cuanto peso aguanta. Cero seria sin limite.
const PESO_MAXIMO := 200.0

## La mochila, como contenedor. La interfaz la muestra con VistaContenedor.
var mochila := Contenedor.new(CASILLAS, PESO_MAXIMO, "Mochila")


func _init() -> void:
	mochila.cambiado.connect(inventario_cambiado.emit)


## Devuelve una copia de las casillas ocupadas, en orden.
func slots() -> Array[InventorySlot]:
	return mochila.slots()


## Devuelve cuantas unidades hay de un item, sumando todas sus casillas.
func cantidad_de(id : StringName) -> int:
	return mochila.cantidad_de(id)


## Devuelve si hay al menos esa cantidad de un item.
func tiene(id : StringName, cantidad : int = 1) -> bool:
	return mochila.tiene(id, cantidad)


## Devuelve cuantas unidades hay de cualquier item de una familia.
##
## Es lo que permite que una receta pida "cualquier taza" sin enumerarlas.
func cantidad_de_familia(familia : StringName) -> int:
	return mochila.cantidad_de_familia(familia)


## Devuelve la primera casilla de una familia, o null.
func buscar_familia(familia : StringName) -> InventorySlot:
	return mochila.buscar_familia(familia)


## Devuelve el peso de todo lo que carga el jugador.
func peso_total() -> float:
	return mochila.peso_total()


## Devuelve si entraria una unidad mas de ese item, sin agregarla.
func hay_lugar_para(def : ItemDefinition) -> Errores.Codigo:
	return mochila.hay_lugar_para(def)


## Agrega unidades de un item. Devuelve OK o el motivo del rechazo.
func agregar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	return mochila.agregar(id, cantidad)


## Guarda una unidad concreta con su estado. Devuelve OK o el motivo.
func agregar_instancia(inst : ItemInstance) -> Errores.Codigo:
	return mochila.agregar_instancia(inst)


## Quita unidades de un item. Devuelve OK o el motivo del rechazo.
func quitar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	return mochila.quitar(id, cantidad)


## Quita unidades de cualquier item de una familia.
func quitar_familia(familia : StringName, cantidad : int = 1) -> Errores.Codigo:
	return mochila.quitar_familia(familia, cantidad)


## Saca una instancia concreta y la devuelve, o null si no estaba.
func quitar_instancia(inst : ItemInstance) -> ItemInstance:
	return mochila.quitar_instancia(inst)


## Vacia la mochila.
func vaciar() -> void:
	mochila.vaciar()


## Vuelca el inventario a un diccionario serializable.
func to_dict() -> Dictionary:
	return mochila.to_dict()


## Reemplaza el inventario con lo que diga el diccionario.
func from_dict(d : Dictionary) -> void:
	mochila.from_dict(d)
