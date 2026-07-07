import 'common.just'

set working-directory := ".."

[group('Builder')]
[no-cd]
build *args:
    @echo "🏗️  Delegating build to openwrt-builder..."
    cd openwrt-builder && just build {{args}}

[group('Builder')]
[no-cd]
list-profiles:
    @echo "📋 Available Builder Profiles:"
    @cd openwrt-builder && just list
