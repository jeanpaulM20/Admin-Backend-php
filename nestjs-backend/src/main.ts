import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

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
