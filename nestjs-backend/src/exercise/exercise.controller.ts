import { Controller, Get, Post, Put, Delete, Param, Body, Query, Res, ParseIntPipe, BadRequestException, NotFoundException } from '@nestjs/common';
import { Response } from 'express';
import { ExerciseService } from './exercise.service';
import { ExerciseIconService } from './exercise-icon.service';
import { Exercise } from '../entities/exercise.entity';
import { Public } from '../auth/decorators/public.decorator';

@Controller('api/exercise')
export class ExerciseController {
  constructor(
    private readonly service: ExerciseService,
    private readonly iconService: ExerciseIconService,
  ) {}

  @Get('groups')
  findGroups() {
    return this.service.findGroups();
  }

  /**
   * POST /api/exercise/verify — AI spell-check & validation before creation.
   * Body: { name: string, groupName?: string, bodyRegion?: string }
   * Returns: ExerciseVerifyResult with correctedName, corrections[], summary
   */
  @Post('verify')
  verify(@Body() body: { name: string; groupName?: string; bodyRegion?: string }) {
    if (!body?.name || typeof body.name !== 'string') {
      throw new BadRequestException('name ist erforderlich');
    }
    return this.service.verifyExercise(body.name, body.groupName, body.bodyRegion);
  }

  /**
   * POST /api/exercise/seed — idempotent: inserts missing exercises, skips existing
   * Public so it can be triggered without auth during setup.
   */
  @Public()
  @Post('seed')
  seed() {
    return this.service.seed();
  }

  // ── Icon generation endpoints ─────────────────────────────────────────

  /** GET /api/exercise/icons/status — how many exercises have icons */
  @Get('icons/status')
  iconStatus() {
    return this.iconService.getStatus();
  }

  /** DELETE /api/exercise/icons/all — delete all icons (for regeneration with new style) */
  @Delete('icons/all')
  async deleteAllIcons() {
    return this.iconService.deleteAllIcons();
  }

  /** POST /api/exercise/icons/batch — generate missing icons (limit=50, delayMs=2000) */
  @Post('icons/batch')
  generateBatch(
    @Query('limit') limit?: string,
    @Query('delay') delay?: string,
  ) {
    return this.iconService.generateMissing({
      limit: limit ? parseInt(limit, 10) : 50,
      delayMs: delay ? parseInt(delay, 10) : 2000,
    });
  }

  /** GET /api/exercise/:id/icon.png — serve the icon as PNG image */
  @Public()
  @Get(':id/icon.png')
  async serveIcon(
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const buffer = await this.iconService.getIconBuffer(id);
    if (!buffer) throw new NotFoundException('Icon nicht vorhanden');
    res.set({
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=86400',
    });
    res.send(buffer);
  }

  /** POST /api/exercise/:id/icon — generate or regenerate icon */
  @Post(':id/icon')
  async generateIcon(@Param('id', ParseIntPipe) id: number) {
    await this.iconService.deleteIcon(id);
    try {
      const url = await this.iconService.generateIcon(id);
      if (!url) throw new BadRequestException('Icon-Generierung fehlgeschlagen');
      return { url, exerciseId: id };
    } catch (err: any) {
      throw new BadRequestException(`Icon-Generierung fehlgeschlagen: ${err.message}`);
    }
  }

  /** DELETE /api/exercise/:id/icon — delete an icon */
  @Delete(':id/icon')
  async deleteIcon(@Param('id', ParseIntPipe) id: number) {
    const deleted = await this.iconService.deleteIcon(id);
    return { deleted, exerciseId: id };
  }

  // ── CRUD endpoints ──────────────────────────────────────────────────────

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  async create(@Body() body: Partial<Exercise>) {
    const exercise = await this.service.create(body);
    // Auto-generate icon in background (don't block the response)
    if (exercise?.id) {
      this.iconService.generateIcon(exercise.id).catch(() => {});
    }
    return exercise;
  }

  @Put(':id')
  update(@Param('id', ParseIntPipe) id: number, @Body() body: Partial<Exercise>) {
    return this.service.update(id, body);
  }

  @Delete(':id')
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.service.remove(id);
  }
}
