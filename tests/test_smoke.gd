extends GutTest

# Smoke test — ensures GUT discovers and runs at least one test so CI exits 0
# on a fresh clone. Delete or replace once your project has real tests under
# tests/domain/.

func test_truth_holds() -> void:
	assert_eq(1 + 1, 2)
