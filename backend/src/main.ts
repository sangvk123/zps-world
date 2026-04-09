import * as path from 'path';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // COOP/COEP headers required for Godot 4 web export (SharedArrayBuffer)
  app.use((_req: unknown, res: { setHeader: (k: string, v: string) => void }, next: () => void) => {
    res.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    res.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    next();
  });

  // Serve exported Godot HTML5 game from backend/public/
  const publicDir = path.join(__dirname, '..', 'public');
  app.useStaticAssets(publicDir);

  // Allow Godot game served from :3000, GitHub Pages, and custom origins via env var
  const defaultOrigins = [
    'http://localhost:3000', 'http://localhost:3001',
    'http://127.0.0.1:3000', 'http://127.0.0.1:3001',
    'https://sangvk123.github.io',
  ];
  const extraOrigins = (process.env['ALLOWED_ORIGINS'] ?? '').split(',').filter(Boolean);
  app.enableCors({
    origin: [...defaultOrigins, ...extraOrigins],
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'bypass-tunnel-reminder'],
  });

  // Validate all incoming request bodies automatically
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const port = process.env['PORT'] ?? 3000;
  await app.listen(port);
  console.log(`[ZPS Backend] Running on http://localhost:${port}`);
  console.log(`[ZPS Backend] Game served at http://localhost:${port}/`);
}

bootstrap();
