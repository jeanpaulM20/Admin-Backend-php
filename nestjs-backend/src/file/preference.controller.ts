import { Controller, Get, Post, Body } from '@nestjs/common';

/**
 * Stub for legacy preference endpoint.
 * Returns empty preferences so the trainer settings screen doesn't crash.
 */
@Controller('api/preference')
export class PreferenceController {
  @Get()
  getPreferences() {
    return {};
  }

  @Post()
  updatePreferences(@Body() body: any) {
    // Stub — preferences not yet persisted in NestJS
    return { success: true, ...body };
  }
}
