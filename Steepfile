D = Steep::Diagnostic

target :lib do
  signature "sig/generated"

  check "lib"

  library "logger"
  library "anthropic"
  library "openai"
  library "aws-sdk-bedrockruntime"

  configure_code_diagnostics(D::Ruby.lenient)
end
