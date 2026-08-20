D = Steep::Diagnostic

target :lib do
  signature "sig/generated"
  signature "sig/manual"
  signature "sig/_private"

  check "lib"

  library "anthropic"
  library "aws-sdk-bedrockruntime"
  library "aws-sdk-core"
  library "base64"
  library "cgi"
  library "digest"
  library "json"
  library "logger"
  library "net-http"
  library "openai"
  library "securerandom"
  library "uri"
  library "yaml"

  configure_code_diagnostics(D::Ruby.strict)
end
