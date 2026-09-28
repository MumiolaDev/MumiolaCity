extends Node

## Comprueba Contenedor: un lugar finito donde se guardan cosas, con casillas de
## posicion fija.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena. No escribe en disco.
##
## Se escribio antes que Contenedor, y fija lo que tiene que cumplir:
##
##  - Que es finito por dos lados, casillas y peso, y que un rechazo no deja
##    nada a medias.
##  - Que cada cosa se queda en la casilla donde la dejaste: sacar algo deja un
##    hueco y no corre a las demas, y lo que entra llena el primer hueco.
##  - Que lo que tiene estado viaja como la misma instancia, y lo que no lo
##    tiene se apila aunque llegue como instancia.
##  - Que avisa una vez por cambio y ninguna por rechazo.
##  - Que el guardado conserva las posiciones, y que un perfil de antes, que no
##    las tenia, se sigue pudiendo leer.
##
## La mochila del jugador es un Contenedor mas: al final se comprueba que
## InventoryManager la expone y reenvia su aviso.

var _fallos := 0


func _ready() -> void:
	_probar_nuevo()
	_probar_apilar()
	_probar_posicion_fija()
	_probar_mover()
	_probar_lleno_por_casillas()
	_probar_todo_o_nada()
	_probar_peso()
	_probar_instancias()
	_probar_sacar_unidad()
	_probar_agregar_en_casilla()
	_probar_senal()
	_probar_guardado()
	_probar_guardado_viejo()
	_probar_mochila()

	print("CONTENEDOR: %s" % ("todo ok" if _fallos == 0 else "%d fallos" % _fallos))
	get_tree().quit()


func _probar_nuevo() -> void:
	var c := Contenedor.new(12, 30.0, "Alacena")
	_comprobar(c.casillas() == 12 and c.casillas_libres() == 12 and c.casillas_usadas() == 0,
		"uno nuevo tiene todas sus casillas libres")
	_comprobar(c.slots().is_empty() and is_zero_approx(c.peso_total()), "y nada adentro")
	_comprobar(c.nombre == "Alacena" and is_equal_approx(c.peso_maximo, 30.0), "guarda su nombre y su limite")
	_comprobar(c.casilla(0) == null and c.casilla(11) == null, "una casilla vacia es null")
	_comprobar(c.casilla(-1) == null and c.casilla(12) == null, "y una que no existe tambien")


func _probar_apilar() -> void:
	var c := Contenedor.new(10)
	_comprobar(Errores.ok(c.agregar(&"tomate", 5)), "agregar 5 tomates")
	_comprobar(_es(c, 0, &"tomate", 5), "van a la primera casilla")
	c.agregar(&"tomate", 97)
	_comprobar(_es(c, 0, &"tomate", 99) and _es(c, 1, &"tomate", 3),
		"97 mas llenan la pila y abren otra al lado")
	_comprobar(c.cantidad_de(&"tomate") == 102 and c.tiene(&"tomate", 102) and not c.tiene(&"tomate", 103),
		"cantidad_de y tiene suman todas las casillas")


func _probar_posicion_fija() -> void:
	var c := Contenedor.new(10)
	c.agregar(&"tomate", 99)
	c.agregar(&"lechuga", 3)
	c.agregar(&"mesa")
	_comprobar(_es(c, 2, &"mesa", 1), "la mesa entra en la tercera")

	c.quitar(&"tomate", 99)
	_comprobar(c.casilla(0) == null, "sacar los tomates deja un hueco")
	_comprobar(_es(c, 1, &"lechuga", 3) and _es(c, 2, &"mesa", 1), "y no corre a las demas")

	c.agregar(&"silla_madera")
	_comprobar(_es(c, 0, &"silla_madera", 1), "lo que entra llena el primer hueco")

	var orden : Array[StringName] = []
	for s in c.slots():
		orden.append(s.definicion_id)
	_comprobar(orden == [&"silla_madera", &"lechuga", &"mesa"], "slots() va en el orden de las casillas")
	_comprobar(c.indice_de(c.casilla(2)) == 2 and c.indice_de(InventorySlot.new()) == -1,
		"indice_de encuentra una casilla, y no una ajena")


func _probar_mover() -> void:
	var c := Contenedor.new(10)
	c.agregar(&"mesa")
	c.agregar(&"tomate", 90)
	c.agregar(&"silla_madera")

	_comprobar(Errores.ok(c.mover(0, 7)), "mover a una casilla vacia")
	_comprobar(c.casilla(0) == null and _es(c, 7, &"mesa", 1), "deja el hueco y la pone ahi")

	var silla := c.casilla(2)
	_comprobar(Errores.ok(c.mover(2, 7)), "mover sobre otra cosa")
	_comprobar(_es(c, 7, &"silla_madera", 1) and _es(c, 2, &"mesa", 1), "las intercambia")
	_comprobar(c.casilla(7) == silla, "moviendo la misma casilla, no una copia")

	c.agregar_en(&"tomate", 20, 5)
	_comprobar(_es(c, 5, &"tomate", 20), "agregar_en pone una pila en la casilla pedida")
	_comprobar(Errores.ok(c.mover(5, 1)), "mover una pila sobre otra del mismo item")
	_comprobar(_es(c, 1, &"tomate", 99) and _es(c, 5, &"tomate", 11),
		"las junta hasta el tope y lo que sobra se queda")
	c.mover(5, 1)
	_comprobar(_es(c, 1, &"tomate", 99) and _es(c, 5, &"tomate", 11), "sobre una pila llena, no pasa nada")

	var antes := c.to_dict()
	_comprobar(not Errores.ok(c.mover(4, 1)), "mover desde una casilla vacia se rechaza")
	_comprobar(not Errores.ok(c.mover(1, 10)) and not Errores.ok(c.mover(-1, 2)),
		"y hacia o desde una que no existe tambien")
	_comprobar(c.to_dict() == antes, "sin cambiar nada")
	_comprobar(Errores.ok(c.mover(1, 1)) and c.to_dict() == antes, "moverla a su lugar es no hacer nada")


func _probar_lleno_por_casillas() -> void:
	var c := Contenedor.new(2)
	c.agregar(&"tomate", 5)
	c.agregar(&"mesa")
	_comprobar(c.casillas_libres() == 0, "dos cosas llenan dos casillas")
	_comprobar(c.agregar(&"maceta") == Errores.Codigo.INVENTARIO_LLENO, "no entra una tercera")
	_comprobar(c.hay_lugar_para(ItemDatabase.obtener(&"maceta")) == Errores.Codigo.INVENTARIO_LLENO,
		"y hay_lugar_para lo sabe antes")
	_comprobar(Errores.ok(c.hay_lugar_para(ItemDatabase.obtener(&"tomate"))),
		"pero un tomate si, porque cabe en la pila")
	_comprobar(Errores.ok(c.agregar(&"tomate")) and _es(c, 0, &"tomate", 6), "y entra")


func _probar_todo_o_nada() -> void:
	var c := Contenedor.new(3)
	c.agregar(&"mesa")
	_comprobar(c.agregar(&"plato", 3) == Errores.Codigo.INVENTARIO_LLENO, "tres platos no entran en dos casillas")
	_comprobar(c.cantidad_de(&"plato") == 0, "y no entra ninguno")
	c.agregar(&"tomate", 90)
	_comprobar(c.agregar(&"tomate", 110) == Errores.Codigo.INVENTARIO_LLENO, "110 tomates no entran en 9 mas una")
	_comprobar(c.cantidad_de(&"tomate") == 90, "y tampoco se agrega una parte")
	_comprobar(c.quitar(&"tomate", 91) == Errores.Codigo.NO_TIENE_ITEM and c.cantidad_de(&"tomate") == 90,
		"quitar de mas no saca nada")


func _probar_peso() -> void:
	var c := Contenedor.new(10, 10.0)
	_comprobar(Errores.ok(c.agregar(&"mesa")), "una mesa de 6 kg entra en 10 kg")
	_comprobar(c.agregar(&"silla_madera") == Errores.Codigo.INVENTARIO_LLENO, "una silla de 6 kg mas, no")
	_comprobar(c.hay_lugar_para(ItemDatabase.obtener(&"silla_madera")) == Errores.Codigo.INVENTARIO_LLENO,
		"y hay_lugar_para mira el peso")
	_comprobar(is_equal_approx(c.peso_total(), 6.0), "peso_total suma lo que hay")

	var sin_limite := Contenedor.new(10)
	sin_limite.agregar(&"mesa", 3)
	_comprobar(sin_limite.cantidad_de(&"mesa") == 3, "con peso_maximo en cero no hay limite de peso")


func _probar_instancias() -> void:
	var c := Contenedor.new(10)
	var plato := _instancia(&"plato", &"guiso", 1)
	_comprobar(Errores.ok(c.agregar_instancia(plato)), "agregar un plato servido")
	_comprobar(c.casilla(0).instancia == plato, "queda la misma instancia, no una copia")

	c.agregar(&"tomate", 5)
	var suelto := _instancia(&"tomate")
	_comprobar(Errores.ok(c.agregar_instancia(suelto)), "agregar un tomate que llega como instancia")
	_comprobar(_es(c, 1, &"tomate", 6) and c.slots().size() == 2,
		"se apila con los otros, porque no tiene estado que perder")

	_comprobar(c.quitar_instancia(plato) == plato and c.casilla(0) == null, "quitar_instancia la devuelve y deja el hueco")
	_comprobar(c.quitar_instancia(plato) == null, "y la segunda vez ya no esta")


func _probar_sacar_unidad() -> void:
	var c := Contenedor.new(10)
	c.agregar(&"tomate", 2)
	var plato := _instancia(&"plato", &"guiso", 1)
	c.agregar_instancia(plato)

	var uno := c.sacar_unidad(0)
	_comprobar(uno != null and uno.definicion_id == &"tomate" and _es(c, 0, &"tomate", 1),
		"de una pila saca una instancia nueva y descuenta uno")
	c.sacar_unidad(0)
	_comprobar(c.casilla(0) == null, "la ultima deja el hueco")
	_comprobar(c.sacar_unidad(1) == plato and c.casilla(1) == null, "de una casilla unica saca esa misma instancia")
	_comprobar(c.sacar_unidad(0) == null and c.sacar_unidad(99) == null, "de una vacia o inexistente, null")


func _probar_agregar_en_casilla() -> void:
	var c := Contenedor.new(10)
	c.agregar(&"mesa")
	var silla := _instancia(&"silla_madera")
	_comprobar(Errores.ok(c.agregar_instancia(silla, 6)) and c.casilla(6).instancia == silla,
		"agregar_instancia respeta la casilla pedida si esta libre")
	var maceta := _instancia(&"maceta")
	c.agregar_instancia(maceta, 0)
	_comprobar(c.casilla(1).instancia == maceta and _es(c, 0, &"mesa", 1),
		"si esta ocupada va al primer hueco, sin pisar lo que habia")

	c.agregar_en(&"tomate", 4, 8)
	c.agregar_instancia(_instancia(&"tomate"), 8)
	_comprobar(_es(c, 8, &"tomate", 5), "un tomate pedido sobre su pila se suma a ella")


func _probar_senal() -> void:
	var c := Contenedor.new(2)
	var avisos := [0]
	c.cambiado.connect(func() -> void: avisos[0] += 1)

	c.agregar(&"tomate", 150)
	_comprobar(avisos[0] == 1, "agregar dos pilas de una vez avisa una sola vez")
	c.agregar(&"mesa")
	c.mover(0, 0)
	c.mover(3, 0)
	c.quitar(&"tomate", 999)
	c.sacar_unidad(5)
	_comprobar(avisos[0] == 1, "los rechazos y lo que no cambia nada no avisan")
	c.mover(1, 0)
	_comprobar(avisos[0] == 1, "juntar sobre una pila llena no cambia nada, y no avisa")
	c.mover(0, 1)
	c.sacar_unidad(0)
	c.vaciar()
	_comprobar(avisos[0] == 4, "mover, sacar y vaciar avisan una vez cada uno")


func _probar_guardado() -> void:
	var c := Contenedor.new(10)
	c.agregar_en(&"tomate", 3, 1)
	c.agregar_en(&"mesa", 1, 2)
	c.agregar_instancia(_instancia(&"plato", &"guiso", 1), 5)
	var d := c.to_dict()

	var otro := Contenedor.new(10)
	otro.agregar(&"lechuga", 4)
	otro.from_dict(JSON.parse_string(JSON.stringify(d)))
	_comprobar(otro.casilla(0) == null and otro.cantidad_de(&"lechuga") == 0,
		"from_dict reemplaza lo que habia y conserva los huecos")
	_comprobar(_es(otro, 1, &"tomate", 3) and _es(otro, 2, &"mesa", 1) and _es(otro, 5, &"plato", 1),
		"cada cosa vuelve a su casilla, despues de pasar por JSON")
	var p := otro.casilla(5)
	_comprobar(p != null and p.instancia != null and p.instancia.contenido_id == &"guiso",
		"y el plato vuelve servido")


func _probar_guardado_viejo() -> void:
	var viejo := {"slots": [
		{"item": "mesa", "cantidad": 1},
		{"item": "tomate", "cantidad": 7},
		{"item": "no_existe", "cantidad": 1},
		{"item": "plato", "cantidad": 1, "contenido": "guiso", "contenido_cantidad": 1},
	]}
	var c := Contenedor.new(10)
	c.from_dict(viejo)
	_comprobar(_es(c, 0, &"mesa", 1) and _es(c, 1, &"tomate", 7) and _es(c, 2, &"plato", 1),
		"un guardado sin casillas se lee de corrido, saltando lo que el catalogo no tiene")

	var raro := {"slots": [
		{"casilla": 1, "item": "mesa", "cantidad": 1},
		{"casilla": 1, "item": "maceta", "cantidad": 1},
		{"casilla": 40, "item": "silla_madera", "cantidad": 1},
	]}
	c.from_dict(raro)
	_comprobar(_es(c, 1, &"mesa", 1) and _es(c, 0, &"maceta", 1) and _es(c, 2, &"silla_madera", 1),
		"una casilla repetida o fuera de rango va al primer hueco, y no se pierde nada")


func _probar_mochila() -> void:
	var mochila : Contenedor = InventoryManager.mochila
	_comprobar(mochila != null and mochila.casillas() == InventoryManager.CASILLAS
		and is_equal_approx(mochila.peso_maximo, InventoryManager.PESO_MAXIMO),
		"la mochila es un Contenedor con las casillas y el peso de InventoryManager")

	InventoryManager.vaciar()
	var avisos := [0]
	var contar := func() -> void: avisos[0] += 1
	InventoryManager.inventario_cambiado.connect(contar)
	mochila.agregar(&"mesa")
	_comprobar(avisos[0] == 1 and InventoryManager.cantidad_de(&"mesa") == 1,
		"cambiar la mochila directo avisa por inventario_cambiado")
	InventoryManager.inventario_cambiado.disconnect(contar)
	InventoryManager.vaciar()


func _instancia(id : StringName, contenido : StringName = &"", cantidad : int = 0) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.definicion_id = id
	inst.contenido_id = contenido
	inst.contenido_cantidad = cantidad
	return inst


## Devuelve si la casilla tiene ese item en esa cantidad.
func _es(c : Contenedor, indice : int, id : StringName, cantidad : int) -> bool:
	var s := c.casilla(indice)
	return s != null and s.definicion_id == id and s.cantidad == cantidad


func _comprobar(condicion : bool, que : String) -> void:
	print("  %s %s" % ["ok   " if condicion else "FALLO", que])
	if not condicion:
		_fallos += 1
