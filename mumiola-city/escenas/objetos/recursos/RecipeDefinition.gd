class_name RecipeDefinition
extends Resource

## Como se produce un item: que hace falta, con que habilidad, cuanto tarda.
##
## Vive anidada dentro del ItemDefinition del resultado, asi que **no guarda su
## resultado**: el resultado es quien la contiene. Guardarlo en ambos lados es el
## mismo error que guardar nivel y xp por separado — dos fuentes para un solo
## dato, esperando a discrepar.
##
## Modela tambien el cultivo: plantar un tomate es una receta cuyo insumo es la
## semilla y cuya estacion es la parcela. Por eso el catalogo no necesita un
## PlantableData aparte.

## Todo lo que la receta pide, se gaste o no. Los utensilios son insumos con
## consume en false.
@export var insumos : Array[InsumoReceta] = []

## Que habilidad se usa y se entrena. Siempre una constante de Habilidades.
@export var habilidad : StringName = &""
@export var nivel_requerido : int = 1
@export var xp_otorgada : int = 0
@export var tiempo_crafteo_seg : float = 1.0
@export var cantidad_resultado : int = 1

## Donde se hace: la parcela, la estufa, el fregadero, el banco de carpintero.
## Vacio significa que se puede hacer en cualquier lado, con los utensilios en
## la mano.
@export var estacion : StringName = &""

## Que sale si se intenta sin el nivel pedido. Vacio significa que la receta
## directamente no esta disponible.
##
## Es la diferencia entre "no podes intentarlo" y "te salio mal": lo segundo
## ensena mas y ya tiene modelo — la carne quemada del pack.
@export var resultado_fallo : StringName = &""


## Devuelve solo los insumos que se destruyen al craftear.
func insumos_consumibles() -> Array[InsumoReceta]:
	var salida : Array[InsumoReceta] = []
	for i in insumos:
		if i != null and i.consume:
			salida.append(i)
	return salida


## Devuelve los insumos que hacen falta pero no se gastan: los utensilios.
func utensilios() -> Array[InsumoReceta]:
	var salida : Array[InsumoReceta] = []
	for i in insumos:
		if i != null and not i.consume:
			salida.append(i)
	return salida


## Devuelve si la receta acepta algun insumo de esa familia.
func requiere_familia(familia : StringName) -> bool:
	for i in insumos:
		if i != null and i.familia == familia:
			return true
	return false


## Devuelve si intentarla con ese nivel produce el resultado bueno.
func sale_bien_con(nivel : int) -> bool:
	return nivel >= nivel_requerido


## Devuelve si se puede intentar con ese nivel.
##
## Se puede por debajo del nivel pedido solo si hay un resultado de fallo
## definido: si no, la receta ni siquiera aparece.
func se_puede_intentar_con(nivel : int) -> bool:
	return sale_bien_con(nivel) or resultado_fallo != &""
