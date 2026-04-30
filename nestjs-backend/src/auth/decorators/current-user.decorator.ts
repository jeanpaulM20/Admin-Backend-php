import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentTrainer = createParamDecorator(
  (_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest().currentTrainer,
);

export const CurrentClient = createParamDecorator(
  (_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest().currentClient,
);
