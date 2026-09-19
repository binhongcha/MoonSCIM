///|
test "module exposes stable development identity" {
  assert_eq(@moonscim.product_name, "MoonSCIM")
  assert_eq(@moonscim.version, "0.1.1")
}
