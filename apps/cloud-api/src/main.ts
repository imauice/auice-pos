import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  app.enableShutdownHooks();
  app.setGlobalPrefix('api');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableCors({ origin: config.get<string>('CORS_ORIGIN', 'http://localhost:5173') });
  const document = SwaggerModule.createDocument(app, new DocumentBuilder().setTitle('Auice POS Cloud API').setVersion('0.1').build());
  SwaggerModule.setup('api/docs', app, document);
  await app.listen(config.get<number>('PORT', 3000));
}
void bootstrap();
