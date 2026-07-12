import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { Connection, ConnectionStates } from 'mongoose';
export interface HealthResponse { status: 'ok'; service: string; database: 'connected' | 'connecting' | 'disconnected'; timestamp: string; }
@Injectable()
export class HealthService {
  constructor(@InjectConnection() private readonly connection: Connection) {}
  getHealth(): HealthResponse {
    const state = this.connection.readyState;
    return { status: 'ok', service: 'auice-pos-cloud-api', database: state === ConnectionStates.connected ? 'connected' : state === ConnectionStates.connecting ? 'connecting' : 'disconnected', timestamp: new Date().toISOString() };
  }
}
