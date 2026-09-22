class_name MirarBehavior
extends InteractionBehavior

## El verbo que tiene absolutamente todo: mirar un objeto y que te cuente que es.
##
## No cambia nada del mundo, y por eso es el unico verbo que no necesita
## permisos, ni adyacencia, ni comprobar nada: mirar siempre se puede. Tambien es
## el unico que puede responder sin que el objeto tenga definicion en el
## catalogo, porque en el peor caso queda el nombre del nodo.
##
## Su valor real no es la descripcion en si sino que **todo objeto responde a
## algo**. Con cuarenta y cuatro de cuarenta y cinco muebles sin ningun verbo,
## hacer clic derecho y que no pase nada se lee como que el juego esta roto. Con
## esto, la sala entera contesta y lo que falta se nota como lo que es: verbos
## sin escribir todavia, no objetos muertos.
##
## Como no vive en items.json sino en WorldObject, tampoco hay que acordarse de
## agregarlo a cada item nuevo. Ver WorldObject.MIRAR.

## Cuanto texto de descripcion se muestra antes de cortar.
##
## El HUD escribe el aviso en una linea y media; una descripcion larga se
## saldria de pantalla en vez de leerse.
const LARGO_MAXIMO := 160


## Mirar no altera nada, asi que siempre se puede.
func puede_interactuar(_actor : Node, _objeto : WorldObject) -> bool:
	return true


## Muestra la descripcion del objeto y devuelve que ocurrio.
##
## Devuelve true aunque no haya descripcion: el verbo se ejecuto igual y algo se
## mostro. Devolver false seria decir que la accion fue rechazada, y no lo fue.
func interactuar(_actor : Node, objeto : WorldObject) -> bool:
	if objeto == null:
		return false
	GameManager.avisar(texto_de(objeto))
	return true


## Arma lo que se le muestra al jugador.
##
## Baja por tres niveles hasta encontrar algo que decir: la descripcion del
## catalogo, el nombre del item, y por ultimo el nombre del nodo. El ultimo
## escalon existe para los objetos que no vienen de items.json —una mesada
## publica puesta a mano en una sala— que igual tienen que contestar algo.
func texto_de(objeto : WorldObject) -> String:
	var def := objeto.definicion()
	if def == null:
		return objeto.name

	var nombre := def.nombre if def.nombre != "" else String(def.id)
	if def.descripcion.strip_edges() == "":
		return nombre

	return "%s — %s" % [nombre, _recortar(def.descripcion.strip_edges())]


## Corta en el ultimo espacio antes del limite, para no partir una palabra.
func _recortar(texto : String) -> String:
	if texto.length() <= LARGO_MAXIMO:
		return texto

	var corte := texto.rfind(" ", LARGO_MAXIMO)
	if corte <= 0:
		corte = LARGO_MAXIMO
	return texto.substr(0, corte) + "..."
