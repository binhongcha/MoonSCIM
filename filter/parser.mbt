///|
pub(all) enum ComparisonOperator {
  EqOp
  NeOp
  CoOp
  SwOp
  EwOp
  GtOp
  GeOp
  LtOp
  LeOp
} derive(Debug, Eq)

///|
pub(all) enum Literal {
  StringLiteral(String)
  NumberLiteral(String)
  BooleanLiteral(Bool)
  NullLiteral
} derive(Debug, Eq)

///|
pub(all) enum FilterExpression {
  Present(@path.AttributePath)
  Compare(@path.AttributePath, ComparisonOperator, Literal)
  ValuePathPresent(@path.AttributePath, FilterExpression, String?)
  ValuePathCompare(
    @path.AttributePath,
    FilterExpression,
    String?,
    ComparisonOperator,
    Literal
  )
  AndExpr(FilterExpression, FilterExpression)
  OrExpr(FilterExpression, FilterExpression)
  NotExpr(FilterExpression)
} derive(Debug, Eq)

///|
pub struct Filter {
  expression : FilterExpression
} derive(Debug, Eq)

///|
pub(all) enum FilterError {
  LexFailure(LexError)
  EmptyFilter
  UnexpectedToken(Int, String)
  TrailingToken(Int)
  InvalidAttributePath(Int, @path.PathError)
} derive(Debug, Eq)

///|
pub fn Filter::expression(self : Filter) -> FilterExpression {
  self.expression
}

///|
pub fn compile_filter(text : String) -> Result[Filter, FilterError] {
  let tokens = match lex_filter(text) {
    Ok(value) => value
    Err(error) => return Err(LexFailure(error))
  }
  if tokens[0].kind() == End {
    return Err(EmptyFilter)
  }
  let (expression, next) = match parse_or(tokens, 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if tokens[next].kind() != End {
    return Err(TrailingToken(tokens[next].offset()))
  }
  Ok({ expression, })
}

///|
fn parse_or(
  tokens : Array[Token],
  start : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  let (initial, initial_next) = match parse_and(tokens, start) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut left = initial
  let mut next = initial_next
  while tokens[next].kind() == Or {
    let (right, after) = match parse_and(tokens, next + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = OrExpr(left, right)
    next = after
  }
  Ok((left, next))
}

///|
fn parse_and(
  tokens : Array[Token],
  start : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  let (initial, initial_next) = match parse_not(tokens, start) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut left = initial
  let mut next = initial_next
  while tokens[next].kind() == And {
    let (right, after) = match parse_not(tokens, next + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = AndExpr(left, right)
    next = after
  }
  Ok((left, next))
}

///|
fn parse_not(
  tokens : Array[Token],
  start : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  if tokens[start].kind() == Not {
    match parse_not(tokens, start + 1) {
      Ok((expression, next)) => Ok((NotExpr(expression), next))
      Err(error) => Err(error)
    }
  } else {
    parse_primary(tokens, start)
  }
}

///|
fn parse_primary(
  tokens : Array[Token],
  start : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  if tokens[start].kind() == LeftParen {
    let (expression, next) = match parse_or(tokens, start + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if tokens[next].kind() != RightParen {
      return Err(UnexpectedToken(tokens[next].offset(), "expected ')'"))
    }
    return Ok((expression, next + 1))
  }
  parse_attribute_expression(tokens, start)
}

///|
fn parse_attribute_expression(
  tokens : Array[Token],
  start : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  guard tokens[start].kind() is Identifier(path_text) else {
    return Err(
      UnexpectedToken(tokens[start].offset(), "expected an attribute path"),
    )
  }
  let path = match @path.parse_attribute_path(path_text) {
    Ok(value) => value
    Err(error) =>
      return Err(InvalidAttributePath(tokens[start].offset(), error))
  }
  let next = start + 1
  if tokens[next].kind() == LeftBracket {
    parse_value_path(tokens, path, next)
  } else {
    parse_terminal(tokens, path, next)
  }
}

///|
fn parse_value_path(
  tokens : Array[Token],
  path : @path.AttributePath,
  bracket : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  let (predicate, after_predicate) = match parse_or(tokens, bracket + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if tokens[after_predicate].kind() != RightBracket {
    return Err(
      UnexpectedToken(tokens[after_predicate].offset(), "expected ']'"),
    )
  }
  let mut next = after_predicate + 1
  let mut sub_attribute : String? = None
  match tokens[next].kind() {
    Identifier(value) if value.has_prefix(".") && value.length() > 1 => {
      let candidate = value[1:].to_owned()
      match @path.parse_attribute_path(candidate) {
        Ok(parsed) if parsed.schema_uri is None && parsed.sub_attribute is None => {
          sub_attribute = Some(candidate)
          next = next + 1
        }
        Ok(_) =>
          return Err(
            UnexpectedToken(
              tokens[next].offset(),
              "expected one sub-attribute after value path",
            ),
          )
        Err(error) =>
          return Err(InvalidAttributePath(tokens[next].offset(), error))
      }
    }
    _ => ()
  }
  if tokens[next].kind() == Pr {
    return Ok((ValuePathPresent(path, predicate, sub_attribute), next + 1))
  }
  let operator = match comparison_operator(tokens[next].kind()) {
    Some(value) => value
    None =>
      return Err(
        UnexpectedToken(tokens[next].offset(), "expected comparison or 'pr'"),
      )
  }
  let literal = match literal(tokens[next + 1].kind()) {
    Some(value) => value
    None =>
      return Err(
        UnexpectedToken(tokens[next + 1].offset(), "expected comparison value"),
      )
  }
  Ok(
    (
      ValuePathCompare(path, predicate, sub_attribute, operator, literal),
      next + 2,
    ),
  )
}

///|
fn parse_terminal(
  tokens : Array[Token],
  path : @path.AttributePath,
  operator_index : Int,
) -> Result[(FilterExpression, Int), FilterError] {
  if tokens[operator_index].kind() == Pr {
    return Ok((Present(path), operator_index + 1))
  }
  let operator = match comparison_operator(tokens[operator_index].kind()) {
    Some(value) => value
    None =>
      return Err(
        UnexpectedToken(
          tokens[operator_index].offset(),
          "expected comparison or 'pr'",
        ),
      )
  }
  let value_index = operator_index + 1
  let value = match literal(tokens[value_index].kind()) {
    Some(value) => value
    None =>
      return Err(
        UnexpectedToken(
          tokens[value_index].offset(),
          "expected comparison value",
        ),
      )
  }
  Ok((Compare(path, operator, value), value_index + 1))
}

///|
fn comparison_operator(kind : TokenKind) -> ComparisonOperator? {
  match kind {
    Eq => Some(EqOp)
    Ne => Some(NeOp)
    Co => Some(CoOp)
    Sw => Some(SwOp)
    Ew => Some(EwOp)
    Gt => Some(GtOp)
    Ge => Some(GeOp)
    Lt => Some(LtOp)
    Le => Some(LeOp)
    _ => None
  }
}

///|
fn literal(kind : TokenKind) -> Literal? {
  match kind {
    StringValue(value) => Some(StringLiteral(value))
    NumberValue(value) => Some(NumberLiteral(value))
    BooleanValue(value) => Some(BooleanLiteral(value))
    NullValue => Some(NullLiteral)
    _ => None
  }
}
