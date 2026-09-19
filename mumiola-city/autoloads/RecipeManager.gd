extends Node

## Convierte insumos en productos. Es el que junta el catalogo, el inventario y
## las habilidades, y el ultimo que hacia falta para que la cadena economica
## exista de punta a punta.
##
## El crafteo es en dos tiempos a proposito. craftear() valida, consume y
## devuelve si la accion fue aceptada; el resultado llega despues, por senal,
## cuando se cumple el tiempo de la receta. Devolver el producto directamente
## obligaria a que todo crafteo fuera instantaneo, y entonces el campo
## tiempo_crafteo_seg no serviria para nada.
##
## El tiempo va por temporizador de escena y no por marca de tiempo, y eso es
## deliberado: un crafteo dura segundos y no tiene sentido que siga corriendo con
## el juego cerrado. Lo que si tiene que sobrevivir —un cultivo creciendo— es de
## TimeManager, que llega en la fase 2b.

## Se emite al aceptar un crafteo, con los insumos ya consumidos.
signal crafteo_empezado(resultado_id : StringName, segundos : float)
## Se emite al entregarse el producto. fallo indica si salio lo que se buscaba.
signal crafteo_terminado(resultado_id : StringName, cantidad : int, fallo : bool)

## Que fraccion de la xp se lleva quien lo arruina.
##
## No cero: sin esto, alguien que solo tiene insumos de una receta que todavia no
## domina los quema una y otra vez sin avanzar nunca. Equivocarse tiene que
## ensenar algo.
const XP_AL_FALLAR := 0.5


## Devuelve las recetas que se pueden ver desde una estacion.
##
## Ver, no necesariamente hacer: incluye las que faltan materiales, porque una
## lista que esconde lo que no podes hacer ahora no te deja saber que juntar.
func recetas_disponibles(estacion : StringName = &"") -> Array[ItemDefinition]:
	var salida : Array[ItemDefinition] = []
	for def in ItemDatabase.items_de_categoria("materia_prima") + \
			ItemDatabase.items_de_categoria("intermedio") + \
			ItemDatabase.items_de_categoria("consumible") + \
			ItemDatabase.items_de_categoria("utensilio") + \
			ItemDatabase.items_de_categoria("decorativo"):
		if def.receta != null and def.receta.estacion == estacion:
			salida.append(def)
	return salida


## Devuelve si se puede craftear algo ahora, o por que no.
##
## El orden de las comprobaciones es el orden en que se le explican al jugador:
## primero si existe la receta, despues si esta en el lugar correcto, despues si
## sabe hacerlo, y recien al final si tiene con que.
func puede_craftear(resultado : ItemDefinition, estacion : StringName = &"") -> Errores.Codigo:
	if resultado == null or resultado.receta == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var r := resultado.receta
	if r.estacion != &"" and r.estacion != estacion:
		return Errores.Codigo.FALTA_ESTACION

	var nivel := SkillManager.nivel_de(r.habilidad)
	if not r.se_puede_intentar_con(nivel):
		return Errores.Codigo.NIVEL_INSUFICIENTE

	for utensilio in r.utensilios():
		if not _hay(utensilio):
			return Errores.Codigo.FALTA_UTENSILIO
	for insumo in r.insumos_consumibles():
		if not _hay(insumo):
			return Errores.Codigo.FALTAN_MATERIALES

	# Se comprueba el hueco antes de consumir: quedarse sin los insumos y sin el
	# producto porque no entraba es la peor forma de fallar.
	if not _entra_el_resultado(resultado, r, nivel):
		return Errores.Codigo.INVENTARIO_LLENO

	return Errores.Codigo.OK


## Consume los insumos y pone el crafteo en marcha.
##
## Devuelve si la accion fue aceptada, no el producto: el producto llega por
## crafteo_terminado cuando se cumple el tiempo.
func craftear(resultado : ItemDefinition, estacion : StringName = &"") -> Errores.Codigo:
	var codigo := puede_craftear(resultado, estacion)
	if not Errores.ok(codigo):
		return codigo

	var r := resultado.receta
	var nivel := SkillManager.nivel_de(r.habilidad)
	var fallo := not r.sale_bien_con(nivel)

	# Consumir es lo primero que se escribe, y ya esta todo validado: si algo
	# fallara aca, el inventario quedaria a medias sin forma de repararlo.
	for insumo in r.insumos_consumibles():
		var quitado := _quitar(insumo)
		if not Errores.ok(quitado):
			push_error("RecipeManager: fallo al consumir '%s' con todo validado." % insumo.descripcion())
			return quitado

	crafteo_empezado.emit(resultado.id, r.tiempo_crafteo_seg)

	if r.tiempo_crafteo_seg <= 0.0:
		_entregar(resultado, fallo)
	else:
		get_tree().create_timer(r.tiempo_crafteo_seg).timeout.connect(
			_entregar.bind(resultado, fallo), CONNECT_ONE_SHOT)

	return Errores.Codigo.OK


## Entrega el producto y reparte la experiencia.
func _entregar(resultado : ItemDefinition, fallo : bool) -> void:
	var r := resultado.receta
	var id := r.resultado_fallo if fallo else resultado.id
	var cantidad := 1 if fallo else r.cantidad_resultado

	var codigo := InventoryManager.agregar(id, cantidad)
	if not Errores.ok(codigo):
		# El hueco se comprobo al empezar, pero pudo llenarse mientras tanto.
		GameManager.avisar_error(codigo)

	var xp := int(r.xp_otorgada * XP_AL_FALLAR) if fallo else r.xp_otorgada
	SkillManager.agregar_xp(r.habilidad, xp)

	crafteo_terminado.emit(id, cantidad, fallo)


## Devuelve si el inventario tiene lo que pide un insumo.
func _hay(insumo : InsumoReceta) -> bool:
	if insumo.es_por_familia():
		return InventoryManager.cantidad_de_familia(insumo.familia) >= insumo.cantidad
	return InventoryManager.tiene(insumo.id, insumo.cantidad)


## Saca del inventario lo que pide un insumo.
##
## Cuando el insumo se pide por familia, se gasta el primero que aparezca. Da
## igual cual mientras ninguno tenga estado propio; el dia que el jugador tenga
## que poder elegir —una taza servida y una vacia— la eleccion va a ser suya y va
## a llegar como parametro, no como una regla escondida aca.
func _quitar(insumo : InsumoReceta) -> Errores.Codigo:
	if insumo.es_por_familia():
		return InventoryManager.quitar_familia(insumo.familia, insumo.cantidad)
	return InventoryManager.quitar(insumo.id, insumo.cantidad)


## Devuelve si el producto va a entrar en el inventario.
##
## Se mide contra el estado de despues de consumir, que es cuando de verdad se
## agrega: los insumos que se van liberan casillas y peso.
func _entra_el_resultado(resultado : ItemDefinition, r : RecipeDefinition, nivel : int) -> bool:
	var fallo := not r.sale_bien_con(nivel)
	var id := r.resultado_fallo if fallo else resultado.id
	var def := ItemDatabase.obtener(id)
	if def == null:
		return false

	var liberado := 0.0
	for insumo in r.insumos_consumibles():
		var d := ItemDatabase.obtener(insumo.id)
		if d != null:
			liberado += d.peso * insumo.cantidad

	var cantidad := 1 if fallo else r.cantidad_resultado
	return InventoryManager.peso_total() - liberado + def.peso * cantidad \
		<= InventoryManager.PESO_MAXIMO
