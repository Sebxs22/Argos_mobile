# 🛡️ ARGOS: Manual de Arquitectura y Sistema de Seguridad (v2.16.6)

> [!IMPORTANT]
> Este documento es la "Fuente de Verdad" técnica de ARGOS. Explica no solo el **cómo**, sino el **por qué** detrás de cada decisión de ingeniería, desde la detección de sensores hasta el renderizado de vidrio líquido.

---

## 🏗️ 1. Filosofía de Arquitectura: "Atomic Features"

ARGOS no es una app monolítica. Se divide en **Silos de Responsabilidad** para garantizar que un fallo en el mapa no detenga la protección del "Ojo Guardián".

### 📂 Estructura de Directorios Detallada

| Carpeta                       | Rol Técnico               | Componentes Clave                                          |
| :---------------------------- | :------------------------ | :--------------------------------------------------------- |
| `lib/core/`                   | **El Núcleo Atmosférico** | Red, Temas, UI Modular (`GlassBox`), Utilidades.           |
| `lib/features/auth/`          | **Identidad y Seguridad** | Registro, Login, Gestión de Permisos Críticos.             |
| `lib/features/eye_guardian/`  | **El Centinela (24/7)**   | Acelerómetro, Isolate de Fondo, Lógica de Alertas.         |
| `lib/features/family_circle/` | **Red Social de Auxilio** | Gestión de Guardianes, Mapas de Miembros, API del Círculo. |
| `lib/features/routes/`        | **Navegación Táctica**    | Motor OSRM, Zonas de Peligro, Búsqueda OSM.                |

---

## ⚡ 2. El Ecosistema de Alerta SOS (Deep Dive)

El sistema de alerta es una coreografía perfecta entre hardware y nube.

### 🔄 Protocolo de Seguridad Blindado (v2.15.1)
En la versión 2.15.1, el protocolo SOS se ha reforzado con **Navigation Locks**:
- **PopScope Blocking**: Las pantallas `AlertConfirmationScreen` e `IncidentClassificationScreen` ahora bloquean el botón físico/gestual de retroceso. El usuario **debe** clasificar el incidente o cancelar la alerta explícitamente.
- **Mandatory Classification**: Se eliminó la opción de "Omitir" en la clasificación de incidentes para forzar la recolección de datos que alimentan las zonas de peligro comunitarias.

### 🔄 Diagrama de Flujo de Datos Vitales

```mermaid
graph TB
    subgraph "Nivel Dispositivo (Capa 0)"
        Sensor[("Acelerómetro<br/>sensors_plus")]
        BG["🛡️ Background Service<br/>(onStart Isolate)"]
        Sensor -- "Streams de 60Hz" --> BG
    end

    subgraph "Capa de Decisión (Capa 1)"
        Logic{"¿Es SOS Real?"}
        AntiSpam["Candado de Concurrencia<br/>(_isProcessingAlert)"]
        BG -- "Magnitud Vectorial" --> Logic
        Logic -- "Si (Acc > 15.0)" --> AntiSpam
        AntiSpam -- "Lock: True" --> Proto["Protocolo SOS"]
        Logic -- "No (Acc > 12.0)" --> Track["Rastreo Proactivo"]
    end

    subgraph "Nube Argos (Capa 2)"
        Supa[("Supabase DB")]
        OneS[("OneSignal API")]
        Proto -- "Insert Alerta" --> Supa
        Proto -- "HTTP POST" --> OneS
    end

    subgraph "Respuesta (Capa 3)"
        OneS -- "Push High Priority" --> G1["Guardian 1"]
        OneS -- "Push High Priority" --> G2["Guardian 2"]
        Supa -- "Real-time Stream" --> MapView["Mapa de Guardianes"]
    end

    classDef hardware fill:#1e293b,stroke:#334155,color:#fff;
    classDef logic fill:#0369a1,stroke:#0ea5e9,color:#fff;
    classDef cloud fill:#7c2d12,stroke:#ea580c,color:#fff;
    
    class Sensor,BG hardware;
    class Logic,AntiSpam,Proto,Track logic;
    class Supa,OneS,G1,G2,MapView cloud;
```

---

## ✨ 3. Sistema de Diseño: "Liquid Glass v2"

Nuestra UI no es solo estética; es **funcionalidad emocional**. El uso de `Glassmorphism` reduce la carga cognitiva al mantener el contexto visual del fondo.

### 🎨 Optimización de Visibilidad (v2.15.1)
Se han ajustado los tokens de diseño para garantizar accesibilidad en **Modo Claro**:
- **Contrast enhancement**: El texto "ESTADO: PROTEGIDO" y "MODO TRAVESÍA" ahora utilizan `emeraldGreen` y `argosRed` respectivamente para destacar sobre fondos claros.
- **Glass Definition**: Se incrementó la opacidad (`0.12`) y el contraste del borde en `GlassBox` cuando se detecta `Brightness.light`.

---

## 📡 4. Integraciones y Servicios Externos

### 🗄️ Supabase (BaaS)
- **Realtime**: Habilitado en las tablas `perfiles` y `alertas`.
- **Anti-Spam Logic**: El servicio de fondo ahora utiliza un timestamp persistente para imponer un cooldown de 3 minutos entre alertas SOS automáticas.

### 🗺️ Motor de Mapas y Rutas
1. **OSRM (Open Source Routing Machine)**: Calculamos la ruta más rápida.
2. **Análisis de Capas**: Si la ruta pasa por una `Danger Zone`, el sistema resta puntos al `Safety Score`.

---

## 🛠️ 5. Guía de Mantenimiento y Evolución

### Cómo añadir una nueva "Feature"
1. Crea una carpeta en `lib/features/nombre_feature`.
2. Define el estado en esa feature.
3. Si requiere comunicación con la nube, añade los métodos a `ApiService`.

### Consideraciones de Rendimiento
- **Concurrency Control**: Siempre usa flags booleanos (`_isProcessingAlert`) en los Isolates de fondo para evitar carreras de datos (Race Conditions).

---

### 🚀 Despliegue y Versión
- **Versión Actual**: 2.16.6+125
- **Build**: Siempre usar `--split-per-abi` para minimizar el tamaño del APK descargado vía OTA.

```bash
# Versión Actual: 2.15.1+110
# 1. Limpieza
flutter clean
# 2. Obtener dependencias
flutter pub get
# 3. Build para Producción
flutter build apk --split-per-abi --release
```

---
*Este manual es propiedad de **ARGOS PROJECT**. Prohibida su distribución sin autorización. 🛡️✨*
