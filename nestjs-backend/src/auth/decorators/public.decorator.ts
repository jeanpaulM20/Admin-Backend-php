import { SetMetadata } from '@nestjs/common';
import { PUBLIC_KEY } from '../auth.guard';

export const Public = () => SetMetadata(PUBLIC_KEY, true);
