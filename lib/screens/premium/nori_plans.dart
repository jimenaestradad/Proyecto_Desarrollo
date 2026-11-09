/// The paid plans Nori would sell, shared by the Nori Plus and payment preview
/// screens so the two can't disagree on a price. Prices and what each plan
/// includes: docs/business/COTIZACION.md, Part 2. Preview only: nothing is
/// billed, and no plan limit is enforced anywhere yet.
enum PlanTier { plus, duo }

enum BillingPeriod { monthly, yearly }

class PlanChoice {
  const PlanChoice(this.tier, this.period);

  final PlanTier tier;
  final BillingPeriod period;

  bool get isYearly => period == BillingPeriod.yearly;

  String get name => tier == PlanTier.plus ? 'Nori Plus' : 'Nori Duo';

  String get title => '$name ${isYearly ? 'yearly' : 'monthly'}';

  /// Dollar amount only, e.g. `$29.99`.
  String get price => switch ((tier, period)) {
    (PlanTier.plus, BillingPeriod.monthly) => r'$3.99',
    (PlanTier.plus, BillingPeriod.yearly) => r'$29.99',
    (PlanTier.duo, BillingPeriod.monthly) => r'$5.99',
    (PlanTier.duo, BillingPeriod.yearly) => r'$44.99',
  };

  /// `/month` or `/year`.
  String get unit => isYearly ? '/year' : '/month';

  /// e.g. `$29.99 / year`.
  String get priceLabel => '$price / ${isYearly ? 'year' : 'month'}';
}
