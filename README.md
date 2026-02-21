# 🛡️ ARGOS - Inteligencia Proactiva en Seguridad Personal

[![Estado de Compilación](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml/badge.svg)](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml)
[![Versión](https://img.shields.io/badge/Versi%C3%B3n-1.0.0-E53935.svg)](https://github.com/Sebxs22/Argos_mobile/releases/latest)
[![Propietario](https://img.shields.io/badge/Propiedad-Privada-red.svg)](#-aviso-legal-y-propiedad-intelectual)

**ARGOS** es un ecosistema de seguridad móvil de alto rendimiento que redefine la protección personal mediante detección inteligente de riesgos y redes de respuesta inmediata. Diseñado con una estética **Glassmorphism Premium**, ofrece una experiencia de usuario fluida y sofisticada.

---

## 🚀 Zaz Flow: Actualización Continua

ARGOS incorpora un sistema de actualización **Seamless OTA**. No necesitas entrar a una tienda de aplicaciones para estar protegido con lo último.

[📥 **DESCARGAR ÚLTIMA VERSIÓN (APK OFICIAL)**](https://github.com/Sebxs22/Argos_mobile/releases/latest/download/app-release.apk)

> [!TIP]
> **Instalación Inteligente**: Una vez instalada, la app detectará automáticamente futuros cambios en el código y te notificará para actualizar al instante.

---

## ⚡ Innovaciones de ARGOS

### 👁️ El Ojo Guardián
Algoritmos avanzados que analizan los sensores del dispositivo para detectar caídas bruscas o comportamientos inusuales. En caso de riesgo, activa un protocolo de emergencia con cuenta regresiva.

### 👪 Círculo de Confianza
Tu red de seguridad humana. Vincula a tus "Guardianes" para que reciban tu ubicación, nivel de batería y alertas críticas en tiempo real, incluso con la app cerrada.

### 🗺️ Rutas y Santuarios
Mapa interactivo con zonas de refugio ("Santuarios") y trazado de rutas seguras basadas en niveles de riesgo locales.

### 🔔 Notificaciones de Alta Prioridad
Infraestructura de mensajería crítica que garantiza la entrega de alertas en menos de 2 segundos a todos tus contactos de emergencia.

---

## 🏗️ Arquitectura Técnica

- **Framework**: Flutter 3.x (Dart) - Arquitectura limpia y escalable.
- **Data Core**: Supabase Realtime - Sincronización instantánea de estados de emergencia.
- **Push Engine**: OneSignal REST API - Entrega garantizada de alertas críticas.
- **Automación**: GitHub Actions (CI/CD) - Compilación en la nube y sincronización automática de versiones.
- **Design System**: Glassmorphism UI - Una interfaz que se siente viva, premium y moderna.

---

## ⚠️ Aviso Legal y Propiedad Intelectual

> [!CAUTION]
> **CÓDIGO PÚBLICO ≠ CÓDIGO ABIERTO (OPEN SOURCE)**
> 
> Este repositorio es de visibilidad pública exclusivamente para fines de demostración de portafolio y revisión académica. **No posee ninguna licencia de uso libre.**
> 
> - **Todos los Derechos Reservados**: Luis Shagñay (Sebxs22) retiene la propiedad total y exclusiva de este software.
> - **Prohibida la Reproducción**: Queda estrictamente prohibido el uso, copia, modificación, fusión, publicación o distribución de este código sin un permiso previo y por escrito del autor.
> - **Uso Educativo Únicamente**: La visualización de este código no otorga ningún derecho de explotación comercial ni personal.
>
> *Cualquier infracción a estos términos será tratada bajo las leyes de propiedad intelectual vigentes.*

---

## 🛠️ Configuración de Desarrollo

Para replicar el entorno de desarrollo, es obligatorio contar con un archivo `.env` configurado:

```env
SUPABASE_URL=argos_project_url
SUPABASE_ANON_KEY=tu_clave_anon_secreta
ONESIGNAL_APP_ID=uuid_de_onesignal
ONESIGNAL_REST_API_KEY=key_de_comunicacion_push
```

### Ejecución rápida:
```bash
flutter pub get
flutter run --release
```

---
*Desarrollado con precisión técnica por Luis Shagñay. 🛡️*
