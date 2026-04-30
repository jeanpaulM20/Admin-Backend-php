import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { APP_GUARD } from '@nestjs/core';
import { AuthService } from './auth.service';
import { AuthGuard } from './auth.guard';
import { Trainer } from '../entities/trainer.entity';
import { Clientaccesstoken } from '../entities/client-access-token.entity';

@Module({
  imports: [TypeOrmModule.forFeature([Trainer, Clientaccesstoken])],
  providers: [
    AuthService,
    {
      provide: APP_GUARD,
      useClass: AuthGuard,
    },
  ],
  exports: [AuthService],
})
export class AuthModule {}
