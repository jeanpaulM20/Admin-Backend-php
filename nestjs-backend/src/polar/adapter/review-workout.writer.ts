import type { ReviewService } from '../../review/review.service';
import type { WorkoutDraft } from '../domain/workout-mapping';
import type { WorkoutWriter } from '../application/ports';

/**
 * Polar-Trainings laufen durch dieselbe Speicherung wie App-Aufzeichnungen —
 * so erscheinen sie ohne Sonderweg in Analytics und im Trainer-Chat.
 */
export class ReviewWorkoutWriter implements WorkoutWriter {
  constructor(private readonly reviews: ReviewService) {}

  async write(clientId: number, draft: WorkoutDraft): Promise<number> {
    const review = await this.reviews.createWorkout({
      clientId,
      clientRecordingId: null,
      source: 'polar',
      ...draft,
    });
    return review.id;
  }
}
