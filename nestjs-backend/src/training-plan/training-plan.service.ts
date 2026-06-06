import { Injectable, NotFoundException, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, DataSource } from 'typeorm';
import { TrainingPlan } from '../entities/training-plan.entity';
import { TrainingPlanComment } from '../entities/training-plan-comment.entity';
import { TrainingPlanLike } from '../entities/training-plan-like.entity';
import { RealtimeService } from '../realtime/realtime.service';
import { PushService } from '../push/push.service';

@Injectable()
export class TrainingPlanService {
  constructor(
    @InjectRepository(TrainingPlan)
    private readonly repo: Repository<TrainingPlan>,
    @InjectRepository(TrainingPlanComment)
    private readonly commentRepo: Repository<TrainingPlanComment>,
    @InjectRepository(TrainingPlanLike)
    private readonly likeRepo: Repository<TrainingPlanLike>,
    private readonly realtime: RealtimeService,
    private readonly dataSource: DataSource,
    private readonly pushService: PushService,
  ) {}

  private readonly logger = new Logger(TrainingPlanService.name);

  /** Notify the client (and any trainer watching) that a plan changed. */
  private notifyPlanChanged(plan: { id: number; clientId: number }): void {
    this.realtime.emitToClient(plan.clientId, 'plan_updated', { planId: plan.id });
  }

  /** Throws if the plan is not published — used for client-facing write actions. */
  private assertPublished(plan: any): void {
    if ((plan as any).status !== 'published') {
      throw new ForbiddenException('Dieser Plan ist noch nicht freigegeben');
    }
  }

  findAll(clientId?: number, publishedOnly = false) {
    const where: any = clientId ? { clientId } : {};
    if (publishedOnly) where.status = 'published';
    return this.repo.find({
      where,
      relations: ['client'],
      // Newest / most recently edited first.
      // Fallback to id for legacy rows without timestamps.
      order: { updatedAt: 'DESC', id: 'DESC' },
    });
  }

  async findOne(id: number, clientId?: number) {
    const plan = await this.repo.findOne({
      where: { id },
      relations: ['client'],
    });
    if (!plan) throw new NotFoundException(`TrainingPlan ${id} not found`);
    if (clientId) {
      const likes = await this.getClientLikes(clientId, id);
      return { ...plan, clientLikes: likes };
    }
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
    const updated = await this.findOne(id);
    this.notifyPlanChanged(updated);
    return updated;
  }

  async remove(id: number) {
    const plan = await this.findOne(id);
    return this.repo.remove(plan);
  }

  // ─── Publication ───────────────────────────────────────────────────────

  /** Release a plan to the client. publishedAt is set once (not reset on
   *  re-publish) so the free-access window can't be gamed by toggling. */
  async publish(id: number) {
    const plan = await this.findOne(id);
    const updates: Partial<TrainingPlan> = { status: 'published' };
    if (!plan.publishedAt) updates.publishedAt = new Date();
    await this.repo.update(id, updates);
    const updated = await this.findOne(id);
    this.notifyPlanChanged(updated);
    return updated;
  }

  /** Revert to draft (hides it from the client again). publishedAt is kept. */
  async unpublish(id: number) {
    await this.findOne(id);
    await this.repo.update(id, { status: 'draft' });
    const updated = await this.findOne(id);
    this.notifyPlanChanged(updated);
    return updated;
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
    clientId?: number,
    senderType: 'trainer' | 'client' = 'trainer',
  ): Promise<TrainingPlanComment> {
    const plan = await this.findOne(planId); // ensure plan exists
    const comment = this.commentRepo.create({
      planId, trainerId, authorName, text,
      ...(exerciseKey ? { exerciseKey } : {}),
      ...(clientId ? { clientId } : {}),
      senderType,
    } as any);
    const saved = await this.commentRepo.save(comment as any);
    this.realtime.emitToClient(plan.clientId, 'plan_comment', { planId, exerciseKey: exerciseKey ?? null });
    // Push notification to client when a trainer adds a comment
    if (senderType === 'trainer' && plan.clientId) {
      const snippet = text.length > 80 ? text.substring(0, 80) + '…' : text;
      this.pushService.sendToClient(plan.clientId, {
        title: exerciseKey ? `${authorName} hat eine Übung kommentiert` : `${authorName} hat deinen Plan kommentiert`,
        body: snippet,
        url: '/client/',
      }).catch(() => {}); // non-blocking — push failure must not abort comment save
    }
    return saved;
  }

  async removeComment(
    commentId: number,
    requestingTrainerId?: number,
    requestingClientId?: number,
  ): Promise<void> {
    const comment = await this.commentRepo.findOne({ where: { id: commentId } });
    if (!comment) throw new NotFoundException(`Comment ${commentId} not found`);

    // Verify the requesting user is associated with this plan
    const plan = await this.findOne(comment.planId);
    const trainerOwnsComment = requestingTrainerId && comment.trainerId === requestingTrainerId;
    const clientOwnsComment  = requestingClientId  && comment.clientId  === requestingClientId;

    if (!trainerOwnsComment && !clientOwnsComment) {
      throw new ForbiddenException('Nur eigene Kommentare können gelöscht werden');
    }

    // Extra: clients can only delete comments on their own plan
    if (requestingClientId && (plan as any).clientId !== requestingClientId) {
      throw new ForbiddenException('Zugriff verweigert');
    }

    await this.commentRepo.remove(comment);
  }

  // ─── Client: like/dislike per exercise ─────────────────────────────────────

  /** Toggle a like or dislike. Returns the updated like map for the client. */
  async toggleLike(
    clientId: number,
    planId: number,
    exerciseKey: string,
    type: 'like' | 'dislike',
  ): Promise<Record<string, 'like' | 'dislike'>> {
    const plan = await this.findOne(planId);
    if ((plan as any).clientId !== clientId) throw new ForbiddenException('Zugriff verweigert');
    this.assertPublished(plan);

    const existing = await this.likeRepo.findOne({
      where: { planId, clientId, exerciseKey },
    });

    if (existing) {
      if (existing.type === type) {
        // Same type → remove (toggle off)
        await this.likeRepo.remove(existing);
      } else {
        // Different type → switch
        existing.type = type;
        await this.likeRepo.save(existing);
      }
    } else {
      await this.likeRepo.save(
        this.likeRepo.create({ planId, clientId, exerciseKey, type }),
      );
    }

    return this.getClientLikes(clientId, planId);
  }

  /** All like/dislike entries for a client on a plan, keyed by exerciseKey. */
  async getClientLikes(
    clientId: number,
    planId: number,
  ): Promise<Record<string, 'like' | 'dislike'>> {
    const rows = await this.likeRepo.find({ where: { planId, clientId } });
    const map: Record<string, 'like' | 'dislike'> = {};
    for (const r of rows) map[r.exerciseKey] = r.type as 'like' | 'dislike';
    return map;
  }

  // ─── Client: save training results (dates columns only) ────────────────────

  /**
   * Merges only the per-exercise `dates` arrays from the client submission into
   * the plan's values JSON. All other fields (exercise name, device, timers, etc.)
   * are preserved from the trainer's plan — the client can't overwrite them.
   */
  async saveClientResults(
    clientId: number,
    planId: number,
    submittedValues: any,
  ): Promise<void> {
    const plan = await this.findOne(planId);
    if ((plan as any).clientId !== clientId) throw new ForbiddenException('Zugriff verweigert');
    this.assertPublished(plan);

    let current: any = {};
    try {
      current = typeof (plan as any).values === 'string'
        ? JSON.parse((plan as any).values)
        : ((plan as any).values ?? {});
    } catch { /* keep empty */ }

    const submitted = typeof submittedValues === 'string'
      ? JSON.parse(submittedValues)
      : (submittedValues ?? {});

    // Merge ONLY the dates arrays — nothing else
    for (const section of ['sonsomo', 'main', 'core', 'mobility']) {
      if (!Array.isArray(current[section])) continue;
      for (let i = 0; i < current[section].length; i++) {
        if (Array.isArray(submitted?.[section]?.[i]?.dates)) {
          current[section][i].dates = submitted[section][i].dates;
        }
      }
    }

    await this.repo.update(planId, { values: JSON.stringify(current) });
    // Do NOT emit plan_updated here — that would trigger a re-fetch in the
    // client app and interrupt the user while they are still typing results.
    // Trainer edits (update/publish) are the ones that warrant a live reload.

    // Notify assigned trainer(s) that the client logged training (fire-and-forget)
    this.notifyTrainersClientTrained(clientId, (plan as any).name ?? 'Trainingsplan').catch(
      (err) => this.logger.warn(`Trainer-notification failed: ${err.message}`),
    );
  }

  /**
   * Creates a system chat message for each trainer assigned to the client.
   * Appears in the trainer's Nachrichten screen — persistent even if offline.
   * SSE 'client_trained' is also emitted so open trainer screens react live.
   */
  private async notifyTrainersClientTrained(clientId: number, planName: string): Promise<void> {
    // Find all trainers assigned to this client
    const trainerRows: { trainer_id: number }[] = await this.dataSource.query(
      'SELECT trainer_id FROM trainer_client WHERE client_id = ?',
      [clientId],
    );
    if (!trainerRows?.length) return;

    const text = `✅ Hat Training erfasst — ${planName}`;

    for (const row of trainerRows) {
      try {
        await this.dataSource.query(
          `INSERT INTO feedback (client_id, trainer_id, text, sender_type, is_circle,
            read_client, read_trainer, created_at)
           VALUES (?, ?, ?, 'client', 1, 1, 0, NOW())`,
          [clientId, row.trainer_id, text],
        );
      } catch (err: any) {
        this.logger.warn(`Insert trainer notification failed: ${err.message}`);
      }
    }
    // SSE ping so trainer's open chat screen refreshes without reload
    this.realtime.emitToClient(clientId, 'client_trained', { planName });
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
