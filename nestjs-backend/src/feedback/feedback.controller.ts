import { Controller, Get, Post, Delete, Param, Body, Query, ParseIntPipe, HttpException, HttpStatus } from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { Feedback } from '../entities/feedback.entity';

@Controller('api/feedback')
export class FeedbackController {
  constructor(private readonly service: FeedbackService) {}

  /**
   * GET /api/feedback?client_id=123  — messages for one client (chat view)
   * GET /api/feedback                — all messages (Nachrichten thread list)
   */
  @Get()
  findAll(@Query('client_id') clientId?: string) {
    if (clientId) {
      return this.service.findByClient(+clientId);
    }
    return this.service.findAll();
  }

  /**
   * POST /api/feedback — send a new message.
   * Flutter sends camelCase body: { clientId, trainerId, message, readTrainer, readClient }
   * We map to snake_case entity properties.
   */
  @Post()
  async create(@Body() body: any) {
    try {
      const data: Partial<Feedback> = {
        client_id: body.client_id ?? body.clientId,
        trainer_id: body.trainer_id ?? body.trainerId,
        text: body.text ?? body.message,
        read_trainer: body.read_trainer ?? body.readTrainer ?? 0,
        read_client: body.read_client ?? body.readClient ?? 0,
        is_circle: body.is_circle ?? body.isCircle ?? 0,
      };
      return await this.service.create(data);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** POST /api/feedback/:id/read — mark message as read by trainer */
  @Post(':id/read')
  markRead(@Param('id', ParseIntPipe) id: number) {
    // Always mark as read by trainer (trainer app context)
    return this.service.markRead(id, false);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
