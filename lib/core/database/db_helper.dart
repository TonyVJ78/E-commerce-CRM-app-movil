import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/usuario.dart';
import '../models/tienda.dart';
import '../models/producto.dart';
import '../models/pedido.dart';
import '../models/bitacora.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Roles
    await db.execute('''
      CREATE TABLE rol (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE
      )
    ''');

    // 2. Usuarios
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

    // 3. Tiendas
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

    // 4. Categorías
    await db.execute('''
      CREATE TABLE categoria (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tienda_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        categoria_padre_id INTEGER
      )
    ''');

    // 5. Productos
    await db.execute('''
      CREATE TABLE producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tienda_id INTEGER NOT NULL,
        tienda_nombre TEXT NOT NULL,
        categoria_id INTEGER,
        categoria_nombre TEXT,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        precio_base REAL NOT NULL,
        sku TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        imagen_url TEXT,
        stock INTEGER NOT NULL DEFAULT 10
      )
    ''');

    // 6. Variantes
    await db.execute('''
      CREATE TABLE variante_producto (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tienda_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        nombre_variante TEXT NOT NULL,
        precio_adicional REAL NOT NULL DEFAULT 0.0,
        sku_variante TEXT
      )
    ''');

    // 7. Pedidos
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

    // 8. Ítems de Pedido
    await db.execute('''
      CREATE TABLE item_pedido (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        pedido_id INTEGER NOT NULL,
        producto_id INTEGER NOT NULL,
        producto_nombre TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL
      )
    ''');

    // 9. Bitácora de Acceso
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

    // 10. Log de Auditoría
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

    // Poblar con Datos Semilla (seed_demo.py de Kantu Market)
    await _seedDatabase(db);
  }

  Future<void> _seedDatabase(Database db) async {
    final now = DateTime.now().toIso8601String();

    // Roles
    await db.insert('rol', {'nombre': 'administrador'});
    await db.insert('rol', {'nombre': 'empresa'});
    await db.insert('rol', {'nombre': 'cliente'});

    // Usuarios Demo
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
      'email': 'cliente@kantu.bo',
      'password': 'Password123!',
      'first_name': 'Ana',
      'last_name': 'Pérez',
      'rol': 'cliente',
      'activo': 1,
      'fecha_registro': now,
    });

    // Tiendas Demo
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

    // Categorías Demo
    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Textiles Andinos'});
    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Cerámica y Barro'});
    await db.insert('categoria', {'tienda_id': 1, 'nombre': 'Joyería Tradicional'});
    await db.insert('categoria', {'tienda_id': 2, 'nombre': 'Café de Especialidad'});

    // Productos Demo
    final productos = [
      {
        'tienda_id': 1,
        'tienda_nombre': 'Artesanías Bolivianas',
        'categoria_id': 1,
        'categoria_nombre': 'Textiles Andinos',
        'nombre': 'Poncho de Alpaca Fina',
        'descripcion': 'Tejido artesanal 100% fibra de alpaca natural con motivos andinos tradicionales.',
        'precio_base': 280.00,
        'sku': 'ALP-PON-001',
        'activo': 1,
        'imagen_url': 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=500',
        'stock': 15,
      },
      {
        'tienda_id': 1,
        'tienda_nombre': 'Artesanías Bolivianas',
        'categoria_id': 1,
        'categoria_nombre': 'Textiles Andinos',
        'nombre': 'Aguayo Tradicional Paceño',
        'descripcion': 'Manta tradicional multicolor confeccionada con técnicas ancestrales del altiplano.',
        'precio_base': 85.00,
        'sku': 'AGU-PAC-002',
        'activo': 1,
        'imagen_url': 'https://images.unsplash.com/photo-1606760227091-3dd870d97f1d?w=500',
        'stock': 25,
      },
      {
        'tienda_id': 1,
        'tienda_nombre': 'Artesanías Bolivianas',
        'categoria_id': 2,
        'categoria_nombre': 'Cerámica y Barro',
        'nombre': 'Vasija Ceremonial Tiwanaku',
        'descripcion': 'Réplica artesanal en arcilla cocida y pintada a mano con simbología andina.',
        'precio_base': 120.00,
        'sku': 'CER-TIW-003',
        'activo': 1,
        'imagen_url': 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=500',
        'stock': 8,
      },
      {
        'tienda_id': 1,
        'tienda_nombre': 'Artesanías Bolivianas',
        'categoria_id': 3,
        'categoria_nombre': 'Joyería Tradicional',
        'nombre': 'Aretes de Plata con Amatista Bolivianita',
        'descripcion': 'Joyería fina en plata boliviana 925 con la exclusiva gema bi-color ametrino.',
        'precio_base': 160.00,
        'sku': 'JOY-BOL-004',
        'activo': 1,
        'imagen_url': 'https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=500',
        'stock': 12,
      },
      {
        'tienda_id': 2,
        'tienda_nombre': 'Café Yungas Gourmet',
        'categoria_id': 4,
        'categoria_nombre': 'Café de Especialidad',
        'nombre': 'Café Arábica Caranavi 500g',
        'descripcion': 'Granos selectos tostado medio con notas a chocolate amargo y frutos rojos.',
        'precio_base': 55.00,
        'sku': 'CAF-CAR-001',
        'activo': 1,
        'imagen_url': 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=500',
        'stock': 40,
      },
    ];

    for (final p in productos) {
      await db.insert('producto', p);
    }

    // Bitácora Inicial
    await db.insert('bitacora_acceso', {
      'usuario_id': 1,
      'usuario_email': 'admin@kantu.bo',
      'fecha': now,
      'ip': '127.0.0.1',
      'dispositivo': 'App Móvil Kantu Market',
    });

    // Log Auditoría Inicial
    await db.insert('log_auditoria', {
      'usuario_email': 'admin@kantu.bo',
      'tabla_afectada': 'tienda',
      'registro_id': 1,
      'accion': 'CREAR',
      'fecha': now,
    });
  }

  // --- CRUD METHODS ---

  // Auth & Usuarios
  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await database;
    final res = await db.query(
      'usuario',
      where: 'LOWER(email) = LOWER(?) AND password = ? AND activo = 1',
      whereArgs: [email.trim(), password],
      limit: 1,
    );
    if (res.isNotEmpty) {
      // Registrar en bitácora
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

  // Tiendas
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
        : data['nombre'].toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

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

    // Auditoría
    await db.insert('log_auditoria', {
      'usuario_email': user.email,
      'tabla_afectada': 'tienda',
      'registro_id': id,
      'accion': 'CREAR',
      'fecha': now,
    });

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

  // Catálogo & Productos
  Future<List<Producto>> getProductos({int? tiendaId, int? categoriaId, String? search}) async {
    final db = await database;
    String whereClause = 'activo = 1';
    List<dynamic> args = [];

    if (tiendaId != null) {
      whereClause += ' AND tienda_id = ?';
      args.add(tiendaId);
    }
    if (categoriaId != null) {
      whereClause += ' AND categoria_id = ?';
      args.add(categoriaId);
    }
    if (search != null && search.trim().isNotEmpty) {
      whereClause += ' AND (LOWER(nombre) LIKE ? OR LOWER(descripcion) LIKE ?)';
      final q = '%${search.trim().toLowerCase()}%';
      args.add(q);
      args.add(q);
    }

    final res = await db.query('producto', where: whereClause, whereArgs: args, orderBy: 'id DESC');
    return res.map((m) => Producto.fromMap(m)).toList();
  }

  Future<List<Categoria>> getCategorias({int? tiendaId}) async {
    final db = await database;
    final List<Map<String, dynamic>> res;
    if (tiendaId != null) {
      res = await db.query('categoria', where: 'tienda_id = ?', whereArgs: [tiendaId]);
    } else {
      res = await db.query('categoria');
    }
    return res.map((m) => Categoria.fromMap(m)).toList();
  }

  Future<int> createProducto(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert('producto', data);
  }

  // Pedidos
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
        'producto_nombre': item.producto.nombre,
        'cantidad': item.cantidad,
        'precio_unitario': item.producto.precioBase,
      });

      // Reducir stock
      await db.rawUpdate(
        'UPDATE producto SET stock = MAX(0, stock - ?) WHERE id = ?',
        [item.cantidad, item.producto.id],
      );

      itemsGuardados.add(ItemPedido(
        id: itemId,
        pedidoId: pedidoId,
        productoId: item.producto.id,
        productoNombre: item.producto.nombre,
        cantidad: item.cantidad,
        precioUnitario: item.producto.precioBase,
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

  Future<List<Pedido>> getPedidos({int? clienteId, int? tiendaId}) async {
    final db = await database;
    final List<Map<String, dynamic>> res;
    if (clienteId != null) {
      res = await db.query('pedido', where: 'cliente_id = ?', whereArgs: [clienteId], orderBy: 'id DESC');
    } else if (tiendaId != null) {
      res = await db.query('pedido', where: 'tienda_id = ?', whereArgs: [tiendaId], orderBy: 'id DESC');
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

  // Bitácora y Auditoría
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

  // Métricas del Admin
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
}
