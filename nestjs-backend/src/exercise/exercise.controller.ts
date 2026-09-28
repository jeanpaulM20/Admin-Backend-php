import { Controller, Get, Post, Put, Delete, Param, Body, Query, Res, ParseIntPipe, BadRequestException, NotFoundException, ForbiddenException, UseInterceptors, UploadedFile, Inject } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import { ExerciseService } from './exercise.service';
import { ExerciseIconService } from './exercise-icon.service';
import { Exercise } from '../entities/exercise.entity';
import { Public } from '../auth/decorators/public.decorator';
import { CurrentTrainer } from '../auth/decorators/current-user.decorator';
import { Trainer } from '../entities/trainer.entity';
import { ImportCatalogUseCase } from './import/application/import-catalog.usecase';
import { REPDB_IMPORT, REFORMER_IMPORT } from './import/interface/catalog-import.provider';

@Controller('api/exercise')
export class ExerciseController {
  constructor(
    private readonly service: ExerciseService,
    private readonly iconService: ExerciseIconService,
    @Inject(REPDB_IMPORT) private readonly repDbImport: ImportCatalogUseCase,
    @Inject(REFORMER_IMPORT) private readonly reformerImport: ImportCatalogUseCase,
  ) {}

  /**
   * POST /api/exercise/import/reformer?dryRun=1 — Erfassungsblatt des Studios
   * einspielen. Das Blatt ist die Wahrheit: gesetzte Felder überschreiben den
   * Bestand, Federangaben werden ersetzt. Zeilen mit Fehlern (unbekannte
   * Kontraindikation, ungültige Federlast) bleiben draussen und stehen im
   * Bericht unter problems.
   */
  @Post('import/reformer')
  async importReformer(
    @CurrentTrainer() trainer: Trainer,
    @Query('dryRun') dryRun?: string,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können den Katalog importieren.');
    return this.reformerImport.execute({ dryRun: dryRun === '1' || dryRun === 'true' });
  }

  /**
   * POST /api/exercise/import/repdb?dryRun=1 — Katalog aus RepDB einspielen.
   * Nur für Trainer; mit dryRun=1 wird nur gezählt, nicht geschrieben.
   * Idempotent: ein zweiter Lauf erkennt die Einträge an source_ref wieder.
   */
  @Post('import/repdb')
  async importRepDb(
    @CurrentTrainer() trainer: Trainer,
    @Query('dryRun') dryRun?: string,
  ) {
    if (!trainer) throw new ForbiddenException('Nur Trainer können den Katalog importieren.');
    return this.repDbImport.execute({ dryRun: dryRun === '1' || dryRun === 'true' });
  }

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
    const limitNum = limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50;
    const delayNum = delay ? Math.min(Math.max(parseInt(delay, 10) || 2000, 500), 60_000) : 2000;
    return this.iconService.generateMissing({ limit: limitNum, delayMs: delayNum });
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

  /**
   * PUT /api/exercise/:id/icon/upload — manually upload a PNG/JPEG as icon.
   * Replaces any existing icon (AI-generated or previous upload).
   * Field name: "icon", max size: 5 MB.
   */
  @Put(':id/icon/upload')
  @UseInterceptors(FileInterceptor('icon', { limits: { fileSize: 5 * 1024 * 1024 } }))
  async uploadIcon(
    @Param('id', ParseIntPipe) id: number,
    @UploadedFile() file: { buffer: Buffer; mimetype: string; originalname: string },
  ) {
    if (!file) throw new BadRequestException('Kein Bild hochgeladen (field: icon)');
    const allowed = ['image/png', 'image/jpeg', 'image/webp'];
    if (!allowed.includes(file.mimetype)) {
      throw new BadRequestException('Nur PNG, JPEG oder WebP erlaubt');
    }
    const url = await this.iconService.saveIconBuffer(id, file.buffer);
    if (!url) throw new NotFoundException(`Übung ${id} nicht gefunden`);
    return { url, exerciseId: id };
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
