import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Rewrite PHP-style URLs from Flutter client app:
  //   /index.php/api/... → /api/...
  //   /api/token         → /api/client/token  (PHP login route)
  app.use((req, _res, next) => {
    if (req.url.startsWith('/index.php/')) {
      req.url = req.url.replace('/index.php/', '/');
      req.originalUrl = req.url;
    }
    if (req.url === '/api/token' || req.url.startsWith('/api/token?')) {
      req.url = '/api/client/token' + req.url.slice('/api/token'.length);
      req.originalUrl = req.url;
    }
    next();
  });

  // Health check for Railway
  app.getHttpAdapter().get('/api/health', (_req, res) => res.json({ status: 'ok' }));

  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    allowedHeaders: 'Content-Type, Accept, X-Auth-Token',
  });

  const config = new DocumentBuilder()
    .setTitle('Sihl Training API')
    .setDescription('NestJS Migration – parallel zu PHP/Yii Backend')
    .setVersion('2.0')
    .addApiKey({ type: 'apiKey', name: 'X-Auth-Token', in: 'header' }, 'X-Auth-Token')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`Backend running on port ${port}`);
  console.log(`Swagger:  http://localhost:${port}/api/docs`);
}

bootstrap();
