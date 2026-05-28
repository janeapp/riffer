D = Steep::Diagnostic

target :lib do
  signature "sig/generated"
  signature "sig/stubs"

  check "lib"

  library "anthropic"
  library "aws-sdk-bedrockruntime"
  library "aws-sdk-core"
  library "base64"
  library "json"
  library "logger"
  library "net-http"
  library "openai"
  library "securerandom"
  library "uri"

  configure_code_diagnostics(D::Ruby.lenient)
end
