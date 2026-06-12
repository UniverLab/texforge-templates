"""Ejemplo mínimo que muestra estructuras condicionales y repetitivas.

Reemplaza este archivo por el código real de tu taller. El informe lo inserta
con \\lstinputlisting, así que cualquier cambio aquí se refleja al recompilar.
"""


def clasificar(numeros):
    """Clasifica una lista de números en pares e impares."""
    pares, impares = [], []

    # Estructura repetitiva: recorre cada elemento de la colección.
    for n in numeros:
        # Estructura condicional: decide a qué grupo pertenece.
        if n % 2 == 0:
            pares.append(n)
        else:
            impares.append(n)

    return pares, impares


def main():
    datos = [3, 8, 1, 6, 7, 4, 9, 2]
    pares, impares = clasificar(datos)

    # Validación simple antes de mostrar resultados.
    if not datos:
        print("No hay datos para procesar.")
        return

    print(f"Pares:   {pares}")
    print(f"Impares: {impares}")


if __name__ == "__main__":
    main()
