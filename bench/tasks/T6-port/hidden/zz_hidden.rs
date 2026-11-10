#![allow(clippy::panic)]
#[test]
fn hidden_cases() {
    let text = std::fs::read_to_string("../cases/zz_hidden.txt").unwrap_or_default();
    let (matched, total, wrong) = pricing::caseio::compare(&text);
    println!("HIDDEN matched {matched} of {total}");
    for w in wrong {
        println!("MISMATCH {}", w.lines().next().unwrap_or(""));
    }
}
