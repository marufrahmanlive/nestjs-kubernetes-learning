import { Injectable } from '@nestjs/common';
import * as os from 'os';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Hello World!';
  }

  healthCheck() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      hostname: os.hostname(),
      version: 'v1.0.3',
    };
  }
}
