# MumiolaCity

Habbo-like isométrico donde la ciudad entera es una economía dirigida por lo que producen los jugadores: recolectar, transformar, vender y consumir, con una moneda única y ninguna tienda del sistema.

- [`docs/GDD.md`](docs/GDD.md) — documento de diseño general (pilares, loop, habilidades, economía, arte, arquitectura técnica, roadmap).
- [`docs/SCRIPTS.md`](docs/SCRIPTS.md) — mapa de todos los scripts principales, su función y cómo interactúan entre sí, ordenados por fase de implementación (también publicado como [artefacto navegable](https://claude.ai/code/artifact/5f914cd8-0d3b-437a-981a-0f18a4bb0a82)).
- [`docs/SISTEMAS.md`](docs/SISTEMAS.md) — cómo se comunican los sistemas entre sí: las cuatro capas y la regla de dirección, el grafo de dependencias, los seis flujos de extremo a extremo, dónde vive cada dato, las once decisiones abiertas (D1–D11) y los hallazgos sobre el balance de la economía (también publicado como [artefacto navegable](https://claude.ai/code/artifact/d03673ae-eb6b-4882-8500-aced5957bd82)).
- [`docs/CLASES.md`](docs/CLASES.md) — referencia de las 43 clases a implementar: de qué hereda cada una, qué campos exporta, qué señales emite, qué métodos ofrece y qué invariantes tiene que respetar.
- [`docs/IMPLEMENTACION.md`](docs/IMPLEMENTACION.md) — checklist de implementación script por script: qué definir, qué construir y cómo verificar antes de pasar al siguiente.
- [`docs/items/items.json`](docs/items/items.json) — diccionario fuente de ítems del MVP (fuente de la futura base de datos de ítems en Godot).
- [`docs/items/lista_items.md`](docs/items/lista_items.md) — lista legible de esos mismos ítems, por categoría, con una nota de en qué sistema participa cada uno.

Repo privado, uso personal de respaldo del diseño.
