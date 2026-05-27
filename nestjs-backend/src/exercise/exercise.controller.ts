import { Controller, Get, Post, Put, Delete, Param, Body, ParseIntPipe, BadRequestException } from '@nestjs/common';
import { ExerciseService } from './exercise.service';
import { Exercise } from '../entities/exercise.entity';
import { Public } from '../auth/decorators/public.decorator';

@Controller('api/exercise')
export class ExerciseController {
  constructor(private readonly service: ExerciseService) {}

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

  @Get()
  findAll() {
    return this.service.findAll();
  }

  @Get(':id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.service.findOne(id);
  }

  @Post()
  create(@Body() body: Partial<Exercise>) {
    return this.service.create(body);
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
