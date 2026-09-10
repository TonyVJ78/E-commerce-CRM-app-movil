import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/usuario.dart';
import '../models/tienda.dart';
import '../models/producto.dart';
import '../models/pedido.dart';
import '../models/bitacora.dart';

/// Base local de la app. Es un espejo simplificado del esquema PostgreSQL del
/// backend, para que Kantu Market siga siendo demostrable sin servidor.
///
/// **Versión 2 (CU-08 a CU-11)**: el catálogo pasó de producto plano a
/// `producto` + `variante` (el precio y el stock viven en la variante, como en
/// el backend) y se añadieron `carrito` / `item_carrito` para que el carrito
/// sobreviva al cierre de la app.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kantu_market.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // --- Accesos: roles y usuarios (CU-01 a CU-05, CU-07) ---
    await db.execute('''
      CREATE TABLE rol (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE usuario (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        rol TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_registro TEXT NOT NULL
      )
    ''');

    // --- Tiendas (CU-06) ---
    await db.execute('''
      CREATE TABLE tienda (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        propietario_id INTEGER NOT NULL,
        propietario_email TEXT NOT NULL,
        nombre TEXT NOT NULL,
        slug TEXT NOT NULL UNIQUE,
        logo_url TEXT,
        color_primario TEXT NOT NULL DEFAULT '#C8102E',
        descripcion TEXT,
        fecha_creacion TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // --- Catálogo (CU-08, CU-09) ---
    await db.execute('''
      CREATE TABLE categoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tienda_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        categoria_padre_id INTEGER
      )
    ''');

    await _createTablasCatalogo(db);
    await _createTablasCarrito(db);

    // --- Ventas: pedidos y su detalle (CU-11) ---
    await db.execute('''
      CREATE TABLE pedido (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        cliente_email TEXT NOT NULL,
        tienda_id INTEGER NOT NULL,
        tienda_nombre TEXT NOT NULL,
        estado_actual TEXT NOT NULL DEFAULT 'completado',
        fecha TEXT NOT NULL,
        subtotal REAL NOT NULL,
        total REAL NOT NULL,
        metodo_pago TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE item_pedido (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pedido_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        variante_id INTEGER NOT NULL DEFAULT 0,
        producto_nombre TEXT NOT NULL,
        variante_nombre TEXT NOT NULL DEFAULT '',
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL
      )
    ''');

    // --- Bitácora y auditoría (CU-07) ---
    await db.execute('''
      CREATE TABLE bitacora_acceso (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        usuario_email TEXT NOT NULL,
        fecha TEXT NOT NULL,
        ip TEXT NOT NULL,
        dispositivo TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE log_auditoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_email TEXT NOT NULL,
        tabla_afectada TEXT NOT NULL,
        registro_id INTEGER NOT NULL,
        accion TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');

    // Mismos usuarios y tiendas demo que `seed_demo.py` del backend.
    await _seedDatabase(db);
  }

  /// Catálogo en dos tablas, igual que `catalogo.Producto` /
  /// `catalogo.Variante` del backend: el precio y el stock son de la variante.
  Future<void> _createTablasCatalogo(Database db) async {
    await db.execute('''
      CREATE TABLE producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tienda_id INTEGER NOT NULL,
        tienda_nombre TEXT NOT NULL,
        categoria_id INTEGER,
        categoria_nombre TEXT,
        nombre TEXT NOT NULL,
        slug TEXT NOT NULL DEFAULT '',
        descripcion TEXT,
        etiquetas TEXT NOT NULL DEFAULT '[]',
        imagenes TEXT NOT NULL DEFAULT '[]',
        activo INTEGER NOT NULL DEFAULT 1,
        creado TEXT NOT NULL,
        actualizado TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE variante (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        tienda_id INTEGER NOT NULL,
        nombre TEXT NOT NULL DEFAULT 'Unica',
        sku TEXT NOT NULL DEFAULT '',
        precio REAL NOT NULL,
        precio_oferta REAL,
        stock INTEGER NOT NULL DEFAULT 0,
        stock_minimo INTEGER NOT NULL DEFAULT 5,
        atributos TEXT NOT NULL DEFAULT '{}',
        activa INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  /// Carrito persistente (CU-11). `id_remoto` guarda el id del `item_carrito`
  /// creado en el backend, para poder hacerle PATCH o DELETE después.
  Future<void> _createTablasCarrito(Database db) async {
    await db.execute('''
      CREATE TABLE carrito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        tienda_id INTEGER NOT NULL,
        fecha_creacion TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE item_carrito (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        carrito_id INTEGER NOT NULL,
        tienda_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        variante_id INTEGER NOT NULL,
        cantidad INTEGER NOT NULL DEFAULT 1,
        id_remoto INTEGER
      )
    ''');
  }

  /// Migración v1 → v2: parte cada producto plano en producto + una variante
  /// `Unica` que hereda su precio, SKU y stock, sin perder datos del usuario.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion >= 2) return;

    final productosViejos = await db.query('producto');

    await db.execute('ALTER TABLE producto RENAME TO producto_v1');
    await _createTablasCatalogo(db);
    await _createTablasCarrito(db);

    final ahora = DateTime.now().toIso8601String();
    for (final viejo in productosViejos) {
      final imagenUrl = (viejo['imagen_url'] ?? '').toString();
      final productoId = await db.insert('producto', {
        'id': viejo['id'],
        'tienda_id': viejo['tienda_id'],
        'tienda_nombre': viejo['tienda_nombre'] ?? '',
        'categoria_id': viejo['categoria_id'],
        'categoria_nombre': viejo['categoria_nombre'] ?? '',
        'nombre': viejo['nombre'],
        'slug': _slugify((viejo['nombre'] ?? '').toString()),
        'descripcion': viejo['descripcion'] ?? '',
        'etiquetas': '[]',
        'imagenes': jsonEncode(imagenUrl.isNotEmpty ? [imagenUrl] : []),
        'activo': viejo['activo'] ?? 1,
        'creado': ahora,
        'actualizado': ahora,
      });

      await db.insert('variante', {
        'producto_id': productoId,
        'tienda_id': viejo['tienda_id'],
        'nombre': 'Unica',
        'sku': viejo['sku'] ?? '',
        'precio': viejo['precio_base'] ?? 0.0,
        'stock': viejo['stock'] ?? 0,
        'stock_minimo': 5,
        'atributos': '{}',
        'activa': 1,
      });
    }

    await db.execute('DROP TABLE producto_v1');
    await db.execute('DROP TABLE IF EXISTS variante_producto');

    // item_pedido gana la referencia a la variante (v1 sólo guardaba el producto).
    await db.execute('ALTER TABLE item_pedido ADD COLUMN variante_id INTEGER NOT NULL DEFAULT 0');
    await db.execute("ALTER TABLE item_pedido ADD COLUMN variante_nombre TEXT NOT NULL DEFAULT ''");
  }

  static String _slugify(String texto) {
    final base = texto.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return base.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();

    await db.insert('rol', {'nombre': 'administrador'});
    await db.insert('rol', {'nombre': 'empresa'});
    await db.insert('rol', {'nombre': 'cliente'});

    await db.insert('usuario', {
      'email': 'admin@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Administrador',
      'last_name': 'Sistema',
      'rol': 'administrador',
      'activo': 1,
      'fecha_registro': now,
    });

    await db.insert('usuario', {
      'email': 'empresa@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Carlos',
      'last_name': 'Mamani',
      'rol': 'empresa',
      'activo': 1,
      'fecha_registro': now,
    });

    await db.insert('usuario', {
      'email': 'empresa1@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Maria',
      'last_name': 'Condori',
      'rol': 'empresa',
      'activo': 1,
      'fecha_registro': now,
    });

    await db.insert('usuario', {
      'email': 'cliente@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Ana',
      'last_name': 'Pérez',
      'rol': 'cliente',
      'activo': 1,
      'fecha_registro': now,
    });

    await db.insert('usuario', {
      'email': 'cliente1@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Lucia',
      'last_name': 'Rojas',
      'rol': 'cliente',
      'activo': 1,
      'fecha_registro': now,
    });

    await db.insert('tienda', {
      'propietario_id': 2,
      'propietario_email': 'empresa@kantu.bo',
      'nombre': 'Artesanías Bolivianas',
      'slug': 'artesanias-bolivianas',
      'logo_url': '',
      'color_primario': '#C8102E',
      'descripcion': 'Tienda demostrativa de textiles y artesanías andinas auténticas de Bolivia.',
      'fecha_creacion': now,
      'activa': 1,
    });

    await db.insert('tienda', {
      'propietario_id': 2,
      'propietario_email': 'empresa@kantu.bo',
      'nombre': 'Café Yungas Gourmet',
      'slug': 'cafe-yungas-gourmet',
      'logo_url': '',
      'color_primario': '#27AE60',
      'descripcion': 'Café de altura 100% boliviano cosechado artesanalmente en Caranavi.',
      'fecha_creacion': now,
      'activa': 1,
    });

    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Textiles Andinos'});
    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Cerámica y Barro'});
    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Joyería Tradicional'});
    await db.insert('categoria', {'tienda_id': 2, 'nombre': 'Café de Especialidad'});

    // Cada producto se siembra con sus variantes, que son las que llevan
    // precio y stock.
    final productos = [
      {
        'producto': {
          'tienda_id': 1,
          'tienda_nombre': 'Artesanías Bolivianas',
          'categoria_id': 1,
          'categoria_nombre': 'Textiles Andinos',
          'nombre': 'Poncho de Alpaca Fina',
          'slug': 'poncho-de-alpaca-fina',
          'descripcion': 'Tejido artesanal 100% fibra de alpaca natural con motivos andinos tradicionales.',
          'etiquetas': jsonEncode(['alpaca', 'tejido', 'invierno']),
          'imagenes': jsonEncode(['https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500']),
          'activo': 1,
          'creado': now,
          'actualizado': now,
        },
        'variantes': [
          {'nombre': 'Talla M', 'sku': 'ALP-PON-001-M', 'precio': 280.0, 'stock': 8, 'stock_minimo': 3},
          {'nombre': 'Talla L', 'sku': 'ALP-PON-001-L', 'precio': 310.0, 'stock': 7, 'stock_minimo': 3},
        ],
      },
      {
        'producto': {
          'tienda_id': 1,
          'tienda_nombre': 'Artesanías Bolivianas',
          'categoria_id': 1,
          'categoria_nombre': 'Textiles Andinos',
          'nombre': 'Aguayo Tradicional Paceño',
          'slug': 'aguayo-tradicional-pacenio',
          'descripcion': 'Manta tradicional multicolor confeccionada con técnicas ancestrales del altiplano.',
          'etiquetas': jsonEncode(['aguayo', 'altiplano']),
          'imagenes': jsonEncode(['https://images.unsplash.com/photo-1606760227091-3dd870d97f1d?w=500']),
          'activo': 1,
          'creado': now,
          'actualizado': now,
        },
        'variantes': [
          {'nombre': 'Unica', 'sku': 'AGU-PAC-002', 'precio': 85.0, 'stock': 25, 'stock_minimo': 5},
        ],
      },
      {
        'producto': {
          'tienda_id': 1,
          'tienda_nombre': 'Artesanías Bolivianas',
          'categoria_id': 2,
          'categoria_nombre': 'Cerámica y Barro',
          'nombre': 'Vasija Ceremonial Tiwanaku',
          'slug': 'vasija-ceremonial-tiwanaku',
          'descripcion': 'Réplica artesanal en arcilla cocida y pintada a mano con simbología andina.',
          'etiquetas': jsonEncode(['cerámica', 'tiwanaku']),
          'imagenes': jsonEncode(['https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500']),
          'activo': 1,
          'creado': now,
          'actualizado': now,
        },
        'variantes': [
          {'nombre': 'Unica', 'sku': 'CER-TIW-003', 'precio': 120.0, 'stock': 4, 'stock_minimo': 5},
        ],
      },
      {
        'producto': {
          'tienda_id': 1,
          'tienda_nombre': 'Artesanías Bolivianas',
          'categoria_id': 3,
          'categoria_nombre': 'Joyería Tradicional',
          'nombre': 'Aretes de Plata con Bolivianita',
          'slug': 'aretes-de-plata-con-bolivianita',
          'descripcion': 'Joyería fina en plata boliviana 925 con la exclusiva gema bi-color ametrino.',
          'etiquetas': jsonEncode(['plata', 'bolivianita']),
          'imagenes': jsonEncode(['https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=500']),
          'activo': 1,
          'creado': now,
          'actualizado': now,
        },
        'variantes': [
          {'nombre': 'Unica', 'sku': 'JOY-BOL-004', 'precio': 160.0, 'precio_oferta': 139.0, 'stock': 12, 'stock_minimo': 4},
        ],
      },
      {
        'producto': {
          'tienda_id': 2,
          'tienda_nombre': 'Café Yungas Gourmet',
          'categoria_id': 4,
          'categoria_nombre': 'Café de Especialidad',
          'nombre': 'Café Arábica Caranavi',
          'slug': 'cafe-arabica-caranavi',
          'descripcion': 'Granos selectos tostado medio con notas a chocolate amargo y frutos rojos.',
          'etiquetas': jsonEncode(['café', 'caranavi', 'tostado medio']),
          'imagenes': jsonEncode(['https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500']),
          'activo': 1,
          'creado': now,
          'actualizado': now,
        },
        'variantes': [
          {'nombre': '250 g', 'sku': 'CAF-CAR-001-250', 'precio': 35.0, 'stock': 30, 'stock_minimo': 10},
          {'nombre': '500 g', 'sku': 'CAF-CAR-001-500', 'precio': 55.0, 'stock': 40, 'stock_minimo': 10},
          {'nombre': '1 kg', 'sku': 'CAF-CAR-001-1000', 'precio': 98.0, 'stock': 6, 'stock_minimo': 8},
        ],
      },
    ];

    for (final entrada in productos) {
      final datosProducto = entrada['producto'] as Map<String, dynamic>;
      final productoId = await db.insert('producto', datosProducto);
      for (final variante in entrada['variantes'] as List) {
        await db.insert('variante', {
          ...variante as Map<String, dynamic>,
          'producto_id': productoId,
          'tienda_id': datosProducto['tienda_id'],
          'atributos': '{}',
          'activa': 1,
        });
      }
    }

    await db.insert('bitacora_acceso', {
      'usuario_id': 1,
      'usuario_email': 'admin@kantu.bo',
      'fecha': now,
      'ip': '127.0.0.1',
      'dispositivo': 'App Móvil Kantu Market',
    });

    await db.insert('log_auditoria', {
      'usuario_email': 'admin@kantu.bo',
      'tabla_afectada': 'tienda',
      'registro_id': 1,
      'accion': 'CREAR',
      'fecha': now,
    });
  }

  // =========================================================================
  // Autenticación y perfil (CU-01 a CU-05)
  // =========================================================================
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    final res = await db.query(
      'usuario',
      where: 'LOWER(email) = LOWER(?) AND password = ? AND activo = 1',
      whereArgs: [email.trim(), password],
      limit: 1,
    );
    if (res.isNotEmpty) {
      // CU-07: cada acceso deja rastro en la bitácora.
      await db.insert('bitacora_acceso', {
        'usuario_id': res.first['id'],
        'usuario_email': res.first['email'],
        'fecha': DateTime.now().toIso8601String(),
        'ip': '192.168.1.10',
        'dispositivo': 'Flutter Android Client',
      });
      return res.first;
    }
    return null;
  }

  Future<int> registerUser(Map<String, dynamic> data) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('usuario', {
      'email': (data['email'] as String).trim(),
      'password': data['password'],
      'first_name': data['first_name'] ?? '',
      'last_name': data['last_name'] ?? '',
      'rol': data['rol'] ?? 'cliente',
      'activo': 1,
      'fecha_registro': now,
    });
  }

  Future<bool> userExists(String email) async {
    final db = await database;
    final res = await db.query('usuario', where: 'LOWER(email) = LOWER(?)', whereArgs: [email.trim()]);
    return res.isNotEmpty;
  }

  Future<int> updatePerfil(int userId, String firstName, String lastName) async {
    final db = await database;
    return await db.update(
      'usuario',
      {'first_name': firstName, 'last_name': lastName},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> resetPassword(String email, String newPassword) async {
    final db = await database;
    return await db.update(
      'usuario',
      {'password': newPassword},
      where: 'LOWER(email) = LOWER(?)',
      whereArgs: [email.trim()],
    );
  }

  Future<List<Usuario>> getAllUsuarios() async {
    final db = await database;
    final res = await db.query('usuario', orderBy: 'id DESC');
    return res.map((m) => Usuario.fromMap(m)).toList();
  }

  // =========================================================================
  // Tiendas (CU-06)
  // =========================================================================
  Future<List<Tienda>> getTiendas({int? propietarioId}) async {
    final db = await database;
    final List<Map<String, dynamic>> res;
    if (propietarioId != null) {
      res = await db.query('tienda', where: 'propietario_id = ?', whereArgs: [propietarioId], orderBy: 'id DESC');
    } else {
      res = await db.query('tienda', where: 'activa = 1', orderBy: 'id DESC');
    }
    return res.map((m) => Tienda.fromMap(m)).toList();
  }

  Future<Tienda> createTienda(Map<String, dynamic> data, Usuario user) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final slug = data['slug'] != null && data['slug'].toString().isNotEmpty
        ? data['slug']
        : _slugify(data['nombre'].toString());

    final id = await db.insert('tienda', {
      'propietario_id': user.id,
      'propietario_email': user.email,
      'nombre': data['nombre'],
      'slug': slug,
      'logo_url': data['logo_url'] ?? '',
      'color_primario': data['color_primario'] ?? '#C8102E',
      'descripcion': data['descripcion'] ?? '',
      'fecha_creacion': now,
      'activa': 1,
    });

    await registrarAuditoria(
      usuarioEmail: user.email,
      tabla: 'tienda',
      registroId: id,
      accion: 'CREAR',
    );

    return Tienda(
      id: id,
      propietarioId: user.id,
      propietarioEmail: user.email,
      nombre: data['nombre'],
      slug: slug,
      logoUrl: data['logo_url'] ?? '',
      colorPrimario: data['color_primario'] ?? '#C8102E',
      descripcion: data['descripcion'] ?? '',
      fechaCreacion: now,
      activa: true,
    );
  }

  // =========================================================================
  // Catálogo: productos y variantes (CU-08, CU-09; lo lee CU-11)
  // =========================================================================

  /// Lee productos con sus variantes en dos consultas, sin N+1.
  /// La usan la vitrina del cliente (CU-11) y el panel de la empresa.
  ///
  /// [soloActivos] en `false` es lo que usa el panel de la empresa para poder
  /// ver también los productos dados de baja (el borrado es lógico).
  Future<List<Producto>> getProductos({
    int? tiendaId,
    int? categoriaId,
    String? search,
    bool soloActivos = true,
  }) async {
    final db = await database;
    final condiciones = <String>[];
    final args = <dynamic>[];

    if (soloActivos) condiciones.add('activo = 1');
    if (tiendaId != null) {
      condiciones.add('tienda_id = ?');
      args.add(tiendaId);
    }
    if (categoriaId != null) {
      condiciones.add('categoria_id = ?');
      args.add(categoriaId);
    }
    if (search != null && search.trim().isNotEmpty) {
      condiciones.add('(LOWER(nombre) LIKE ? OR LOWER(descripcion) LIKE ? OR LOWER(etiquetas) LIKE ?)');
      final q = '%${search.trim().toLowerCase()}%';
      args.addAll([q, q, q]);
    }

    final filas = await db.query(
      'producto',
      where: condiciones.isEmpty ? null : condiciones.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
    );
    if (filas.isEmpty) return [];

    final variantesPorProducto = await _variantesDe(filas.map((f) => f['id'] as int).toList());

    return filas
        .map((fila) => Producto.fromMap(
              fila,
              variantes: variantesPorProducto[fila['id'] as int] ?? const [],
            ))
        .toList();
  }

  Future<Map<int, List<Variante>>> _variantesDe(List<int> productoIds) async {
    if (productoIds.isEmpty) return {};
    final db = await database;
    final marcadores = List.filled(productoIds.length, '?').join(',');
    final filas = await db.query(
      'variante',
      where: 'producto_id IN ($marcadores)',
      whereArgs: productoIds,
      orderBy: 'id ASC',
    );

    final agrupadas = <int, List<Variante>>{};
    for (final fila in filas) {
      final variante = Variante.fromMap(fila);
      agrupadas.putIfAbsent(variante.productoId, () => []).add(variante);
    }
    return agrupadas;
  }

  Future<Producto?> getProductoById(int productoId) async {
    final db = await database;
    final filas = await db.query('producto', where: 'id = ?', whereArgs: [productoId], limit: 1);
    if (filas.isEmpty) return null;
    final variantes = await _variantesDe([productoId]);
    return Producto.fromMap(filas.first, variantes: variantes[productoId] ?? const []);
  }

  /// Inserta producto y variantes en una transacción (CU-08).
  Future<Producto> createProducto({
    required Producto producto,
    required List<Variante> variantes,
    String? usuarioEmail,
  }) async {
    final db = await database;
    final ahora = DateTime.now().toIso8601String();

    final productoId = await db.transaction((txn) async {
      final id = await txn.insert('producto', {
        ...producto.toMap()..remove('id'),
        'slug': producto.slug.isNotEmpty ? producto.slug : _slugify(producto.nombre),
        'creado': ahora,
        'actualizado': ahora,
      });

      for (final variante in variantes) {
        await txn.insert('variante', {
          ...variante.toMap()..remove('id'),
          'producto_id': id,
          'tienda_id': producto.tiendaId,
        });
      }
      return id;
    });

    if (usuarioEmail != null) {
      await registrarAuditoria(
        usuarioEmail: usuarioEmail,
        tabla: 'producto',
        registroId: productoId,
        accion: 'CREAR',
      );
    }

    return (await getProductoById(productoId))!;
  }

  /// Actualiza el producto y sustituye sus variantes (CU-09).
  ///
  /// Las variantes que ya existen se actualizan por id y las nuevas se
  /// insertan; las que el usuario quitó del formulario se eliminan.
  Future<Producto?> updateProducto({
    required Producto producto,
    required List<Variante> variantes,
    String? usuarioEmail,
  }) async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'producto',
        {
          ...producto.toMap()..remove('id'),
          'actualizado': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [producto.id],
      );

      final idsConservados = variantes.where((v) => v.id > 0).map((v) => v.id).toList();
      if (idsConservados.isEmpty) {
        await txn.delete('variante', where: 'producto_id = ?', whereArgs: [producto.id]);
      } else {
        final marcadores = List.filled(idsConservados.length, '?').join(',');
        await txn.delete(
          'variante',
          where: 'producto_id = ? AND id NOT IN ($marcadores)',
          whereArgs: [producto.id, ...idsConservados],
        );
      }

      for (final variante in variantes) {
        final datos = {
          ...variante.toMap()..remove('id'),
          'producto_id': producto.id,
          'tienda_id': producto.tiendaId,
        };
        if (variante.id > 0) {
          await txn.update('variante', datos, where: 'id = ?', whereArgs: [variante.id]);
        } else {
          await txn.insert('variante', datos);
        }
      }
    });

    if (usuarioEmail != null) {
      await registrarAuditoria(
        usuarioEmail: usuarioEmail,
        tabla: 'producto',
        registroId: producto.id,
        accion: 'ACTUALIZAR',
      );
    }

    return await getProductoById(producto.id);
  }

  /// CU-09 — Baja lógica, igual que `perform_destroy` del backend: los pedidos
  /// históricos deben seguir apuntando a un producto existente.
  Future<void> setProductoActivo(int productoId, bool activo, {String? usuarioEmail}) async {
    final db = await database;
    await db.update(
      'producto',
      {'activo': activo ? 1 : 0, 'actualizado': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [productoId],
    );

    if (usuarioEmail != null) {
      await registrarAuditoria(
        usuarioEmail: usuarioEmail,
        tabla: 'producto',
        registroId: productoId,
        accion: activo ? 'ACTUALIZAR' : 'ELIMINAR',
      );
    }
  }

  Future<List<Categoria>> getCategorias({int? tiendaId}) async {
    final db = await database;
    final res = tiendaId != null
        ? await db.query('categoria', where: 'tienda_id = ?', whereArgs: [tiendaId], orderBy: 'nombre ASC')
        : await db.query('categoria', orderBy: 'nombre ASC');
    return res.map((m) => Categoria.fromMap(m)).toList();
  }

  /// Devuelve la categoría con ese nombre en la tienda, creándola si no existe.
  Future<Categoria> getOrCreateCategoria(int tiendaId, String nombre) async {
    final db = await database;
    final limpio = nombre.trim();
    final existentes = await db.query(
      'categoria',
      where: 'tienda_id = ? AND LOWER(nombre) = LOWER(?)',
      whereArgs: [tiendaId, limpio],
      limit: 1,
    );
    if (existentes.isNotEmpty) return Categoria.fromMap(existentes.first);

    final id = await db.insert('categoria', {'tienda_id': tiendaId, 'nombre': limpio});
    return Categoria(id: id, tiendaId: tiendaId, nombre: limpio);
  }

  Future<void> registrarAuditoria({
    required String usuarioEmail,
    required String tabla,
    required int registroId,
    required String accion,
  }) async {
    final db = await database;
    await db.insert('log_auditoria', {
      'usuario_email': usuarioEmail,
      'tabla_afectada': tabla,
      'registro_id': registroId,
      'accion': accion,
      'fecha': DateTime.now().toIso8601String(),
    });
  }

  // =========================================================================
  // Carrito persistente (CU-11)
  // =========================================================================

  Future<int> _getOrCreateCarrito(DatabaseExecutor db, int clienteId, int tiendaId) async {
    final existentes = await db.query(
      'carrito',
      where: 'cliente_id = ? AND tienda_id = ?',
      whereArgs: [clienteId, tiendaId],
      limit: 1,
    );
    if (existentes.isNotEmpty) return existentes.first['id'] as int;

    return await db.insert('carrito', {
      'cliente_id': clienteId,
      'tienda_id': tiendaId,
      'fecha_creacion': DateTime.now().toIso8601String(),
    });
  }

  /// Suma la cantidad al ítem si la variante ya está en el carrito; si no, lo crea.
  Future<int> upsertItemCarrito({
    required int clienteId,
    required Producto producto,
    required Variante variante,
    required int cantidad,
    int? idRemoto,
  }) async {
    final db = await database;
    final carritoId = await _getOrCreateCarrito(db, clienteId, producto.tiendaId);

    final existentes = await db.query(
      'item_carrito',
      where: 'carrito_id = ? AND variante_id = ?',
      whereArgs: [carritoId, variante.id],
      limit: 1,
    );

    if (existentes.isEmpty) {
      return await db.insert('item_carrito', {
        'carrito_id': carritoId,
        'tienda_id': producto.tiendaId,
        'producto_id': producto.id,
        'variante_id': variante.id,
        'cantidad': cantidad,
        'id_remoto': idRemoto,
      });
    }

    final itemId = existentes.first['id'] as int;
    await db.update(
      'item_carrito',
      {
        'cantidad': (existentes.first['cantidad'] as int) + cantidad,
        'id_remoto': ?idRemoto,
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );
    return itemId;
  }

  Future<void> setCantidadItemCarrito(int itemId, int cantidad) async {
    final db = await database;
    if (cantidad <= 0) {
      await db.delete('item_carrito', where: 'id = ?', whereArgs: [itemId]);
      return;
    }
    await db.update('item_carrito', {'cantidad': cantidad}, where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> removeItemCarrito(int itemId) async {
    final db = await database;
    await db.delete('item_carrito', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> clearCarrito(int clienteId) async {
    final db = await database;
    final carritos = await db.query('carrito', where: 'cliente_id = ?', whereArgs: [clienteId]);
    for (final carrito in carritos) {
      await db.delete('item_carrito', where: 'carrito_id = ?', whereArgs: [carrito['id']]);
    }
  }

  /// Reconstruye el carrito del cliente uniendo ítem, producto y variante.
  /// Descarta en silencio los ítems cuyo producto o variante ya no existen.
  Future<List<ItemCarrito>> getItemsCarrito(int clienteId) async {
    final db = await database;
    final filas = await db.rawQuery('''
      SELECT ic.id, ic.cantidad, ic.id_remoto, ic.producto_id, ic.variante_id
      FROM item_carrito ic
      INNER JOIN carrito c ON c.id = ic.carrito_id
      WHERE c.cliente_id = ?
      ORDER BY ic.id ASC
    ''', [clienteId]);
    if (filas.isEmpty) return [];

    final items = <ItemCarrito>[];
    for (final fila in filas) {
      final producto = await getProductoById(fila['producto_id'] as int);
      if (producto == null) continue;

      final varianteId = fila['variante_id'] as int;
      Variante? variante;
      for (final v in producto.variantes) {
        if (v.id == varianteId) variante = v;
      }
      if (variante == null) continue;

      items.add(ItemCarrito(
        id: fila['id'] as int,
        producto: producto,
        variante: variante,
        cantidad: fila['cantidad'] as int,
        idRemoto: fila['id_remoto'] as int?,
      ));
    }
    return items;
  }

  // =========================================================================
  // Pedidos (CU-11)
  // =========================================================================
  Future<Pedido> createPedido({
    required int clienteId,
    required String clienteEmail,
    required int tiendaId,
    required String tiendaNombre,
    required double total,
    required String metodoPago,
    required List<ItemCarrito> items,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final pedidoId = await db.insert('pedido', {
      'cliente_id': clienteId,
      'cliente_email': clienteEmail,
      'tienda_id': tiendaId,
      'tienda_nombre': tiendaNombre,
      'estado_actual': 'completado',
      'fecha': now,
      'subtotal': total,
      'total': total,
      'metodo_pago': metodoPago,
    });

    List<ItemPedido> itemsGuardados = [];
    for (final item in items) {
      final itemId = await db.insert('item_pedido', {
        'pedido_id': pedidoId,
        'producto_id': item.producto.id,
        'variante_id': item.variante.id,
        'producto_nombre': item.producto.nombre,
        'variante_nombre': item.variante.nombre,
        'cantidad': item.cantidad,
        'precio_unitario': item.precioUnitario,
      });

      // El stock vive en la variante, no en el producto.
      await db.rawUpdate(
        'UPDATE variante SET stock = MAX(0, stock - ?) WHERE id = ?',
        [item.cantidad, item.variante.id],
      );

      itemsGuardados.add(ItemPedido(
        id: itemId,
        pedidoId: pedidoId,
        productoId: item.producto.id,
        varianteId: item.variante.id,
        productoNombre: item.producto.nombre,
        varianteNombre: item.variante.nombre,
        cantidad: item.cantidad,
        precioUnitario: item.precioUnitario,
      ));
    }

    return Pedido(
      id: pedidoId,
      clienteId: clienteId,
      clienteEmail: clienteEmail,
      tiendaId: tiendaId,
      tiendaNombre: tiendaNombre,
      estadoActual: 'completado',
      fecha: now,
      subtotal: total,
      total: total,
      metodoPago: metodoPago,
      items: itemsGuardados,
    );
  }

  Future<List<Pedido>> getPedidos({int? clienteId, int? tiendaId, int? propietarioId}) async {
    final db = await database;
    final List<Map<String, dynamic>> res;
    if (clienteId != null) {
      res = await db.query('pedido', where: 'cliente_id = ?', whereArgs: [clienteId], orderBy: 'id DESC');
    } else if (tiendaId != null) {
      res = await db.query('pedido', where: 'tienda_id = ?', whereArgs: [tiendaId], orderBy: 'id DESC');
    } else if (propietarioId != null) {
      res = await db.rawQuery('''
        SELECT p.* FROM pedido p
        INNER JOIN tienda t ON t.id = p.tienda_id
        WHERE t.propietario_id = ?
        ORDER BY p.id DESC
      ''', [propietarioId]);
    } else {
      res = await db.query('pedido', orderBy: 'id DESC');
    }

    List<Pedido> pedidos = [];
    for (final p in res) {
      final itemRows = await db.query('item_pedido', where: 'pedido_id = ?', whereArgs: [p['id']]);
      final items = itemRows.map((it) => ItemPedido.fromMap(it)).toList();
      pedidos.add(Pedido.fromMap(p, items: items));
    }
    return pedidos;
  }

  // =========================================================================
  // Bitácora y auditoría (CU-07)
  // =========================================================================
  Future<List<BitacoraAcceso>> getBitacora() async {
    final db = await database;
    final res = await db.query('bitacora_acceso', orderBy: 'id DESC', limit: 50);
    return res.map((m) => BitacoraAcceso.fromMap(m)).toList();
  }

  Future<List<LogAuditoria>> getLogsAuditoria() async {
    final db = await database;
    final res = await db.query('log_auditoria', orderBy: 'id DESC', limit: 50);
    return res.map((m) => LogAuditoria.fromMap(m)).toList();
  }

  // =========================================================================
  // Métricas de los paneles (CU-10)
  // =========================================================================
  Future<Map<String, int>> getAdminStats() async {
    final db = await database;
    final usuariosCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM usuario')) ?? 0;
    final tiendasCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM tienda')) ?? 0;
    final productosCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM producto')) ?? 0;
    final pedidosCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pedido')) ?? 0;

    return {
      'usuarios': usuariosCount,
      'tiendas': tiendasCount,
      'productos': productosCount,
      'pedidos': pedidosCount,
    };
  }

  /// KPIs del panel del vendedor (CU-10) calculados en local.
  ///
  /// Replica campo por campo lo que devuelve `DashboardVendedorView` del
  /// backend, para que la pantalla sea idéntica en modo autónomo y en remoto.
  Future<Map<String, dynamic>> getDashboardVendedor(int propietarioId) async {
    final db = await database;

    Future<int> contar(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql, [propietarioId])) ?? 0;

    final totalProductos = await contar('''
      SELECT COUNT(*) FROM producto p
      INNER JOIN tienda t ON t.id = p.tienda_id WHERE t.propietario_id = ?
    ''');

    final productosActivos = await contar('''
      SELECT COUNT(*) FROM producto p
      INNER JOIN tienda t ON t.id = p.tienda_id
      WHERE t.propietario_id = ? AND p.activo = 1
    ''');

    final totalPedidos = await contar('''
      SELECT COUNT(*) FROM pedido pe
      INNER JOIN tienda t ON t.id = pe.tienda_id WHERE t.propietario_id = ?
    ''');

    final pedidosPendientes = await contar('''
      SELECT COUNT(*) FROM pedido pe
      INNER JOIN tienda t ON t.id = pe.tienda_id
      WHERE t.propietario_id = ? AND pe.estado_actual = 'pendiente'
    ''');

    final bajoStock = await contar('''
      SELECT COUNT(*) FROM variante v
      INNER JOIN producto p ON p.id = v.producto_id
      INNER JOIN tienda t ON t.id = p.tienda_id
      WHERE t.propietario_id = ? AND v.activa = 1 AND v.stock <= v.stock_minimo
    ''');

    final ingresosFila = await db.rawQuery('''
      SELECT COALESCE(SUM(pe.total), 0) AS suma FROM pedido pe
      INNER JOIN tienda t ON t.id = pe.tienda_id
      WHERE t.propietario_id = ? AND pe.estado_actual != 'cancelado'
    ''', [propietarioId]);
    final ingresos = (ingresosFila.first['suma'] as num?)?.toDouble() ?? 0.0;

    // Ventas de los últimos 7 días, agrupadas en una sola consulta.
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 6));
    final ventasFilas = await db.rawQuery('''
      SELECT DATE(pe.fecha) AS dia, SUM(ip.cantidad) AS cantidad
      FROM item_pedido ip
      INNER JOIN pedido pe ON pe.id = ip.pedido_id
      INNER JOIN tienda t ON t.id = pe.tienda_id
      WHERE t.propietario_id = ? AND pe.estado_actual != 'cancelado' AND DATE(pe.fecha) >= DATE(?)
      GROUP BY DATE(pe.fecha)
    ''', [propietarioId, inicio.toIso8601String().substring(0, 10)]);

    final ventasPorDia = <String, int>{
      for (final fila in ventasFilas)
        fila['dia'].toString(): (fila['cantidad'] as num?)?.toInt() ?? 0,
    };

    final graficoVentas = List.generate(7, (i) {
      final dia = inicio.add(Duration(days: i));
      final clave = dia.toIso8601String().substring(0, 10);
      final dd = dia.day.toString().padLeft(2, '0');
      final mm = dia.month.toString().padLeft(2, '0');
      return {'fecha': '$dd/$mm', 'cantidad': ventasPorDia[clave] ?? 0};
    });

    return {
      'total_productos': totalProductos,
      'productos_activos': productosActivos,
      'total_pedidos': totalPedidos,
      'pedidos_pendientes': pedidosPendientes,
      'ingresos_totales': ingresos,
      'productos_bajo_stock': bajoStock,
      'grafico_ventas': graficoVentas,
    };
  }
}
