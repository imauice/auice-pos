import { HealthService } from '../src/health/health.service';
describe('HealthService', () => {
  it('reports the real connection state and a timestamp', () => {
    const service = new HealthService({ readyState: 1 } as never);
    const result = service.getHealth();
    expect(result.database).toBe('connected');
    expect(result.service).toBe('auice-pos-cloud-api');
    expect(new Date(result.timestamp).toISOString()).toBe(result.timestamp);
  });
  it('remains meaningful while MongoDB is unavailable', () => expect(new HealthService({ readyState: 0 } as never).getHealth().database).toBe('disconnected'));
});

