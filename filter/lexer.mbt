///|
pub(all) enum TokenKind {
  LeftParen
  RightParen
  LeftBracket
  RightBracket
  Identifier(String)
  StringValue(String)
  NumberValue(String)
  BooleanValue(Bool)
  NullValue
  Eq
  Ne
  Co
  Sw
  Ew
  Gt
  Ge
  Lt
  Le
  Pr
  And
  Or
  Not
  End
} derive(Debug, Eq)

///|
pub struct Token {
  kind : TokenKind
  offset : Int
} derive(Debug, Eq)

///|
pub(all) enum LexError {
  InvalidToken(Int, String)
  UnterminatedString(Int)
  InvalidEscape(Int, Char)
} derive(Debug, Eq)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  self.kind
}

///|
pub fn Token::offset(self : Token) -> Int {
  self.offset
}

///|
pub fn lex_filter(text : String) -> Result[Array[Token], LexError] {
  let tokens : Array[Token] = []
  let mut cursor = 0
  while cursor < text.length() {
    let character = text[cursor].to_int().unsafe_to_char()
    if whitespace(character) {
      cursor = cursor + 1
      continue
    }
    match character {
      '(' => {
        tokens.push(token(LeftParen, cursor))
        cursor = cursor + 1
      }
      ')' => {
        tokens.push(token(RightParen, cursor))
        cursor = cursor + 1
      }
      '[' => {
        tokens.push(token(LeftBracket, cursor))
        cursor = cursor + 1
      }
      ']' => {
        tokens.push(token(RightBracket, cursor))
        cursor = cursor + 1
      }
      '"' =>
        match read_quoted(text, cursor) {
          Ok((value, next)) => {
            tokens.push(token(StringValue(value), cursor))
            cursor = next
          }
          Err(error) => return Err(error)
        }
      _ => {
        if !bare_character(character) {
          return Err(InvalidToken(cursor, text[cursor:cursor + 1].to_owned()))
        }
        let start = cursor
        cursor = cursor + 1
        while cursor < text.length() &&
              bare_character(text[cursor].to_int().unsafe_to_char()) {
          cursor = cursor + 1
        }
        let raw = text[start:cursor].to_owned()
        tokens.push(token(classify_bare(raw), start))
      }
    }
  }
  tokens.push(token(End, text.length()))
  Ok(tokens)
}

///|
fn classify_bare(raw : String) -> TokenKind {
  match raw.to_lower() {
    "eq" => Eq
    "ne" => Ne
    "co" => Co
    "sw" => Sw
    "ew" => Ew
    "gt" => Gt
    "ge" => Ge
    "lt" => Lt
    "le" => Le
    "pr" => Pr
    "and" => And
    "or" => Or
    "not" => Not
    "true" => BooleanValue(true)
    "false" => BooleanValue(false)
    "null" => NullValue
    _ => if numeric_candidate(raw) { NumberValue(raw) } else { Identifier(raw) }
  }
}

///|
fn read_quoted(text : String, start : Int) -> Result[(String, Int), LexError] {
  let output = StringBuilder()
  let mut cursor = start + 1
  while cursor < text.length() {
    let character = text[cursor].to_int().unsafe_to_char()
    if character == '"' {
      return Ok((output.to_string(), cursor + 1))
    }
    if character == '\\' {
      if cursor + 1 >= text.length() {
        return Err(UnterminatedString(start))
      }
      let escaped = text[cursor + 1].to_int().unsafe_to_char()
      match escaped {
        '"' => output.write_char('"')
        '\\' => output.write_char('\\')
        '/' => output.write_char('/')
        'b' => output.write_char('\b')
        'f' => output.write_char('\u{000c}')
        'n' => output.write_char('\n')
        'r' => output.write_char('\r')
        't' => output.write_char('\t')
        _ => return Err(InvalidEscape(cursor, escaped))
      }
      cursor = cursor + 2
    } else {
      if character.to_int() < 32 {
        return Err(InvalidToken(cursor, "control character in string"))
      }
      output.write_char(character)
      cursor = cursor + 1
    }
  }
  Err(UnterminatedString(start))
}

///|
fn numeric_candidate(value : String) -> Bool {
  if value.is_empty() {
    return false
  }
  let first = value[0].to_int().unsafe_to_char()
  if !first.is_ascii_digit() && first != '-' {
    return false
  }
  let mut digits = 0
  for character in value {
    if character.is_ascii_digit() {
      digits = digits + 1
    } else if character != '-' &&
      character != '+' &&
      character != '.' &&
      character != 'e' &&
      character != 'E' {
      return false
    }
  }
  digits > 0
}

///|
fn whitespace(value : Char) -> Bool {
  value == ' ' || value == '\t' || value == '\r' || value == '\n'
}

///|
fn bare_character(value : Char) -> Bool {
  value.is_ascii_alphabetic() ||
  value.is_ascii_digit() ||
  value == '$' ||
  value == '-' ||
  value == '_' ||
  value == '.' ||
  value == ':' ||
  value == '/' ||
  value == '~' ||
  value == '%' ||
  value == '+'
}

///|
fn token(kind : TokenKind, offset : Int) -> Token {
  { kind, offset, }
}
