import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ClientAnamnese } from '../entities/client-anamnese.entity';
import { AnamneseController } from './anamnese.controller';
import { AnamneseService } from './anamnese.service';

@Module({
  imports: [TypeOrmModule.forFeature([ClientAnamnese])],
  controllers: [AnamneseController],
  providers: [AnamneseService],
})
export class AnamneseModule {}
