# 🛡️ ARGOS - Seguridad Inteligente Movil

[![Build & Release APK](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml/badge.svg)](https://github.com/Sebxs22/Argos_mobile/actions/workflows/release.yml)

**ARGOS** es una plataforma de seguridad personal avanzada diseñada para proteger a los usuarios en situaciones críticas mediante tecnología de detección proactiva y redes de confianza. 

---

## 🚀 Zaz Flow (Descarga Directa)

¿Quieres probar la última versión ahora mismo? No necesitas compilar nada.

[👉 **DESCARGAR ÚLTIMA VERSIÓN (APK)**](https://github.com/Sebxs22/Argos_mobile/releases/latest/download/app-release.apk)

*Nota: Una vez instalada, la app te avisará automáticamente cuando haya nuevas actualizaciones disponibles gracias a nuestro sistema Seamless OTA.*

---

## ✨ Características Principales

### 👁️ Ojo Guardián
Sistema inteligente de detección de caídas y emergencias basado en sensores inerciales del dispositivo. Activa una cuenta regresiva automática antes de alertar a tu círculo de confianza.

### 👥 Círculo de Confianza
Gestión de guardianes y protegidos. Vincula a tus familiares y amigos mediante códigos únicos para que reciban notificaciones en tiempo real si te encuentras en peligro.

### 📍 Santuarios y Rutas Seguras
Visualización de zonas seguras ("Santuarios") en el mapa y cálculo de rutas protegidas para minimizar riesgos en tus trayectos diarios.

### 🆘 Alertas Críticas
Sistema de notificaciones push de alta prioridad que funcionan incluso en segundo plano, enviando tu ubicación exacta y estado actual a tus guardianes.

---

## 🛠️ Stack Tecnológico

- **Frontend**: [Flutter](https://flutter.dev/) (Dart) - UI Moderna con Glassmorphism.
- **Backend / DB**: [Supabase](https://supabase.com/) - Autenticación y base de datos en tiempo real.
- **Notificaciones**: [OneSignal](https://onesignal.com/) - Infraestructura de mensajería push a escala.
- **CI/CD**: [GitHub Actions](https://github.com/features/actions) - Compilación y despliegue automatizado.
- **Mapas**: [Flutter Map](https://pub.dev/packages/flutter_map) + OpenStreetMap.

---

## ⚙️ Configuración del Entorno

Si eres desarrollador y quieres replicar el entorno, necesitas un archivo `.env` en la raíz con las siguientes claves:

```env
SUPABASE_URL=tu_url_de_supabase
SUPABASE_ANON_KEY=tu_clave_anon
ONESIGNAL_APP_ID=tu_id_de_app
ONESIGNAL_REST_API_KEY=tu_clave_rest_api
```

### Comandos útiles:
```bash
# Obtener dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Generar versión de producción
flutter build apk --release
```

---

## 🤖 Automatización (CI/CD)

Este repositorio utiliza **GitHub Actions** para:
1. Validar la integridad del código en cada commit.
2. Compilar automáticamente el APK en la nube.
3. Publicar versiones automáticas bajo el tag `latest` para el sistema de actualizaciones OTA.

---

## 📄 Licencia

Este proyecto es parte de un desarrollo académico y profesional por **[Sebxs22]**. Todos los derechos reservados.

---
*Desarrollado con ❤️ para un mundo más seguro.*
