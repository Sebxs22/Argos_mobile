# 🛡️ ARGOS - Inteligencia Proactiva en Seguridad Personal

[![Estado de Compilación](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml/badge.svg)](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml)
[![Versión](https://img.shields.io/badge/Versi%C3%B3n-2.9.0-E53935.svg)](https://github.com/Sebxs22/Argos_mobile/releases/latest)
[![Propietario](https://img.shields.io/badge/Propiedad-Privada-red.svg)](#-aviso-legal-y-propiedad-intelectual)

**ARGOS** es un ecosistema de seguridad móvil de alto rendimiento que redefine la protección personal mediante detección inteligente de riesgos y redes de respuesta inmediata. Diseñado con una estética **Glassmorphism Premium**, ofrece una experiencia de usuario fluida y sofisticada.

---

## 🚀 Zaz Flow: Automatización Total (v2.9.0)

ARGOS incorpora un sistema de actualización **Seamless OTA** totalmente autónomo. 
- **Detección en Tiempo Real**: La app sincroniza versiones mediante Supabase Streams.
- **Broadcast Inteligente**: Cualquier actualización detectada en la nube dispara automáticamente una notificación Push global para todos los usuarios.

[📥 **DESCARGAR ÚLTIMA VERSIÓN (APK OFICIAL)**](https://github.com/Sebxs22/Argos_mobile/releases/latest/download/app-release.apk)

---

## ⚡ Innovaciones Vanguardistas

### 👁️ El Ojo Guardián 24/7
Sensores de alta fidelidad que analizan patrones de riesgo. El sistema es capaz de mantener la protección incluso con la pantalla bloqueada o en segundo plano, optimizando el consumo de batería.

### 👪 Círculo de Guardianes
Tu red de seguridad humana. Vincula a tus contactos para que reciban alertas SOS con geolocalización exacta en menos de 2 segundos.

### 🛡️ Santuarios Automáticos (Powered by OSM)
**Nuevo en v2.8.8**: El mapa ahora escanea dinámicamente tu entorno usando la **Overpass API**. Encuentra estaciones de policía, hospitales y refugios reales en cualquier ciudad del mundo, sin listas precargadas.

---

## 🏗️ Arquitectura Técnica

- **Framework**: Flutter 3.x (Dart) - Arquitectura Atómica y escalable.
- **Backend**: Supabase Realtime - Sincronización de milisegundos.
- **Push Engine**: OneSignal REST API - Entrega crítica priorizada.
- **Motor de Mapas**: Flutter Map + Overpass API + OSRM.
- **Design System**: Liquid Glass UI - Estética premium con rendimiento optimizado.

---

## ⚠️ Aviso Legal y Propiedad Intelectual

> [!CAUTION]
> **CÓDIGO PÚBLICO ≠ CÓDIGO ABIERTO (OPEN SOURCE)**
> 
> Este repositorio es de visibilidad pública exclusivamente para fines de demostración de portafolio y revisión académica. **No posee ninguna licencia de uso libre.**
> 
> - **Todos los Derechos Reservados**: Luis Shagñay (Sebxs22) retiene la propiedad total y exclusiva de este software.
> - **Prohibida la Reproducción**: Queda estrictamente prohibido el uso, copia, modificación, fusión, publicación o distribución de este código sin un permiso previo y por escrito del autor.
>
> *Cualquier infracción a estos términos será tratada bajo las leyes de propiedad intelectual vigentes.*

---

## 🛠️ Configuración de Desarrollo

Es obligatorio contar con un archivo `.env` configurado en la raíz:

```env
SUPABASE_URL=tu_url
SUPABASE_ANON_KEY=tu_anon_key
ONESIGNAL_APP_ID=uuid
ONESIGNAL_REST_API_KEY=api_key
```

### Comandos de inicio:
```bash
flutter pub get
flutter run --release
```

---
*Desarrollado con precisión técnica por Luis Shagñay. 🛡️*
