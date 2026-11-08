/// Aviso de privacidad y autorización de tratamiento de datos (Ley 1581 de 2012 y Decreto 1377 de
/// 2013). Al cambiar el texto de forma sustancial hay que subir [version]: la app pedirá aceptarlo
/// de nuevo.
class PrivacyNotice {
  PrivacyNotice._();

  static const version = '2026-11';

  static const responsible = 'Juan Felipe Mora, estudiante de Ingeniería de Software de la Universidad '
      'Cooperativa de Colombia, sede Pasto, responsable del proyecto de grado AgroVet';

  static const contactEmail = 'juan.morarevel@campusucc.edu.co';

  static const title = 'Aviso de privacidad';

  /// Secciones del aviso: título y párrafos.
  static const sections = <(String, List<String>)>[
    (
      'Quién trata sus datos',
      [
        '$responsible. Correo de contacto: $contactEmail.',
      ],
    ),
    (
      'Qué datos se recogen',
      [
        'De usted: nombre, correo, y si los escribe, nombre de la finca, municipio y teléfono.',
        'De sus animales: identificación, raza, partos, registros diarios (temperatura, leche, alimento y '
            'síntomas), resultados del semáforo, alertas y las fotos que tome.',
        'No se recoge su ubicación. Las fotos se guardan sin los datos de ubicación de la cámara.',
      ],
    ),
    (
      'Para qué se usan',
      [
        'Para darle alertas tempranas de mastitis y guardar el historial de sus vacas.',
        'Para hacer una copia de respaldo en el servidor del proyecto y recuperar sus datos si cambia de '
            'celular.',
        'Para enviarle por correo los códigos de verificación y de cambio de contraseña.',
        'Si usa el asistente, su pregunta, el último resultado de la vaca y la foto que adjunte se envían '
            'a un servicio de inteligencia artificial para generar la respuesta. No se envía su nombre ni '
            'su correo.',
        'Para investigación, solo las fotos que usted marque expresamente como permitidas, y sin datos '
            'que lo identifiquen. Puede retirar ese permiso cuando quiera.',
      ],
    ),
    (
      'Sus derechos',
      [
        'Conocer, actualizar y corregir sus datos (desde "Mi perfil").',
        'Pedir la eliminación de su cuenta y de todos sus datos (desde "Mi perfil" → "Eliminar mi cuenta").',
        'Revocar esta autorización, pedir prueba de ella y saber cómo se han usado sus datos, escribiendo '
            'a $contactEmail.',
        'Presentar quejas ante la Superintendencia de Industria y Comercio.',
      ],
    ),
    (
      'Cómo se protegen',
      [
        'En el celular los datos están cifrados. La conexión con el servidor es protegida y las contraseñas '
            'se guardan de forma que nadie puede leerlas.',
        'Sus datos no se venden ni se comparten con terceros para publicidad.',
        'Los datos de salud de los animales no son datos sensibles de personas, pero se tratan con el mismo '
            'cuidado.',
      ],
    ),
  ];
}
