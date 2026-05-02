import {
  Controller, Get, Post, Delete, Param, Body, Query,
  ParseIntPipe, NotFoundException,
} from '@nestjs/common';
import { DataSource } from 'typeorm';
import { ClientAppService } from './client-app.service';
import { Public } from '../auth/decorators/public.decorator';

/**
 * Client-app specific endpoints.
 *
 * These mirror the PHP endpoints the Flutter client-app calls:
 *   /api/client/start/:id    — dashboard data (credits + upcoming trainings)
 *   /api/client/calendar/:id — calendar data (trainers, types, availability, appointments)
 *   /api/client/profile/:id  — client profile
 *   /api/client/credits/:id  — credit packs
 *   /api/client/appointment  — book / cancel
 */
@Public()
@Controller('api/client')
export class ClientAppController {

  constructor(
    private readonly appService: ClientAppService,
    private readonly dataSource: DataSource,
  ) {}

  /** Debug: list all tables in the database (remove after debugging) */
  @Get('debug/tables')
  async debugTables() {
    try {
      const tables = await this.dataSource.query('SHOW TABLES');
      return tables;
    } catch (e: any) {
      return { error: e.message };
    }
  }

  /** Dashboard — credits + upcoming trainings */
  @Get('start/:clientId')
  start(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getStartData(clientId);
  }

  /** Calendar — trainers, types, availability, appointments */
  @Get('calendar/:clientId')
  calendar(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getCalendarData(clientId);
  }

  /** Profile */
  @Get('profile/:clientId')
  profile(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getProfile(clientId);
  }

  /** Credits */
  @Get('credits/:clientId')
  credits(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getCredits(clientId);
  }

  /** Invoices (stub — Bexio integration to be migrated) */
  @Get('invoices/:clientId')
  invoices(@Param('clientId', ParseIntPipe) clientId: number) {
    return [];
  }

  /** Tests / Performance data */
  @Get('tests/:clientId')
  tests(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getTests(clientId);
  }

  /** Training reviews (stub — to be connected to review module) */
  @Get('reviews/:clientId')
  reviews(@Param('clientId', ParseIntPipe) clientId: number) {
    return [];
  }

  /** Client files */
  @Get('files/:clientId')
  files(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getFiles(clientId);
  }

  /** Polar status */
  @Get('polar/status/:clientId')
  polarStatus(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.appService.getPolarStatus(clientId);
  }

  /** Polar sync (stub) */
  @Post('polar/sync/:clientId')
  polarSync(@Param('clientId', ParseIntPipe) clientId: number) {
    return { success: true, message: 'Polar sync not yet migrated' };
  }

  /** Polar disconnect (stub) */
  @Post('polar/disconnect/:clientId')
  polarDisconnect(@Param('clientId', ParseIntPipe) clientId: number) {
    return { success: true };
  }

  /** Book appointment */
  @Post('appointment/:clientId')
  book(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: any,
  ) {
    return this.appService.bookAppointment(clientId, body);
  }

  /** Cancel appointment */
  @Delete('appointment/:clientId/:appointmentId')
  cancel(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Param('appointmentId', ParseIntPipe) appointmentId: number,
  ) {
    return this.appService.cancelAppointment(clientId, appointmentId);
  }
}
