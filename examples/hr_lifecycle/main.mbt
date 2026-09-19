///|
fn main {
  let original = @codec.decode_object(
    (
      #|{"schemas":["urn:ietf:params:scim:schemas:core:2.0:User"],"id":"employee-42","userName":"employee42@example.com","active":true,"title":"Engineer"}
    ),
  ).unwrap()
  let offboarded = @patch.apply_patch(original, [
    @patch.replace("active", @value.boolean(false)),
    @patch.remove("title"),
  ]).unwrap()
  let transition = @validation.validate_transition(
    @standard.standard_registry(),
    @standard.user_schema_id(),
    original,
    offboarded,
    @validation.Patch,
  )
  if !transition.is_valid() {
    abort("the offboarding transition must remain schema-valid")
  }
  println(@codec.encode_object(offboarded).unwrap())
}
