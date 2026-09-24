class_name LevantarBehavior
extends InteractionBehavior

## El otro verbo que tiene todo objeto: sacarlo de la sala y guardarlo.
##
## Junto con mirar son los dos verbos universales, y por el mismo motivo: no son
## contenido de un item concreto sino propiedades de ser un objeto del mundo.
## Todo lo que se pudo colocar se puede volver a levantar, asi que ponerlo en la
## lista de interacciones de cada item seria una lista que hay que acordarse de
## completar, y olvidarse no daria error — simplemente ese mueble quedaria
## clavado en el piso para siempre. Ver WorldObject.LEVANTAR.
##
## Es el primer verbo que **muta la sala**, y por eso es el primero que pasa por
## RoomController.aplicar() en vez de llamar a retirar_objeto(). Esa es la
## costura de D23: jugando se aplica en el acto, online se manda la misma
## operacion, el servidor la valida y la retransmite.
##
## Lo que se guarda es *la misma* instancia que estaba en el mundo y no una
## copia. La taza vuelve a la mochila con su cafe, y la lampara que estaba
## encendida sigue encendida cuando la vuelvas a poner.

## Cuanto pesa la operacion en el orden del menu no se decide aca sino en
## WorldObject.verbos_disponibles(): despues de los verbos del mueble y antes de
## mirar.

## La animacion que hace el personaje al levantar algo.
##
## Es un @export y no una constante para que un mueble pesado pueda pedir otra
## el dia que exista, sin tocar este script.
@export var animacion : StringName = &"levantar"


## Devuelve si el objeto se puede levantar, sin mirar si entra en la mochila.
##
## La division no es casual. Aca se decide si el verbo **aparece** en el menu, y
## eso tiene que depender del objeto y no de cuanto te queda libre: un mueble que
## desaparece del menu cuando tenes la mochila llena se lee como que el juego se
## rompio. Que no entre se dice al intentarlo, con el motivo escrito.
func puede_interactuar(actor : Node, objeto : WorldObject) -> bool:
	if actor == null or objeto == null:
		return false

	# Sin definicion no hay id que meter en el inventario. Alcanza a los objetos
	# puestos a mano en una sala —una mesada, un mostrador— que son escenario
	# aunque sean WorldObject, y los deja fijos sin necesidad de una lista de
	# excepciones que mantener.
	if objeto.definicion() == null:
		return false

	var sala := objeto.sala()
	if sala == null:
		return false
	# La misma puerta que el editor: levantar es modificar la sala. Hoy siempre
	# deja, pero el dia que una sala tenga duenio la comprobacion ya esta puesta.
	if not sala.puede_editar(actor):
		return false

	return not _esta_ocupado(objeto)


## Saca el objeto de la sala y lo guarda en el inventario. Devuelve si ocurrio.
##
## El orden es lo unico delicado: se pregunta si entra, despues se retira y por
## ultimo se guarda. Retirar primero y descubrir despues que no entraba destruye
## el objeto, y guardarlo antes de retirarlo lo deja existiendo en dos lugares a
## la vez, que es lo que D3 prohibe.
func interactuar(actor : Node, objeto : WorldObject) -> bool:
	if not puede_interactuar(actor, objeto):
		return false

	var sala := objeto.sala()
	var instancia := objeto.instancia
	var lugar := InventoryManager.hay_lugar_para(objeto.definicion())
	if not Errores.ok(lugar):
		GameManager.avisar_error(lugar)
		return false

	# El gesto va antes de retirar y no despues, por dos motivos. Uno es que
	# despues el objeto ya esta liberado y no se le puede preguntar donde estaba
	# para mirarlo. El otro es que el personaje tiene que empezar a agacharse
	# cuando levanta, no cuando termino. A cambio el mueble desaparece al
	# principio de la animacion en vez de al final; diferirlo es el mismo truco
	# que usa dejar_pose(), y va aca el dia que moleste.
	if actor.has_method(&"hacer_gesto"):
		actor.hacer_gesto(animacion, objeto.global_position)

	# Sin registrar: deshacer es del editor y el historial es el de la
	# construccion. Si levantar algo jugando entrara al historial, un Ctrl+Z
	# posterior devolveria el mueble a la sala **y** lo dejaria en la mochila.
	var codigo := sala.aplicar(OperacionSala.retirar(objeto.celda_origen), false)
	if not Errores.ok(codigo):
		GameManager.avisar_error(codigo)
		return false

	# A partir de aca el objeto ya no esta en la sala y la unica referencia viva
	# a su instancia es la de arriba: si esto fallara, el mueble se perderia. Por
	# eso se pregunto antes, y por eso un fallo aca es un error y no un aviso.
	var guardado := InventoryManager.agregar_instancia(instancia)
	if not Errores.ok(guardado):
		push_error("LevantarBehavior: '%s' salio de la sala y no entro en el inventario (%s)."
			% [instancia.definicion_id, Errores.mensaje(guardado)])
		GameManager.avisar_error(guardado)
		return false

	GameManager.avisar("Levantaste %s." % _nombre_de(instancia))
	return true


## Devuelve si alguien esta usando el objeto ahora mismo.
##
## Se pregunta por metodo y no por tipo, igual que hace el personaje al
## desanotarse: este verbo no tiene por que conocer PoseBehavior, y el dia que
## haya otro comportamiento con ocupantes queda cubierto solo.
##
## Levantar la cama con alguien acostado encima lo dejaria en pose sobre un
## mueble liberado, que es una referencia a un nodo que ya no existe.
func _esta_ocupado(objeto : WorldObject) -> bool:
	var def := objeto.definicion()
	if def == null:
		return false
	for verbo in def.interacciones:
		if verbo != null and verbo.has_method(&"ocupantes"):
			if not verbo.ocupantes(objeto).is_empty():
				return true
	return false


## El nombre para el aviso, con el del catalogo como primera opcion.
func _nombre_de(instancia : ItemInstance) -> String:
	var def := instancia.definicion()
	if def == null:
		return String(instancia.definicion_id)
	return def.nombre if def.nombre != "" else String(def.id)
