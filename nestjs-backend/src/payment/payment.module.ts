import { Module } from '@nestjs/common';
import { SaferpayService } from './saferpay.service';
import { InvoiceModule } from '../invoice/invoice.module';

@Module({
  imports: [InvoiceModule],
  providers: [SaferpayService],
  exports: [SaferpayService],
})
export class PaymentModule {}
