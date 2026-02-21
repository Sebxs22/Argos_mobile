import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // Import OneSignal
import 'package:flutter/foundation.dart'; // For debugPrint
import '../utils/ui_utils.dart'; // Import UiUtils

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- ESTADO ---
  User? get usuarioActual => _supabase.auth.currentUser;

  // --- 1. REGISTRO (Conectado al Trigger SQL) ---
  Future<String?> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    required String telefono,
    required String cedula,
    required String pais,
    required String estado,
    required String ciudad,
    required bool aceptaTerminos,
  }) async {
    try {
      debugPrint("🚀 Intentando registrar usuario: $email");
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre': nombre,
          'telefono': telefono,
          'cedula': cedula,
          'pais': pais,
          'estado': estado,
          'ciudad': ciudad,
          'acepta_terminos': aceptaTerminos,
        },
      );
      if (res.user != null) {
        debugPrint("✅ Registro exitoso en Supabase Auth");
        // No esperamos (await) a OneSignal para no bloquear el inicio de la app
        actualizarPushToken();
        UiUtils.showSuccess("Cuenta creada exitosamente");
        return null;
      } else {
        UiUtils.showError("Error al crear cuenta");
        return "Error al crear cuenta";
      }
    } on AuthException catch (e) {
      UiUtils.showError(e.message);
      return e.message;
    } catch (e) {
      UiUtils.showError("Error inesperado: $e");
      return "Error inesperado: $e";
    }
  }

  // --- 2. LOGIN ---
  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint("🚀 Intentando iniciar sesión: $email");
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (res.user == null) {
        debugPrint("❌ Error: Usuario nulo tras login");
        UiUtils.showError("Credenciales inválidas");
        return "Credenciales inválidas";
      }
      debugPrint("✅ Login exitoso");
      actualizarPushToken(); // Sincronizar OneSignal (sin await)
      return null;
    } on AuthException catch (e) {
      debugPrint("❌ AuthException: ${e.message}");
      UiUtils.showError("Correo o contraseña incorrectos");
      return "Correo o contraseña incorrectos";
    } catch (e) {
      debugPrint("❌ Error inesperado en login: $e");
      UiUtils.showError("Error de conexión");
      return "Error de conexión";
    }
  }

  // --- 3. CERRAR SESIÓN ---
  Future<void> cerrarSesion() async => await _supabase.auth.signOut();

  // --- 4. PERFIL Y CÍRCULO FAMILIAR ---

  // Obtener mis datos desde la tabla 'perfiles'
  Future<Map<String, dynamic>?> obtenerMiPerfil() async {
    try {
      final user = usuarioActual;
      if (user == null) return null;

      return await _supabase
          .from('perfiles')
          .select()
          .eq('id', user.id)
          .single();
    } catch (e) {
      return null;
    }
  }

  // Buscar a un familiar por código (Ej: ARG-1234)
  Future<Map<String, dynamic>?> buscarPorCodigo(String codigo) async {
    try {
      return await _supabase
          .from('perfiles')
          .select()
          .eq('codigo_familia', codigo.toUpperCase())
          .single();
    } catch (e) {
      return null;
    }
  }

  // Vincular: Yo (protegido) agrego a alguien como mi Guardia (familiar)
  Future<void> vincularFamiliar(String idFamiliar) async {
    final yo = usuarioActual;
    if (yo == null) return;

    await _supabase.from('circulo_confianza').insert({
      'usuario_id': yo.id,
      'guardian_id': idFamiliar,
    });
  }

  // Ver quiénes están en mi círculo (Mis Guardianes)
  Future<List<Map<String, dynamic>>> obtenerMisGuardianes() async {
    final yo = usuarioActual;
    if (yo == null) return [];

    try {
      // 1. Obtener IDs de mis guardianes
      final relations = await _supabase
          .from('circulo_confianza')
          .select('guardian_id')
          .eq('usuario_id', yo.id);

      final List<String> ids = List<String>.from(
        relations.map((e) => e['guardian_id']),
      );

      if (ids.isEmpty) return [];

      // 2. Obtener perfiles de esos IDs
      final profiles =
          await _supabase.from('perfiles').select().filter('id', 'in', ids);

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      return [];
    }
  }

  // Ver a quiénes protejo (Soy su Guardián)
  Future<List<Map<String, dynamic>>> obtenerAQuienesProtejo() async {
    final yo = usuarioActual;
    if (yo == null) return [];

    try {
      // 1. Obtener IDs de mis protegidos
      final relations = await _supabase
          .from('circulo_confianza')
          .select('usuario_id')
          .eq('guardian_id', yo.id);

      final List<String> ids = List<String>.from(
        relations.map((e) => e['usuario_id']),
      );

      if (ids.isEmpty) return [];

      // 2. Obtener perfiles de esos IDs
      final profiles =
          await _supabase.from('perfiles').select().filter('id', 'in', ids);

      return List<Map<String, dynamic>>.from(profiles);
    } catch (e) {
      return [];
    }
  }
  // --- 5. NOTIFICACIONES PUSH ---

  // Vincular el ID de OneSignal con el perfil de Supabase
  Future<void> actualizarPushToken() async {
    try {
      final yo = usuarioActual;
      if (yo == null) return;

      // Obtener el ID de OneSignal (Subscription ID)
      final status = OneSignal.User.pushSubscription.id;

      if (status != null && status.isNotEmpty) {
        await _supabase
            .from('perfiles')
            .update({'onesignal_id': status}).eq('id', yo.id);
        debugPrint("✅ Token de OneSignal registrado: $status");
      }
    } catch (e) {
      debugPrint("❌ Error al registrar OneSignal ID: $e");
    }
  }
}
