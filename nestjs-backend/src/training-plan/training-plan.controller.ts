import { Controller, Get, Post, Put, Delete, Param, Body, Query, ParseIntPipe } from '@nestjs/common';
import { TrainingPlanService } from './training-plan.service';
import { AiPlanService } from './ai-plan.service';
import { TrainingPlan } from '../entities/training-plan.entity';
import { CurrentClient } from '../auth/decorators/current-user.decorator';
import { Client } from '../entities/client.entity';
import { Public } from '../auth/decorators/public.decorator';

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

  /** TEMPORARY test endpoint — remove after verifying 0-value fix */
  @Public()
  @Get('ai/test/:clientId')
  testRecommend(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.aiService.generateAiPlan(clientId);
  }

  @Get()
  findAll(@CurrentClient() client: Client, @Query('client_id') clientId?: number) {
    return this.service.findAll(client?.id ?? clientId);
  }

  /**
   * Preview AI plan without saving — trainer can review before committing.
   * GET /api/training-plan/ai/recommend/:clientId
   *
   * Returns: AiPlanResult with sonsomo, main, core rows + ai_reasoning
   * Falls back to rule-based generation if ANTHROPIC_API_KEY is not set.
   */
  @Get('ai/recommend/:clientId')
  recommend(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.aiService.generateAiPlan(clientId);
  }

  // NB: :id route MUST come after /ai/* routes to avoid "ai" matching as :id
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
   * Returns: { plan: TrainingPlan, meta: { ai_reasoning, weaknesses, ... } }
   */
  @Post('ai/generate/:clientId')
  generate(@Param('clientId', ParseIntPipe) clientId: number) {
    return this.aiService.generateAndSave(clientId);
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
}
