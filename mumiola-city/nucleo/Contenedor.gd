extends RefCounted
class_name Contenedor

## Un lugar finito donde se guardan cosas: la mochila, y mañana una alacena, un
## cajon o una heladera.
##
## Finito por dos lados, y los dos se miran siempre: tiene una cantidad fija de
## casillas y, si peso_maximo no es cero, un limite de peso. Una mochila se
## llena por volumen o por peso, lo que llegue primero, y el jugador tiene que
## poder ver las dos cosas.
##
## Las casillas tienen posicion fija. Cada cosa se queda donde la dejaste:
## sacar algo deja un hueco y no corre a las demas, y lo que entra llena el
## primer hueco. Ordenar la mochila a mano es parte del sandbox, y es lo que
## despues permite arrastrar de un contenedor a otro sin que las cosas salten
## de lugar.
##
## Cada casilla guarda lo mismo que antes guardaba el inventario (D1): o una pila
## de cosas identicas, o una unidad con estado propio. Noventa y nueve tomates
## son una casilla con cantidad 99; *esta* taza servida es una casilla con su
## propia ItemInstance.
##
## Todo lo que puede ser rechazado devuelve un Errores.Codigo, y nada se hace a
## medias: si no entra todo, no entra nada. Avisa con cambiado una vez por
## operacion que cambio algo, y nunca por un rechazo.
##
## Es un RefCounted y no un nodo porque es un dato: vive dentro de quien lo
## tenga —InventoryManager, y el dia de ContenedorBehavior un mueble— y se guarda
## con to_dict() dentro del documento de su duenio.

## Cambio algo de lo que hay adentro.
signal cambiado()

## Como se llama, para el titulo de su ventana.
var nombre : String = ""
## Cuanto peso aguanta. Cero es sin limite.
var peso_maximo : float = 0.0

## Una entrada por casilla, null donde hay un hueco. Su tamano no cambia nunca.
var _casillas : Array[InventorySlot] = []


func _init(cantidad_casillas : int = 40, peso : float = 0.0, nombre_contenedor : String = "") -> void:
	_casillas.resize(maxi(cantidad_casillas, 0))
	peso_maximo = peso
	nombre = nombre_contenedor


## Devuelve cuantas casillas tiene, ocupadas o no.
func casillas() -> int:
	return _casillas.size()


## Devuelve cuantas casillas tienen algo.
func casillas_usadas() -> int:
	var usadas := 0
	for s in _casillas:
		if s != null:
			usadas += 1
	return usadas


## Devuelve cuantas casillas estan vacias.
func casillas_libres() -> int:
	return casillas() - casillas_usadas()


## Devuelve lo que hay en una casilla, o null si esta vacia o no existe.
##
## Es la casilla viva y no una copia, para que la interfaz pueda mirarla. Se
## lee y no se escribe: cambiarla por fuera se saltearia los limites y el aviso.
func casilla(indice : int) -> InventorySlot:
	if indice < 0 or indice >= _casillas.size():
		return null
	return _casillas[indice]


## Devuelve en que casilla esta un slot, o -1 si no es de este contenedor.
func indice_de(slot : InventorySlot) -> int:
	if slot == null:
		return -1
	return _casillas.find(slot)


## Devuelve las casillas ocupadas, en el orden de las casillas.
func slots() -> Array[InventorySlot]:
	var salida : Array[InventorySlot] = []
	for s in _casillas:
		if s != null:
			salida.append(s)
	return salida


## Devuelve cuantas unidades hay de un item, sumando todas sus casillas.
func cantidad_de(id : StringName) -> int:
	var total := 0
	for s in _casillas:
		if s != null and s.definicion_id == id:
			total += s.cantidad
	return total


## Devuelve si hay al menos esa cantidad de un item.
func tiene(id : StringName, cantidad : int = 1) -> bool:
	return cantidad_de(id) >= cantidad


## Devuelve cuantas unidades hay de cualquier item de una familia.
func cantidad_de_familia(familia : StringName) -> int:
	if familia == &"":
		return 0
	var total := 0
	for s in _casillas:
		if s == null:
			continue
		var def := s.definicion()
		if def != null and def.familia == familia:
			total += s.cantidad
	return total


## Devuelve la primera casilla de una familia, o null.
func buscar_familia(familia : StringName) -> InventorySlot:
	for s in _casillas:
		if s == null:
			continue
		var def := s.definicion()
		if def != null and def.familia == familia:
			return s
	return null


## Devuelve el peso de todo lo que hay adentro.
func peso_total() -> float:
	var total := 0.0
	for s in _casillas:
		if s != null:
			total += s.peso_total()
	return total


## Devuelve si entraria una unidad mas de ese item, sin agregarla.
##
## Existe porque hay acciones que tienen que preguntar antes de mutar otra cosa:
## levantar un mueble lo saca de la sala, y si recien ahi se descubre que no
## entra, el mueble se perdio.
##
## Algo apilable entra sin casilla libre si cabe en una pila que ya esta.
func hay_lugar_para(def : ItemDefinition) -> Errores.Codigo:
	if def == null:
		return Errores.Codigo.NO_TIENE_ITEM
	return _cabe(def, 1)


## Agrega unidades de un item, donde toque. Devuelve OK o el motivo del rechazo.
##
## Si el item tiene estado propio crea una instancia por unidad, cada una en su
## casilla; si no, llena primero las pilas que ya estan y abre pilas nuevas en
## los primeros huecos. El contenedor decide la forma, no quien llama.
func agregar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	return agregar_en(id, cantidad, -1)


## Agrega unidades de un item empezando por una casilla. Devuelve OK o el motivo.
##
## Si la casilla pedida esta vacia, o tiene una pila del mismo item con lugar,
## lo primero va ahi; el resto, y todo si la casilla no sirve, va donde iria con
## agregar(). Es lo que usa quien suelta algo sobre una casilla concreta.
func agregar_en(id : StringName, cantidad : int, indice : int) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK

	var def := ItemDatabase.obtener(id)
	if def == null:
		push_error("Contenedor: no existe el item '%s'." % id)
		return Errores.Codigo.NO_TIENE_ITEM

	# Se valida que entre todo antes de escribir nada: un agregado a medias
	# dejaria al jugador con parte de lo que pidio y sin saber por que.
	var cabe := _cabe(def, cantidad)
	if not Errores.ok(cabe):
		return cabe

	if def.tiene_estado_propio():
		for i in cantidad:
			var inst := ItemInstance.new()
			inst.definicion_id = id
			_poner_unica(inst, indice if i == 0 else -1)
	else:
		_poner_pila(def, cantidad, indice)

	cambiado.emit()
	return Errores.Codigo.OK


## Guarda una unidad concreta. Devuelve OK o el motivo del rechazo.
##
## Si el item tiene estado propio, queda esa misma instancia en su propia
## casilla: la taza conserva su cafe. Si no lo tiene, se apila como cualquier
## otra unidad, porque no hay nada que perder y un tomate levantado del piso
## no tiene por que ocupar una casilla aparte de los otros.
##
## indice es la casilla preferida, con las mismas reglas que agregar_en(). Es
## lo que permite devolver algo al lugar exacto de donde salio.
func agregar_instancia(inst : ItemInstance, indice : int = -1) -> Errores.Codigo:
	if inst == null:
		return Errores.Codigo.NO_TIENE_ITEM

	var def := inst.definicion()
	if def == null:
		push_error("Contenedor: la instancia apunta a '%s', que no existe." % inst.definicion_id)
		return Errores.Codigo.NO_TIENE_ITEM

	if not def.tiene_estado_propio():
		return agregar_en(def.id, 1, indice)

	var cabe := _cabe(def, 1)
	if not Errores.ok(cabe):
		return cabe

	_poner_unica(inst, indice)
	cambiado.emit()
	return Errores.Codigo.OK


## Quita unidades de un item, de la primera casilla a la ultima. Devuelve OK o
## el motivo del rechazo.
##
## No quita nada si no hay suficiente: sacar la mitad y fallar despues deja al
## jugador peor que si no hubiera intentado.
func quitar(id : StringName, cantidad : int = 1) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK
	if not tiene(id, cantidad):
		return Errores.Codigo.NO_TIENE_ITEM
	_descontar(func(s : InventorySlot) -> bool: return s.definicion_id == id, cantidad)
	return Errores.Codigo.OK


## Quita unidades de cualquier item de una familia.
func quitar_familia(familia : StringName, cantidad : int = 1) -> Errores.Codigo:
	if cantidad <= 0:
		return Errores.Codigo.OK
	if cantidad_de_familia(familia) < cantidad:
		return Errores.Codigo.NO_TIENE_ITEM
	_descontar(func(s : InventorySlot) -> bool:
		var def := s.definicion()
		return def != null and def.familia == familia, cantidad)
	return Errores.Codigo.OK


## Saca una instancia concreta y la devuelve, o null si no estaba.
##
## Devuelve la misma instancia y no una copia: la propiedad tiene que ser
## exclusiva (D3), y quien la recibe pasa a ser su unico duenio.
func quitar_instancia(inst : ItemInstance) -> ItemInstance:
	if inst == null:
		return null
	for i in _casillas.size():
		if _casillas[i] != null and _casillas[i].instancia == inst:
			_casillas[i] = null
			cambiado.emit()
			return inst
	return null


## Saca una unidad de una casilla y la devuelve, o null si esta vacia.
##
## De una casilla unica devuelve su instancia, la misma; de una pila descuenta
## uno y devuelve una instancia nueva, porque las unidades de una pila no tienen
## nada propio. Asi quien saca algo —para ponerlo en la sala, para pasarlo a
## otro contenedor— recibe siempre lo mismo y no tiene que preguntar que era.
func sacar_unidad(indice : int) -> ItemInstance:
	var s := casilla(indice)
	if s == null:
		return null

	var inst : ItemInstance
	if s.es_unico():
		inst = s.instancia
		_casillas[indice] = null
	else:
		inst = ItemInstance.new()
		inst.definicion_id = s.definicion_id
		s.cantidad -= 1
		if s.esta_vacio():
			_casillas[indice] = null

	cambiado.emit()
	return inst


## Mueve lo de una casilla a otra. Devuelve OK o el motivo del rechazo.
##
## A un hueco, lo muda. Sobre una pila del mismo item, las junta hasta el tope y
## lo que no entra se queda donde estaba. Sobre cualquier otra cosa, las
## intercambia. Lo que se mueve es la misma casilla y no una copia, asi que
## quien la estaba mirando la sigue encontrando.
func mover(desde : int, hasta : int) -> Errores.Codigo:
	var origen := casilla(desde)
	if origen == null or hasta < 0 or hasta >= _casillas.size():
		return Errores.Codigo.NO_TIENE_ITEM
	if desde == hasta:
		return Errores.Codigo.OK

	var destino := _casillas[hasta]
	if destino != null and destino.puede_apilar_con(origen):
		var pasa := mini(destino.espacio_libre(), origen.cantidad)
		if pasa <= 0:
			return Errores.Codigo.OK
		destino.cantidad += pasa
		origen.cantidad -= pasa
		if origen.esta_vacio():
			_casillas[desde] = null
	else:
		_casillas[hasta] = origen
		_casillas[desde] = destino

	cambiado.emit()
	return Errores.Codigo.OK


## Vacia el contenedor.
func vaciar() -> void:
	_casillas.fill(null)
	cambiado.emit()


## Vuelca el contenido a un diccionario serializable.
##
## Solo las casillas ocupadas, cada una con su numero: un contenedor de
## cuarenta casillas con tres cosas no tiene por que escribir treinta y siete
## huecos.
func to_dict() -> Dictionary:
	var lista : Array = []
	for i in _casillas.size():
		var s := _casillas[i]
		if s == null:
			continue
		var entrada := {"casilla": i, "item": String(s.definicion_id), "cantidad": s.cantidad}
		if s.es_unico():
			entrada["contenido"] = String(s.instancia.contenido_id)
			entrada["contenido_cantidad"] = s.instancia.contenido_cantidad
		lista.append(entrada)
	return {"slots": lista}


## Reemplaza el contenido con lo que diga el diccionario.
##
## Cada cosa vuelve a su casilla. Si no dice cual —un perfil de antes de que las
## casillas tuvieran posicion—, o si la que dice esta ocupada o no existe, va al
## primer hueco: un guardado raro tiene que leerse con todo lo que trae, aunque
## no quede cada cosa en su lugar.
##
## No respeta los limites a proposito. Lo que se lee es lo que habia, y un
## catalogo que cambio el peso de algo no puede borrarle cosas a nadie.
##
## Los numeros llegan como float desde JSON, que no distingue enteros, de ahi
## los int().
func from_dict(d : Dictionary) -> void:
	_casillas.fill(null)
	for entrada in d.get("slots", []):
		var id := StringName(entrada.get("item", ""))
		var def := ItemDatabase.obtener(id)
		if def == null:
			push_warning("Contenedor: el guardado trae '%s', que el catalogo no tiene." % id)
			continue

		var s := InventorySlot.new()
		s.definicion_id = id
		if def.tiene_estado_propio():
			var inst := ItemInstance.new()
			inst.definicion_id = id
			inst.contenido_id = StringName(entrada.get("contenido", ""))
			inst.contenido_cantidad = int(entrada.get("contenido_cantidad", 0))
			s.instancia = inst
			s.cantidad = 1
		else:
			s.cantidad = int(entrada.get("cantidad", 1))
		if s.esta_vacio():
			continue

		var indice := int(entrada.get("casilla", -1))
		if casilla(indice) != null or indice < 0 or indice >= _casillas.size():
			indice = _primer_hueco()
		if indice == -1:
			push_warning("Contenedor: el guardado trae mas cosas que casillas; se descarta '%s'." % id)
			continue
		_casillas[indice] = s

	cambiado.emit()


## Devuelve si entran tantas unidades de un item, contando casillas y peso.
func _cabe(def : ItemDefinition, cantidad : int) -> Errores.Codigo:
	if peso_maximo > 0.0 and peso_total() + def.peso * cantidad > peso_maximo + 0.0001:
		return Errores.Codigo.INVENTARIO_LLENO
	if _casillas_necesarias(def, cantidad) > casillas_libres():
		return Errores.Codigo.INVENTARIO_LLENO
	return Errores.Codigo.OK


## Cuantas casillas nuevas harian falta para meter esa cantidad, contando lo que
## entra en las pilas que ya existen.
func _casillas_necesarias(def : ItemDefinition, cantidad : int) -> int:
	if def.tiene_estado_propio():
		return cantidad
	var resto := cantidad
	for s in _casillas:
		if s != null and s.definicion_id == def.id and not s.es_unico():
			resto -= s.espacio_libre()
	if resto <= 0:
		return 0
	return ceili(float(resto) / float(maxi(def.stack_maximo, 1)))


## Pone una unidad con estado en la casilla pedida si esta libre, o en el
## primer hueco. Quien llama ya comprobo que entra.
func _poner_unica(inst : ItemInstance, indice : int) -> void:
	if casilla(indice) != null or indice < 0 or indice >= _casillas.size():
		indice = _primer_hueco()
	var s := InventorySlot.new()
	s.definicion_id = inst.definicion_id
	s.cantidad = 1
	s.instancia = inst
	_casillas[indice] = s


## Reparte una cantidad en pilas: primero la casilla pedida, despues las pilas
## que ya estan, despues pilas nuevas en los huecos. Quien llama ya comprobo que
## entra.
func _poner_pila(def : ItemDefinition, cantidad : int, indice : int) -> void:
	var resto := cantidad

	if indice >= 0 and indice < _casillas.size():
		if _casillas[indice] == null:
			_casillas[indice] = _pila_nueva(def, mini(def.stack_maximo, resto))
			resto -= _casillas[indice].cantidad
		elif _casillas[indice].definicion_id == def.id and not _casillas[indice].es_unico():
			var entra := mini(_casillas[indice].espacio_libre(), resto)
			_casillas[indice].cantidad += entra
			resto -= entra

	for s in _casillas:
		if resto <= 0:
			break
		if s != null and s.definicion_id == def.id and not s.es_unico():
			var entra := mini(s.espacio_libre(), resto)
			s.cantidad += entra
			resto -= entra

	while resto > 0:
		var hueco := _primer_hueco()
		_casillas[hueco] = _pila_nueva(def, mini(def.stack_maximo, resto))
		resto -= _casillas[hueco].cantidad


func _pila_nueva(def : ItemDefinition, cantidad : int) -> InventorySlot:
	var s := InventorySlot.new()
	s.definicion_id = def.id
	s.cantidad = cantidad
	return s


## Descuenta unidades de las casillas que cumplan la condicion, de la primera a
## la ultima, y deja hueco donde se vacien. Quien llama ya comprobo que alcanza.
func _descontar(cumple : Callable, cantidad : int) -> void:
	var resto := cantidad
	for i in _casillas.size():
		if resto <= 0:
			break
		var s := _casillas[i]
		if s == null or not cumple.call(s):
			continue
		var saca := mini(s.cantidad, resto)
		s.cantidad -= saca
		resto -= saca
		if s.esta_vacio():
			_casillas[i] = null
	cambiado.emit()


## Devuelve la primera casilla vacia, o -1 si no hay.
func _primer_hueco() -> int:
	return _casillas.find(null)
