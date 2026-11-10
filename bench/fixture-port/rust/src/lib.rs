//! Cart pricing. A port of `ts/price-cart.ts`, which stays the specification until cutover.

pub mod caseio;
mod price;

pub use price::price_cart;

#[derive(Debug, Clone, PartialEq)]
pub struct CartLine {
    pub sku: String,
    pub qty: i64,
    pub unit_minor: i64,
}

/// `coupon_pct` and `tax_bps` are `f64` because callers send JSON numbers and the old
/// implementation validates them itself, including values that are not whole numbers.
#[derive(Debug, Clone, PartialEq)]
pub struct Cart {
    pub lines: Vec<CartLine>,
    pub coupon_pct: Option<f64>,
    pub tax_bps: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PricedLine {
    pub sku: String,
    pub qty: i64,
    pub subtotal_minor: i64,
    pub discount_minor: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PricedCart {
    pub lines: Vec<PricedLine>,
    pub subtotal_minor: i64,
    pub discount_minor: i64,
    pub tax_minor: i64,
    pub total_minor: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub enum PricingError {
    EmptyCart,
    InvalidCoupon { coupon_pct: f64 },
    InvalidTax { tax_bps: f64 },
}
