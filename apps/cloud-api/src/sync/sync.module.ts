import { Module } from '@nestjs/common'; import { MongooseModule } from '@nestjs/mongoose';
import { SyncEventSchema } from './schemas/sync-event.schema'; import { SyncController } from './sync.controller'; import { SyncService } from './sync.service';
@Module({ imports: [MongooseModule.forFeature([{ name: 'SyncEvent', schema: SyncEventSchema }])], controllers: [SyncController], providers: [SyncService] })
export class SyncModule {}

