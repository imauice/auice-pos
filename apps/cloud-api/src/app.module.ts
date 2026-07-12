import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MongooseModule } from '@nestjs/mongoose';
import { HealthModule } from './health/health.module';
import * as Joi from 'joi';
import { DomainModule } from './domain/domain.module';
import { SyncModule } from './sync/sync.module';
import { MasterDataModule } from './master-data/master-data.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: Joi.object({
        NODE_ENV: Joi.string().valid('development', 'test', 'production').default('development'),
        PORT: Joi.number().port().default(3000),
        MONGODB_URI: Joi.string().uri().default('mongodb://localhost:27017/auice_pos'),
        VALKEY_HOST: Joi.string().hostname().default('localhost'),
        VALKEY_PORT: Joi.number().port().default(6379),
        CORS_ORIGIN: Joi.string().uri().default('http://localhost:5173'),
      }),
    }),
    MongooseModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        uri: config.get<string>('MONGODB_URI', 'mongodb://localhost:27017/auice_pos'),
        serverSelectionTimeoutMS: 3000,
        lazyConnection: true,
      }),
    }),
    HealthModule,
    DomainModule,
    SyncModule,
    MasterDataModule,
  ],
})
export class AppModule {}
