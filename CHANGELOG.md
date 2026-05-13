# 📝 CHANGELOG - ARGOS Mobile

Todos los cambios notables en este proyecto serán documentados en este archivo.


---

## [2.16.6] - 2026-05-13
### 🔄 Sincronización y Flujo de Actualización
- **📡 Robustecimiento OTA**: Corregido el flujo de actualización automática. Ahora el sistema asegura que la base de datos de Supabase y el APK descargable estén siempre en sincronía total con la última compilación.
- **🛠️ Fix de Versión**: Solucionado el problema donde se notificaba una versión superior a la instalada pero el APK descargado seguía siendo antiguo.
- **✨ Consistencia Visual**: Actualizada la información de la aplicación para reflejar la versión real de compilación.

---

## [2.16.1] - 2026-02-25
### 🎨 Refinamiento Estético Final
- **🔡 Consistencia Roboto**: Re-habilitada la tipografía `Roboto` de forma explícita para asegurar un renderizado limpio y profesional en todos los dispositivos.
- **✨ Ajuste de Peso Visual**: Se redujeron los pesos de texto extremos (`w900` ➔ `w800`) y el espaciado excesivo en títulos y botones para evitar el aspecto "pixelado" en modo claro.
- **🌓 Contraste en Modo Claro**: Reforzados los tonos rojos en el diálogo de acompañamiento para garantizar una lectura perfecta sobre el fondo de cristal sólido.

---

## [2.16.0] - 2026-02-25
### 🛡️ Seguridad y Optimización Visual
- **🚀 Cierre Inmediato**: Eliminado el efecto de salida en los diálogos de alerta y acompañamiento para una respuesta táctil instantánea tras la confirmación.
- **🔡 Tipografía Nativa**: Unificada la fuente de toda la aplicación al estándar del sistema (nativo), eliminando inconsistencias en pantallas como "Lugares Securos".
- **🔒 Bloqueo Airtight de SOS**: Reforzado el sistema anti-spam de alertas en segundo plano; ahora se bloquea cualquier re-invocación redundante si ya existe una alerta activa, evitando la acumulación visual de pantallas.
- **🏠 Automatización de Lugares**: Radio automático de 200m y notificaciones dinámicas al círculo.
### 🏠 Automatización de Lugares
- **🎯 Radio Inteligente**: Eliminado el selector manual de radio; ahora se asigna automáticamente **200 metros**, optimizando el geofencing para entornos urbanos.
- **🔔 Notificaciones al Círculo**: Al registrar un nuevo lugar, todos los miembros del círculo de confianza reciben una notificación instantánea con el nombre del miembro y el lugar añadido.
- **⚡ Flujo Simplificado**: Registro de lugares más rápido y eficiente, permitiendo al usuario enfocarse solo en nombrar sus zonas seguras.

---

## [2.15.8] - 2026-02-25
### 💎 Pulido de Interfaz y Rastreo 🛰️
- **🌓 Contraste Premium**: Ajustada la opacidad del cristal en el diálogo "Modo Travesía" (de 5% a 80%) para una legibilidad perfecta en Modo Claro.
- **✨ Detalles de Cristal**: Añadido borde brillante (rim light) al diálogo en Modo Claro para mejorar la profundidad y el aspecto premium.
- **⚡ Frecuencia de 5 Segundos**: Optimizado el intervalo de rastreo de 10s a 5s durante el "Modo Travesía" para una experiencia de tiempo real absoluta.
- **🔄 Sincronización Total**: Corregido bug donde el estado de acompañamiento no se sincronizaba con la base de datos al iniciar una ruta.
### 🛰️ Rastreo en Tiempo Real (Círculo Familiar)
- **⚡ Frecuencia de 5 Segundos**: Optimizado el intervalo de rastreo de 10s a 5s durante el "Modo Travesía" para una experiencia de tiempo real absoluta.
- **🔄 Sincronización Total**: Corregido bug donde el estado de acompañamiento no se sincronizaba con la base de datos al iniciar una ruta.
- **🏁 Gestión de Viaje**: Añadido botón "Finalizar Recorrido" en la pantalla de rutas para detener el rastreo de alta frecuencia manualmente.
- **🛰️ Precisión Dinámica**: Ahora el sistema utiliza `LocationAccuracy.high` automáticamente cuando el usuario está en un trayecto protegido.

---

## [2.15.6] - 2026-02-25
### 💎 Experiencia Premium y Transiciones
- **🎬 Transiciones Cinematográficas**: El sistema SOS ahora emerge con un efecto de "Zoom Aero" desde el centro de la pantalla, eliminando la navegación estándar.
- **🧊 Liquid Glass 2.5**: Rediseño total del diálogo de "Modo Travesía" con mayor profundidad, desenfoque de cristal (15px) y bordes reactivos.
- **🔆 Optimización de Contraste**: El modo claro ahora utiliza tokens de contraste dinámico para garantizar la legibilidad en exteriores sin sacrificar la estética de vidrio.
- **✨ Micro-animaciones**: Añadido feedback visual fluido al activar servicios de rastreo.

---

## [2.15.5] - 2026-02-25
### 🛡️ SOS Atómico y Bloqueo Inteligente
- **🚫 Bloqueo Estricto**: Ahora es imposible enviar una segunda alerta SOS hasta que la actual sea clasificada o cancelada, garantizando un solo registro por incidente.
- **⚡ Cooldown Dinámico**: Al clasificar un incidente o marcarlo como falsa alarma, el cooldown se elimina instantáneamente, permitiendo re-activar la protección sin esperas.
- **🧵 Sync de Isolates**: Implementada comunicación bidireccional entre UI y Background para resetear la memoria del Isolate en tiempo real.

---

## [2.15.4] - 2026-02-25
### 🎨 Pulido Estético y Mantenimiento
- **💅 Refinamiento en Rutas**: Mejorado el contraste y la visibilidad del diálogo de "Modo Travesía" en modo claro (Light Mode).
- **🧹 Limpieza de Repositorio**: Depuración de etiquetas de versiones antiguas para mantener un historial de Releases limpio en GitHub.
- **✨ UX mejorada**: Ajuste en las transparencias y bordes del sistema Liquid Glass para una experiencia más premium en condiciones de alta luminosidad.

---

## [2.15.3] - 2026-02-25
### 🛡️ Estabilidad y Sincronización SOS
- **🧵 Gestión de Memoria**: Corregido bug de múltiples listeners; ahora las suscripciones de alerta se limpian al salir de la app o cerrar sesión.
- **🧭 Navegación Segura**: Rediseñado el check de duplicados de pantalla para evitar interferencias con el Navigator.
- **🔄 Sync de Sesión Isolate**: Implementado re-intento de lectura de sesión en el servicio de fondo para evitar fallos por latencia de persistencia.
- **🧹 Limpieza Post-Logout**: Ahora se borran los IDs de alertas pendientes al cerrar sesión para evitar colisiones entre cuentas.

---

## [2.15.2] - 2026-02-25
### 🛡️ Refuerzo de Identidad y SOS
- **🔐 Autenticación Mandatoria**: El sistema SOS ahora verifica la sesión activa antes de procesar cualquier alerta.
- **🔄 Recuperación de Pantalla**: Si existe una alerta pendiente sin clasificar, el sistema forzará la reaparición de la pantalla de confirmación al detectar movimiento (Shake).
- **🛑 Logout Seguro**: El servicio de protección de fondo se detiene automáticamente al cerrar sesión para garantizar la privacidad.
- **🐛 Bugfix**: Corregido problema donde la app quedaba bloqueada si la pantalla de alerta se cerraba accidentalmente.

## [2.15.1] - 2026-02-24
### ✨ Refinamientos de Seguridad y UI
- **🛡️ SOS Blindado**: Implementación de `PopScope` en `AlertConfirmationScreen` e `IncidentClassificationScreen`. La navegación hacia atrás está bloqueada hasta completar la acción.
- **🚫 Clasificación Obligatoria**: Se eliminó el botón "Omitir" en la clasificación de incidentes para asegurar que cada alerta SOS genere datos útiles para la comunidad.
- **🔒 Anti-Spam de Fondo**: Candado de concurrencia en `BackgroundService` para evitar que múltiples falsos positivos generen cascadas de notificaciones.
- **🎨 Contraste Premium (Modo Claro)**:
  - Mejorada la visibilidad de "ESTADO: PROTEGIDO" en el perfil usando `emeraldGreen`.
  - Mejorada la visibilidad de "MODO TRAVESÍA ACTIVO" en rutas usando `argosRed`.
  - Ajustada la definición de `GlassBox` para fondos claros.

## [2.14.8] - 2026-02-15
### 🎨 Rediseño "Liquid Glass v2"
- Introducción de bordes dinámicos y auroras ambientales.
- Optimización de la navegación táctica en el mapa de Santuarios.

## [2.9.0] - 2026-01-20
### 🚀 Automatización OTA
- Sistema "Seamless OTA" integrado con Supabase y OneSignal.
- Primera implementación de detección de riesgos por sensores de alta fidelidad.

---
*Mantenido por Luis Shagñay. 🛡️*
