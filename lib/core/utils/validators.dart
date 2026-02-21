class Validators {
  /// Valida una cédula ecuatoriana usando el algoritmo de Módulo 10.
  static bool isValidCedula(String? cedula) {
    if (cedula == null || cedula.isEmpty) return false;

    // Eliminar espacios o guiones si existen
    final cleanCedula = cedula.replaceAll(RegExp(r'\s+|-'), '');

    if (cleanCedula.length != 10) return false;
    if (int.tryParse(cleanCedula) == null) return false;

    // Verificar provincia (primeros dos dígitos)
    // 01-24 para provincias, 30 para número reservado para extranjeros
    int provincia = int.parse(cleanCedula.substring(0, 2));
    if (provincia < 1 || (provincia > 24 && provincia != 30)) return false;

    // Verificar tercer dígito (debe ser de 0 a 5 para cédulas de personas naturales)
    int tercerDigito = int.parse(cleanCedula.substring(2, 3));
    if (tercerDigito < 0 || tercerDigito > 5) return false;

    // Algoritmo de Coeficientes Modulo 10
    List<int> coeficientes = [2, 1, 2, 1, 2, 1, 2, 1, 2];
    int suma = 0;

    for (int i = 0; i < 9; i++) {
      int valor = int.parse(cleanCedula[i]) * coeficientes[i];
      suma += (valor > 9) ? valor - 9 : valor;
    }

    int digitoVerificador = int.parse(cleanCedula[9]);
    int superior = (suma % 10 == 0) ? suma : ((suma ~/ 10) + 1) * 10;
    int resultado = superior - suma;

    return resultado == digitoVerificador;
  }
}
