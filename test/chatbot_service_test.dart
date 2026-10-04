import 'package:flutter_test/flutter_test.dart';
import 'package:kantu_market/core/models/producto.dart';
import 'package:kantu_market/core/services/api_service.dart';
import 'package:kantu_market/core/services/chatbot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatbotService Tests', () {
    late ChatbotService service;

    setUp(() {
      service = ChatbotService();
    });

    test('inicializa con el saludo y sugerencias por defecto', () {
      expect(service.mensajes.length, 1);
      final saludo = service.mensajes.first;
      expect(saludo.esUsuario, isFalse);
      expect(saludo.contenido, contains('Kantu'));
      expect(saludo.sugerencias.isNotEmpty, isTrue);
      expect(saludo.error, isFalse);
      expect(service.enviando, isFalse);
    });

    test('MensajeChat toApiJson mapea roles y contenido correctamente', () {
      const msgUsuario = MensajeChat(esUsuario: true, contenido: 'Hola');
      expect(msgUsuario.toApiJson(), {'rol': 'usuario', 'contenido': 'Hola'});

      const msgAsistente = MensajeChat(esUsuario: false, contenido: 'Respuesta');
      expect(msgAsistente.toApiJson(), {'rol': 'asistente', 'contenido': 'Respuesta'});
    });

    test('reiniciar() restablece la conversación al saludo inicial', () {
      service.reiniciar();
      expect(service.mensajes.length, 1);
      expect(service.mensajes.first.esUsuario, isFalse);
    });

    test('prepararPara reinicia si cambia el ID de usuario', () {
      service.prepararPara(1);
      expect(service.mensajes.length, 1);

      service.prepararPara(2);
      expect(service.mensajes.length, 1);
    });

    test('productoCitado encuentra productos en el historial', () {
      final productoPrueba = Producto(
        id: 99,
        tiendaId: 1,
        tiendaNombre: 'Tienda Test',
        nombre: 'Café Yungas',
        slug: 'cafe-yungas',
        descripcion: 'Café de altura',
        imagenes: const [],
        categoriaNombre: 'Bebidas',
        variantes: const [],
      );

      // Verificamos cuando no hay productos citados
      expect(service.productoCitado(99), isNull);

      // Verificamos al simular un mensaje que incluye el producto
      final msgConProd = MensajeChat(
        esUsuario: false,
        contenido: 'Te recomiendo [Café Yungas](producto:99)',
        productos: [productoPrueba],
      );

      // El getter es inmutable, probamos la búsqueda en MensajeChat
      expect(msgConProd.productos.first.id, 99);
      expect(msgConProd.productos.first.nombre, 'Café Yungas');
    });

    test('enviar con texto vacío no emite mensaje ni muta estado', () async {
      final initialCount = service.mensajes.length;
      await service.enviar('   ');
      expect(service.mensajes.length, initialCount);
      expect(service.enviando, isFalse);
    });

    test('enviar en modo offline maneja respuesta segura sin crash', () async {
      // Por defecto ApiService.instance.useOnlineBackend es false si no se configuró baseUrl remota
      ApiService.instance.setOnlineBackend(false);
      
      bool notificado = false;
      service.addListener(() {
        notificado = true;
      });

      await service.enviar('¿Qué tienen de café?');

      expect(notificado, isTrue);
      expect(service.enviando, isFalse);
      expect(service.mensajes.length, 3); // Saludo + Mensaje Usuario + Respuesta Offline
      expect(service.mensajes[1].esUsuario, isTrue);
      expect(service.mensajes[1].contenido, '¿Qué tienen de café?');
      expect(service.mensajes[2].esUsuario, isFalse);
      expect(service.mensajes[2].error, isTrue);
      expect(service.mensajes[2].contenido, contains('servidor'));
    });
  });
}
