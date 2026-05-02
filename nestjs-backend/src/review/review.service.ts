import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Review } from '../entities/review.entity';
import { Reviewheartratetimeseries } from '../entities/review-heartrate-timeseries.entity';

@Injectable()
export class ReviewService {
  constructor(
    @InjectRepository(Review)
    private readonly reviewRepo: Repository<Review>,
    @InjectRepository(Reviewheartratetimeseries)
    private readonly timeseriesRepo: Repository<Reviewheartratetimeseries>,
  ) {}

  /**
   * Find all reviews for a given training.
   * Includes the heart-rate timeseries ordered by `sort`.
   */
  async findByTraining(trainingId: number) {
    return this.reviewRepo.find({
      where: { trainingId },
      relations: ['heartRateTimeseries'],
      order: { id: 'ASC' },
    });
  }

  /**
   * Find reviews for a client via training → client_id join.
   * Uses raw SQL sub-query to avoid TypeORM camelCase/snake_case mapping issues.
   */
  async findByClient(clientId: number) {
    // Get training IDs for this client first, then find reviews
    const rows = await this.reviewRepo
      .createQueryBuilder('review')
      .leftJoinAndSelect('review.training', 'training')
      .where('training.client_id = :clientId', { clientId })
      .orderBy('review.id', 'DESC')
      .getMany();
    return rows;
  }

  /** Single review with timeseries */
  async findOne(id: number) {
    return this.reviewRepo.findOne({
      where: { id },
      relations: ['heartRateTimeseries', 'training'],
    });
  }

  /** Heart-rate timeseries for one review, ordered by sort */
  async getTimeseries(reviewId: number) {
    return this.timeseriesRepo.find({
      where: { reviewId },
      order: { timestamp: 'ASC' },
    });
  }

  create(data: Partial<Review>) {
    return this.reviewRepo.save(this.reviewRepo.create(data));
  }

  async update(id: number, data: Partial<Review>) {
    await this.reviewRepo.update(id, data);
    return this.findOne(id);
  }
}
