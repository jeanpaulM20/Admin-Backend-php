import { Controller, Get, ForbiddenException } from '@nestjs/common';
import { DailyQuoteService } from './daily-quote.service';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { Client } from '../entities/client.entity';

@Controller('api/daily-quote')
export class DailyQuoteController {
  constructor(private readonly service: DailyQuoteService) {}

  /** GET /api/daily-quote — returns today's personalised quote for the client. */
  @Get()
  async getQuote(@CurrentClient() client: Client) {
    if (!client) throw new ForbiddenException('Anmeldung erforderlich');
    const firstName =
      (client as any).firstname ??
      (client as any).name ??
      '';
    return this.service.getQuote(client.id, firstName);
  }
}
