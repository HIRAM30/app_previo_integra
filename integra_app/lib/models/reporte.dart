// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// models/reporte.dart
// Descripción: Modelos de datos del Reporte de Previo con
//   Avería o Discrepancia. Refleja el formato oficial de
//   Integra Del Centro S.C. Compatibles con Hive y con el
//   archivo .integra exportado a la Web App de oficina.
// ============================================================

/// Representa un hallazgo de mercancía en la tabla de discrepancias.
/// Cada fila del formato oficial: No Factura, No Partida, No Parte,
/// Cantidad Factura, Conteo, Marca, Modelo.
class HallazgoItem {
  String noFactura;
  String noPartida;
  String noParte;
  String cantidadFactura;
  String conteo;
  String marca;
  String modelo;
  String observaciones;

  HallazgoItem({
    this.noFactura = '',
    this.noPartida = '',
    this.noParte = '',
    this.cantidadFactura = '',
    this.conteo = '',
    this.marca = '',
    this.modelo = '',
    this.observaciones = '',
  });

  /// Devuelve true si hay discrepancia entre la cantidad facturada y el conteo.
  bool get tieneDiscrepancia =>
      cantidadFactura.isNotEmpty &&
      conteo.isNotEmpty &&
      cantidadFactura.trim() != conteo.trim();

  Map<String, dynamic> toMap() => {
        'noFactura': noFactura,
        'noPartida': noPartida,
        'noParte': noParte,
        'cantidadFactura': cantidadFactura,
        'conteo': conteo,
        'marca': marca,
        'modelo': modelo,
        'observaciones': observaciones,
      };

  factory HallazgoItem.fromMap(Map map) => HallazgoItem(
        noFactura: map['noFactura'] ?? '',
        noPartida: map['noPartida'] ?? '',
        noParte: map['noParte'] ?? '',
        cantidadFactura: map['cantidadFactura'] ?? '',
        conteo: map['conteo'] ?? '',
        marca: map['marca'] ?? '',
        modelo: map['modelo'] ?? '',
        observaciones: map['observaciones'] ?? '',
      );
}

/// Estado de la mercancía revisada durante el previo.
class EstadoMercancia {
  bool completa;
  bool faltantes;
  bool sobrantes;
  bool cargaCompleta;

  EstadoMercancia({
    this.completa = false,
    this.faltantes = false,
    this.sobrantes = false,
    this.cargaCompleta = true,
  });

  Map<String, dynamic> toMap() => {
        'completa': completa,
        'faltantes': faltantes,
        'sobrantes': sobrantes,
        'cargaCompleta': cargaCompleta,
      };

  factory EstadoMercancia.fromMap(Map map) => EstadoMercancia(
        completa: map['completa'] ?? false,
        faltantes: map['faltantes'] ?? false,
        sobrantes: map['sobrantes'] ?? false,
        cargaCompleta: map['cargaCompleta'] ?? true,
      );
}

/// Modelo principal del Reporte de Previo con Avería o Discrepancia.
/// Contiene todos los campos del formato oficial de Integra Del Centro S.C.
class ReportePrevio {
  final String id;

  // Encabezado
  String importador;
  String proveedor;
  String recintoFiscal;
  String realizaPrevio;

  // Embarque
  String referencia;
  String guiaBLMaster;
  DateTime? fechaEntrada;
  String bultos;
  String pesoBruto;

  // Detalle del previo
  DateTime? fechaSolicitud;
  DateTime? fechaHoraInicio;
  DateTime? fechaHoraTermino;

  // Estado
  EstadoMercancia estadoMercancia;
  String observacionesIncidencias;
  String observacionesCarga;

  // Carga suelta
  String cantidadBultosSueltos;
  String tipoBulto;
  String largoBulto;
  String anchoBulto;
  String altoBulto;

  // Hallazgos
  List<HallazgoItem> hallazgos;
  String totalMercancias;

  // Fotos
  List<String> fotos;
  List<String> fotosTipos;

  final DateTime fechaCreacion;

  ReportePrevio({
    required this.id,
    this.importador = '',
    this.proveedor = '',
    this.recintoFiscal = '',
    this.realizaPrevio = '',
    this.referencia = '',
    this.guiaBLMaster = '',
    this.fechaEntrada,
    this.bultos = '',
    this.pesoBruto = '',
    this.fechaSolicitud,
    this.fechaHoraInicio,
    this.fechaHoraTermino,
    EstadoMercancia? estadoMercancia,
    this.observacionesIncidencias = '',
    this.observacionesCarga = '',
    this.cantidadBultosSueltos = '',
    this.tipoBulto = '',
    this.largoBulto = '',
    this.anchoBulto = '',
    this.altoBulto = '',
    List<HallazgoItem>? hallazgos,
    this.totalMercancias = '',
    List<String>? fotos,
    List<String>? fotosTipos,
    DateTime? fechaCreacion,
  })  : estadoMercancia = estadoMercancia ?? EstadoMercancia(),
        hallazgos = hallazgos ?? [],
        fotos = fotos ?? [],
        fotosTipos = fotosTipos ?? [],
        fechaCreacion = fechaCreacion ?? DateTime.now();

  /// Número de hallazgos con discrepancia entre factura y conteo.
  int get totalDiscrepancias =>
      hallazgos.where((h) => h.tieneDiscrepancia).length;

  /// Convierte a mapa para guardar en Hive o exportar como JSON.
  Map<String, dynamic> toMap() => {
        'id': id,
        'importador': importador,
        'proveedor': proveedor,
        'recintoFiscal': recintoFiscal,
        'realizaPrevio': realizaPrevio,
        'referencia': referencia,
        'guiaBLMaster': guiaBLMaster,
        'fechaEntrada': fechaEntrada?.toIso8601String(),
        'bultos': bultos,
        'pesoBruto': pesoBruto,
        'fechaSolicitud': fechaSolicitud?.toIso8601String(),
        'fechaHoraInicio': fechaHoraInicio?.toIso8601String(),
        'fechaHoraTermino': fechaHoraTermino?.toIso8601String(),
        'estadoMercancia': estadoMercancia.toMap(),
        'observacionesIncidencias': observacionesIncidencias,
        'observacionesCarga': observacionesCarga,
        'cantidadBultosSueltos': cantidadBultosSueltos,
        'tipoBulto': tipoBulto,
        'largoBulto': largoBulto,
        'anchoBulto': anchoBulto,
        'altoBulto': altoBulto,
        'hallazgos': hallazgos.map((h) => h.toMap()).toList(),
        'totalMercancias': totalMercancias,
        'fotos': fotos,
        'fotosTipos': fotosTipos,
        'fechaCreacion': fechaCreacion.toIso8601String(),
      };

  /// Reconstruye desde Hive o desde el JSON del archivo .integra.
  factory ReportePrevio.fromMap(Map data) {
    final hRaw = data['hallazgos'] as List? ?? [];
    final emRaw = data['estadoMercancia'] as Map?;

    return ReportePrevio(
      id: data['id'] ?? ReportePrevio.generarId(),
      importador: data['importador'] ?? '',
      proveedor: data['proveedor'] ?? '',
      recintoFiscal: data['recintoFiscal'] ?? '',
      realizaPrevio: data['realizaPrevio'] ?? '',
      referencia: data['referencia'] ?? '',
      guiaBLMaster: data['guiaBLMaster'] ?? '',
      fechaEntrada: _parseDate(data['fechaEntrada']),
      bultos: data['bultos'] ?? '',
      pesoBruto: data['pesoBruto'] ?? '',
      fechaSolicitud: _parseDate(data['fechaSolicitud']),
      fechaHoraInicio: _parseDate(data['fechaHoraInicio']),
      fechaHoraTermino: _parseDate(data['fechaHoraTermino']),
      estadoMercancia: emRaw != null
          ? EstadoMercancia.fromMap(emRaw)
          : EstadoMercancia(),
      observacionesIncidencias: data['observacionesIncidencias'] ?? '',
      observacionesCarga: data['observacionesCarga'] ?? '',
      cantidadBultosSueltos: data['cantidadBultosSueltos'] ?? '',
      tipoBulto: data['tipoBulto'] ?? '',
      largoBulto: data['largoBulto'] ?? '',
      anchoBulto: data['anchoBulto'] ?? '',
      altoBulto: data['altoBulto'] ?? '',
      hallazgos: hRaw.map((h) => HallazgoItem.fromMap(h as Map)).toList(),
      totalMercancias: data['totalMercancias'] ?? '',
      fotos: List<String>.from(data['fotos'] ?? []),
      fotosTipos: List<String>.from(data['fotosTipos'] ?? []),
      fechaCreacion: _parseDate(data['fechaCreacion']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    return DateTime.tryParse(val.toString());
  }

  static String generarId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  /// Formato dd/MM/yyyy para mostrar en UI y PDF.
  static String formatFecha(DateTime? fecha) {
    if (fecha == null) return '';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  /// Formato dd/MM/yyyy HH:mm para mostrar en UI y PDF.
  static String formatFechaHora(DateTime? fecha) {
    if (fecha == null) return '';
    return '${formatFecha(fecha)} '
        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';
  }
}
