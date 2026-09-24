extends Node

## La mochila del jugador. Es donde aterriza D1 de verdad.
##
## Guarda dos cosas distintas en la misma lista, y esa asimetria es la decision:
## noventa y nueve tomates identicos son *una* casilla con cantidad 99, pero
## *esta* taza servida con cafe es una casilla con su propia ItemInstance. Noventa
## y nueve recursos para representar noventa y nueve tomates seria desperdiciar
## memoria y engordar el guardado sin ganar nada; en cambio dos tazas no son
## intercambiables si una tiene cafe.
##
## Es la asimetria opuesta a la del mundo, donde todo WorldObject tiene instancia
## aunque no la necesite. El inventario optimiza por volumen y el mundo por
## uniformidad, y la conversion entre las dos formas ocurre unicamente en
## RoomController.colocar_objeto() y retirar_objeto().
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

var _slots : Array[InventorySlot] = []


## Devuelve una copia de las casillas ocupadas.
##
## Copia y no la lista viva: si la interfaz recibiera la lista real, cualquier
## widget podria modificar el inventario sin pasar por aca ni emitir la senal.
func slots() -> Array[InventorySlot]:
	var salida : Array[InventorySlot] = []
	for s in _slots:
		if not s.esta_vacio():
			salida.append(s)
	return salida


## Devuelve cuantas unidades hay de un item, sumando todas sus casillas.
func cantidad_de(id : StringName) -> int:
	var total := 0
	for s in _slots:
		if s.definicion_id == id:
			total += s.cantidad
	return total


## Devuelve si hay al menos esa cantidad de un item.
func tiene(id : StringName, cantidad : int = 1) -> bool:
	return cantidad_de(id) >= cantidad


## Devuelve cuantas unidades hay de cualquier item de una familia.
##
## Es lo que permite que una receta pida "cualquier taza" sin enumerarlas, y lo
## que hace que agregar una taza nueva no obligue a tocar ninguna receta.
func cantidad_de_familia(familia : StringName) -> int:
	if familia == &"":
		return 0
	var total := 0
	for s in _slots:
		var def := s.definicion()
		if def != null and def.familia == familia:
			total += s.cantidad
	return total


## Devuelve la primera casilla de una familia, o null.
func buscar_familia(familia : StringName) -> InventorySlot:
	for s in _slots:
		var def := s.definicion()
		if def != null and def.familia == familia and not s.esta_vacio():
			return s
	return null


## Devuelve el peso de todo lo que carga el jugador.
func peso_total() -> float:
	var total := 0.0
	for s in _slots:
		total += s.peso_total()
	return total


## Devuelve si entraria una instancia mas de ese item, sin agregarla.
##
## Existe porque hay acciones que tienen que preguntar **antes** de mutar otra
## cosa. Levantar un mueble lo saca de la sala y lo mete en la mochila, y si se
## descubre que no entra cuando el mueble ya no esta, el objeto se perdio. La
## alternativa —agregarlo primero y devolverlo si falla— deja el objeto en dos
## lugares durante un instante, que es justo lo que D3 prohibe.
##
## Una instancia siempre pide una casilla propia: lo que tiene estado no se
## apila (D1).
func hay_lugar_para(def : ItemDefinition) -> Errores.Codigo:
	if def == null:
		return Errores.Codigo.NO_TIENE_ITEM
	if _casillas_libres() < 1:
		return Errores.Codigo.INVENTARIO_LLENO
	if peso_total() + def.peso > PESO_MAXIMO:
		return Errores.Codigo.INVENTARIO_LLENO
	return Errores.Codigo.OK


## Agrega unidades de un item. Devuelve OK o el motivo del rechazo.
##
## Si el item tiene estado propio crea una instancia por unidad en vez de
## apilarlas: el inventario decide la forma, no quien llama. Asi nadie tiene que
## acordarse de cual de los dos metodos corresponde para cada item.
func agregar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK

	var def := ItemDatabase.obtener(id)
	if def == null:
		push_error("InventoryManager: no existe el item '%s'." % id)
		return Errores.Codigo.NO_TIENE_ITEM

	if def.tiene_estado_propio():
		for i in cantidad:
			var inst := ItemInstance.new()
			inst.definicion_id = id
			var codigo := agregar_instancia(inst)
			if not Errores.ok(codigo):
				return codigo
		return Errores.Codigo.OK

	if peso_total() + def.peso * cantidad > PESO_MAXIMO:
		return Errores.Codigo.INVENTARIO_LLENO

	# Se valida que entre todo antes de escribir nada: un agregado a medias
	# dejaria al jugador con parte de lo que pidio y sin saber por que.
	if _casillas_necesarias(def, cantidad) > _casillas_libres():
		return Errores.Codigo.INVENTARIO_LLENO

	var resto := cantidad
	for s in _slots:
		if resto <= 0:
			break
		if s.definicion_id == id and not s.es_unico():
			var cabe := mini(s.espacio_libre(), resto)
			s.cantidad += cabe
			resto -= cabe

	while resto > 0:
		var nuevo := InventorySlot.new()
		nuevo.definicion_id = id
		nuevo.cantidad = mini(def.stack_maximo, resto)
		resto -= nuevo.cantidad
		_slots.append(nuevo)

	inventario_cambiado.emit()
	return Errores.Codigo.OK


## Guarda una unidad concreta con su estado. Devuelve OK o el motivo.
func agregar_instancia(inst : ItemInstance) -> Errores.Codigo:
	if inst == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var def := inst.definicion()
	if def == null:
		push_error("InventoryManager: la instancia apunta a '%s', que no existe." % inst.definicion_id)
		return Errores.Codigo.NO_TIENE_ITEM

	var lugar := hay_lugar_para(def)
	if not Errores.ok(lugar):
		return lugar

	var slot := InventorySlot.new()
	slot.definicion_id = inst.definicion_id
	slot.cantidad = 1
	slot.instancia = inst
	_slots.append(slot)

	inventario_cambiado.emit()
	return Errores.Codigo.OK


## Quita unidades de un item. Devuelve OK o el motivo del rechazo.
##
## No quita nada si no hay suficiente: consumir la mitad de una receta y fallar
## despues deja al jugador peor que si no hubiera intentado.
func quitar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK
	if not tiene(id, cantidad):
		return Errores.Codigo.NO_TIENE_ITEM

	var resto := cantidad
	for s in _slots:
		if resto <= 0:
			break
		if s.definicion_id != id:
			continue
		var saca := mini(s.cantidad, resto)
		s.cantidad -= saca
		resto -= saca

	_limpiar_vacias()
	inventario_cambiado.emit()
	return Errores.Codigo.OK


## Quita unidades de cualquier item de una familia.
func quitar_familia(familia : StringName, cantidad : int = 1) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK
	if cantidad_de_familia(familia) < cantidad:
		return Errores.Codigo.NO_TIENE_ITEM

	var resto := cantidad
	for s in _slots:
		if resto <= 0:
			break
		var def := s.definicion()
		if def == null or def.familia != familia:
			continue
		var saca := mini(s.cantidad, resto)
		s.cantidad -= saca
		resto -= saca

	_limpiar_vacias()
	inventario_cambiado.emit()
	return Errores.Codigo.OK


## Saca una instancia concreta y la devuelve, o null si no estaba.
##
## Devuelve la misma instancia y no una copia: es la que va a quedar dentro del
## WorldObject al colocarla, y la propiedad tiene que ser exclusiva (D3).
func quitar_instancia(inst : ItemInstance) -> ItemInstance:
	if inst == null:
		return null
	for i in _slots.size():
		if _slots[i].instancia == inst:
			_slots.remove_at(i)
			inventario_cambiado.emit()
			return inst
	return null


## Vacia la mochila.
func vaciar() -> void:
	_slots.clear()
	inventario_cambiado.emit()


## Vuelca el inventario a un diccionario serializable.
func to_dict() -> Dictionary:
	var lista : Array = []
	for s in slots():
		var entrada := {"item": String(s.definicion_id), "cantidad": s.cantidad}
		if s.es_unico():
			entrada["contenido"] = String(s.instancia.contenido_id)
			entrada["contenido_cantidad"] = s.instancia.contenido_cantidad
		lista.append(entrada)
	return {"slots": lista}


## Reemplaza el inventario con lo que diga el diccionario.
##
## Los numeros llegan como float desde JSON, que no distingue enteros, de ahi los
## int(): sin eso una cantidad seria 3.0 y fallaria el tipado.
func from_dict(d : Dictionary) -> void:
	_slots.clear()
	for entrada in d.get("slots", []):
		var id := StringName(entrada.get("item", ""))
		var def := ItemDatabase.obtener(id)
		if def == null:
			push_warning("InventoryManager: el guardado trae '%s', que el catalogo no tiene." % id)
			continue

		if def.tiene_estado_propio():
			var inst := ItemInstance.new()
			inst.definicion_id = id
			inst.contenido_id = StringName(entrada.get("contenido", ""))
			inst.contenido_cantidad = int(entrada.get("contenido_cantidad", 0))
			agregar_instancia(inst)
		else:
			agregar(id, int(entrada.get("cantidad", 1)))

	inventario_cambiado.emit()


## Cuantas casillas libres quedan.
func _casillas_libres() -> int:
	var usadas := 0
	for s in _slots:
		if not s.esta_vacio():
			usadas += 1
	return maxi(CASILLAS - usadas, 0)


## Cuantas casillas nuevas harian falta para meter esa cantidad, contando lo que
## entra en las pilas que ya existen.
func _casillas_necesarias(def : ItemDefinition, cantidad : int) -> int:
	var resto := cantidad
	for s in _slots:
		if s.definicion_id == def.id and not s.es_unico():
			resto -= s.espacio_libre()
	if resto <= 0:
		return 0
	return ceili(float(resto) / float(maxi(def.stack_maximo, 1)))


## Descarta las casillas que quedaron en cero.
func _limpiar_vacias() -> void:
	var vivas : Array[InventorySlot] = []
	for s in _slots:
		if not s.esta_vacio():
			vivas.append(s)
	_slots = vivas
