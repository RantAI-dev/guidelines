use crate::{Cart, PricedCart, PricingError};

/// # Errors
/// See `ts/price-cart.ts`.
pub fn price_cart(cart: &Cart) -> Result<PricedCart, PricingError> {
    let _ = cart;
    Err(PricingError::EmptyCart)
}
