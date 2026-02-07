D = Steep::Diagnostic

target :lib do
  signature "sig/generated"

  check "lib"

  library "logger"

  configure_code_diagnostics(D::Ruby.lenient)
end
