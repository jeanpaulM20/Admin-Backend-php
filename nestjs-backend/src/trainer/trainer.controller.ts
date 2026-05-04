import {
  Controller, Get, Post, Put, Delete, Param, Body, Query,
  ParseIntPipe, HttpException, HttpStatus,
} from '@nestjs/common';
import { createHash } from 'crypto';
import { TrainerService } from './trainer.service';
import { Trainer } from '../entities/trainer.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';

const AUTH_SALT = process.env.AUTH_SALT ?? 'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';

@Controller('api/trainer')
export class TrainerController {
  constructor(private readonly service: TrainerService) {}

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get('me')
  getMe(@CurrentTrainer() trainer: Trainer) {
    return trainer;
  }

  /** GET /api/trainer/qr?id=X — QR code for trainer (returns qrcode field) */
  @Get('qr')
  async getQr(@Query('id') id?: string, @CurrentTrainer() trainer?: Trainer) {
    const trainerId = id ? +id : trainer?.id;
    if (!trainerId) {
      throw new HttpException('Trainer ID required', HttpStatus.BAD_REQUEST);
    }
    const t = await this.service.findOne(trainerId);
    if (t.qrcode) {
      return { code: t.qrcode };
    }
    return { message: 'QR code not available for this trainer' };
  }

  /** GET /api/trainer/aboutus — studio info stub */
  @Get('aboutus')
  getAboutUs() {
    return {
      name: 'Sihl Training',
      description: '',
      address: '',
      phone: '',
      email: '',
      website: '',
    };
  }

  /** POST /api/trainer/password — change trainer password */
  @Post('password')
  async changePassword(
    @Body() body: { password?: string },
    @CurrentTrainer() trainer: Trainer,
  ) {
    if (!body.password || body.password.length < 4) {
      throw new HttpException(
        'Password must be at least 4 characters',
        HttpStatus.BAD_REQUEST,
      );
    }
    await this.service.updatePasscode(trainer.id, body.password);
    return { success: true, message: 'Password updated' };
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Trainer>) {
    return this.service.create(body);
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Trainer>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
