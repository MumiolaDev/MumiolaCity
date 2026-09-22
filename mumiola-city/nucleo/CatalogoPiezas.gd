class_name CatalogoPiezas
extends RefCounted

## El contrato entre las escenas pintadas y las MeshLibrary del escenario.
##
## Un GridMap guarda ids, no nombres. La MeshLibrary mapea id -> malla + nombre,
## y esos ids se asignan al exportar la biblioteca desde su escena fuente: si un
## re-export los reasigna, toda sala pintada se repinta con mallas distintas y
## nada da error. Las paredes se vuelven suelo y lo descubris mirando.
##
## Este archivo es la unica defensa que detecta eso antes de que lo veas. Declara
## que piezas tiene que traer cada capa y con que prefijo se llaman, y IsoGrid lo
## comprueba al arrancar. Si una pieza cambia de nombre, desaparece o se pinta en
## la capa equivocada, sale un aviso que la nombra.
##
## Los ids a proposito NO estan aca. Fijarlos convertiria cada re-export en una
## migracion; el nombre es el contrato estable y find_item_by_name() lo resuelve
## en runtime (D18).

## Nombres de capa. Se pasan a verificar() y a IsoGrid._validar_piezas().
const SUELO := &"suelo"
const PAREDES := &"paredes"

## Con que puede empezar el nombre de una pieza de cada capa.
##
## Separa dibujar de comportarse: lo que se pinta en la capa de paredes bloquea
## salvo que este en piezas_transitables, asi que pintar ahi un suelo por error es
## un muro invisible que nadie va a poder explicar.
const PREFIJOS := {
	SUELO: [&"suelo_", &"cubo_"],
	PAREDES: [&"pared_", &"pilar_", &"espacio_", &"ventana_"],
}

## Las piezas que cada biblioteca tiene que traer.
##
## Agregar contenido es agregar un nombre aca y exportar la biblioteca; si se
## olvida uno de los dos pasos, el arranque lo dice. Quitar un nombre de esta
## lista sin despintarlo de las salas tambien.
const PIEZAS := {
	SUELO: [&"suelo_base", &"suelo_piedra", &"suelo_tierra", &"cubo_base", &"cubo_grande"],
	PAREDES: [&"pilar_base", &"pared_base", &"pared_doble_base", &"espacio_puerta",
		&"ventana_cerrada", &"ventana_abierta"],
}


## Los cuatro giros de un cuarto de vuelta, como indices de orientacion de GridMap.
##
## Un GridMap no guarda grados sino un indice ortogonal de 0 a 23, que cubre las
## veinticuatro orientaciones de un cubo. Solo cuatro de ellas son un giro en Y,
## y son estas.
##
## El orden no es el natural [0, 16, 10, 22] sino este, y la razon importa: el 16
## es +90 grados, pero los objetos colocados giran con -PASO_ROTACION, o sea -90.
## Con el orden natural, girar una pared y girar una silla irian para lados
## opuestos con la misma tecla. Asi hay una sola regla: un paso es un cuarto de
## vuelta en el mismo sentido, sea lo que sea que estes girando.
const ORIENTACIONES : Array[int] = [0, 22, 10, 16]


## Convierte pasos de un cuarto de vuelta en indice de orientacion de GridMap.
static func orientacion_de(pasos : int) -> int:
	return ORIENTACIONES[posmod(pasos, ORIENTACIONES.size())]


## Convierte un indice de orientacion en pasos, o 0 si no es un giro en Y.
##
## Devuelve 0 para las orientaciones que no son un giro en Y —una pieza puesta de
## costado, que el editor no produce pero una sala pintada a mano si puede
## tener—, porque no hay un numero de pasos que las describa.
static func pasos_de(orientacion : int) -> int:
	var indice := ORIENTACIONES.find(orientacion)
	return 0 if indice == -1 else indice


## Devuelve el id de una pieza por su nombre, o -1 si la biblioteca no la tiene.
##
## Es el primitivo de D18: todo lo que se guarde o se lea de afuera viaja por
## nombre y se resuelve a id contra la biblioteca cargada en ese momento, para
## que un re-export no corrompa lo guardado.
static func id_de(biblioteca : MeshLibrary, nombre : StringName) -> int:
	if biblioteca == null:
		return -1
	return biblioteca.find_item_by_name(nombre)


## Devuelve el nombre de una pieza por su id, o vacio si el id no existe.
static func nombre_de(biblioteca : MeshLibrary, id : int) -> StringName:
	if biblioteca == null or not (id in biblioteca.get_item_list()):
		return &""
	return StringName(biblioteca.get_item_name(id))


## Devuelve si el nombre corresponde a la capa, segun su prefijo.
static func corresponde_a(nombre : StringName, capa : StringName) -> bool:
	if not PREFIJOS.has(capa):
		return true
	for prefijo in PREFIJOS[capa]:
		if String(nombre).begins_with(String(prefijo)):
			return true
	return false


## Compara una biblioteca contra el contrato y devuelve los problemas en texto.
##
## Devuelve una lista y no un bool para que quien llama decida si avisa, si corta
## o si los muestra todos juntos. Lista vacia es que esta todo bien.
static func verificar(biblioteca : MeshLibrary, capa : StringName) -> Array[String]:
	var problemas : Array[String] = []
	if biblioteca == null:
		problemas.append("La capa '%s' no tiene MeshLibrary asignada." % capa)
		return problemas
	if not PIEZAS.has(capa):
		problemas.append("Capa desconocida: '%s'." % capa)
		return problemas

	for nombre in PIEZAS[capa]:
		if biblioteca.find_item_by_name(nombre) == -1:
			problemas.append(
				"Falta la pieza '%s' en la biblioteca de '%s'. " % [nombre, capa]
				+ "O se renombro, o se borro, o la biblioteca se exporto sin ella."
			)
	return problemas
