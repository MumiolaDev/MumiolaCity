#!/usr/bin/env python3
"""Genera las plantillas de forma para crear salas nuevas.

Uso:
    python3 herramientas/generar_plantillas.py

Escribe un JSON por forma en mumiola-city/data/salas/plantillas/. Cada uno es un
documento de sala sin objetos: la misma forma que produce RoomController.to_dict(),
asi que crear una sala es copiar la plantilla y ponerle nombre y duenio.

Una forma se describe como un conjunto de celdas. De ahi sale todo lo demas, con
las mismas reglas que se usaron al pintar las salas a mano:

- El suelo cubre la forma entera, tambien debajo de las paredes: si no, la sala
  se ve desconectada del piso.
- Las paredes van en el borde de la forma, en las celdas que tocan el afuera. Su
  orientacion depende del lado: arriba 0, abajo 10, izquierda 16, derecha 22.
- Donde el borde dobla —una esquina, por fuera o por dentro— va un pilar.
- La puerta es un hueco en la pared de arriba, y la entrada es la celda de
  adentro que tiene enfrente.

Agregar una forma es agregar una funcion a FORMAS. Es idempotente: vuelve a
escribir todas las plantillas.
"""

import json
from pathlib import Path

DESTINO = Path(__file__).resolve().parent.parent / "mumiola-city" / "data" / "salas" / "plantillas"

SUELO = "suelo_piedra"
ORIENTACION_SUELO = 22
PARED = "pared_base"
PILAR = "pilar_base"

# Lado donde esta el afuera -> orientacion de la pared.
ARRIBA, ABAJO, IZQUIERDA, DERECHA = (0, -1), (0, 1), (-1, 0), (1, 0)
ORIENTACION_PARED = {ARRIBA: 0, ABAJO: 10, IZQUIERDA: 16, DERECHA: 22}


def rectangulo(x0, y0, ancho, alto):
    return {(x, y) for x in range(x0, x0 + ancho) for y in range(y0, y0 + alto)}


FORMAS = {
    "cuadrada_chica": {
        "nombre": "Cuadrada chica",
        "descripcion": "Un cuarto de 8 por 8. Para empezar.",
        "celdas": rectangulo(0, 0, 10, 10),
        "puerta_x": 2,
    },
    "cuadrada_grande": {
        "nombre": "Cuadrada grande",
        "descripcion": "Un salon de 14 por 14, con lugar para todo.",
        "celdas": rectangulo(0, 0, 16, 16),
        "puerta_x": 3,
    },
    "en_l": {
        "nombre": "En L",
        "descripcion": "Dos alas en angulo: una para estar y otra para lo que quieras.",
        "celdas": rectangulo(0, 0, 14, 7) | rectangulo(0, 7, 7, 7),
        "puerta_x": 2,
    },
    "pasillo": {
        "nombre": "Pasillo",
        "descripcion": "Largo y angosto, de 3 por 16.",
        "celdas": rectangulo(0, 0, 5, 18),
        "puerta_x": 2,
    },
    "en_t": {
        "nombre": "En T",
        "descripcion": "Un frente ancho y un ala que baja por el medio.",
        "celdas": rectangulo(0, 0, 16, 6) | rectangulo(5, 6, 6, 10),
        "puerta_x": 7,
    },
}


def borde(celdas):
    """Devuelve {celda: [lados que dan afuera]} para las celdas del borde."""
    salida = {}
    for (x, y) in celdas:
        afuera = [d for d in ORIENTACION_PARED if (x + d[0], y + d[1]) not in celdas]
        # Una esquina de adentro no toca el afuera por ningun lado recto, solo en
        # diagonal, y tambien es borde: ahi dobla la pared.
        diagonal = any((x + dx, y + dy) not in celdas for dx in (-1, 1) for dy in (-1, 1))
        if afuera or diagonal:
            salida[(x, y)] = afuera
    return salida


def paredes(celdas, puerta):
    salida = []
    for (x, y), lados in sorted(borde(celdas).items(), key=lambda e: (e[0][1], e[0][0])):
        if (x, y) == puerta:
            continue
        if len(lados) == 1:
            salida.append([x, y, PARED, ORIENTACION_PARED[lados[0]]])
        else:
            # Dos lados (esquina de afuera) o ninguno (esquina de adentro).
            salida.append([x, y, PILAR, 0])
    return salida


def plantilla(id_forma, forma):
    celdas = forma["celdas"]
    y_arriba = min(y for (_, y) in celdas)
    puerta = (forma["puerta_x"], y_arriba)
    assert puerta in celdas and (puerta[0], puerta[1] + 1) in celdas, f"{id_forma}: puerta fuera de la forma"
    assert borde(celdas).get(puerta) == [ARRIBA], f"{id_forma}: la puerta tiene que estar en un tramo recto de arriba"

    return {
        "version_formato": 1,
        "id": id_forma,
        "nombre": forma["nombre"],
        "descripcion": forma["descripcion"],
        "tipo": "vivienda",
        "entrada": [puerta[0], puerta[1] + 1],
        "estructura": {
            "suelo": [[x, y, SUELO, ORIENTACION_SUELO] for (x, y) in sorted(celdas, key=lambda c: (c[1], c[0]))],
            "paredes": paredes(celdas, puerta),
        },
        "objetos": [],
    }


def main():
    DESTINO.mkdir(parents=True, exist_ok=True)
    for id_forma, forma in FORMAS.items():
        doc = plantilla(id_forma, forma)
        (DESTINO / f"{id_forma}.json").write_text(json.dumps(doc, ensure_ascii=False, indent="\t") + "\n")
        print(f"{id_forma}: {len(doc['estructura']['suelo'])} de suelo, {len(doc['estructura']['paredes'])} de pared")


if __name__ == "__main__":
    main()
