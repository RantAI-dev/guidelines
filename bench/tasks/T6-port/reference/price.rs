use crate::{Cart, PricedCart, PricedLine, PricingError};

/// JavaScript's `Math.round`: ties go towards positive infinity, so -0.5 becomes 0 and -1.5
/// becomes -1. Rust's `f64::round` sends ties away from zero and would give -1 and -2.
fn js_round(value: f64) -> i64 {
    (value + 0.5).floor() as i64
}

/// # Errors
/// The same three errors, checked in the same order, as `ts/price-cart.ts`.
pub fn price_cart(cart: &Cart) -> Result<PricedCart, PricingError> {
    if cart.lines.is_empty() {
        return Err(PricingError::EmptyCart);
    }
    let pct = cart.coupon_pct.unwrap_or(0.0);
    if !pct.is_finite() || !(0.0..=100.0).contains(&pct) {
        return Err(PricingError::InvalidCoupon { coupon_pct: pct });
    }
    let bps = cart.tax_bps;
    if !bps.is_finite() || bps.fract() != 0.0 || !(0.0..=10000.0).contains(&bps) {
        return Err(PricingError::InvalidTax { tax_bps: bps });
    }

    let mut lines = Vec::with_capacity(cart.lines.len());
    let mut subtotal_minor: i64 = 0;
    let mut discount_minor: i64 = 0;
    for line in &cart.lines {
        let sub = line.qty.saturating_mul(line.unit_minor);
        let disc = js_round((sub as f64 * pct) / 100.0);
        lines.push(PricedLine {
            sku: line.sku.clone(),
            qty: line.qty,
            subtotal_minor: sub,
            discount_minor: disc,
        });
        subtotal_minor = subtotal_minor.saturating_add(sub);
        discount_minor = discount_minor.saturating_add(disc);
    }
    let taxable = subtotal_minor.saturating_sub(discount_minor);
    let tax_minor = js_round((taxable as f64 * bps) / 10000.0);
    Ok(PricedCart {
        lines,
        subtotal_minor,
        discount_minor,
        tax_minor,
        total_minor: taxable.saturating_add(tax_minor),
    })
}
