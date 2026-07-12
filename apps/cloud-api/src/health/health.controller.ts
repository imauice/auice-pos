import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiTags } from '@nestjs/swagger';
import { HealthResponse, HealthService } from './health.service';
@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}
  @Get()
  @ApiOkResponse({ description: 'Service and database health' })
  getHealth(): HealthResponse { return this.healthService.getHealth(); }
}

