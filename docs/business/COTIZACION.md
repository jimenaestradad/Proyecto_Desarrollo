# Nori — Cotización y modelo de cobro

Cuánto costaría construir Nori, qué precio le ponemos y cómo pensamos ganar dinero con la app. Sigue el método del Módulo 1: story points → horas → tarifa → colchón de riesgo → precio, y compara el resultado con lo que cuestan apps parecidas.

- **Parte 1:** cotización del desarrollo y costos mensuales de operación.
- **Parte 2:** modelo de cobro al usuario final (freemium con anuncios y tres planes).

**Qué es medido y qué es supuesto.** No llevamos registro de horas. WakaTime registró 48 h en el editor, que es un piso, no el total. Los puntos del backlog inicial y la re-estimación de lo construido se hicieron con apoyo de IA (Claude), sin calibrar con horas reales. Todo número que no sea un dato del repositorio es una estimación o un supuesto.

---

# Parte 1 — Cotización del desarrollo

## Resumen

| Concepto | Valor |
|---|---:|
| Backlog re-estimado (lo que se construyó) | **306 story points** (65 historias) |
| Horas por punto | **2.0** |
| Horas estimadas | **612 h** |
| Tarifa | **US$15 / hora** |
| Costo del desarrollo | US$9,180 |
| Colchón de riesgo (20%) | US$1,836 |
| **Total** | **US$11,016 → precio propuesto: US$11,000** (≈ Q84,700; US$12,320 con IVA de 12%) |

Tipo de cambio supuesto: Q7.70 por US$1.

## 1. La tarifa: US$15 por hora

Es una referencia de mercado: lo que un catedrático de Ingeniería de Software recomienda para estudiantes de nivel inicial. La fórmula de la clase 2 (`(lo que necesitás + lo que gastás + tu ganancia) ÷ horas cobrables`) sirve para comprobar que cubre los costos reales.

Los gastos mensuales de una persona del equipo suman **≈ Q1,200 a Q1,500** (comida en la universidad, gasolina, la herramienta de IA de US$20, parqueo, proyectos de la universidad y salidas; sin renta, vive con su familia). Con las 100 horas cobrables al mes de la clase, US$15 por hora son ≈ Q11,550 al mes; con 40 horas (supuesto, más realista para alguien que estudia), ≈ Q4,620. En los dos casos cubre esos gastos varias veces, y la diferencia es margen y colchón. Los dos integrantes cobran la misma tarifa.

## 2. De dónde salen los puntos y las horas

**Backlog original (Release 0, ClickUp).** El MVP tenía 41 historias con puntos: 175 pts, 683.5 h con la tabla PERT del Release 0 (≈3.9 h por punto), o US$12,303 con tarifa y colchón. Había además 19 historias fuera de alcance (78 pts: social, quests, leaderboards).

**Alcance ampliado a propósito.** El MVP original era simple. Como nos sobró tiempo, construimos tantos elementos fuera de alcance como fue realista: el tab Social como demo visual con datos simulados (el backend social no se hizo por falta de tiempo), notificaciones in-app, segunda evolución, vinculación de cuentas Google ↔ email, username único, bucket list con recompensas, archivar hábitos, borrar cuenta y dos rondas de QA con pruebas automatizadas. Ante un cliente real, todo eso se habría cotizado como *change request*. El alcance construido es **75% mayor** (175 → 306 pts).

**Backlog re-estimado.** Misma escala de puntos, estimada de forma retroactiva mirando el repositorio, a 2 h por punto:

| Épica | Historias (puntos) | Pts | Horas |
|---|---|---:|---:|
| A. Fundamentos e infraestructura | Setup Flutter (2), Firebase/GCP (3), identidad visual (5), personaje Nori (8), design tokens (5), CI (3), build de release y deploy web (3) | 29 | 58 |
| B. Cuenta y autenticación | Email (3), Google + username (3), vinculación de cuentas (5), username único (3), recuperar contraseña (2), sesión (2), verificación de email (2), perfil y borrar cuenta (5), ajustes (3) | 28 | 56 |
| C. Onboarding | Flujo (5), primer Nori (5), retomar onboarding (2), ayuda de primer uso (3) | 15 | 30 |
| D. Hábitos (núcleo) | Crear/editar (8), registro por tipo (8), claim/unclaim (8), XP adaptativo (5), rachas (5), calendario (8), archivar/borrar (5), modo vacaciones (5), categorías (2) | 54 | 108 |
| E. Mascota y progreso | Home (8), animaciones (3), barra de XP (3), level-up (5), trigger de evolución (3), reveal (5), assets de evolución 1 (5), evolución 2 (5), stats y decaimiento (5), cuidado (5), notificaciones (5), bandeja (3) | 55 | 110 |
| F. Economía y tienda | Monedas y compras (5), tienda (5), accesorios y armario (8), regalo (2), balance (3) | 23 | 46 |
| G. Perfil, logros y bucket list | Perfil y stats (5), logros (5), bucket list (5) | 15 | 30 |
| H. Social (demo con datos simulados) | Hub (5), feed (8), amigos (8), leaderboard (3), competencias (8), asistente (5), circles (5), rachas con amigos (3), privacidad (2) | 47 | 94 |
| I. Datos | Firestore y reglas (8), seed y reseteo de la cuenta demo (5) | 13 | 26 |
| J. Monetización (vista previa) | Pantalla Nori Plus (3) | 3 | 6 |
| K. QA y cierre | Pruebas automatizadas (8), QA manual (5), corrección de bugs (8), documentación y Demo Day (3) | 24 | 48 |
| **Total** | **65 historias** | **306** | **612** |

**Por qué 2 horas por punto y no 3.9.** El 3.9 del Release 0 fue la estimación a ciegas que la clase dice que se corrige con datos reales. Ahora hay un dato, impreciso: entre **300 y 600 h** en total (no medidas; el techo son unas 20 h por semana por persona durante las 15 semanas de historial de git), o **1 a 2 h por punto**. Usamos 2.0, el extremo alto, porque un cliente no tendría el contexto que el equipo ya tenía ni la ayuda de IA. **No cobramos US$15 × 48 h**: un precio de proyecto cubre también diseño, pruebas, documentación y riesgo.

**Comprobaciones de orden de magnitud:** el repositorio tiene unas 38,500 líneas (Dart, TypeScript de Cloud Functions y pruebas), o **63 líneas por hora** con 612 h, un ritmo creíble solo con IA (con las 1,196 h del Release 0 serían 32). Y 734 h con colchón, para dos personas a 100 h al mes, son unos 3.7 meses; el historial real (28 de julio a 8 de noviembre) son unos 3.5.

## 3. PERT de las tres historias más riesgosas

Fórmula: `(O + 4×P + Pe) ÷ 6`. Los escenarios son estimaciones retroactivas, no mediciones.

| Historia | Optimista | Probable | Pesimista | PERT |
|---|---:|---:|---:|---:|
| Claim/unclaim atómico en Cloud Function (XP, monedas, level-up, evolución) | 10 h | 15 h | 26 h | **16.0 h** |
| Calendario + historial con edición de días pasados | 11 h | 15 h | 28 h | **16.5 h** |
| Accesorios y armario con posición por etapa | 9 h | 14 h | 30 h | **15.8 h** |

Las tres caen cerca de las 16 h que da 2 h por punto para 8 puntos. La de accesorios es la más incierta: ajustar el arte en cada etapa tomó varias rondas de prueba visual.

## 4. Colchón de riesgo y sensibilidad

**20%** (la clase recomienda 15% a 25%): el equipo dominaba Flutter, pero Cloud Functions, las reglas de Firestore y el plan Blaze eran nuevos, y el alcance ya está cerrado. Con 306 puntos y US$15 por hora:

| Horas por punto | Horas | Con 20% de colchón | De dónde sale |
|---|---:|---:|---|
| 1.0 | 306 | US$5,508 | Extremo bajo de lo trabajado (300 h) |
| 1.5 | 459 | US$8,262 | Punto medio |
| **2.0** | **612** | **US$11,016** | **Extremo alto (600 h); el que usamos** |
| 3.9 | ≈1,196 | US$21,528 | Estimación a ciegas del Release 0 |

## 5. Comparación con el mercado

Para ver si US$11,000 es razonable buscamos precios de apps parecidas. **Casi todas las cifras vienen de agencias que venden desarrollo y tienden a ser altas**; no son cotizaciones para Nori.

| Referencia | Rango publicado |
|---|---|
| App de hábitos (MVP), guías de agencias 2026 | ≈ US$10,000 a US$27,000 |
| Caso publicado: MVP de hábitos y analítica | [US$10,000 en 11 días](https://mobidev.biz/case-studies/rapid-mvp-development-wellness-app) |
| App tipo Finch, [guía de costos](https://kitemetric.com/blogs/finch-app-cost-build-your-self-care-app) | solo diseño US$5,000 a US$20,000; total "decenas de miles" |
| Desarrolladores en Guatemala, [firma de desarrollo](https://devtechnosys.com/insights/cost-to-hire-developers-in-guatemala/) | Q115 a Q191 por hora (≈ US$15 a US$25) |
| Desarrolladores Flutter en Latinoamérica, [Flexiple](https://flexiple.com/cost-to-hire/flutter-developer) | US$25 a US$60 por hora |

Nuestra tarifa (Q115.50) es el piso de lo que se cobra en Guatemala, y US$11,000 queda en el extremo bajo del rango de una app de hábitos, lo esperable de un equipo de nivel inicial. Las mismas 734 h a US$25 darían US$18,360, y a US$40, US$29,376.

## 6. Cómo se cobra el desarrollo

**Precio fijo por hitos**, porque el alcance ya está cerrado:

| Hito | Entregable | % | Monto |
|---|---|---:|---:|
| Firma | Propuesta y SOW firmados | 30% | US$3,300 |
| Backend + datos | Auth, hábitos, XP y mascota conectados a Firestore | 25% | US$2,750 |
| QA | Suite de pruebas en CI y pasada de QA aprobada | 25% | US$2,750 |
| Entrega | APK de release, deploy y documentación | 20% | US$2,200 |

Todo lo que no esté en el backlog entra como *change request* a US$15/h con aprobación previa. Opcional: retainer de 10 h al mes (US$150) para correcciones y monitoreo. En el Ejercicio 1 planteamos cobro por valor; para cotizar usamos horas × tarifa porque es el método del módulo, y el cobro por valor sigue en la Parte 2.

## 7. Fases siguientes (fuera de esta cotización)

Los puntos son estimaciones retroactivas, a 2 h por punto.

| Fase | Contenido | Pts | Costo con 20% de colchón |
|---|---|---:|---:|
| **2. Google Play** | Google Play Billing para Plus y Duo (8), AdMob (5), límites del plan gratuito en el servidor (8: campo `plan`, funciones `createHabit` y `createBucketListItem`, reglas, restaurar hábitos archivados), paywall y mensajes de límite en la app (3), App Check con Play Integrity (5), ficha y publicación (5), Analytics (3), notificaciones push (5) | 42 | US$1,512 (84 h) |
| Backend social real | Amigos, feed con fotos, leaderboard, competencias, circles, rachas con amigos, reportes | 52 | US$1,872 (104 h) |
| **3. App Store (iOS)** | Configuración de iOS y firma (3), Sign in with Apple (3), compras con Apple (5), AdMob y push en iOS (5), pruebas en iPhone y TestFlight (5), ficha y revisión de la App Store (5) | 26 | US$936 (52 h) |

Queremos publicar también en iOS más adelante. Es más caro que Android (cuenta anual, comisión, revisión más estricta y trabajo extra). Apple suele exigir Sign in with Apple si la app ofrece inicio de sesión con Google; hay que verificarlo en developer.apple.com. Hace falta una Mac con Xcode (el equipo ya tiene) y, idealmente, un iPhone para probar.

## 8. Costos mensuales de operación (nube y otros)

Los paga quien opera la app, aparte de la cotización. Solo el gasto en Firebase/GCP crece con los usuarios.

**Hoy: US$0 al mes** (revisión del 26 de octubre). El proyecto `nori-pet` está en el plan Blaze con un pico de ≈1,200 lecturas de Firestore por día (el nivel gratuito permite 50,000). Lo único que cuesta es Artifact Registry, un centavo al mes o menos.

**Con usuarios reales** (supuestos nuestros, no medidos: 30% de los usuarios entra cada día, ≈200 lecturas, ≈30 escrituras y ≈10 invocaciones de funciones por usuario activo al día; lecturas de Firestore a US$0.06 por 100,000, la cifra más alta que encontramos, y escrituras a US$0.18):

| Usuarios al mes | Lecturas por día | Escrituras por día | Firebase/GCP al mes |
|---:|---:|---:|---:|
| 1,000 | ≈64,000 | ≈9,000 | **≈ US$0.25** |
| 5,000 | ≈320,000 | ≈45,000 | **≈ US$6** |
| 10,000 | ≈640,000 | ≈90,000 | **≈ US$14** |
| 50,000 | ≈3,200,000 | ≈450,000 | **≈ US$80** |

Cloud Functions y Cloud Scheduler quedan dentro del nivel gratuito. Las fuentes difieren en el precio de las lecturas (US$0.03 contra US$0.06), así que hay que confirmarlo en la [página de Firebase](https://firebase.google.com/pricing) antes de lanzar.

**`petCareCheck`** (la función que revisa a todas las mascotas y crea el aviso "tu mascota te necesita") es la única partida que crece sola. **La pasamos de cada hora a cada 6 horas** (24 → 4 lecturas por cuenta al día): el aviso es una entrada dentro de la app y una barra tarda unas 70 horas en bajar de 100 a 30, así que revisar cada hora no aportaba nada. El cambio está en el código; **la función en producción sigue corriendo cada hora hasta que se despliegue**. Sin él, la tabla de arriba costaría ≈ US$0.61, US$8, US$18 y US$98. Aun así, lee todas las mascotas creadas, también las abandonadas; la corrección de fondo (consultar solo las atendidas recientemente, con un índice sobre `lastDecayAt`) queda para después de la presentación.

**Control de gasto** (revisado en vivo el 8 de noviembre):

| Control | Estado |
|---|---|
| Presupuesto de alerta de US$5 al mes (50%, 90%, 100%) | Activo |
| Presupuesto de alerta temprana de US$1 al mes (50% gastado, o proyección a pasar de US$1); agregado el 8 de noviembre | Activo |
| Topes de gasto por servicio: Cloud Run Functions US$5; Cloud Run, Gemini API y Vertex AI US$1 | Configurados, ninguno aplicado |
| `maxInstances: 10` en las funciones | Activo |

Los topes de Firebase no son duros (el reporte de uso tarda minutos y eso se cobra), y **Firestore y Authentication no admiten tope**, solo alertas. El riesgo que queda es que un error o una app falsa genere lecturas sin freno. Para eso: las alertas, subir el presupuesto de US$1 a medida que crezcan los usuarios y **App Check antes de lanzar** (Fase 2). No usamos un interruptor que desactive la facturación al pasar un límite, porque apagaría el proyecto completo, datos de usuarios incluidos.

**Otros costos:**

| Concepto | Costo |
|---|---|
| Cuenta de Google Play | US$25, una sola vez |
| **Cuenta de Apple Developer (Fase 3)** | **US$99 al año** |
| Comisión de Google Play sobre suscripciones | 15% (ya descontada en la Parte 2) |
| **Comisión de Apple** | 15% con el Small Business Program (bajo US$1M al año; hay que inscribirse cada año), 30% sin él; verificar en developer.apple.com |
| Dominio para la política de privacidad (opcional) | ≈ US$12 al año |
| Impuestos en Guatemala (IVA 12%, ISR) | Pendiente: dependen del régimen con el que facture el equipo |
| Soporte y mantenimiento | Tiempo del equipo, no incluido en las proyecciones |

La App Store sale más cara que Google Play: la cuenta cuesta cuatro veces más y se paga cada año, suma 52 h de trabajo y su revisión es más estricta. Las proyecciones de la Parte 2 cubren solo Android.

---

# Parte 2 — Modelo de cobro al usuario

**Freemium con anuncios y tres planes.** Nori es completo sin pagar: el loop principal (hábitos → XP y monedas → cuidar y evolucionar la mascota) nunca queda detrás de un pago, y **todo lo social es gratis para todos**. Los anuncios generan ingresos con quienes no pagan, y los planes de pago quitan los anuncios y suman comodidad y cosméticos.

| | **Gratis** | **Nori Plus** | **Nori Duo** |
|---|---|---|---|
| Mensual | US$0 | **US$3.99** (≈Q31) | **US$5.99** (≈Q46) |
| Anual | US$0 | **US$29.99** (≈Q231) | **US$44.99** (≈Q346) |
| Para quién | Cualquiera | Una persona | Dos personas, una sola factura |

## Los tres planes

**Gratis**
- Los 5 tipos de hábito, rachas, calendario y XP adaptativo.
- Mascota, evoluciones, cuidado y tienda con monedas del juego; modo vacaciones; logros; estadísticas básicas.
- **Hasta 5 hábitos activos y 3 metas de bucket list.**
- **Todo lo social:** amigos, feed, leaderboard de amigos, circles, competencias, rachas con amigos y visitar mascotas.
- Anuncios: banner pequeño en pantallas secundarias y recompensados opcionales (máximo 3 al día).

**Nori Plus** (US$3.99 al mes o US$29.99 al año, 37% menos que pagar los doce meses). Todo lo gratuito, y además:
- **Sin anuncios.**
- **Hábitos y metas de bucket list ilimitados.**
- Bono diario de monedas (equivale a lo que darían los anuncios recompensados).
- Un accesorio exclusivo nuevo cada mes.
- Estadísticas avanzadas (tendencias por hábito y por categoría) y temas de color.
- Acceso anticipado a mascotas nuevas (huevos), cuando existan.

**Nori Duo** (US$5.99 al mes o US$44.99 al año). Todo lo de Plus para **dos cuentas vinculadas** con una sola factura, 25% más barato que dos Plus (US$7.98 al mes). Pensado para parejas, amigos, compañeros de cuarto o hermanos. Idea sin definir: un par de accesorios a juego exclusivo de Duo.

**Cómo decidimos qué es gratis.**
- Nada que proteja al usuario se cobra (modo vacaciones, rachas, cuidado básico): volver a la app nunca debe sentirse como un castigo.
- El límite es de **5 hábitos, no 3**: la economía está balanceada para unos 5, con los que la mascota llega a la primera evolución en unas dos semanas. Con 3, el usuario gratuito avanzaría más lento y sentiría el juego roto, no limitado.
- Lo social es gratis porque su valor depende de que haya gente. Plus y Duo venden comodidad y estética, no ventaja: no hay leaderboards globales, así que pagar no le quita nada a nadie.

Hoy el tab Social funciona con datos simulados; esto describe cómo se cobraría cuando exista el backend social.

## Por qué estos precios

| App | Modelo | Precio |
|---|---|---|
| Habitica | Freemium + suscripción | US$4.99/mes · US$47.99/año |
| Finch | Freemium + suscripción | US$9.99/mes · US$69.99/año |
| **Nori Plus (propuesta)** | Freemium + anuncios + suscripción | **US$3.99/mes · US$29.99/año** |

Nuestro primer mercado es Guatemala, en Android, con estudiantes y jóvenes profesionales: un público más sensible al precio que el de Finch o Habitica en EE. UU., y Nori es una marca nueva. Por eso salimos por debajo de los dos. El descuento anual es fuerte a propósito: quien paga el año sigue usando la app. Google Play permite fijar precios en quetzales. Las pantallas Nori Plus y de pago de la app ya muestran estos planes (vista previa).

## Anuncios y cosméticos

| Formato | Dónde | Regla |
|---|---|---|
| **Recompensado (opcional)** | Tienda y cuidado de la mascota | Anuncio a cambio de monedas o un ítem de cuidado. Máximo 3 al día, para que no reemplace a los hábitos como fuente de monedas |
| **Banner pequeño** | Tienda, calendario y logros | Nunca en Home, al registrar un hábito ni en las celebraciones de level-up o evolución |
| **Intersticial** | — | No los usamos: interrumpen justo cuando el usuario termina un hábito |

Los anuncios no son la fuente principal de ingresos: generan algo con quien no paga y le dan una razón para pasarse a Plus. Además, la categoría Premium de la tienda puede vender accesorios exclusivos sueltos (US$0.99 a US$1.99). **No vendemos monedas**: se ganan con hábitos, y comprarlas rompería el loop principal.

## Proyección de ingresos

**No tenemos datos de usuarios**, así que esto es un ejercicio con supuestos nuestros, no una predicción. Mostramos tres escenarios porque lo que más cambia el resultado es cuánta gente usa la app. Supuestos comunes (INFERIDOS, para validar tras el lanzamiento):
- 60% de los suscriptores paga anual y 40% mensual (promedio US$3.10 al mes); Google se queda con 15%. Duo se cuenta como Plus.
- 30% de los usuarios gratuitos entra cada día; 40% de ellos ve 2 anuncios recompensados y todos ven 3 banners.
- eCPM de US$2 en recompensados y US$0.30 en banners. No encontramos un dato de Guatemala; las fuentes dicen que Latinoamérica paga entre 4 y 5 veces menos que Norteamérica, y el número real solo se ve en el panel de AdMob.
- 1% de los usuarios compra un cosmético de US$1.99 al mes.
- Costos: Firebase/GCP de la sección 8 más ≈US$1 al mes de dominio. No se cuenta el tiempo del equipo. Solo Android.

| Escenario | Usuarios al mes | Pagan Plus | Suscripciones | Anuncios | Cosméticos | Costos | **Neto al mes** | Recupera US$11,016 en |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Conservador | 1,000 | 2% | US$53 | US$22 | US$17 | −US$1 | **US$90** | 122 meses |
| Base | 5,000 | 3% | US$395 | US$109 | US$85 | −US$7 | **US$581** | 19 meses |
| Optimista | 10,000 | 4% | US$1,052 | US$216 | US$169 | −US$15 | **US$1,422** | 8 meses |

Las suscripciones son entre 57% y 73% de los ingresos, así que la palanca más fuerte es la conversión a Plus y el tamaño de la base de usuarios, no los anuncios. Los costos de nube son menos del 2% de los ingresos: no son el riesgo del negocio. Recuperar el precio cotizado es razonable con unos 5,000 usuarios al mes y poco probable con 1,000. Para el equipo, que lo construyó como proyecto de curso, el costo real fue su tiempo.

## Pendiente de decidir

- Las pantallas Nori Plus y de pago ya muestran los planes, pero son una vista previa: los límites del plan gratuito, los pagos y los anuncios no están implementados (Fase 2).
- Cantidades exactas del bono diario de Plus y de la recompensa por anuncio (próximo pase de balance de la economía).
- Duo y los beneficios sociales dependen del backend social, que no es parte del MVP. Cuándo lanzar en iOS y si conviene el Small Business Program de Apple.

---

*Fuentes de precios de la competencia: [Habitica en el App Store](https://apps.apple.com/br/app/id994882113), [precios de Finch (Recurdash)](https://recurdash.com/subscription-pricing/finch). Referencia de eCPM en Latinoamérica: [Playio, benchmarks 2026](https://blog.playio.co/mobile-game-ecpm-benchmarks-2026). Apple: [cuota de Apple Developer](https://magora-systems.com/apple-developer-fee/) y [Small Business Program](https://magora-systems.com/app-store-small-business-program/).*
