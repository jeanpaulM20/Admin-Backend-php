import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from '../entities/review.entity';
import { ReviewHeartRateTimeseries } from '../entities/review-heartrate-timeseries.entity';

@Injectable()
export class ReviewService {
  constructor(
    @InjectRepository(Review)
    private readonly reviewRepo: Repository<Review>,
    @InjectRepository(ReviewHeartRateTimeseries)
    private readonly timeseriesRepo: Repository<ReviewHeartRateTimeseries>,
  ) {}

  /**
   * Find all reviews for a given training.
   * Includes the heart-rate timeseries ordered by timestamp.
   */
  async findByTraining(trainingId: number) {
    return this.reviewRepo.find({
      where: { training_id: trainingId },
      relations: ['timeseries'],
      order: { id: 'ASC' },
    });
  }

  /**
   * Find reviews for a client via training → client_id join.
   * Uses QueryBuilder to avoid TypeORM camelCase/snake_case mapping issues.
   */
  async findByClient(clientId: number) {
    const rows = await this.reviewRepo
      .createQueryBuilder('review')
      .leftJoinAndSelect('review.training', 'training')
      .where('(training.client_id = :clientId OR review.client_id = :clientId)', { clientId })
      .orderBy('review.id', 'DESC')
      .getMany();
    return rows;
  }

  /** Single review with timeseries */
  async findOne(id: number) {
    return this.reviewRepo.findOne({
      where: { id },
      relations: ['timeseries', 'training'],
    });
  }

  /** Heart-rate timeseries for one review, ordered by timestamp */
  async getTimeseries(reviewId: number) {
    return this.timeseriesRepo.find({
      where: { review_id: reviewId },
      order: { timestamp: 'ASC' },
    });
  }

  create(data: Partial<Review>) {
    return this.reviewRepo.save(this.reviewRepo.create(data));
  }

  /**
   * App-recorded workout: standalone review (no booked training) plus
   * heart-rate timeseries, written in one transaction.
   */
  async createWorkout(input: {
    clientId: number;
    date: string;
    trainingType: string;
    duration: string | null;
    heartRate: number | null;
    kcal: number | null;
    hrSeries: { t: string; v: number }[];
  }): Promise<Review> {
    return this.reviewRepo.manager.transaction(async (manager) => {
      const review = await manager.getRepository(Review).save({
        client_id: input.clientId,
        date: input.date,
        training_type: input.trainingType,
        type: 'workout',
        duration: input.duration ?? undefined,
        heart_rate: input.heartRate ?? undefined,
        kcal: input.kcal ?? undefined,
        source: 'app',
      });

      const tsRepo = manager.getRepository(ReviewHeartRateTimeseries);
      const rows = input.hrSeries.map((p, i) => ({
        review_id: review.id,
        timestamp: p.t,
        value: p.v,
        sort: i,
      }));
      // Chunked insert — ein 2-h-Training hat ~7200 Punkte
      for (let i = 0; i < rows.length; i += 1000) {
        await tsRepo.insert(rows.slice(i, i + 1000));
      }
      return review;
    });
  }

  async update(id: number, data: Partial<Review>) {
    await this.reviewRepo.update(id, data);
    return this.findOne(id);
  }
}
