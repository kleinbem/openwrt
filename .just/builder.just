import 'common.just'

set working-directory := ".."

[group('Builder')]
[no-cd]
build *args:
    @echo "🏗️  Delegating build to openwrt-builder..."
    cd {{ROOT}}/openwrt-builder && just build {{args}}

[group('Builder')]
[no-cd]
list-profiles:
    @echo "📋 Available Builder Profiles:"
    @cd {{ROOT}}/openwrt-builder && just list
