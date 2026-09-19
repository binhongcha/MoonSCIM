///|
pub fn Filter::matches(self : Filter, resource : @value.Object) -> Bool {
  evaluate_expression(self.expression, resource)
}

///|
fn evaluate_expression(
  expression : FilterExpression,
  resource : @value.Object,
) -> Bool {
  match expression {
    Present(path) => values_for_path(resource, path).length() > 0
    Compare(path, operator, literal) =>
      compare_values(values_for_path(resource, path), operator, literal)
    AndExpr(left, right) =>
      evaluate_expression(left, resource) &&
      evaluate_expression(right, resource)
    OrExpr(left, right) =>
      evaluate_expression(left, resource) ||
      evaluate_expression(right, resource)
    NotExpr(inner) => !evaluate_expression(inner, resource)
    ValuePathPresent(path, predicate, sub_attribute) =>
      evaluate_value_path(resource, path, predicate, sub_attribute, None)
    ValuePathCompare(path, predicate, sub_attribute, operator, literal) =>
      evaluate_value_path(
        resource,
        path,
        predicate,
        sub_attribute,
        Some((operator, literal)),
      )
  }
}

///|
fn evaluate_value_path(
  resource : @value.Object,
  path : @path.AttributePath,
  predicate : FilterExpression,
  sub_attribute : String?,
  comparison : (ComparisonOperator, Literal)?,
) -> Bool {
  let values = raw_values_for_path(resource, path)
  for value in values {
    let candidates = match value.as_list() {
      Some(items) => items
      None => [value]
    }
    for candidate in candidates {
      guard candidate.as_object() is Some(object) else { continue }
      if !evaluate_expression(predicate, object) {
        continue
      }
      let selected = match sub_attribute {
        None => [candidate]
        Some(name) =>
          match object.get(name) {
            None => []
            Some(item) => flatten(item)
          }
      }
      match comparison {
        None => if !selected.is_empty() { return true }
        Some((operator, literal)) =>
          if compare_values(selected, operator, literal) {
            return true
          }
      }
    }
  }
  false
}

///|
fn values_for_path(
  resource : @value.Object,
  path : @path.AttributePath,
) -> Array[@value.Value] {
  let raw = raw_values_for_path(resource, path)
  let result : Array[@value.Value] = []
  for value in raw {
    for item in flatten(value) {
      if !item.is_null() {
        result.push(item)
      }
    }
  }
  result
}

///|
fn raw_values_for_path(
  resource : @value.Object,
  path : @path.AttributePath,
) -> Array[@value.Value] {
  let container = match path.schema_uri {
    None => Some(resource)
    Some(uri) =>
      match resource.get(uri) {
        Some(value) => value.as_object()
        None => None
      }
  }
  guard container is Some(object) else { return [] }
  guard object.get(path.attribute) is Some(attribute_value) else { return [] }
  match path.sub_attribute {
    None => [attribute_value]
    Some(name) => {
      let result : Array[@value.Value] = []
      for candidate in flatten(attribute_value) {
        match candidate.as_object() {
          Some(complex) =>
            match complex.get(name) {
              Some(item) => result.push(item)
              None => ()
            }
          None => ()
        }
      }
      result
    }
  }
}

///|
fn flatten(value : @value.Value) -> Array[@value.Value] {
  match value.as_list() {
    Some(items) => items
    None => [value]
  }
}

///|
fn compare_values(
  values : Array[@value.Value],
  operator : ComparisonOperator,
  literal : Literal,
) -> Bool {
  for value in values {
    if compare_one(value, operator, literal) {
      return true
    }
  }
  false
}

///|
fn compare_one(
  value : @value.Value,
  operator : ComparisonOperator,
  literal : Literal,
) -> Bool {
  match literal {
    StringLiteral(expected) =>
      match value.as_string() {
        Some(actual) => compare_string(actual, expected, operator)
        None => false
      }
    BooleanLiteral(expected) =>
      match value.as_boolean() {
        Some(actual) => compare_bool(actual, expected, operator)
        None => false
      }
    NumberLiteral(expected) =>
      match (value.as_number(), parse_number(expected)) {
        (Some(actual), Some(wanted)) => compare_number(actual, wanted, operator)
        _ => false
      }
    NullLiteral =>
      match operator {
        EqOp => value.is_null()
        NeOp => !value.is_null()
        _ => false
      }
  }
}

///|
fn compare_string(
  actual : String,
  expected : String,
  operator : ComparisonOperator,
) -> Bool {
  let left = actual.to_lower()
  let right = expected.to_lower()
  match operator {
    EqOp => left == right
    NeOp => left != right
    CoOp => left.contains(right)
    SwOp => left.has_prefix(right)
    EwOp => left.has_suffix(right)
    GtOp => left > right
    GeOp => left >= right
    LtOp => left < right
    LeOp => left <= right
  }
}

///|
fn compare_bool(
  actual : Bool,
  expected : Bool,
  operator : ComparisonOperator,
) -> Bool {
  match operator {
    EqOp => actual == expected
    NeOp => actual != expected
    _ => false
  }
}

///|
fn compare_number(
  actual : Double,
  expected : Double,
  operator : ComparisonOperator,
) -> Bool {
  match operator {
    EqOp => actual == expected
    NeOp => actual != expected
    GtOp => actual > expected
    GeOp => actual >= expected
    LtOp => actual < expected
    LeOp => actual <= expected
    _ => false
  }
}

///|
fn parse_number(value : String) -> Double? {
  Some(@string.parse_double(value)) catch {
    _ => None
  }
}
