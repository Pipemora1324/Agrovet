/// Borra de este celular todo lo del usuario: cierra la base cifrada, borra su archivo y olvida sus
/// claves. Se usa después de eliminar la cuenta en el servidor.
class LocalDataWiper {
  const LocalDataWiper(this._wipe);

  final Future<void> Function() _wipe;

  Future<void> wipe() => _wipe();
}
