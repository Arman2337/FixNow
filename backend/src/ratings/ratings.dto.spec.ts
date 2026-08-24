import { validate } from 'class-validator';
import { CreateReviewDto } from './ratings.dto';

describe('CreateReviewDto', () => {
  it.each([0, 6, 2.5])(
    'rejects invalid bounded integer rating %s',
    async (rating) => {
      const dto = Object.assign(new CreateReviewDto(), { rating });
      expect(await validate(dto)).not.toHaveLength(0);
    },
  );

  it('accepts a rating with no optional text and rejects excessive text', async () => {
    expect(
      await validate(Object.assign(new CreateReviewDto(), { rating: 5 })),
    ).toHaveLength(0);
    expect(
      await validate(
        Object.assign(new CreateReviewDto(), {
          rating: 5,
          reviewText: 'x'.repeat(1001),
        }),
      ),
    ).not.toHaveLength(0);
  });
});
