import { Controller, Get, Post, Delete, Param, Body, Query, ParseIntPipe, HttpException, HttpStatus, ForbiddenException } from '@nestjs/common';
import { FeedbackService } from './feedback.service';
import { PushService } from '../push/push.service';
import { Feedback } from '../entities/feedback.entity';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';

@Controller('api/feedback')
export class FeedbackController {
  constructor(
    private readonly service: FeedbackService,
    private readonly pushService: PushService,
  ) {}

  /**
   * GET /api/feedback/conversations?trainer_id=2 — efficient conversation list
   * Validates that the authenticated trainer matches the requested trainer_id.
   */
  @Get('conversations')
  getConversations(
    @CurrentTrainer() trainer: Trainer,
    @Query('trainer_id', ParseIntPipe) trainerId: number,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Konversationen abrufen');
    if (trainer.id !== trainerId) throw new ForbiddenException('Zugriff verweigert');
    return this.service.getTrainerConversations(trainerId);
  }

  /**
   * GET /api/feedback?client_id=123  — messages for one client (chat view)
   * GET /api/feedback                — all messages for the authenticated trainer
   */
  @Get()
  findAll(
    @CurrentTrainer() trainer: Trainer,
    @Query('client_id') clientId?: string,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Nachrichten abrufen');
    if (clientId) {
      return this.service.findByClient(+clientId);
    }
    return this.service.findAll();
  }

  /**
   * POST /api/feedback — send a new message (trainer → client).
   * Flutter sends camelCase body: { clientId, trainerId, message, readTrainer, readClient }
   * We map to snake_case entity properties.
   */
  @Post()
  async create(
    @CurrentTrainer() trainer: Trainer,
    @Body() body: any,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können hier Nachrichten senden');
    try {
      const readTrainer = body.read_trainer ?? body.readTrainer ?? 0;
      const readClient = body.read_client ?? body.readClient ?? 0;
      // Determine sender: trainer-sent = read_trainer=1 & read_client=0
      const senderType = (readTrainer === 1 && readClient === 0) ? 'trainer' : 'client';
      const data: Partial<Feedback> = {
        client_id: body.client_id ?? body.clientId,
        trainer_id: body.trainer_id ?? body.trainerId ?? trainer.id,
        text: body.text ?? body.message,
        sender_type: body.sender_type ?? senderType,
        read_trainer: readTrainer,
        read_client: readClient,
        is_circle: body.is_circle ?? body.isCircle ?? 0,
      };
      const saved = await this.service.create(data);

      // If trainer sent message to client → push notification
      if (saved.read_trainer === 1 && saved.read_client === 0 && saved.client_id) {
        this.pushService.sendToClient(saved.client_id, {
          title: 'Neue Nachricht',
          body: (saved.text ?? '').substring(0, 120),
          url: '/client/',
        }).catch(() => {}); // fire-and-forget
      }

      return saved;
    } catch (err) {
      throw new HttpException(
        { message: err.message ?? 'Nachricht konnte nicht gesendet werden' },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** POST /api/feedback/read-all?client_id=123 — batch mark all as read by trainer */
  @Post('read-all')
  markAllRead(
    @CurrentTrainer() trainer: Trainer,
    @Query('client_id', ParseIntPipe) clientId: number,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Nachrichten als gelesen markieren');
    return this.service.markAllReadByTrainer(clientId);
  }

  /** POST /api/feedback/:id/read — mark single message as read by trainer */
  @Post(':id/read')
  markRead(
    @CurrentTrainer() trainer: Trainer,
    @Param('id', ParseIntPipe) id: number,
  ) {
    if (!trainer) throw new ForbiddenException('Zugriff verweigert');
    // Always mark as read by trainer (trainer app context)
    return this.service.markRead(id, false);
  }

  @Delete(':id')
  remove(
    @CurrentTrainer() trainer: Trainer,
    @Param('id', ParseIntPipe) id: number,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können Nachrichten löschen');
    return this.service.remove(id);
  }
}
