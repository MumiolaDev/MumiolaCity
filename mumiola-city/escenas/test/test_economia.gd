extends Node

## Verificaciones de InventoryManager y SkillManager. Se corre con F6 sobre esta
## escena y reporta por consola.
##
## A diferencia de test_isogrid, esta si se versiona: no depende de como este
## pintada ninguna sala ni de nada de esta maquina. Es logica pura y determinista,
## asi que el resultado tiene que ser el mismo para cualquiera que la corra.
##
## Comprueba sobre todo las reglas de D1, que son las que se rompen sin hacer
## ruido: apilar lo que no deberia apilarse pierde el estado de una unidad, y no
## hay error que lo delate.

var _pasados : int = 0
var _fallados : int = 0
var _niveles_vistos : Array = []


func _ready() -> void:
	# El estado arranca limpio: estas pruebas escriben en los autoloads reales.
	InventoryManager.vaciar()
	SkillManager.reiniciar()

	_probar_catalogo()
	_probar_apilado()
	_probar_estado_propio()
	_probar_familias()
	_probar_limites()
	_probar_serializacion_inventario()
	_probar_habilidades()

	print("\n--- %d pasados, %d fallados ---" % [_pasados, _fallados])


func verificar(condicion : bool, nombre : String) -> void:
	if condicion:
		_pasados += 1
		print("  ok    ", nombre)
	else:
		_fallados += 1
		printerr("  FALLA ", nombre)


## Sin catalogo no hay nada que probar, asi que conviene decirlo primero y claro.
func _probar_catalogo() -> void:
	print("catalogo")
	verificar(ItemDatabase.cantidad() > 0, "ItemDatabase tiene definiciones cargadas")
	verificar(ItemDatabase.existe(&"tomate"), "existe el tomate")
	verificar(ItemDatabase.existe(&"plato"), "existe el plato")
	var tomate := ItemDatabase.obtener(&"tomate")
	verificar(tomate != null and tomate.es_apilable(), "el tomate es apilable")
	var plato := ItemDatabase.obtener(&"plato")
	verificar(plato != null and plato.tiene_estado_propio(), "el plato tiene estado propio")


func _probar_apilado() -> void:
	print("apilado de lo identico")
	InventoryManager.vaciar()

	verificar(Errores.ok(InventoryManager.agregar(&"tomate", 5)), "agregar 5 tomates")
	verificar(InventoryManager.cantidad_de(&"tomate") == 5, "hay 5")
	verificar(InventoryManager.slots().size() == 1, "ocupan una sola casilla")

	InventoryManager.agregar(&"tomate", 97)
	verificar(InventoryManager.cantidad_de(&"tomate") == 102, "hay 102 tras sumar 97")
	verificar(InventoryManager.slots().size() == 2, "102 no entran en una pila de 99")

	verificar(Errores.ok(InventoryManager.quitar(&"tomate", 100)), "quitar 100")
	verificar(InventoryManager.cantidad_de(&"tomate") == 2, "quedan 2")
	verificar(InventoryManager.slots().size() == 1, "la casilla vaciada se descarta")

	var codigo := InventoryManager.quitar(&"tomate", 999)
	verificar(codigo == Errores.Codigo.NO_TIENE_ITEM, "quitar de mas da NO_TIENE_ITEM")
	verificar(InventoryManager.cantidad_de(&"tomate") == 2, "y no saca nada")


## La regla central de D1: lo que tiene estado propio nunca se apila.
func _probar_estado_propio() -> void:
	print("unidades con estado propio")
	InventoryManager.vaciar()

	InventoryManager.agregar(&"plato", 2)
	verificar(InventoryManager.cantidad_de(&"plato") == 2, "hay 2 platos")
	verificar(InventoryManager.slots().size() == 2, "cada plato ocupa su casilla")

	var slots := InventoryManager.slots()
	verificar(slots[0].es_unico() and slots[1].es_unico(), "los dos son unicos")
	verificar(not slots[0].puede_apilar_con(slots[1]), "dos platos no se apilan entre si")

	# El caso que motiva toda la regla: si se apilaran, una de las dos perderia
	# su contenido sin que nada diera error.
	slots[0].instancia.contenido_id = &"guiso"
	slots[0].instancia.contenido_cantidad = 1
	verificar(not slots[0].instancia.esta_vacio(), "un plato queda servido")
	verificar(slots[1].instancia.esta_vacio(), "el otro sigue vacio")
	verificar(not slots[0].puede_apilar_con(slots[1]), "el servido tampoco se apila con el vacio")

	var devuelto := InventoryManager.quitar_instancia(slots[0].instancia)
	verificar(devuelto == slots[0].instancia, "quitar_instancia devuelve la misma, no una copia")
	verificar(InventoryManager.cantidad_de(&"plato") == 1, "queda un plato")


func _probar_familias() -> void:
	print("busqueda por familia")
	InventoryManager.vaciar()

	InventoryManager.agregar(&"plato", 1)
	InventoryManager.agregar(&"bol", 1)
	verificar(InventoryManager.cantidad_de_familia(&"plato") == 2,
		"plato y bol cuentan como la misma familia")
	verificar(InventoryManager.buscar_familia(&"plato") != null, "se encuentra alguno")
	verificar(InventoryManager.buscar_familia(&"inexistente") == null, "una familia que no existe da null")

	verificar(Errores.ok(InventoryManager.quitar_familia(&"plato", 1)), "quitar uno de la familia")
	verificar(InventoryManager.cantidad_de_familia(&"plato") == 1, "queda uno")


func _probar_limites() -> void:
	print("limites de peso y casillas")
	InventoryManager.vaciar()

	# La tabla pesa 2 kg y el tope son 200: 101 tablas no pueden entrar.
	var codigo := InventoryManager.agregar(&"tabla_madera", 101)
	verificar(codigo == Errores.Codigo.INVENTARIO_LLENO, "el peso rechaza el agregado")
	verificar(InventoryManager.cantidad_de(&"tabla_madera") == 0, "y no agrega nada a medias")

	InventoryManager.vaciar()
	verificar(Errores.ok(InventoryManager.agregar(&"tabla_madera", 99)), "99 tablas si entran")
	verificar(InventoryManager.peso_total() <= InventoryManager.PESO_MAXIMO,
		"el peso queda bajo el tope")


func _probar_serializacion_inventario() -> void:
	print("guardado del inventario")
	InventoryManager.vaciar()
	InventoryManager.agregar(&"tomate", 7)
	InventoryManager.agregar(&"plato", 1)
	InventoryManager.slots()[1].instancia.contenido_id = &"guiso"

	var copia := InventoryManager.to_dict()
	InventoryManager.vaciar()
	verificar(InventoryManager.slots().is_empty(), "se vacio")

	InventoryManager.from_dict(copia)
	verificar(InventoryManager.cantidad_de(&"tomate") == 7, "vuelven los 7 tomates")
	verificar(InventoryManager.cantidad_de(&"plato") == 1, "vuelve el plato")
	var servido := false
	for s in InventoryManager.slots():
		if s.es_unico() and s.instancia.contenido_id == &"guiso":
			servido = true
	verificar(servido, "y vuelve servido: el contenido sobrevive al guardado")


func _probar_habilidades() -> void:
	print("habilidades")
	SkillManager.reiniciar()
	_niveles_vistos.clear()
	SkillManager.nivel_subido.connect(_anotar_nivel)

	verificar(SkillManager.definicion(Habilidades.COCINA) != null, "existe la definicion de Cocina")
	verificar(SkillManager.nivel_de(&"no_existe") == 0,
		"una habilidad desconocida da nivel 0, no 1")
	verificar(SkillManager.nivel_de(Habilidades.COCINA) == 1, "con 0 xp se esta en nivel 1")

	SkillManager.agregar_xp(Habilidades.COCINA, 500)
	verificar(SkillManager.xp_de(Habilidades.COCINA) == 500, "la xp se acumula")
	verificar(SkillManager.nivel_de(Habilidades.COCINA) > 1, "y el nivel sube")
	verificar(not _niveles_vistos.is_empty(), "se avisa de la subida")
	verificar(_niveles_vistos.size() == SkillManager.nivel_de(Habilidades.COCINA) - 1,
		"se avisa una vez por cada nivel alcanzado, no una sola por la ganancia")

	verificar(SkillManager.alcanza_nivel(Habilidades.COCINA, 2), "alcanza el nivel 2")
	verificar(not SkillManager.alcanza_nivel(Habilidades.CARPINTERIA, 2),
		"Carpinteria sigue en 1: la xp no se mezcla entre habilidades")

	var copia := SkillManager.to_dict()
	SkillManager.reiniciar()
	verificar(SkillManager.xp_de(Habilidades.COCINA) == 0, "se reinicio")
	SkillManager.from_dict(copia)
	verificar(SkillManager.xp_de(Habilidades.COCINA) == 500, "vuelve la xp del guardado")

	SkillManager.nivel_subido.disconnect(_anotar_nivel)


func _anotar_nivel(_habilidad : StringName, nivel : int) -> void:
	_niveles_vistos.append(nivel)
