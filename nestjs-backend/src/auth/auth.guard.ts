import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthService } from './auth.service';

export const PUBLIC_KEY = 'isPublic';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly authService: AuthService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    // Accept token from header or query parameter (needed for file downloads
    // opened in new browser tabs where custom headers can't be sent)
    const token = request.headers['x-auth-token'] || request.query?.token;
    if (!token) throw new UnauthorizedException();

    const result = await this.authService.validateToken(token);
    if (!result) throw new UnauthorizedException();

    request.currentTrainer = result.trainer ?? null;
    request.currentClient = result.client ?? null;
    return true;
  }
}
