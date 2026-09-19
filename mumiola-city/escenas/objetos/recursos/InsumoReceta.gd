class_name InsumoReceta
extends Resource

## Un requisito de una receta: que hace falta, cuanto, y si se gasta.
##
## Modela tanto los ingredientes como los utensilios, y eso es a proposito: un
## utensilio es un insumo que no se consume. Con dos mecanismos distintos habria
## que preguntar dos veces en cada validacion y en cada consumo, y tarde o
## temprano uno de los dos se olvidaria en algun lado.

## Que item concreto hace falta. Exclusivo con familia.
@export var id : StringName = &""

## Que familia de items sirve: "cualquier taza", "cualquier olla".
##
## Es lo que permite que una receta acepte la taza de madera o la de piedra sin
## enumerarlas, y lo que hace que agregar una taza nueva no obligue a tocar
## ninguna receta.
@export var familia : StringName = &""

@export var cantidad : int = 1

## Si se destruye al craftear. Un utensilio va con consume en false: hace falta
## tenerlo, pero sigue ahi despues.
@export var consume : bool = true


## Devuelve si el requisito se pide por familia en vez de por id concreto.
func es_por_familia() -> bool:
	return familia != &""


## Devuelve si el requisito esta bien formado.
##
## Exactamente uno de id o familia tiene que estar poblado. Los dos vacios es una
## receta que no pide nada; los dos llenos es una receta ambigua. Ninguno de los
## dos casos deberia llegar a RecipeManager en medio de un crafteo: ItemDatabase
## lo comprueba al cargar el catalogo.
func es_valido() -> bool:
	return (id != &"") != (familia != &"") and cantidad > 0


## Texto corto para mensajes y para depurar.
func descripcion() -> String:
	var que := String(familia) + " (cualquiera)" if es_por_familia() else String(id)
	return "%d x %s%s" % [cantidad, que, "" if consume else " (no se gasta)"]
