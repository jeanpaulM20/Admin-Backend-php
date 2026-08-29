import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { json, urlencoded } from 'express';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // GPS-Tracks (mehrstündige Touren) und Trainingsfotos kommen als JSON —
  // das Express-Standardlimit von 100 kb wirft dafür PayloadTooLargeError.
  app.use(json({ limit: '10mb' }));
  app.use(urlencoded({ extended: true, limit: '10mb' }));

  // Health check for Railway
  app.getHttpAdapter().get('/api/health', (_req, res) => res.json({ status: 'ok' }));

  // CORS — restrict to known origins in production
  const allowedOrigins = process.env.CORS_ORIGINS
    ? process.env.CORS_ORIGINS.split(',').map((o) => o.trim())
    : ['*'];

  app.enableCors({
    origin: allowedOrigins.includes('*') ? true : allowedOrigins,
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
