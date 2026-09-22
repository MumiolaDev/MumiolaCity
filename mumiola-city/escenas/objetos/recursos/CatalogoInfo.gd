@tool
class_name CatalogoInfo
extends Resource

## Los datos del catalogo que no son de ningun item en particular.
##
## Existe por una sola cosa que hacia falta y no habia: **la version del catalogo
## en runtime**. Vive en items.json, que es fuente y no dato de juego —nadie lo
## abre con FileAccess durante la partida—, asi que sin esto el numero se perdia
## al importar.
##
## Lo necesita el documento de sala (D24): guardar con que catalogo se creo es lo
## que permite detectar una discrepancia al abrirla en vez de dibujar cualquier
## cosa. Sin el numero, una sala hecha con muebles que ya no existen se carga a
## medias y el unico rastro son avisos sueltos por consola.
##
## Es @tool por lo mismo que ItemDefinition: el importador corre dentro del
## editor y necesita poder escribirlo.

## La version declarada en items.json: "0.5".
@export var version : String = ""
## Cuantos items traia ese catalogo, para poder decir algo util cuando la version
## coincide pero el contenido no.
@export var cantidad_items : int = 0
