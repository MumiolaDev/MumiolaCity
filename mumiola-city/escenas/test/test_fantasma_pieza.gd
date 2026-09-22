extends Node

## Comprueba que el fantasma de una pieza caiga exactamente donde el GridMap la
## pondria: misma posicion, misma escala y mismo giro.
##
## Para correrlo: agregar un Node con este script como hijo de Mundo y ejecutar
## la escena.
##
## La cuenta contra la que se compara es la definicion de como coloca un GridMap:
##     Transform3D(base_de_la_orientacion, ancla_de_la_celda) * transformada_de_la_pieza
## Si el fantasma no da eso, se ve distinto de lo que vas a colocar.

func _ready() -> void:
	for i in 3: await get_tree().process_frame
	var sala := GameManager.sala_actual()
	var indicador := sala.indicador
	var fallos := 0
	var gm := GridMap.new()

	for capa in [CatalogoPiezas.SUELO, CatalogoPiezas.PAREDES]:
		var biblioteca := sala.grid.biblioteca_de(capa)
		for pieza in CatalogoPiezas.PIEZAS[capa]:
			var id := CatalogoPiezas.id_de(biblioteca, pieza)
			if id == -1:
				continue
			var malla : Mesh = biblioteca.get_item_mesh(id)
			var tp : Transform3D = biblioteca.get_item_mesh_transform(id)

			for pasos in 4:
				var celda := Vector2i(7, 9)
				indicador.elegir_pieza(malla, tp, pasos)
				indicador.mostrar_en(celda, pasos)
				await get_tree().process_frame

				var nodo : MeshInstance3D = null
				for h in indicador.get_children():
					if h is Node3D and h.get_child_count() > 0 and h.get_child(0) is MeshInstance3D:
						nodo = h.get_child(0)
				if nodo == null:
					print("FALLO: sin fantasma para %s paso %d" % [pieza, pasos]); fallos += 1
					continue

				var orientacion := CatalogoPiezas.orientacion_de(pasos)
				var esperado := Transform3D(gm.get_basis_with_orthogonal_index(orientacion),
					sala.grid.ancla_de_pieza(celda)) * tp
				var obtenido := nodo.global_transform

				var d_pos : float = (esperado.origin - obtenido.origin).length()
				var d_escala : float = (esperado.basis.get_scale() - obtenido.basis.get_scale()).length()
				var d_giro : float = absf(rad_to_deg(esperado.basis.get_euler().y - obtenido.basis.get_euler().y))
				d_giro = fmod(d_giro + 360.0, 360.0)
				if d_giro > 180.0:
					d_giro = 360.0 - d_giro

				if d_pos > 0.001 or d_escala > 0.001 or d_giro > 0.1:
					print("FALLO %-18s paso %d: pos %.4f  escala %.4f  giro %.2f"
						% [pieza, pasos, d_pos, d_escala, d_giro])
					fallos += 1

	gm.free()
	print("comparadas %d piezas x 4 giros contra la colocacion real del GridMap"
		% (CatalogoPiezas.PIEZAS[CatalogoPiezas.SUELO].size() + CatalogoPiezas.PIEZAS[CatalogoPiezas.PAREDES].size()))
	print("FANTASMA DE PIEZA: %s" % ("todo ok" if fallos == 0 else "%d fallos" % fallos))
	get_tree().quit()
