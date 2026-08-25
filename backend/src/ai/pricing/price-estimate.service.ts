import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import {
  AdvisoryPriceEstimate,
  PriceEstimateResponse,
} from '../../../../shared/price-estimate.types';
import { ServiceCategoriesService } from '../../services/service-categories.service';
import { Booking } from '../../bookings/domain/booking.entity';
import {
  PaymentOrder,
  PaymentOrderStatus,
} from '../../payments/domain/payment-order.entity';

/**
 * FN-060 policy thresholds. Owned by product/AI like the trust rules; a
 * change must go through the versioned evaluation suite.
 */
export const PRICE_ESTIMATE_RULES = {
  /** Paid orders required before the observed band replaces the published anchor. */
  observedMinSamples: 5,
  sampleCap: 50,
  advisoryNotice:
    'Advisory only — FixNow confirms the final charge for your booking before payment.',
} as const;

@Injectable()
export class PriceEstimateService {
  constructor(
    private readonly categories: ServiceCategoriesService,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  /**
   * FN-060: deterministic advisory range grounded in the admin-published
   * price and, where enough history exists, real paid orders for the
   * category. A model never determines a price (ADR-0014); this is a plain
   * explainable read of authoritative data and never feeds booking totals.
   */
  async estimate(serviceCategoryId: string): Promise<PriceEstimateResponse> {
    const category = (await this.categories.getActiveCategories()).find(
      (item) => item.id === serviceCategoryId,
    );
    if (!category) throw new NotFoundException('Service category not found');

    const paid = await this.paidOrders(category.id);
    if (paid.length >= PRICE_ESTIMATE_RULES.observedMinSamples) {
      const amounts = paid.map((row) => row.amountMinor).sort((a, b) => a - b);
      const estimate: AdvisoryPriceEstimate = {
        kind: 'ESTIMATE',
        serviceCategoryId: category.id,
        currency: paid[0].currency,
        minAmountMinor: amounts[0],
        maxAmountMinor: amounts[amounts.length - 1],
        typicalAmountMinor: amounts[Math.floor((amounts.length - 1) / 2)],
        basis: 'OBSERVED',
        sampleSize: amounts.length,
        explanation: `Typical range across ${amounts.length} completed FixNow bookings in this category.`,
        advisoryNotice: PRICE_ESTIMATE_RULES.advisoryNotice,
      };
      return estimate;
    }

    if (category.pricing) {
      return {
        kind: 'ESTIMATE',
        serviceCategoryId: category.id,
        currency: category.pricing.currency,
        minAmountMinor: category.pricing.amountMinor,
        maxAmountMinor: category.pricing.amountMinor,
        typicalAmountMinor: category.pricing.amountMinor,
        basis: 'PUBLISHED',
        sampleSize: null,
        explanation:
          'FixNow publishes a standard price for this service category.',
        advisoryNotice: PRICE_ESTIMATE_RULES.advisoryNotice,
      };
    }

    return {
      kind: 'PRICE_ON_REQUEST',
      serviceCategoryId: category.id,
      explanation:
        'This service is priced individually. Create a request and the assigned provider will confirm the price.',
    };
  }

  private async paidOrders(
    categoryId: string,
  ): Promise<Array<{ amountMinor: number; currency: string }>> {
    const rows = await this.dataSource
      .getRepository(PaymentOrder)
      .createQueryBuilder('order')
      .innerJoin(Booking, 'booking', 'booking.id = order.bookingId')
      .where('booking.service_category_id = :categoryId', { categoryId })
      .andWhere('order.status = :status', {
        status: PaymentOrderStatus.PAID,
      })
      .orderBy('order.created_at', 'DESC')
      .take(PRICE_ESTIMATE_RULES.sampleCap)
      .select('order.amount_minor AS amount_minor')
      .addSelect('order.currency AS currency')
      .getRawMany<{ amount_minor: number | string; currency: string }>();
    return rows.map((row) => ({
      amountMinor: Number(row.amount_minor),
      currency: row.currency,
    }));
  }
}
