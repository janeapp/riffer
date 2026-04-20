D = Steep::Diagnostic

target :lib do
  signature "sig/generated"

  check "lib"

  library "anthropic"
  library "aws-sdk-bedrockruntime"
  library "aws-sdk-core"
  library "logger"
  library "net-http"
  library "openai"
  library "uri"

  configure_code_diagnostics(D::Ruby.lenient)
end
