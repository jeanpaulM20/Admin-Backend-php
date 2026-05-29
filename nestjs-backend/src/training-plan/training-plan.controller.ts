import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe, BadRequestException } from '@nestjs/common';
import { TrainingPlanService } from './training-plan.service';
import { AiPlanService } from './ai-plan.service';
import { TrainingPlan } from '../entities/training-plan.entity';
import { TrainingPlanComment } from '../entities/training-plan-comment.entity';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Client } from '../entities/client.entity';
import { Trainer } from '../entities/trainer.entity';
import { AiPlanRequest, AI_TRAINING_TYPES, AI_DURATIONS, AI_EQUIPMENT_OPTIONS, AI_AUSDAUER_INTENSITIES } from './ai-plan.interfaces';

@Controller('api/training-plan')
export class TrainingPlanController {
  constructor(
    private readonly service: TrainingPlanService,
    private readonly aiService: AiPlanService,
  ) {}

  /** Debug endpoint — shows AI provider status (auth required) */
  @Get('ai/status')
  aiStatus(@Query('test') test?: string) {
    return this.aiService.getProviderStatus(test === 'true');
  }

  /** Temporary deploy check — remove after verifying */
  @Get('version')
  getVersion() {
    return { version: 'd6f2fa4-v2', routes: ['comment-counts', 'comments'], ts: new Date().toISOString() };
  }

  @Get()
  findAll(@CurrentClient() client: Client, @Query('client_id') clientId?: number) {
    return this.service.findAll(client?.id ?? clientId);
  }

  /**
   * Preview AI plan without saving — trainer can review before committing.
   * POST /api/training-plan/ai/recommend/:clientId
   *
   * Body: { trainingType, duration, equipment }
   * Returns: AiPlanResult with sonsomo, main, core rows + ai_reasoning
   * Falls back to rule-based generation if ANTHROPIC_API_KEY is not set.
   *
   * Also accepts GET for backward compatibility (uses defaults).
   */
  @Post('ai/recommend/:clientId')
  recommend(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: any,
  ) {
    const request = this.validatePlanRequest(body);
    return this.aiService.generateAiPlan(clientId, request);
  }

  /** GET kept for backward compatibility — generates with default params */
  @Get('ai/recommend/:clientId')
  recommendGet(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.aiService.generateAiPlan(clientId);
  }

  /** GET /api/training-plan/:id/comments — list comments for a plan or exercise */
  @Get(':id/comments')
  getComments(
    @Param('id', ParseIntPipe) planId: number,
    @Query('exerciseKey') exerciseKey?: string,
  ) {
    return this.service.getComments(planId, exerciseKey);
  }

  /** GET /api/training-plan/:id/comment-counts — comment counts per exercise */
  @Get(':id/comment-counts')
  getCommentCounts(@Param('id', ParseIntPipe) planId: number) {
    return this.service.getCommentCounts(planId);
  }

  // NB: :id route MUST come after /ai/* and multi-segment routes to avoid "ai" matching as :id
  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: any) {
    // Flutter sends snake_case (client_id), but TypeORM entity uses camelCase (clientId)
    const mapped: Partial<TrainingPlan> = {
      ...body,
      clientId: body.clientId ?? body.client_id,
    };
    delete (mapped as any).client_id;
    return this.service.create(mapped);
  }

  /**
   * Generate AI plan AND persist to DB + auto-create new exercises.
   * POST /api/training-plan/ai/generate/:clientId
   *
   * Body: { trainingType, duration, equipment }
   * Returns: { plan: TrainingPlan, meta: { ai_reasoning, weaknesses, ... } }
   */
  @Post('ai/generate/:clientId')
  generate(
    @Param('clientId', ParseIntPipe) clientId: number,
    @Body() body: any,
  ) {
    const request = this.validatePlanRequest(body);
    return this.aiService.generateAndSave(clientId, request);
  }

  // ── Validation helper ──────────────────────────────────────────────────

  private validatePlanRequest(body: any): AiPlanRequest {
    if (!body || typeof body !== 'object') {
      throw new BadRequestException('Request body fehlt');
    }

    const { trainingType, duration, equipment, ausdauerIntensity } = body;

    // trainingType — required, must be one of the allowed values
    if (!trainingType || !AI_TRAINING_TYPES.includes(trainingType)) {
      throw new BadRequestException(
        `trainingType muss einer der Werte sein: ${AI_TRAINING_TYPES.join(', ')}`,
      );
    }

    // ausdauerIntensity — optional, only valid for trainingType 'ausdauer'
    let intensity: AiPlanRequest['ausdauerIntensity'] = undefined;
    if (ausdauerIntensity !== undefined && ausdauerIntensity !== null) {
      if (trainingType !== 'ausdauer') {
        throw new BadRequestException('ausdauerIntensity ist nur für trainingType "ausdauer" erlaubt');
      }
      if (!AI_AUSDAUER_INTENSITIES.includes(ausdauerIntensity)) {
        throw new BadRequestException(
          `ausdauerIntensity muss einer der Werte sein: ${AI_AUSDAUER_INTENSITIES.join(', ')}`,
        );
      }
      intensity = ausdauerIntensity;
    }

    // duration — optional, null = frei, otherwise 30/45/60
    const durNum = duration === undefined || duration === null ? null : Number(duration);
    if (durNum !== null && ![30, 45, 60].includes(durNum)) {
      throw new BadRequestException('duration muss 30, 45, 60 oder null sein');
    }
    const dur = durNum as AiPlanRequest['duration'];

    // equipment — optional, null = frei, otherwise array of valid equipment
    let equip: AiPlanRequest['equipment'] = null;
    if (equipment !== undefined && equipment !== null) {
      if (!Array.isArray(equipment)) {
        throw new BadRequestException('equipment muss ein Array oder null sein');
      }
      const invalid = equipment.filter((e: any) => !AI_EQUIPMENT_OPTIONS.includes(e));
      if (invalid.length > 0) {
        throw new BadRequestException(
          `Ungültige Geräte: ${invalid.join(', ')}. Erlaubt: ${AI_EQUIPMENT_OPTIONS.join(', ')}`,
        );
      }
      equip = equipment.length > 0 ? equipment : null;
    }

    return {
      trainingType,
      duration: dur,
      equipment: equip,
      ...(intensity ? { ausdauerIntensity: intensity } : {}),
    };
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: any) {
    // Flutter sends snake_case (client_id), but TypeORM entity uses camelCase (clientId)
    const mapped: Partial<TrainingPlan> = {
      ...body,
      clientId: body.clientId ?? body.client_id,
    };
    delete (mapped as any).client_id;
    return this.service.update(id, mapped);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }

  // ── Comments (POST / DELETE) ────────────────────────────────────────

  /** POST /api/training-plan/:id/comments — add a comment */
  @Post(':id/comments')
  addComment(
    @Param('id', ParseIntPipe) planId: number,
    @CurrentTrainer() trainer: Trainer,
    @Body() body: { text: string; exerciseKey?: string },
  ) {
    const text = (body.text ?? '').trim();
    if (!text) throw new BadRequestException('Kommentar darf nicht leer sein');
    const authorName = trainer
      ? `${trainer.firstname ?? ''} ${trainer.lastname ?? ''}`.trim() || 'Trainer'
      : 'Unbekannt';
    return this.service.addComment(planId, trainer?.id, authorName, text, body.exerciseKey);
  }

  /** DELETE /api/training-plan/comments/:commentId — delete a comment */
  @Delete('comments/:commentId')
  removeComment(@Param('commentId', ParseIntPipe) commentId: number) {
    return this.service.removeComment(commentId);
  }
}
