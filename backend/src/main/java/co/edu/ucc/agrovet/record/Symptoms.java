package co.edu.ucc.agrovet.record;

/**
 * Lo que el ganadero observa en el día: dos preguntas Sí/No (pueden quedar sin responder) y los signos
 * de la ubre.
 *
 * @param udderSwelling ubre hinchada
 * @param abnormalMilk  grumos o sangre en la leche
 * @param udderPain     dolor al tocar
 * @param lethargy      casilla de versiones anteriores ("decaída, come poco"); ya no se pregunta
 * @param udderRedness  ubre enrojecida
 * @param udderHeat     ubre caliente
 * @param ateNormally   ¿comió normal? (null: sin respuesta)
 * @param milkDrop      ¿produjo menos leche de lo usual? (null: sin respuesta)
 */
public record Symptoms(boolean udderSwelling, boolean abnormalMilk, boolean udderPain, boolean lethargy,
        boolean udderRedness, boolean udderHeat, Boolean ateNormally, Boolean milkDrop) {

    public static final Symptoms NONE = new Symptoms(false, false, false, false, false, false, null, null);
}
