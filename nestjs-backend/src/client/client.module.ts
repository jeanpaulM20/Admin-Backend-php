import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Client } from '../entities/client.entity';
import { Clientaccesstoken } from '../entities/client-access-token.entity';
import { Training } from '../entities/training.entity';
import { Trainer } from '../entities/trainer.entity';
import { TrainerAvailability } from '../entities/trainer-availability.entity';
import { Location } from '../entities/location.entity';
import {
  ClientCredits, TrainingType, PerformanceTest, File as ClientFile,
} from '../entities/remaining.entities';
import { Feedback } from '../entities/feedback.entity';
import { ReviewModule } from '../review/review.module';
import { ClientService } from './client.service';
import { ClientAppService } from './client-app.service';
import { ClientChatService } from './client-chat.service';
import { ClientController } from './client.controller';
import { ClientAppController } from './client-php-proxy.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Client,
      Clientaccesstoken,
      Training,
      Trainer,
      TrainerAvailability,
      Location,
      ClientCredits,
      TrainingType,
      PerformanceTest,
      ClientFile,
      Feedback,
    ]),
    ReviewModule,
  ],
  providers: [ClientService, ClientAppService, ClientChatService],
  controllers: [ClientAppController, ClientController],
  exports: [ClientService],
})
export class ClientModule {}
