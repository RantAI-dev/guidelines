//! Parity with the old implementation on the committed cases. Do not edit: add your own cases to
//! `cases/extra.txt` (generate the expected side with `bun ts/oracle.ts`).
#![allow(clippy::panic)]

fn check(path: &str) {
    let Ok(text) = std::fs::read_to_string(path) else {
        return;
    };
    let (matched, total, wrong) = pricing::caseio::compare(&text);
    assert!(
        matched == total,
        "{path}: {matched} of {total} cases match\n{}",
        wrong.join("\n")
    );
}

#[test]
fn visible_cases_match_the_old_implementation() {
    check("../cases/visible.txt");
}

#[test]
fn extra_cases_match_the_old_implementation() {
    check("../cases/extra.txt");
}
