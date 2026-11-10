//! Reads and writes the case format shared with `ts/oracle.ts`, so both implementations can be
//! run on the same lines and compared as text.

use crate::{price_cart, Cart, CartLine, PricingError};

fn number(text: &str) -> f64 {
    text.trim().parse::<f64>().unwrap_or(f64::NAN)
}

fn show(value: f64) -> String {
    if value.is_infinite() {
        return if value > 0.0 {
            "Infinity".to_owned()
        } else {
            "-Infinity".to_owned()
        };
    }
    format!("{value}")
}

#[must_use]
pub fn parse_case(line: &str) -> Cart {
    let mut parts = line.split(';');
    let tax = parts.next().unwrap_or("").trim_start_matches("tax=");
    let pct = parts.next().unwrap_or("").trim_start_matches("pct=");
    let items = parts.next().unwrap_or("");
    let lines = items
        .split(',')
        .filter(|s| !s.is_empty())
        .map(|item| {
            let mut f = item.split(':');
            CartLine {
                sku: f.next().unwrap_or("").to_owned(),
                qty: f.next().unwrap_or("").trim().parse().unwrap_or(0),
                unit_minor: f.next().unwrap_or("").trim().parse().unwrap_or(0),
            }
        })
        .collect();
    Cart {
        lines,
        coupon_pct: if pct.is_empty() {
            None
        } else {
            Some(number(pct))
        },
        tax_bps: number(tax),
    }
}

/// Runs one case line and returns the result line, in the oracle's format.
#[must_use]
pub fn run_case(line: &str) -> String {
    match price_cart(&parse_case(line)) {
        Err(PricingError::EmptyCart) => "err;EmptyCart".to_owned(),
        Err(PricingError::InvalidCoupon { coupon_pct }) => {
            format!("err;InvalidCoupon;{}", show(coupon_pct))
        }
        Err(PricingError::InvalidTax { tax_bps }) => format!("err;InvalidTax;{}", show(tax_bps)),
        Ok(v) => {
            let lines: Vec<String> = v
                .lines
                .iter()
                .map(|l| format!("{}:{}", l.subtotal_minor, l.discount_minor))
                .collect();
            format!(
                "ok;sub={};disc={};tax={};total={};lines={}",
                v.subtotal_minor,
                v.discount_minor,
                v.tax_minor,
                v.total_minor,
                lines.join(",")
            )
        }
    }
}

/// Compares every `case => expected` line in `text`. Returns (matched, total, first mismatches).
#[must_use]
pub fn compare(text: &str) -> (usize, usize, Vec<String>) {
    let mut matched = 0;
    let mut total = 0;
    let mut wrong = Vec::new();
    for raw in text.lines() {
        let Some((input, expected)) = raw.split_once(" => ") else {
            continue;
        };
        if input.trim_start().starts_with('#') {
            continue;
        }
        total += 1;
        let got = run_case(input.trim());
        if got == expected.trim() {
            matched += 1;
        } else if wrong.len() < 5 {
            wrong.push(format!("{input}\n  expected {expected}\n  got      {got}"));
        }
    }
    (matched, total, wrong)
}
