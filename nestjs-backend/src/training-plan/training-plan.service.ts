import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { TrainingPlan } from '../entities/training-plan.entity';
import { TrainingPlanComment } from '../entities/training-plan-comment.entity';

@Injectable()
export class TrainingPlanService {
  constructor(
    @InjectRepository(TrainingPlan)
    private readonly repo: Repository<TrainingPlan>,
    @InjectRepository(TrainingPlanComment)
    private readonly commentRepo: Repository<TrainingPlanComment>,
  ) {}

  findAll(clientId?: number) {
    return this.repo.find({
      where: clientId ? { clientId } : {},
      relations: ['client'],
    });
  }

  async findOne(id: number) {
    const plan = await this.repo.findOne({
      where: { id },
      relations: ['client'],
    });
    if (!plan) throw new NotFoundException(`TrainingPlan ${id} not found`);
    return plan;
  }

  create(data: Partial<TrainingPlan>) {
    if (data.values) this.validateValues(data.values);
    return this.repo.save(this.repo.create(data));
  }

  async update(id: number, data: Partial<TrainingPlan>) {
    await this.findOne(id);
    if (data.values) this.validateValues(data.values);
    await this.repo.update(id, data);
    return this.findOne(id);
  }

  async remove(id: number) {
    const plan = await this.findOne(id);
    return this.repo.remove(plan);
  }

  // ─── Comments ──────────────────────────────────────────────────────────

  async getComments(planId: number, exerciseKey?: string): Promise<TrainingPlanComment[]> {
    await this.findOne(planId); // ensure plan exists
    const where: any = { planId };
    if (exerciseKey) {
      where.exerciseKey = exerciseKey;
    } else {
      // Plan-level comments only (exerciseKey IS NULL)
      where.exerciseKey = IsNull();
    }
    return this.commentRepo.find({
      where,
      order: { createdAt: 'ASC' },
    });
  }

  /** Count comments per exercise key for a plan (for badge display) */
  async getCommentCounts(planId: number): Promise<Record<string, number>> {
    const rows = await this.commentRepo
      .createQueryBuilder('c')
      .select('c.exercise_key', 'exerciseKey')
      .addSelect('COUNT(*)', 'count')
      .where('c.plan_id = :planId', { planId })
      .andWhere('c.exercise_key IS NOT NULL')
      .groupBy('c.exercise_key')
      .getRawMany();
    const result: Record<string, number> = {};
    for (const r of rows) {
      result[r.exerciseKey] = parseInt(r.count, 10);
    }
    return result;
  }

  async addComment(
    planId: number,
    trainerId: number | undefined,
    authorName: string,
    text: string,
    exerciseKey?: string,
  ): Promise<TrainingPlanComment> {
    await this.findOne(planId); // ensure plan exists
    const comment = this.commentRepo.create({
      planId, trainerId, authorName, text,
      ...(exerciseKey ? { exerciseKey } : {}),
    } as any);
    return this.commentRepo.save(comment as any);
  }

  async removeComment(commentId: number): Promise<void> {
    const comment = await this.commentRepo.findOne({ where: { id: commentId } });
    if (!comment) throw new NotFoundException(`Comment ${commentId} not found`);
    await this.commentRepo.remove(comment);
  }

  // ─── Values JSON validation ─────────────────────────────────────────────

  private validateValues(raw: string): void {
    let parsed: any;
    try {
      parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    } catch {
      throw new BadRequestException('values must be valid JSON');
    }

    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      throw new BadRequestException('values must be a JSON object');
    }

    const sections = ['sonsomo', 'main', 'core', 'mobility'];
    for (const key of sections) {
      if (parsed[key] !== undefined && !Array.isArray(parsed[key])) {
        throw new BadRequestException(`values.${key} must be an array`);
      }
      if (Array.isArray(parsed[key])) {
        for (let i = 0; i < parsed[key].length; i++) {
          const row = parsed[key][i];
          if (typeof row !== 'object' || row === null || Array.isArray(row)) {
            throw new BadRequestException(`values.${key}[${i}] must be an object`);
          }
          // Validate dates array if present
          if (row.dates !== undefined && !Array.isArray(row.dates)) {
            throw new BadRequestException(`values.${key}[${i}].dates must be an array`);
          }
        }
      }
    }

    // Validate top-level dates array
    if (parsed.dates !== undefined && !Array.isArray(parsed.dates)) {
      throw new BadRequestException('values.dates must be an array');
    }
  }
}
