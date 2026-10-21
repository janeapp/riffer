# frozen_string_literal: true

D = Steep::Diagnostic

# RBS 4.2.0 re-validates every declaration of a module each time its type
# params are read, which is quadratic in how often a module is reopened. The
# openai gem reopens its namespace ~1,600 times, so loading signatures takes
# over a minute per Steep worker. Fixed upstream in
# ruby/rbs a5458a83; delete this once the bundle has an RBS release newer
# than 4.2.
if RBS::Environment::ModuleEntry.instance_method(:validate_type_params).owner == RBS::Environment::ModuleEntry
  validate_once = Module.new do
    def validate_type_params
      return if @validated_decl_count == context_decls.size

      super
      @validated_decl_count = context_decls.size
    end
  end
  RBS::Environment::ModuleEntry.prepend(validate_once)
  RBS::Environment::ClassEntry.prepend(validate_once)
end

target :lib do
  signature "sig/generated"
  signature "sig/manual"
  signature "sig/_private"

  check "lib"

  configure_code_diagnostics(D::Ruby.all_error)
end
