///|
extern "C" fn process_exit(code : Int) = "exit"

///|
fn usage() -> Unit {
  println("moonscim 0.1.0 — portable SCIM 2.0 semantics")
  println("usage:")
  println("  moonscim validate <user-json>")
  println("  moonscim match <filter> <resource-json>")
  println("  moonscim discover")
  println("  moonscim version")
}

///|
fn fail(message : String, code : Int) -> Unit {
  println("error: " + message)
  process_exit(code)
}

///|
fn validate_command(text : String) -> Unit {
  let resource = match @codec.decode_object(text) {
    Ok(resource) => resource
    Err(error) => {
      fail(@debug.to_string(error), 2)
      return
    }
  }
  let report = @validation.validate_resource(
    @standard.standard_registry(),
    @standard.user_schema_id(),
    resource,
    @validation.Create,
  )
  if report.is_valid() {
    println("valid")
  } else {
    for diagnostic in report.diagnostics() {
      println(
        diagnostic.code + "\t" + diagnostic.path + "\t" + diagnostic.message,
      )
    }
    process_exit(3)
  }
}

///|
fn match_command(filter_text : String, resource_text : String) -> Unit {
  let filter = match @filter.compile_filter(filter_text) {
    Ok(filter) => filter
    Err(error) => {
      fail(@debug.to_string(error), 2)
      return
    }
  }
  let resource = match @codec.decode_object(resource_text) {
    Ok(resource) => resource
    Err(error) => {
      fail(@debug.to_string(error), 2)
      return
    }
  }
  println(if filter.matches(resource) { "true" } else { "false" })
}

///|
fn discovery_command() -> Unit {
  let config = @protocol.service_provider_config_resource(
    @protocol.service_provider_config(authentication_schemes=[
      @protocol.authentication_scheme(
        "oauthbearertoken",
        "OAuth Bearer Token",
        spec_uri="https://www.rfc-editor.org/info/rfc6750",
      ),
    ]),
  )
  match @codec.encode_object(config) {
    Ok(json) => println(json)
    Err(error) => fail(@debug.to_string(error), 4)
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    usage()
    process_exit(2)
    return
  }
  match args[1] {
    "validate" =>
      if args.length() == 3 {
        validate_command(args[2])
      } else {
        usage()
        process_exit(2)
      }
    "match" =>
      if args.length() == 4 {
        match_command(args[2], args[3])
      } else {
        usage()
        process_exit(2)
      }
    "discover" =>
      if args.length() == 2 {
        discovery_command()
      } else {
        usage()
        process_exit(2)
      }
    "version" | "--version" | "-V" => println("moonscim 0.1.0")
    "help" | "--help" | "-h" => usage()
    command => fail("unknown command: " + command, 2)
  }
}
