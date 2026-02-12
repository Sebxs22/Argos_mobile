import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

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
  }) async {
    try {
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'nombre': nombre,
          'telefono': telefono,
        },
      );
      return res.user != null ? null : "Error al crear cuenta";
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Error inesperado: $e";
    }
  }

  // --- 2. LOGIN ---
  Future<String?> iniciarSesion({required String email, required String password}) async {
    try {
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user != null ? null : "Credenciales inválidas";
    } on AuthException catch (e) {
      return "Correo o contraseña incorrectos";
    } catch (e) {
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

  // Ver quiénes están en mi círculo
  Future<List<dynamic>> obtenerMisFamiliares() async {
    final yo = usuarioActual;
    if (yo == null) return [];

    final res = await _supabase
        .from('circulo_confianza')
        .select('perfiles!guardian_id(nombre_completo, telefono, avatar_url)')
        .eq('usuario_id', yo.id);

    return res as List<dynamic>;
  }
}