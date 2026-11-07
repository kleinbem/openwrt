import 'common.just'

set working-directory := ".."

[group('Secrets')]
[no-cd]
edit file:
    @echo "🔐 Editing secret file: {{file}}..."
    cd {{ROOT}}/kleinbem-secrets && sops {{file}}
