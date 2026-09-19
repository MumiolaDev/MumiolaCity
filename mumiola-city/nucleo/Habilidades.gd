class_name Habilidades
extends RefCounted

## Los ids de habilidad del juego, y el unico lugar donde se escriben.
##
## Existe por una falla concreta que el catalogo viejo tenia latente (D4): el GDD
## escribia "Mineria" con tilde y items.json sin tilde. El dia que alguien pasara
## el nombre del GDD, la xp se habria acumulado en una habilidad inexistente
## **sin dar ningun error**, y el bug habria aparecido semanas despues como "no
## me sube el nivel".
##
## La regla: ninguna cadena literal de habilidad se escribe fuera de este
## archivo. Si hace falta el nombre con tilde para mostrarle al jugador, sale de
## SkillDefinition.nombre_display, que es un campo de presentacion aparte.

const AGRICULTURA := &"agricultura"
const COCINA := &"cocina"
const CARPINTERIA := &"carpinteria"

## Las habilidades que hoy tienen contenido en el catalogo.
##
## El GDD define nueve —se suman Pesca, Mineria, Silvicultura, Ganaderia,
## Manufactura y Costura— pero no estan declaradas aca a proposito: declarar una
## constante para algo que ningun item produce invita a escribir codigo que
## nunca se puede ejecutar. Se agregan cuando tengan items.
const TODAS : Array[StringName] = [AGRICULTURA, COCINA, CARPINTERIA]


## Devuelve si el id corresponde a una habilidad con contenido.
static func existe(id : StringName) -> bool:
	return id in TODAS
