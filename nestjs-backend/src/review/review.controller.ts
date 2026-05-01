import {
  Controller, Get, Post, Put, Param, Body, Query,
  ParseIntPipe, HttpException, HttpStatus,
} from '@nestjs/common';
import { ReviewService } from './review.service';
import { Review } from '../entities/review.entity';

@Controller('api/review')
export class ReviewController {
  constructor(private readonly service: ReviewService) {}

  /**
   * GET /api/review?training_id=X  — reviews for one training session
   * GET /api/review?client_id=X    — all reviews for a client (across trainings)
   * GET /api/review                — (unused, returns empty array for safety)
   */
  @Get()
  async findAll(
    @Query('training_id') trainingId?: string,
    @Query('client_id') clientId?: string,
  ) {
    try {
      if (trainingId) {
        return await this.service.findByTraining(+trainingId);
      }
      if (clientId) {
        return await this.service.findByClient(+clientId);
      }
      return [];
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** GET /api/review/:id — single review with timeseries + training */
  @Get(':id')
  async findOne(@Param('id', ParseIntPipe) id: number) {
    try {
      const review = await this.service.findOne(id);
      if (!review) {
        throw new HttpException('Review not found', HttpStatus.NOT_FOUND);
      }
      return review;
    } catch (err) {
      if (err instanceof HttpException) throw err;
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** GET /api/review/:id/timeseries — heart-rate data points for chart */
  @Get(':id/timeseries')
  async getTimeseries(@Param('id', ParseIntPipe) id: number) {
    try {
      return await this.service.getTimeseries(id);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** POST /api/review — create a new review */
  @Post()
  async create(@Body() body: Partial<Review>) {
    try {
      return await this.service.create(body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }

  /** PUT /api/review/:id — update review */
  @Put(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<Review>,
  ) {
    try {
      return await this.service.update(id, body);
    } catch (err) {
      throw new HttpException(
        { message: err.message, detail: err.sqlMessage ?? null },
        HttpStatus.BAD_REQUEST,
      );
    }
  }
}
