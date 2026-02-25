# 📝 CHANGELOG - ARGOS Mobile

Todos los cambios notables en este proyecto serán documentados en este archivo.

---

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
