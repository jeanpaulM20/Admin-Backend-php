import { Controller, Get, Post, Delete, Param, Body, ParseIntPipe } from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { Feedback } from '../entities/feedback.entity';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Client } from '../entities/client.entity';
import { Trainer } from '../entities/trainer.entity';

@Controller('api/feedback')
export class FeedbackController {
  constructor(private readonly service: FeedbackService) {}

  @Get()
  findAll(@CurrentClient() client: Client) {
    return this.service.findByClient(client?.id);
  }

  @Post()
  create(
    @Body() body: Partial<Feedback>,
    @CurrentClient() client: Client,
    @CurrentTrainer() trainer: Trainer,
  ) {
    return this.service.create({
      ...body,
      clientId: body.clientId ?? client?.id,
      trainerId: body.trainerId ?? trainer?.id,
    });
  }

  @Post(':id/read')
  markRead(
    @Param('id', ParseIntPipe) id: number,
    @CurrentClient() client: Client,
  ) {
    return this.service.markRead(id, !!client);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
